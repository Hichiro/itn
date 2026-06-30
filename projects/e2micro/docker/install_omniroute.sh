#!/bin/bash

# ================================================
# OmniRoute Docker Installer - Manual URL Version
# ================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APP_DIR="$HOME/omniroute"
DATA_DIR="$HOME/omniroute-data"

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   CÀI ĐẶT OMNIROUTE DOCKER (v2.3)       ${NC}"
echo -e "${GREEN}=========================================${NC}"

# 1. Kiểm tra công cụ hệ thống
check_dependencies() {
    for cmd in curl openssl docker; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}❌ Lỗi: Máy bạn chưa cài $cmd. Vui lòng cài đặt trước khi chạy script.${NC}"
            exit 1
        fi
    done

    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        echo -e "${RED}❌ Lỗi: Máy bạn chưa cài Docker Compose.${NC}"
        exit 1
    fi
}

check_dependencies

# 2. Tạo thư mục và phân quyền
mkdir -p "$APP_DIR"
mkdir -p "$DATA_DIR"
chmod -R 777 "$DATA_DIR"
cd "$APP_DIR"

# 3. Xóa container cũ nếu có
if docker ps -a --format '{{.Names}}' | grep -q "^omniroute$"; then
    echo "🗑️ Đang dọn dẹp container cũ..."
    $COMPOSE_CMD down 2>/dev/null || true
    docker rm -f omniroute 2>/dev/null || true
fi

# 4. Tạo file docker-compose.yml
echo "--> Tạo cấu hình docker-compose.yml..."
cat > docker-compose.yml <<EOF
services:
  omniroute:
    image: diegosouzapw/omniroute:latest
    container_name: omniroute
    restart: unless-stopped
    stop_grace_period: 40s
    ports:
      - "20128:20128"
    volumes:
      - $DATA_DIR:/app/data
    env_file:
      - .env
EOF

# 5. Xử lý file .env và Secret Keys
if [ ! -f .env ]; then
    echo "--> Tải file .env mẫu..."
    if ! curl -fsSL https://raw.githubusercontent.com/diegosouzapw/OmniRoute/main/.env.example -o .env; then
        echo -e "${YELLOW}⚠️ Tạo file .env cơ bản...${NC}"
        touch .env
    fi
fi

# A. Tự động tạo Secret Keys nếu chưa có
if ! grep -q "^JWT_SECRET=.\+" .env || ! grep -q "^API_KEY_SECRET=.\+" .env; then
    echo "--> Tạo ngẫu nhiên Secret Keys..."
    JWT_S=$(openssl rand -base64 48 2>/dev/null || echo "jwt-$(date +%s%N)")
    API_S=$(openssl rand -hex 32 2>/dev/null || echo "api-$(date +%s%N)")
    
    grep -q "^JWT_SECRET=" .env && sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$JWT_S|" .env || echo "JWT_SECRET=$JWT_S" >> .env
    grep -q "^API_KEY_SECRET=" .env && sed -i "s|^API_KEY_SECRET=.*|API_KEY_SECRET=$API_S|" .env || echo "API_KEY_SECRET=$API_S" >> .env
fi

# B. Nhập Public URL thủ công (Sửa lỗi Invalid Request Origin)
echo -e "\n${YELLOW}--- Cấu hình Truy cập Dashboard ---${NC}"
read -p "Nhập Domain hoặc IP (Ví dụ: abc.com hoặc 1.2.3.4): " USER_HOST
read -p "Sử dụng HTTPS? (y/n): " USE_HTTPS

# Xử lý giao thức
if [[ "$USE_HTTPS" =~ ^[Yy]$ ]]; then
    PROTOCOL="https://"
else
    PROTOCOL="http://"
fi

# Loại bỏ http:// hoặc https:// nếu người dùng lỡ nhập vào để tránh bị lặp (ví dụ http://http://abc.com)
CLEAN_HOST=$(echo "$USER_HOST" | sed -E 's|^https?://||')

# Ghép lại thành URL hoàn chỉnh
FINAL_URL="${PROTOCOL}${CLEAN_HOST}"

# Ghi vào .env
grep -q "^OMNIROUTE_PUBLIC_BASE_URL=" .env && sed -i "s|^OMNIROUTE_PUBLIC_BASE_URL=.*|OMNIROUTE_PUBLIC_BASE_URL=$FINAL_URL|" .env || echo "OMNIROUTE_PUBLIC_BASE_URL=$FINAL_URL" >> .env

echo -e "${GREEN}✅ Đã thiết lập URL truy cập: $FINAL_URL${NC}\n"

# 6. Khởi chạy Docker
echo "--> Đang khởi chạy OmniRoute..."
if $COMPOSE_CMD up -d; then
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}         CÀI ĐẶT THÀNH CÔNG!             ${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo -e "🌐 Truy cập ngay: $FINAL_URL"
    echo -e "📜 Log: cd $APP_DIR && $COMPOSE_CMD logs -f"
else
    echo -e "${RED}❌ Lỗi khi khởi chạy Docker.${NC}"
    exit 1
fi

#!/bin/bash

# ================================================
# OmniRoute Docker Installer - Fully Automated (Curl-Ready)
# ================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APP_DIR="$HOME/omniroute"
DATA_DIR="$HOME/omniroute-data"

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   CÀI ĐẶT OMNIROUTE DOCKER (Auto)       ${NC}"
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

# 2. Tạo thư mục và phân quyền (Sử dụng sudo để tránh lỗi Permission denied)
mkdir -p "$APP_DIR"
mkdir -p "$DATA_DIR"
sudo chmod -R 777 "$DATA_DIR"
cd "$APP_DIR"

# 3. Tự động dọn dẹp container cũ (Vì chạy auto nên sẽ tự dọn dẹp để cập nhật bản mới nhất)
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
        echo -e "${YELLOW}⚠️ Không tải được. ${NC}"
        touch .env
    fi
fi

# Xử lý Public URL (Ưu tiên Biến Môi Trường -> IP Công Cộng)
# Nếu USER_HOST trống, tự lấy IP server
if [ -z "$USER_HOST" ]; then
    USER_HOST=$(curl -s ifconfig.me || echo "localhost")
fi

# Nếu USE_HTTPS trống, mặc định là 'n'
if [ -z "$USE_HTTPS" ]; then
    USE_HTTPS="n"
fi

if [[ "$USE_HTTPS" =~ ^[Yy]$ ]]; then
    PROTOCOL="https://"
else
    PROTOCOL="http://"
fi

# Xóa http/https nếu người dùng lỡ nhập vào
CLEAN_HOST=$(echo "$USER_HOST" | sed -E 's|^https?://||')
FINAL_URL="${PROTOCOL}${CLEAN_HOST}"

grep -q "^OMNIROUTE_PUBLIC_BASE_URL=" .env && sed -i "s|^OMNIROUTE_PUBLIC_BASE_URL=.*|OMNIROUTE_PUBLIC_BASE_URL=$FINAL_URL|" .env || echo "OMNIROUTE_PUBLIC_BASE_URL=$FINAL_URL" >> .env

echo -e "${GREEN}✅ Cấu hình URL truy cập: $FINAL_URL${NC}"

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

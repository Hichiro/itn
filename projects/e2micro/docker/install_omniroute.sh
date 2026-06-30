#!/bin/bash

# ================================================
# OmniRoute Docker Installer - Custom Password Version
# ================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APP_DIR="$HOME/omniroute"
DATA_DIR="$HOME/omniroute-data"

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   CÀI ĐẶT OMNIROUTE DOCKER (v2.2)        ${NC}"
echo -e "${GREEN}=========================================${NC}"

# 1. Kiểm tra công cụ hệ thống
check_dependencies() {
    for cmd in curl docker; do
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

safe_read() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    if [ ! -t 0 ]; then
        eval "$var_name=\"$default\""
    else
        read -p "$prompt [$default]: " input
        eval "$var_name=\"${input:-$default}\""
    fi
}

check_dependencies

# Tạo thư mục và phân quyền
mkdir -p "$APP_DIR"
mkdir -p "$DATA_DIR"
chmod -R 777 "$DATA_DIR"
cd "$APP_DIR"

# 2. Xử lý container cũ
if docker ps -a --format '{{.Names}}' | grep -q "^omniroute$"; then
    echo -e "${YELLOW}⚠️ Phát hiện container omniroute cũ.${NC}"
    safe_read "Bạn có muốn xóa container cũ để cài mới không?" "Y" confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "🗑️ Đang dọn dẹp..."
        $COMPOSE_CMD down 2>/dev/null || true
        docker rm -f omniroute 2>/dev/null || true
    else
        echo -e "${RED}⛔ Đã hủy cài đặt.${NC}"
        exit 0
    fi
fi

# 3. Tạo file docker-compose.yml
echo "--> Tạo file docker-compose.yml..."
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

# 4. Xử lý file .env
# 4.1. Kiểm tra xem file .env có tồn tại không
if [ ! -f .env ]; then
    echo "--> File .env chưa tồn tại. Đang tải về từ GitHub..."
    if curl -fsSL https://raw.githubusercontent.com/diegosouzapw/OmniRoute/main/.env.example -o .env; then
        echo "✅ Đã tải file .env thành công."
    else
        echo "❌ Không thể tải file .env từ internet. Đang tạo file trống..."
        touch .env
    fi
else
    echo "--> File .env đã tồn tại. Bỏ qua bước tải về."
fi

# 4.2. Kiểm tra từng Secret Key (nếu chưa có hoặc bị để trống thì mới tạo)

# Kiểm tra JWT_SECRET
if ! grep -q "^JWT_SECRET=.\+" .env; then
    echo "--> JWT_SECRET chưa được thiết lập. Đang tạo mã mới..."
    JWT_S=$(openssl rand -base64 48 2>/dev/null || echo "jwt-$(date +%s%N)")
    
    # Nếu trong file đã có dòng JWT_SECRET= (nhưng trống), thì thay thế. Nếu chưa có dòng đó, thì thêm mới vào cuối file.
    if grep -q "^JWT_SECRET=" .env; then
        sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$JWT_S|" .env
    else
        echo "JWT_SECRET=$JWT_S" >> .env
    fi
    echo "✅ Đã tạo JWT_SECRET."
else
    echo "--> JWT_SECRET đã tồn tại. Giữ nguyên."
fi

# Kiểm tra API_KEY_SECRET
if ! grep -q "^API_KEY_SECRET=.\+" .env; then
    echo "--> API_KEY_SECRET chưa được thiết lập. Đang tạo mã mới..."
    API_S=$(openssl rand -hex 32 2>/dev/null || echo "api-$(date +%s%N)")
    
    if grep -q "^API_KEY_SECRET=" .env; then
        sed -i "s|^API_KEY_SECRET=.*|API_KEY_SECRET=$API_S|" .env
    else
        echo "API_KEY_SECRET=$API_S" >> .env
    fi
    echo "✅ Đã tạo API_KEY_SECRET."
else
    echo "--> API_KEY_SECRET đã tồn tại. Giữ nguyên."
fi

# 5. Khởi chạy
echo "--> Đang khởi chạy OmniRoute..."
if $COMPOSE_CMD up -d; then
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}         CÀI ĐẶT THÀNH CÔNG!             ${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo -e "🌐 Truy cập: http://$(curl -s ifconfig.me || echo "localhost"):20128"
    echo -e "🔑 Mật khẩu: $USER_PWD"
    echo -e "📜 Log: cd $APP_DIR && $COMPOSE_CMD logs -f"
else
    echo -e "${RED}❌ Lỗi khi khởi chạy Docker.${NC}"
    exit 1
fi

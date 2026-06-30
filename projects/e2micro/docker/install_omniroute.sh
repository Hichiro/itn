#!/bin/bash

# ================================================
# OmniRoute Docker Installer - Fixed Compose Check
# ================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APP_DIR="$HOME/omniroute"
DATA_DIR="$HOME/omniroute-data"

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   CÀI ĐẶT OMNIROUTE DOCKER (v2.1)        ${NC}"
echo -e "${GREEN}=========================================${NC}"

# 1. Hàm kiểm tra công cụ hệ thống (ĐÃ SỬA)
check_dependencies() {
    # Kiểm tra curl và openssl
    for cmd in curl openssl docker; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}❌ Lỗi: Máy bạn chưa cài $cmd. Vui lòng cài đặt trước khi chạy script.${NC}"
            exit 1
        fi
    done

    # Kiểm tra Docker Compose (V1 hoặc V2)
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
        echo -e "${GREEN}✅ Đã tìm thấy Docker Compose V2${NC}"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
        echo -e "${GREEN}✅ Đã tìm thấy Docker Compose V1${NC}"
    else
        echo -e "${RED}❌ Lỗi: Máy bạn chưa cài Docker Compose.${NC}"
        echo -e "Vui lòng cài đặt bằng lệnh: sudo apt-get install docker-compose-plugin"
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

mkdir -p "$APP_DIR"
mkdir -p "$DATA_DIR"
chmod -R 777 "$DATA_DIR"
cd "$APP_DIR"

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

if [ ! -f .env ]; then
    echo "--> Tải file .env..."
    if curl -fsSL https://raw.githubusercontent.com/diegosouzapw/OmniRoute/main/.env.example -o .env; then
        echo -e "${GREEN}✅ Thành công.${NC}"
    else
        echo -e "${YELLOW}⚠️ Tạo .env tạm thời...${NC}"
        echo -e "JWT_SECRET=\nAPI_KEY_SECRET=\nINITIAL_PASSWORD=admin123" > .env
    fi
fi

if ! grep -q "^JWT_SECRET=.\+" .env || ! grep -q "^API_KEY_SECRET=.\+" .env; then
    echo "--> Tạo Secret keys..."
    JWT_S=$(openssl rand -base64 48 2>/dev/null || echo "jwt-$(date +%s%N)")
    API_S=$(openssl rand -hex 32 2>/dev/null || echo "api-$(date +%s%N)")
    sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$JWT_S|" .env
    sed -i "s|^API_KEY_SECRET=.*|API_KEY_SECRET=$API_S|" .env
fi

echo -e "${YELLOW}⚠️ Kiểm tra mật khẩu tại: $APP_DIR/.env${NC}"
if [ -t 0 ]; then
    safe_read "Nhấn Enter để khởi chạy..." "" dummy
fi

echo "--> Đang khởi chạy OmniRoute..."
if $COMPOSE_CMD up -d; then
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}         CÀI ĐẶT THÀNH CÔNG!             ${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo -e "🌐 Truy cập: http://$(curl -s ifconfig.me || echo "localhost"):20128"
    echo -e "📜 Log: cd $APP_DIR && $COMPOSE_CMD logs -f"
else
    echo -e "${RED}❌ Lỗi khi khởi chạy Docker.${NC}"
    exit 1
fi

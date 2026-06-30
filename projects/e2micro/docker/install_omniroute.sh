#!/bin/bash

# ================================================
# OmniRoute Docker Installer - Ultra Lean (Auto)
# ================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APP_DIR="$HOME/omniroute"
DATA_DIR="$HOME/omniroute-data"

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   CÀI ĐẶT OMNIROUTE DOCKER (Lean)       ${NC}"
echo -e "${GREEN}=========================================${NC}"

# 1. Kiểm tra công cụ cơ bản
for cmd in curl docker; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}❌ Lỗi: Máy bạn chưa cài $cmd.${NC}"
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

# 2. Tạo thư mục và Fix quyền ghi (Sử dụng sudo để triệt tiêu lỗi Permission)
mkdir -p "$APP_DIR"
mkdir -p "$DATA_DIR"
sudo chmod -R 777 "$DATA_DIR"
cd "$APP_DIR"

# 3. Dọn dẹp container cũ để cập nhật
if docker ps -a --format '{{.Names}}' | grep -q "^omniroute$"; then
    echo "🗑️ Đang dọn dẹp container cũ..."
    $COMPOSE_CMD down 2>/dev/null || true
    docker rm -f omniroute 2>/dev/null || true
fi

# 4. Tạo file docker-compose.yml
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

# 5. Xử lý file .env (Chỉ tải mẫu và set Public URL)
if [ ! -f .env ]; then
    curl -fsSL https://raw.githubusercontent.com/diegosouzapw/OmniRoute/main/.env.example -o .env || touch .env
fi

# Xử lý Public URL để tránh lỗi "Invalid request origin"
# Ưu tiên: Biến môi trường USER_HOST -> IP công cộng -> localhost
HOST=${USER_HOST:-$(curl -s ifconfig.me || echo "localhost")}
PROTOCOL=${USE_HTTPS:+https://} # Nếu USE_HTTPS=y thì dùng https://
[ -z "$PROTOCOL" ] && PROTOCOL="http://"

# Loại bỏ http/https nếu người dùng lỡ nhập vào USER_HOST
CLEAN_HOST=$(echo "$HOST" | sed -E 's|^https?://||')
FINAL_URL="${PROTOCOL}${CLEAN_HOST}"

# Ghi/Ghi đè OMNIROUTE_PUBLIC_BASE_URL vào .env
grep -q "^OMNIROUTE_PUBLIC_BASE_URL=" .env && \
    sed -i "s|^OMNIROUTE_PUBLIC_BASE_URL=.*|OMNIROUTE_PUBLIC_BASE_URL=$FINAL_URL|" .env || \
    echo "OMNIROUTE_PUBLIC_BASE_URL=$FINAL_URL" >> .env

echo -e "${GREEN}✅ Cấu hình URL truy cập: $FINAL_URL${NC}"

# 6. Khởi chạy
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

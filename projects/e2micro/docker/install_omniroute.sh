#!/bin/bash

# ================================================
# OmniRoute Docker Installer - Interactive Curl Version
# ================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APP_DIR="$HOME/omniroute"
DATA_DIR="$HOME/omniroute-data"

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   CÀI ĐẶT OMNIROUTE DOCKER (Interactive)  ${NC}"
echo -e "${GREEN}=========================================${NC}"

# 1. Kiểm tra công cụ
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

# 2. Tạo thư mục và Fix quyền ghi (Sử dụng sudo)
mkdir -p "$APP_DIR"
mkdir -p "$DATA_DIR"
sudo chmod -R 777 "$DATA_DIR"
cd "$APP_DIR"

# 3. Hỏi xác nhận dọn dẹp container cũ (Sử dụng </dev/tty)
if docker ps -a --format '{{.Names}}' | grep -q "^omniroute$"; then
    echo -e "\n${YELLOW}⚠️ Phát hiện container 'omniroute' cũ đang tồn tại.${NC}"
    read -p "👉 Bạn có muốn xóa container cũ để cài mới không? (Y/n): " confirm </dev/tty
    if [[ "$confirm" =~ ^[Yy]$ ]] || [[ -z "$confirm" ]]; then
        echo "🗑️ Đang dọn dẹp container cũ..."
        $COMPOSE_CMD down 2>/dev/null || true
        docker rm -f omniroute 2>/dev/null || true
    else
        echo -e "${GREEN}⏩ Bỏ qua bước dọn dẹp.${NC}"
    fi
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

# 5. Xử lý file .env
if [ ! -f .env ]; then
    curl -fsSL https://raw.githubusercontent.com/diegosouzapw/OmniRoute/main/.env.example -o .env || touch .env
fi

# 6. NHẬP CẤU HÌNH URL (Sử dụng </dev/tty để chạy được với curl)
echo -e "\n${YELLOW}--- 🌐 Cấu hình Truy cập Dashboard ---${NC}"
read -p "👉 Nhập Domain hoặc IP (Ví dụ: abc.com): " USER_HOST </dev/tty
read -p "👉 Sử dụng HTTPS? (y/n): " USE_HTTPS </dev/tty

# Xử lý logic URL
if [[ "$USE_HTTPS" =~ ^[Yy]$ ]]; then
    PROTOCOL="https://"
else
    PROTOCOL="http://"
fi

# Loại bỏ http/https nếu lỡ nhập
CLEAN_HOST=$(echo "$USER_HOST" | sed -E 's|^https?://||')
FINAL_URL="${PROTOCOL}${CLEAN_HOST}"

# Ghi vào .env
grep -q "^OMNIROUTE_PUBLIC_BASE_URL=" .env && \
    sed -i "s|^OMNIROUTE_PUBLIC_BASE_URL=.*|OMNIROUTE_PUBLIC_BASE_URL=$FINAL_URL|" .env || \
    echo "OMNIROUTE_PUBLIC_BASE_URL=$FINAL_URL" >> .env

echo -e "${GREEN}✅ Đã thiết lập URL: $FINAL_URL${NC}"

# 7. Khởi chạy
echo -e "\n--> Đang khởi chạy OmniRoute..."
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

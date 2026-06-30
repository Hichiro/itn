#!/bin/bash
# ================================================
# OmniRoute Docker Installer - Data lưu user
# ================================================

set -e

APP_DIR="$HOME/omniroute"
DATA_DIR="$HOME/omniroute-data"

echo "========================================="
echo " CÀI ĐẶT OMNIROUTE DOCKER"
echo "========================================="

# Hàm đọc input an toàn
safe_read() {
    if [ -t 0 ]; then
        read "$@"
    else
        read "$@" </dev/tty
    fi
}

# 1. Tạo thư mục
mkdir -p "$APP_DIR"
mkdir -p "$DATA_DIR"
cd "$APP_DIR"

# 2. Hỏi xóa container cũ
if docker ps -a --format '{{.Names}}' | grep -q "^omniroute$"; then
    echo "⚠️ Phát hiện container cũ."
    safe_read -p "Bạn có muốn xóa container cũ không? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]] || [[ -z "$confirm" ]]; then
        echo "🗑️ Đang xóa container cũ..."
        docker compose down 2>/dev/null || true
        docker rm -f omniroute 2>/dev/null || true
    else
        echo "⛔ Hủy cài đặt."
        exit 0
    fi
fi

# 3. Tạo docker-compose.yml
echo "--> Tạo file docker-compose.yml..."
cat > docker-compose.yml <<EOF
version: '3.8'
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

# 4. Tạo .env nếu chưa có
if [ ! -f .env ]; then
    echo "--> Tạo file .env..."
    curl -fsSL https://raw.githubusercontent.com/diegosouzapw/OmniRoute/main/.env.example -o .env
    echo "⚠️ Vui lòng chỉnh sửa INITIAL_PASSWORD"
    echo "   nano .env"
    safe_read -p "Nhấn Enter sau khi chỉnh xong..."
fi

# 5. Khởi chạy
echo "--> Khởi chạy OmniRoute..."
docker compose up -d

echo "========================================="
echo " HOÀN TẤT!"
echo "========================================="
echo "Thư mục cài đặt : $APP_DIR"
echo "Data lưu tại    : $DATA_DIR"
echo "Truy cập        : http://localhost:20128"
echo ""
echo "Kiểm tra log    : cd $APP_DIR && docker compose logs -f"

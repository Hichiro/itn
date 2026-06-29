#!/bin/bash

set -e

echo "========================================="
echo " CÀI ĐẶT OMNIROUTE DOCKER"
echo "========================================="

# 1. Tạo thư mục làm việc
APP_DIR="$HOME/omniroute"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# 2. Tạo file docker-compose.yml
echo "--> Tạo cấu hình docker-compose.yml..."
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
      - omniroute-data:/app/data

volumes:
  omniroute-data:
    name: omniroute-data
EOF

# 3. Kiểm tra trạng thái và khởi chạy
if [ "$(docker ps -q -f name=omniroute)" ]; then
    echo "--> [Bỏ qua] Container omniroute đang hoạt động."
else
    echo "--> Khởi chạy OmniRoute..."
    docker compose up -d
fi

echo "========================================="
echo " HOÀN TẤT!"
echo "========================================="
echo "Thư mục cài đặt: $APP_DIR"
echo "Kiểm tra log: cd $APP_DIR && docker compose logs -f"

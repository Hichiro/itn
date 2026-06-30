#!/bin/bash

set -e

echo "========================================="
echo " CÀI ĐẶT OMNIROUTE DOCKER (TỐI ƯU)"
echo "========================================="

# 1. Tạo thư mục làm việc
APP_DIR="$HOME/omniroute"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# 2. Tạo file .env nếu chưa tồn tại
if [ ! -f ".env" ]; then
    echo "--> Tạo file môi trường..."
    SECRET=$(openssl rand -hex 16 2>/dev/null || date +%s%N | sha256sum | head -c 32)
    echo "OMNIROUTE_WS_BRIDGE_SECRET=$SECRET" > .env
fi

# 3. Tạo file docker-compose.yml (Đã loại bỏ dòng version để tránh cảnh báo)
echo "--> Tạo cấu hình docker-compose.yml..."
cat > docker-compose.yml <<EOF
services:
  omniroute:
    image: diegosouzapw/omniroute:latest
    container_name: omniroute
    restart: unless-stopped
    stop_grace_period: 40s
    env_file:
      - .env
    ports:
      - "20128:20128"
      - "20129:20129"
    volumes:
      - omniroute-data:/app/data

volumes:
  omniroute-data:
    name: omniroute-data
EOF

# 4. Khởi chạy hệ thống
echo "--> Khởi động OmniRoute..."
docker compose pull
docker compose up -d

echo "========================================="
echo " HOÀN TẤT!"
echo "========================================="
echo "Dashboard: http://localhost:20128"
echo "API Port:  20129"

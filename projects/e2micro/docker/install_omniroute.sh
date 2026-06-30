#!/bin/bash

set -e

echo "========================================="
echo " CÀI ĐẶT OMNIROUTE DOCKER (BẢN SIÊU NHẸ - NO CLI)"
echo "========================================="

# 1. Tạo thư mục làm việc
APP_DIR="$HOME/omniroute"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# 2. Tạo chuỗi bảo mật ngẫu nhiên cho biến môi trường
echo "--> Khởi tạo biến môi trường..."
if [ ! -f ".env" ]; then
    SECRET=$(openssl rand -hex 16 2>/dev/null || date +%s%N | sha256sum | head -c 32)
    cat > .env <<EOF
OMNIROUTE_WS_BRIDGE_SECRET=$SECRET
EOF
    echo "--> Đã tạo file .env với chuỗi bảo mật mới."
fi

# 3. Tạo file docker-compose.yml chuẩn
echo "--> Tạo cấu hình docker-compose.yml..."
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  omniroute:
    image: diegosouzapw/omniroute:base
    container_name: omniroute
    restart: unless-stopped
    stop_grace_period: 40s
    env_file:
      - .env
    ports:
      - "20128:20128" # Giao diện Dashboard
      - "20129:20129" # API Gateway cho các ứng dụng
    volumes:
      - omniroute-data:/app/data

volumes:
  omniroute-data:
    name: omniroute-data
EOF

# 4. Kiểm tra trạng thái và khởi chạy
if [ "$(docker ps -q -f name=omniroute)" ]; then
    echo "--> [Bỏ qua] Container omniroute đang hoạt động."
else
    echo "--> Khởi chạy OmniRoute..."
    # Lệnh pull được thêm vào để đảm bảo tải đúng bản base mới nhất trước khi chạy
    docker compose pull 
    docker compose up -d
fi

echo "========================================="
echo " HOÀN TẤT CÀI ĐẶT!"
echo "========================================="
echo "Thư mục cài đặt: $APP_DIR"
echo "Giao diện quản lý: http://localhost:20128"
echo "API Endpoint cho App: http://localhost:20129"
echo "Kiểm tra log bằng lệnh: cd $APP_DIR && docker compose logs -f"

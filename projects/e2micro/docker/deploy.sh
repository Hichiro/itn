#!/bin/bash

set -e

# ⚠️ THAY ĐƯỜNG DẪN RAW GITHUB CỦA BẠN VÀO ĐÂY
GITHUB_RAW_URL="https://raw.githubusercontent.com/Hichiro/itn/refs/heads/main/projects/e2micro/docker/docker-compose.yml"

echo "========================================="
echo " CẤP NHẬT, TRIỂN KHAI & DỌN RÁC IMAGE"
echo "========================================="

# 1. Vào thư mục làm việc
APP_DIR="$HOME/apps"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Hàm ảo để chạy docker compose thông qua container (Bypass giới hạn của COS)
dcompose() {
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v /var/lib/docker:/var/lib/docker:ro \
      -v "$PWD:$PWD" \
      -w "$PWD" \
      docker:latest docker compose "$@"
}

# 2. Tải cấu hình mới từ GitHub
echo "--> 1/4: Đang cập nhật cấu hình từ GitHub..."
curl -sSL "$GITHUB_RAW_URL" -o docker-compose.yml

# 3. Tải Image mới từ Docker Hub (nếu có)
echo "--> 2/4: Đang kiểm tra cập nhật cho các Container..."
dcompose pull

# 4. Khởi chạy lại Container bằng bản mới
echo "--> 3/4: Đang khởi chạy ứng dụng..."
dcompose up -d --remove-orphans

# 5. Tự động xóa sạch các bản Image cũ lỗi thời
echo "--> 4/4: Đang dọn dẹp các Image cũ để giải phóng ổ cứng..."
docker image prune -f

echo "========================================="
echo " ĐÃ CẬP NHẬT VÀ DỌN SẠCH HỆ THỐNG!"
echo "========================================="
dcompose ps

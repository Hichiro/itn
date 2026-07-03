#!/bin/bash

set -e

GITHUB_RAW_URL="https://raw.githubusercontent.com/Hichiro/itn/refs/heads/main/projects/e2micro/docker/docker-compose.yml"

echo "========================================="
echo " CẤP NHẬT, TRIỂN KHAI & DỌN RÁC IMAGE"
echo "========================================="

# 1. Vào thư mục làm việc
APP_DIR="$HOME/apps"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Hàm ảo chạy docker compose (Đã xóa dòng mount log thừa)
dcompose() {
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$PWD:$PWD" \
      -w "$PWD" \
      docker:latest docker compose "$@"
}

# 2. Tải cấu hình mới từ GitHub
echo "--> 1/4: Đang cập nhật cấu hình từ GitHub..."
curl -sSL "$GITHUB_RAW_URL" -o docker-compose.yml

# 3. Tải Image mới từ Docker Hub
echo "--> 2/4: Đang kiểm tra cập nhật cho các Container..."
dcompose pull

# 4. Khởi chạy lại Container bằng bản mới
echo "--> 3/4: Đang khởi chạy ứng dụng..."
dcompose up -d --remove-orphans

# 5. Tự động xóa sạch các bản Image cũ
echo "--> 4/4: Đang dọn dẹp các Image cũ..."
docker image prune -f

# Tự động tạo lệnh phím tắt 'lzd' cho hệ thống nếu chưa có
if ! grep -q "alias lzd=" ~/.bashrc; then
    echo "alias lzd='docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker:/var/lib/docker:ro lazyteam/lazydocker:latest'" >> ~/.bashrc
    source ~/.bashrc
fi

echo "========================================="
echo " ĐÃ CẬP NHẬT VÀ DỌN SẠCH HỆ THỐNG!"
echo "========================================="
dcompose ps

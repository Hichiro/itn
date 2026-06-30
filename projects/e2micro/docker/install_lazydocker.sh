#!/bin/bash

set -e

echo "========================================="
echo " CÀI ĐẶT LAZYDOCKER BINARY TRÊN COS"
echo "========================================="

# 1. Tạo thư mục chứa file chạy cá nhân
BIN_DIR="$HOME/bin"
mkdir -p "$BIN_DIR"

# 2. Tải phiên bản Lazydocker chính thức mới nhất (Linux x86_64)
echo "--> 1/3: Đang tải Lazydocker..."
URL="https://github.com/jesseduffield/lazydocker/releases/latest/download/lazydocker_Linux_x86_64.tar.gz"
curl -sSL "$URL" -o lazydocker.tar.gz

# 3. Giải nén và di chuyển file vào thư mục bin
echo "--> 2/3: Giải nén và thiết lập hệ thống..."
tar -xf lazydocker.tar.gz lazydocker
mv lazydocker "$BIN_DIR/"
rm lazydocker.tar.gz

# 4. Thêm biến môi trường và phím tắt lzd vào .bashrc nếu chưa có
echo "--> 3/3: Đang cấu hình phím tắt..."
if ! grep -q 'export PATH=$PATH:$HOME/bin' ~/.bashrc; then
    echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
fi

if ! grep -q 'alias lzd="lazydocker"' ~/.bashrc; then
    echo 'alias lzd="lazydocker"' >> ~/.bashrc
fi

echo "========================================="
echo " CẤP PHÉP VÀ HOÀN TẤT!"
echo "========================================="
echo "BƯỚC CUỐI: Hãy copy và chạy lệnh dưới đây để kích hoạt:"
echo ""
echo "source ~/.bashrc && lzd"
echo ""

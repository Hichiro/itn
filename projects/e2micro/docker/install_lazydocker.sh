#!/bin/bash

set -e

echo "========================================="
echo " CÀI ĐẶT LAZYDOCKER BINARY TRÊN COS"
echo "========================================="

# 1. Tạo thư mục chứa file chạy cá nhân
BIN_DIR="$HOME/bin"
mkdir -p "$BIN_DIR"

# 2. Tự động kiểm tra phiên bản mới nhất từ GitHub API
echo "--> 1/4: Đang kiểm tra phiên bản mới nhất..."
TAG=$(curl -s https://api.github.com/repos/jesseduffield/lazydocker/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
VERSION=$(echo "$TAG" | sed 's/^v//')

if [ -z "$VERSION" ]; then
    echo "❌ Lỗi: Không thể lấy thông tin phiên bản từ GitHub. Hãy kiểm tra kết nối mạng."
    exit 1
fi

echo "Tìm thấy phiên bản: v$VERSION"

# 3. Tải file nén chuẩn theo đúng phiên bản vừa tìm được
echo "--> 2/4: Đang tải Lazydocker v$VERSION..."
URL="https://github.com/jesseduffield/lazydocker/releases/download/v${VERSION}/lazydocker_${VERSION}_Linux_x86_64.tar.gz"
curl -sSL "$URL" -o lazydocker.tar.gz

# 4. Giải nén và di chuyển vào thư mục bin
echo "--> 3/4: Giải nén và thiết lập hệ thống..."
tar -xf lazydocker.tar.gz lazydocker
mv lazydocker "$BIN_DIR/"
rm lazydocker.tar.gz

# 5. Cấu hình biến môi trường và phím tắt lzd vào .bashrc
echo "--> 4/4: Đang cấu hình phím tắt lzd..."
if ! grep -q 'export PATH=$PATH:$HOME/bin' ~/.bashrc; then
    echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
fi

if ! grep -q 'alias lzd="lazydocker"' ~/.bashrc; then
    echo 'alias lzd="lazydocker"' >> ~/.bashrc
fi

echo "========================================="
echo " CÀI ĐẶT THÀNH CÔNG!"
echo "========================================="
echo "Hãy chạy lệnh sau để kích hoạt và mở ngay:"
echo ""
echo "source ~/.bashrc && lzd"
echo ""

#!/bin/bash
# =====================================================================
# Script Name   : install_lazydocker_cos.sh
# Description   : Install Lazydocker as a container alias for Google Cloud COS
# Author        : Your Name / GitHub Username
# License       : MIT
# =====================================================================

set -e

# Khai báo các biến cấu hình
ALIAS_NAME="lzd"
IMAGE_NAME="lazyteam/lazydocker:latest"
BASHRC="$HOME/.bashrc"

echo "=================================================="
# Căn lề trái bằng khoảng trắng thông thường
echo " CÀI ĐẶT LAZYDOCKER CHO CONTAINER-OPTIMIZED OS    "
echo "=================================================="

# 1. Tải trước Docker Image để chạy nhanh hơn ở lần đầu
echo "--> 1/2: Đang tải Docker Image chính thức..."
docker pull $IMAGE_NAME

# 2. Thiết lập cấu hình Alias vào .bashrc
echo "--> 2/2: Cấu hình lệnh viết tắt vào $BASHRC..."

# Chuỗi định nghĩa alias cần thêm
ALIAS_CMD="alias $ALIAS_NAME='docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v /home/\$USER/.config/lazydocker:/.config/jesseduffield/lazydocker $IMAGE_NAME'"

# Kiểm tra xem alias đã tồn tại chưa để tránh ghi đè/trùng lặp
if grep -q "alias $ALIAS_NAME=" "$BASHRC"; then
    echo "[Bỏ qua] Lệnh viết tắt '$ALIAS_NAME' đã tồn tại trong $BASHRC."
else
    echo "" >> "$BASHRC"
    echo "# Lazydocker Alias for COS" >> "$BASHRC"
    echo "$ALIAS_CMD" >> "$BASHRC"
    echo "[Thành công] Đã thêm cấu hình vào $BASHRC."
fi

echo "=================================================="
echo " CÀI ĐẶT HOÀN TẤT THÀNH CÔNG!"
echo "=================================================="
echo "Để áp dụng cấu hình ngay lập tức, hãy chạy lệnh:"
echo "source ~/.bashrc"
echo ""
echo "Sau đó, bạn có thể mở nhanh bằng lệnh: $ALIAS_NAME"
echo "=================================================="

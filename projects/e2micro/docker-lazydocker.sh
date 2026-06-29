#!/bin/bash

# Dừng script nếu có lỗi xảy ra hoặc lỗi trong pipe
set -e
set -o pipefail

echo "========================================="
echo " CÀI ĐẶT DOCKER & LAZYDOCKER TỐI GIẢN"
echo "========================================="

# --- 1. CÀI ĐẶT DOCKER ---
if command -v docker &> /dev/null; then
    echo "--> [Bỏ qua] Docker đã được cài đặt. Phiên bản: $(docker --version)"
else
    echo "--> [Cài đặt] Đang tải và cài đặt Docker bản tinh gọn..."
    # Cài đặt curl nếu hệ thống chưa có
    if ! command -v curl &> /dev/null; then
        sudo apt-get update -y && sudo apt-get install -y curl
    fi
    # Sử dụng script chính thức của Docker để tự động thiết lập repo và cài đặt tối giản
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh

    # Kích hoạt Docker chạy ngầm và thêm user hiện tại vào nhóm docker
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"
    echo "--> Cài đặt Docker hoàn tất."
fi

# --- 2. CÀI ĐẶT LAZYDOCKER ---
# Nạp tạm đường dẫn để kiểm tra lazydocker
export PATH="$HOME/.local/bin:$PATH"

if command -v lazydocker &> /dev/null; then
    echo "--> [Bỏ qua] Lazydocker đã được cài đặt. Phiên bản: $(lazydocker --version)"
else
    echo "--> [Cài đặt] Đang cài đặt Lazydocker..."
    # Tải và chạy script cài đặt Lazydocker
    curl -s https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

    # Kiểm tra và thêm đường dẫn vào .bashrc nếu chưa tồn tại
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        echo "--> Đã cấu hình đường dẫn Lazydocker vào ~/.bashrc"
    fi
fi

echo "========================================="
echo " KIỂM TRA TRẠNG THÁI CUỐI CÙNG"
echo "========================================="
docker --version
docker compose version || echo "Docker Compose chưa được kích hoạt đúng cách."
lazydocker --version || echo "Vui lòng chạy 'source ~/.bashrc' để nhận lệnh lazydocker."
echo "----------------------------------------"
echo "Lưu ý: Để chạy Docker không cần sudo và nhận lệnh Lazydocker, hãy chạy:"
echo "source ~/.bashrc"
echo "hoặc đăng nhập lại SSH."

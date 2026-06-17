#!/bin/bash

# ==============================================================================
# Tên Script: install-openclaw-gh.sh
# Mô tả: Tải bản build OpenClaw sạch, tự động cài dependencies tinh gọn tại VM.
#        Đã sửa lỗi phân quyền file ảo /dev/fd khi dùng lệnh sudo.
# CHẠY TRÊN: Máy ảo Debian 12 (Quyền root/sudo).
# ==============================================================================

# Thông tin tài khoản và kho lưu trữ GitHub của bạn
GH_USER_REPO="Hichiro/itn" 
SCRIPT_URL="https://raw.githubusercontent.com/${GH_USER_REPO}/main/projects/openclaw/scripts/install-openclaw-gh.sh"

# 1. SỬA LỖI /dev/fd: Tải về file vật lý trong /tmp trước khi nâng quyền root
if [ "$EUID" -ne 0 ]; then
    echo "Đang yêu cầu nâng quyền root bằng sudo..."
    curl -fsSL "$SCRIPT_URL" -o /tmp/install-openclaw-gh.sh
    exec sudo bash /tmp/install-openclaw-gh.sh "$@"
fi

# Tự động dọn dẹp file tạm sau khi script kết thúc
trap 'rm -f /tmp/install-openclaw-gh.sh' EXIT

set -e

echo "================================================="
echo "🚀 ĐANG TRIỂN KHAI OPENCLAW NATIVE TỪ BẢN BUILD GITHUB"
echo "================================================="

# 2. CÀI ĐẶT NODE.JS V24 CHUẨN
if ! command -v node &> /dev/null || [ $(node -v | cut -d'.' -f1) != "v24" ]; then
    echo "--- [1/5] Đang cài đặt Node.js v24... ---"
    curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
    apt-get install -y nodejs wget tar git build-essential
fi

# 3. KÍCH HOẠT COREPACK VÀ PNPM TOÀN CỤC
echo "--- [2/5] Đang cấu hình Corepack và cài đặt pnpm... ---"
corepack enable
if ! command -v pnpm &> /dev/null; then
    corepack prepare pnpm@latest --activate
fi

# 4. TẢI VÀ GIẢI NÉN BẢN PHÁT HÀNH SẠCH TỪ REPO
echo "--- [3/5] Tải và giải nén bản phát hành sạch... ---"
INSTALL_DIR="/opt/openclaw"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Tải file nén dạng .tar.gz từ thư mục projects của bạn
DOWNLOAD_URL="https://raw.githubusercontent.com/${GH_USER_REPO}/main/projects/openclaw/openclaw-release.tar.gz"
wget -qO openclaw-release.tar.gz "$DOWNLOAD_URL"

# Giải nén cấu hình và xóa file nén tạm để tiết kiệm không gian đĩa
tar -xzf openclaw-release.tar.gz
rm -f openclaw-release.tar.gz

# 5. CÀI ĐẶT THƯ VIỆN PRODUCTION TINH GỌN (CỰC NHẸ, KHÔNG TỐN TÀI NGUYÊN)
echo "--- [4/5] Khởi tạo các gói phụ thuộc môi trường production... ---"
pnpm install --production

# Khởi tạo file môi trường .env từ file mẫu nếu chưa tồn tại
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
    else
        touch .env
    fi
fi

# 6. LIÊN KẾT HỆ THỐNG VÀ KHỞI CHẠY DAEMON
echo "--- [5/5] Cấu hình môi trường thực thi và kích hoạt OpenClaw... ---"
pnpm link --global

# Dừng cổng kết nối cũ nếu có để tránh xung đột
openclaw gateway stop 2>/dev/null || true

# Kích hoạt dịch vụ daemon chạy ngầm theo tài liệu chuẩn OpenClaw
openclaw onboard --install-daemon

echo "================================================="
echo "🎉 HOÀN TẤT CÀI ĐẶT OPENCLAW SẠCH TỪ GITHUB ACTIONS!"
echo "================================================="
echo "• Thư mục cài đặt: $INSTALL_DIR"
echo "• Kiểm tra trạng thái hệ thống: openclaw gateway status"
echo "• Bắt đầu cấu hình agent ban đầu: openclaw onboard"
echo "================================================="

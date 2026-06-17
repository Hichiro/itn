#!/bin/bash

# ==============================================================================
# Tên Script: install-openclaw-gh.sh
# Mô tả: Tải bản build OpenClaw sạch, tự động cài dependencies tinh gọn tại VM.
# CHẠY TRÊN: Máy ảo Debian 12 (Quyền root/sudo).
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
    echo "Đang yêu cầu nâng quyền root bằng sudo..."
    exec sudo bash "$0" "$@"
fi

set -e

# ĐIỀN THÔNG TIN REPO CỦA BẠN (Ví dụ: Hichiro/itn)
GH_USER_REPO="Hichiro/itn" 

echo "================================================="
echo "🚀 ĐANG TRIỂN KHAI OPENCLAW NATIVE TỪ BẢN BUILD GITHUB"
echo "================================================="

# 1. CÀI ĐẶT NODE 24 CHUẨN
if ! command -v node &> /dev/null || [ $(node -v | cut -d'.' -f1) != "v24" ]; then
    echo "--- [1/5] Đang cài đặt Node.js v24... ---"
    curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
    apt-get install -y nodejs wget tar
fi

# 2. KÍCH HOẠT COREPACK VÀ PNPM
corepack enable
if ! command -v pnpm &> /dev/null; then
    corepack prepare pnpm@latest --activate
fi

# 3. TẢI VÀ GIẢI NÉN BẢN PHÁT HÀNH
echo "--- [2/5] Tải và giải nén bản phát hành sạch... ---"
INSTALL_DIR="/opt/openclaw"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

DOWNLOAD_URL="https://raw.githubusercontent.com/${GH_USER_REPO}/main/projects/openclaw/openclaw-release.tar.gz"
wget -qO openclaw-release.tar.gz "$DOWNLOAD_URL"

tar -xzf openclaw-release.tar.gz
rm -f openclaw-release.tar.gz

# 4. CÀI ĐẶT THƯ VIỆN PRODUCTION TRÊN MÁY ẢO (CỰC NHẸ, KHÔNG TỐN TÀI NGUYÊN BUILD)
echo "--- [3/5] Khởi tạo dependencies môi trường production... ---"
pnpm install --production

# 5. KHỞI TẠO HOẶC CẬP NHẬT BIẾN MÔI TRƯỜNG (.ENV)
if [ ! -f ".env" ]; then
    [ -f ".env.example" ] && cp .env.example .env || touch .env
fi

# 6. LIÊN KẾT HỆ THỐNG VÀ RUN DAEMON
echo "--- [4/5] Cấu hình môi trường thực thi và tạo Link... ---"
pnpm link --global

echo "--- [5/5] Khởi động OpenClaw Daemon... ---"
openclaw gateway stop 2>/dev/null || true
openclaw onboard --install-daemon

echo "================================================="
echo "🎉 HOÀN TẤT CÀI ĐẶT OPENCLAW SẠCH TỪ GITHUB ACTIONS!"
echo "================================================="

#!/bin/bash

# ==============================================================================
# Tên Script: install-openclaw-gh.sh
# Mô tả: Tải bản build OpenClaw sạch, tự động cài dependencies tinh gọn tại VM.
#        Chặn cài đặt bằng tài khoản root để đảm bảo an toàn hệ thống.
# CHẠY TRÊN: Máy ảo Debian 12 (Quyền user thường có cấu hình sudo).
# ==============================================================================

# Thông tin tài khoản và kho lưu trữ GitHub của bạn
GH_USER_REPO="Hichiro/itn" 
SCRIPT_URL="https://raw.githubusercontent.com/${GH_USER_REPO}/main/projects/openclaw/scripts/install-openclaw-gh.sh"

# 1. CHẶN ROOT & TỰ ĐỘNG XỬ LÝ QUYỀN TRÊN USER THƯỜNG
# Kiểm tra nếu người dùng thực sự đăng nhập trực tiếp bằng root (SUDO_USER không tồn tại)
if [ "$EUID" -eq 0 ] && [ -z "$SUDO_USER" ]; then
    echo "================================================="
    echo "❌ LỖI BẢO MẬT: KHÔNG ĐƯỢC PHÉP CÀI ĐẶT BẰNG TÀI KHOẢN ROOT!"
    echo "================================================="
    echo "Để bảo vệ hệ thống khỏi các rủi ro tiêm lệnh (prompt injection) từ AI,"
    echo "OpenClaw yêu cầu phải được cài đặt và chạy dưới quyền user thường."
    echo ""
    echo "👉 Hướng dẫn khắc phục:"
    echo " 1. Thoát tài khoản root bằng lệnh: exit"
    echo " 2. Chạy lại script bằng tài khoản user của bạn."
    echo "================================================="
    exit 1
fi

# Nếu là user thường chạy script, tự động dùng sudo tải file tạm và chạy nâng quyền
if [ "$EUID" -ne 0 ]; then
    echo "Đang xác thực quyền quản trị để cài đặt gói hệ thống..."
    curl -fsSL "$SCRIPT_URL" -o /tmp/install-openclaw-gh.sh
    exec sudo bash /tmp/install-openclaw-gh.sh "$@"
fi

# Tự động dọn dẹp file tạm sau khi script kết thúc
trap 'rm -f /tmp/install-openclaw-gh.sh' EXIT

set -e

# Xác định thư mục home chuẩn của user thực tế (ngay cả khi đang chạy dưới sudo)
REAL_USER_HOME=$(eval echo "~$SUDO_USER")

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
    echo "y" | corepack prepare pnpm@latest --activate
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
pnpm install --production --no-frozen-lockfile

# Khởi tạo file môi trường .env từ file mẫu nếu chưa tồn tại
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
    else
        touch .env
    fi
    # Phân quyền lại file .env cho user thực sở hữu
    chown "$SUDO_USER:$SUDO_USER" .env
fi

# 6. LIÊN KẾT HỆ THỐNG VÀ KHỞI CHẠY DAEMON
echo "--- [5/5] Cấu hình môi trường thực thi và kích hoạt OpenClaw... ---"

# Cấu hình biến môi trường PATH cho pnpm bin toàn cục của USER THỰC TẾ
USER_PNPM_BIN="${REAL_USER_HOME}/.local/share/pnpm/bin"
export PATH="${USER_PNPM_BIN}:$PATH"

if ! grep -q "${USER_PNPM_BIN}" "${REAL_USER_HOME}/.bashrc"; then
    echo "export PATH=\"${USER_PNPM_BIN}:\$PATH\"" >> "${REAL_USER_HOME}/.bashrc"
    chown "$SUDO_USER:$SUDO_USER" "${REAL_USER_HOME}/.bashrc"
fi

# Sử dụng lệnh thay thế an toàn cho pnpm mới để đăng ký lệnh 'openclaw' toàn cục
pnpm install --global .

# Chuyển giao quyền sở hữu thư mục cài đặt /opt/openclaw cho user để không bị lỗi Permission sau này
chown -R "$SUDO_USER:$SUDO_USER" "$INSTALL_DIR"

# Dừng cổng kết nối cũ nếu có để tránh xung đột
openclaw gateway stop 2>/dev/null || true

# Thực thi lệnh onboard với tư cách của user thường để tạo config tại thư mục home của user
sudo -u "$SUDO_USER" env "PATH=$PATH" openclaw onboard --install-daemon

echo "================================================="
echo "🎉 HOÀN TẤT CÀI ĐẶT OPENCLAW SẠCH TỪ GITHUB ACTIONS!"
echo "================================================="
echo "• Thư mục cài đặt: $INSTALL_DIR"
echo "• Tài khoản sở hữu: $SUDO_USER"
echo "• Kiểm tra trạng thái hệ thống: openclaw gateway status"
echo "• Bắt đầu cấu hình agent ban đầu: openclaw onboard"
echo "================================================="

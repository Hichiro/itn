#!/bin/bash

# ==============================================================================
# Tên Script: install-openclaw-gh.sh
# Mô tả: Tải bản build OpenClaw sạch, tự động cài dependencies tinh gọn tại VM.
#        Cô lập môi trường pnpm/openclaw hoàn toàn trong thư mục của USER thường.
# CHẠY TRÊN: Máy ảo Debian 12 (Quyền user thường có cấu hình sudo không mật khẩu).
# ==============================================================================

# Thông tin tài khoản và kho lưu trữ GitHub của bạn
GH_USER_REPO="Hichiro/itn" 
SCRIPT_URL="https://raw.githubusercontent.com/${GH_USER_REPO}/main/projects/openclaw/scripts/install-openclaw-gh.sh"

# 1. CHẶN ROOT & XÁC ĐỊNH USER THỰC THI
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

# Tự động dọn dẹp file tạm sau khi script kết thúc
trap 'rm -f /tmp/install-openclaw-gh.sh' EXIT

set -e

# Xác định danh tính và thư mục Home của User thực (không phải root)
REAL_USER=""
REAL_HOME=""

if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME=$(eval echo "~$SUDO_USER")
else
    REAL_USER="$USER"
    REAL_HOME="$HOME"
fi

echo "================================================="
echo "🚀 ĐANG TRIỂN KHAI OPENCLAW CHO USER: $REAL_USER"
echo "================================================="

# 2. CÀI ĐẶT CÁC GÓI HỆ THỐNG (YÊU CẦU NÂNG QUYỀN SUDO)
echo "--- [1/5] Đang kiểm tra và cài đặt các gói hệ thống cần thiết... ---"
if ! command -v node &> /dev/null || [ $(node -v | cut -d'.' -f1) != "v24" ]; then
    sudo curl -fsSL https://deb.nodesource.com/setup_24.x | sudo bash -
    sudo apt-get install -y nodejs wget tar git build-essential
fi

# 3. KÍCH HOẠT COREPACK VÀ PNPM TOÀN CỤC KHÔNG CHẠY BẰNG SUDO
echo "--- [2/5] Đang cấu hình Corepack và cài đặt pnpm... ---"
sudo corepack enable

# Bỏ qua hộp thoại xác nhận tải của Corepack một cách tự động
export COREPACK_ENABLE_DOWNLOADS=1

# Ép buộc pnpm thiết lập thư mục global bin nằm trong thư mục của User thường
USER_PNPM_BIN="${REAL_HOME}/.local/share/pnpm"
export PNPM_HOME="$USER_PNPM_BIN"
export PATH="$USER_PNPM_BIN:$PATH"

if ! command -v pnpm &> /dev/null; then
    corepack prepare pnpm@latest --activate
fi

# Ép buộc pnpm thiết lập thư mục global bin nằm trong thư mục của User thường
USER_PNPM_BIN="${REAL_HOME}/.local/share/pnpm"
export PNPM_HOME="$USER_PNPM_BIN"
export PATH="$USER_PNPM_BIN:$PATH"

if ! command -v pnpm &> /dev/null; then
    echo "y" | corepack prepare pnpm@latest --activate
fi

# Cấu hình cứng để pnpm luôn cài lệnh vào thư mục của User thường
pnpm config set global-dir "${REAL_HOME}/.local/share/pnpm/store" --global
pnpm config set global-bin-dir "${REAL_HOME}/.local/share/pnpm" --global

# Thêm đường dẫn PATH vào .bashrc của User nếu chưa có
if ! grep -q "${USER_PNPM_BIN}" "${REAL_HOME}/.bashrc"; then
    echo "" >> "${REAL_HOME}/.bashrc"
    echo "# OpenClaw pnpm PATH" >> "${REAL_HOME}/.bashrc"
    echo "export PNPM_HOME=\"${USER_PNPM_BIN}\"" >> "${REAL_HOME}/.bashrc"
    echo "export PATH=\"\${PNPM_HOME}:\$PATH\"" >> "${REAL_HOME}/.bashrc"
fi

# 4. TẢI VÀ GIẢI NÉN BẢN PHÁT HÀNH SẠCH TỪ REPO
echo "--- [3/5] Tải và giải nén bản phát hành sạch... ---"
INSTALL_DIR="${REAL_HOME}/openclaw-agent"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

DOWNLOAD_URL="https://raw.githubusercontent.com/${GH_USER_REPO}/main/projects/openclaw/openclaw-release.tar.gz"
wget -qO openclaw-release.tar.gz "$DOWNLOAD_URL"

tar -xzf openclaw-release.tar.gz
rm -f openclaw-release.tar.gz

# 5. CÀI ĐẶT THƯ VIỆN PRODUCTION TINH GỌN
echo "--- [4/5] Khởi tạo các gói phụ thuộc môi trường production... ---"
pnpm install --production --no-frozen-lockfile

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
    else
        touch .env
    fi
fi

# 6. LIÊN KẾT HỆ THỐNG VÀ KHỞI CHẠY DAEMON VỚI QUYỀN USER THƯỜNG
echo "--- [5/5] Cấu hình môi trường thực thi và kích hoạt OpenClaw... ---"

# Đăng ký lệnh 'openclaw' toàn cục trong phạm vi User thường
pnpm install --global .

# Dừng cổng kết nối cũ nếu có để tránh xung đột
"${USER_PNPM_BIN}/openclaw" gateway stop 2>/dev/null || true

# Kích hoạt dịch vụ daemon chạy ngầm theo tài liệu chuẩn OpenClaw
"${USER_PNPM_BIN}/openclaw" onboard --install-daemon

echo "================================================="
echo "🎉 HOÀN TẤT CÀI ĐẶT OPENCLAW SẠCH CHO USER THƯỜNG!"
echo "================================================="
echo "• Thư mục cài đặt: $INSTALL_DIR"
echo "• Đường dẫn thực thi: ${USER_PNPM_BIN}/openclaw"
echo ""
echo "👉 LƯU Ý: Hãy chạy lệnh dưới đây để cập nhật Terminal hiện tại:"
echo "   source ~/.bashrc"
echo ""
echo "• Kiểm tra trạng thái hệ thống: openclaw gateway status"
echo "• Bắt đầu cấu hình agent ban đầu: openclaw onboard"
echo "================================================="

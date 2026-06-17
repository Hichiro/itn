#!/bin/bash

# ==============================================================================
# Tên Script: install-openclaw-gh.sh
# Mô tả: Tải bản build OpenClaw sạch, tự động cài dependencies tinh gọn tại VM.
#        Cô lập môi trường pnpm/openclaw hoàn toàn trong thư mục của USER thường.
#        Sử dụng Standalone pnpm Installer thay cho Corepack để vượt mốc Y/n.
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

# 3. CÀI ĐẶT PNPM CHÍNH THỨC CHO USER (KHÔNG DÙNG COREPACK)
echo "--- [2/5] Đang cài đặt pnpm vào môi trường User độc lập... ---"

# Khai báo sẵn các biến môi trường cho phiên script hiện tại
if command -v pnpm &> /dev/null; then
# Nếu pnpm đã tồn tại và là standalone (có PNPM_HOME trong output của --version hoặc nằm trong HOME), giữ nguyên
PNPM_PATH="$(command -v pnpm)"
if echo "$PNPM_PATH" | grep -q "${REAL_HOME}" ; then
echo "pnpm đã cài trong phạm vi user: $PNPM_PATH — bỏ qua cài đặt."
else
echo "pnpm đã cài ở hệ thống: $PNPM_PATH — sẽ bỏ qua cài đặt để tránh can thiệp system-wide."
fi
else
echo "pnpm chưa tồn tại — tiến hành cài đặt standalone (non-interactive)..."
env COREPACK_DISABLE=1 SHELL="$(which bash)" \
curl -fsSL https://get.pnpm.io/install.sh | bash -s -- --disable-version-check
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

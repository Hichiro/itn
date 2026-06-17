#!/usr/bin/env bash
# ==============================================================================
# Tên Script: install-openclaw-gh.sh
# Mô tả:      Kiểm tra môi trường, cài đặt các thành phần thiếu,
#             khởi động daemon và xác minh trạng thái.
# Yêu cầu:   Debian 12 (hoặc Ubuntu 22.04+), người dùng thường có sudo không mật khẩu.
# ==============================================================================

# ----------------------------------------------------------------------
# 0️⃣ Cấu hình người dùng / repo GitHub
# ----------------------------------------------------------------------
GH_USER_REPO="Hichiro/itn"                 # <-- sửa <user>/<repo> của bạn
SCRIPT_URL="https://raw.githubusercontent.com/${GH_USER_REPO}/main/projects/openclaw/scripts/install-openclaw-gh.sh"

# ----------------------------------------------------------------------
# 1️⃣ Kiểm tra môi trường tổng quan
# ----------------------------------------------------------------------
# 1.1 Hệ điều hành & phiên bản
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
else
    echo "❌ Không tìm thấy /etc/os-release" && exit 1
fi
[[ "$ID" == "debian" || "$ID" == "ubuntu" ]] || { echo "❌ Chỉ hỗ trợ Debian/Ubuntu"; exit 1; }
(( VERSION_ID >= 12 )) || { echo "❌ Yêu cầu Debian 12+ (hiện: $VERSION_ID)"; exit 1; }

# 1.2 Kiến trúc CPU (Node v24 chỉ có binary cho amd64)
arch=$(dpkg --print-architecture)
[[ "$arch" == "amd64" ]] || { echo "❌ Node v24 chỉ hỗ trợ amd64 (hiện: $arch)"; exit 1; }

# 1.3 Kiểm tra sudo không mật khẩu (không bắt buộc, chỉ cảnh báo)
sudo -n true 2>/dev/null || echo "⚠️  User không có sudo không mật khẩu – sẽ được hỏi khi cần."

# 1.4 Kết nối Internet
ping -c1 -W2 raw.githubusercontent.com >/dev/null 2>&1 || { echo "❌ Không thể ping GitHub"; exit 1; }

# 1.5 Công cụ tải
for cmd in curl wget; do
    command -v $cmd >/dev/null || { echo "❌ $cmd chưa được cài đặt – sudo apt-get install $cmd"; exit 1; }
done

# ----------------------------------------------------------------------
# 2️⃣ Ngăn chạy trực tiếp dưới root
# ----------------------------------------------------------------------
if [ "$EUID" -eq 0 ] && [ -z "$SUDO_USER" ]; then
    echo "❌ Không chạy script bằng root trực tiếp. Hãy chạy dưới user thường."
    exit 1
fi

# ----------------------------------------------------------------------
# 3️⃣ Xác định người dùng thực thi
# ----------------------------------------------------------------------
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME=$(eval echo "~$SUDO_USER")
else
    REAL_USER="$USER"
    REAL_HOME="$HOME"
fi
echo "▶ Đang thực hiện cho $REAL_USER ($REAL_HOME)"

# ----------------------------------------------------------------------
# 4️⃣ Định nghĩa các hàm kiểm tra / cài đặt
# ----------------------------------------------------------------------
check_node() {
    if command -v node &>/dev/null && [[ "$(node -v)" =~ ^v24 ]]; then
        echo "✅ Node.js v24 đã có"
        return 0
    else
        return 1
    fi
}

install_node() {
    echo "🚀 Cài Node.js v24 (sudo)…"
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
    sudo apt-get update
    sudo apt-get install -y nodejs
}

check_pnpm() {
    command -v pnpm &>/dev/null
}

install_pnpm() {
    echo "🚀 Cài pnpm (standalone)…"
    env COREPACK_DISABLE=1 SHELL="$(which bash)" \
        curl -fsSL https://get.pnpm.io/install.sh | bash -s -- --disable-version-check
    export PATH="$HOME/.local/share/pnpm:$PATH"
}

check_release() {
    [[ -d "$INSTALL_DIR/.git" || -f "$INSTALL_DIR/package.json" ]]
}

download_release() {
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    DOWNLOAD_URL="https://raw.githubusercontent.com/${GH_USER_REPO}/main/projects/openclaw/openclaw-release.tar.gz"
    echo "⬇️  Tải release từ $DOWNLOAD_URL …"
    wget -qO openclaw-release.tar.gz "$DOWNLOAD_URL"
    tar -xzf openclaw-release.tar.gz && rm -f openclaw-release.tar.gz
}

check_dependencies() {
    pnpm install --production --no-frozen-lockfile >/dev/null 2>&1
}

install_dependencies() {
    echo "📦 pnpm install --production …"
    export PNPM_SKIP_ASK=1       # vô hiệu hoá mọi prompt
    pnpm install --production --no-frozen-lockfile
}

check_service_active() {
    systemctl is-active --quiet openclaw
}

install_service() {
    pnpm install --global .
    USER_PNPM_BIN="$(pnpm bin -g)"

    # Dừng daemon cũ nếu còn
    "$USER_PNPM_BIN/openclaw" gateway stop 2>/dev/null || true

    sudo tee /etc/systemd/system/openclaw.service > /dev/null <<EOF
[Unit]
Description=OpenClaw daemon (system‑wide)
After=network.target

[Service]
Type=simple
User=${REAL_USER}
ExecStart=${USER_PNPM_BIN}/openclaw gateway start
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now openclaw.service
}

# ----------------------------------------------------------------------
# 5️⃣ Thực hiện kiểm tra & cài đặt (lần đầu hoặc khi thiếu)
# ----------------------------------------------------------------------
INSTALL_DIR="${REAL_HOME}/openclaw-agent"

# 5.1 Node.js
if ! check_node; then
    install_node
else
    echo "✅ Node.js đã có – bỏ qua cài đặt."
fi

# 5.2 pnpm
if ! check_pnpm; then
    install_pnpm
else
    echo "✅ pnpm đã có – bỏ qua cài đặt."
fi

# 5.3 Release (mã nguồn OpenClaw)
if ! check_release; then
    echo "🚀 Tải và giải nén bản phát hành OpenClaw…"
    download_release
else
    echo "✅ Release đã tồn tại trong $INSTALL_DIR"
fi

# 5.4 Các phụ thuộc Node
cd "$INSTALL_DIR"
if ! check_dependencies; then
    install_dependencies
else
    echo "✅ Các phụ thuộc Node đã được cài (production)."
fi

# 5.5 Service daemon
if ! check_service_active; then
    echo "🚀 Đăng ký và khởi động daemon systemd..."
    install_service
else
    echo "✅ Daemon openclaw đang chạy."
fi

# ----------------------------------------------------------------------
# 6️⃣ Xác minh cuối cùng
# ----------------------------------------------------------------------
echo "================================================="
echo "🔎 Kiểm tra trạng thái cuối cùng"
echo "• Node.js      : $(node -v)"
echo "• pnpm         : $(pnpm -v)"
echo "• Thư mục cài  : $INSTALL_DIR"
echo "• Service      : $(systemctl is-active openclaw)"
echo "• Lệnh CLI    : $(pnpm bin -g)/openclaw"
echo "================================================="
echo "✅ Cài đặt và kiểm tra hoàn tất. Bạn có thể sử dụng:"
echo "   openclaw gateway status"
echo "   openclaw onboard"
echo "================================================="

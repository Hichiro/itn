#!/usr/bin/env bash
# ==============================================================================
# Tên Script: install-openclaw-gh.sh
# Mô tả:      Tải bản build OpenClaw sạch, tự động cài dependencies tinh gọn
#             trên máy Debian 12.  Cô lập môi trường pnpm/openclaw trong
#             thư mục HOME của USER thường và đăng ký daemon system‑wide.
# Yêu cầu:   Máy ảo Debian 12, người dùng thường có quyền sudo không mật khẩu.
# ==============================================================================

# ----------------------------------------------------------------------
# Cấu hình người dùng / kho GitHub
# ----------------------------------------------------------------------
GH_USER_REPO="Hichiro/itn"
SCRIPT_URL="https://raw.githubusercontent.com/${GH_USER_REPO}/main/projects/openclaw/scripts/install-openclaw-gh.sh"

# ----------------------------------------------------------------------
# 0️⃣ Kiểm tra môi trường tổng quan
# ----------------------------------------------------------------------
# 0.1 Hệ điều hành & phiên bản
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
else
    echo "❌ Không tìm thấy file /etc/os-release." && exit 1
fi
if [[ "$ID" != "debian" && "$ID" != "ubuntu" ]]; then
    echo "❌ Chỉ hỗ trợ Debian/Ubuntu." && exit 1
fi
if (( VERSION_ID < 12 )); then
    echo "❌ Yêu cầu Debian 12 trở lên (hiện: $VERSION_ID)." && exit 1
fi

# 0.2 Kiến trúc CPU (Node v24 chỉ có binary cho amd64)
arch=$(dpkg --print-architecture)
if [[ "$arch" != "amd64" ]]; then
    echo "❌ Node v24 chỉ hỗ trợ amd64 (hiện: $arch)." && exit 1
fi

# 0.3 Kiểm tra sudo (không cần mật khẩu)
if ! sudo -n true 2>/dev/null; then
    echo "⚠️  User không có sudo không mật khẩu – sẽ yêu cầu nhập khi cần."
fi

# 0.4 Kiểm tra kết nối Internet
if ! ping -c1 -W2 raw.githubusercontent.com >/dev/null 2>&1; then
    echo "❌ Không thể ping GitHub – kiểm tra kết nối mạng." && exit 1
fi

# 0.5 Kiểm tra công cụ tải
for cmd in curl wget; do
    command -v $cmd >/dev/null || { echo "❌ $cmd chưa được cài đặt – cài bằng sudo apt-get install $cmd"; exit 1; }
done

# ----------------------------------------------------------------------
# 1️⃣ Ngăn chạy trực tiếp dưới root
# ----------------------------------------------------------------------
if [ "$EUID" -eq 0 ] && [ -z "$SUDO_USER" ]; then
    echo "❌ Không được phép chạy script bằng tài khoản root trực tiếp."
    echo "   Hãy chạy dưới user thường và để script tự dùng sudo khi cần."
    exit 1
fi

# ----------------------------------------------------------------------
# 2️⃣ Xác định người dùng thực thi
# ----------------------------------------------------------------------
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME=$(eval echo "~$SUDO_USER")
else
    REAL_USER="$USER"
    REAL_HOME="$HOME"
fi
echo "▶ Cài đặt cho $REAL_USER ($REAL_HOME)"

# ----------------------------------------------------------------------
# 3️⃣ Kiểm tra/chuẩn bị thư mục cài đặt
# ----------------------------------------------------------------------
INSTALL_DIR="${REAL_HOME}/openclaw-agent"
if [[ -d "$INSTALL_DIR" ]]; then
    read -p "📂 Thư mục $INSTALL_DIR đã tồn tại. Ghi đè? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "🛑 Hủy cài đặt."; exit 0; }
fi
mkdir -p "$INSTALL_DIR"

# ----------------------------------------------------------------------
# 4️⃣ Kiểm tra Node.js (v24) – cài nếu chưa có
# ----------------------------------------------------------------------
if command -v node &>/dev/null && [[ "$(node -v)" =~ ^v24 ]]; then
    echo "✅ Node.js v24 đã có – bỏ qua cài đặt."
    NODE_INSTALLED=1
else
    NODE_INSTALLED=0
fi

if (( NODE_INSTALLED == 0 )); then
    echo "🚀 Cài Node.js v24 (sudo)…"
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
    sudo apt-get update
    sudo apt-get install -y nodejs
fi

# ----------------------------------------------------------------------
# 5️⃣ Kiểm tra pnpm – cài standalone nếu chưa có
# ----------------------------------------------------------------------
if ! command -v pnpm &>/dev/null; then
    echo "🚀 Cài pnpm (standalone)…"
    env COREPACK_DISABLE=1 SHELL="$(which bash)" \
        curl -fsSL https://get.pnpm.io/install.sh | bash -s -- --disable-version-check
    export PATH="$HOME/.local/share/pnpm:$PATH"
else
    echo "✅ pnpm đã có."
fi

# ----------------------------------------------------------------------
# 6️⃣ Tải và giải nén bản phát hành OpenClaw
# ----------------------------------------------------------------------
cd "$INSTALL_DIR"
DOWNLOAD_URL="https://raw.githubusercontent.com/${GH_USER_REPO}/main/projects/openclaw/openclaw-release.tar.gz"
echo "⬇️  Tải release từ $DOWNLOAD_URL …"
wget -qO openclaw-release.tar.gz "$DOWNLOAD_URL"
tar -xzf openclaw-release.tar.gz && rm -f openclaw-release.tar.gz

# ----------------------------------------------------------------------
# 7️⃣ Cài các phụ thuộc Node (pnpm)
# ----------------------------------------------------------------------
echo "📦 pnpm install --production …"
pnpm install --production --no-frozen-lockfile

# .env handling
if [ ! -f ".env" ]; then
    [[ -f ".env.example" ]] && cp .env.example .env || touch .env
fi

# ----------------------------------------------------------------------
# 8️⃣ Đăng ký daemon system‑wide (systemd)
# ----------------------------------------------------------------------
pnpm install --global .
USER_PNPM_BIN="$(pnpm bin -g)"

# Dừng daemon cũ nếu còn
"$USER_PNPM_BIN/openclaw" gateway stop 2>/dev/null || true

# Tạo file service dưới root
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

# ----------------------------------------------------------------------
# 9️⃣ Kết thúc
# ----------------------------------------------------------------------
echo "================================================="
echo "✅ Cài đặt OpenClaw thành công!"
echo "📂 Thư mục cài đặt : $INSTALL_DIR"
echo "🚀 Lệnh CLI       : $USER_PNPM_BIN/openclaw"
echo "🧭 Kiểm tra daemon: sudo systemctl status openclaw"
echo "================================================="

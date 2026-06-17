#!/usr/bin/env bash
# ==============================================================================
# Tên Script: install-openclaw-gh.sh
# Mô tả:      Kiểm tra môi trường, cài đặt thành phần thiếu (config, node_modules nhẹ),
#             khởi động daemon chạy ngầm và xác minh trạng thái.
#             Tối ưu hóa: Giới hạn 300MB RAM cho Node (e2-micro), bỏ gói AI cục bộ.
# Yêu cầu:    Debian 12+ (hoặc Ubuntu 22.04+), người dùng thường có sudo.
# ==============================================================================

# VÔ HIỆU HÓA HOÀN TOÀN COREPACK ĐỂ TRÁNH BỊ HỎI [Y/n]
export COREPACK_DISABLE=1

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

# So sánh phiên bản an toàn cho cả số nguyên và số thập phân
if [[ "$ID" == "debian" ]]; then
    (( VERSION_ID >= 12 )) || { echo "❌ Yêu cầu Debian 12+ (hiện: $VERSION_ID)"; exit 1; }
elif [[ "$ID" == "ubuntu" ]]; then
    is_valid_ubuntu=$(awk -v ver="$VERSION_ID" 'BEGIN { print (ver >= 22.04) ? 1 : 0 }')
    [[ "$is_valid_ubuntu" -eq 1 ]] || { echo "❌ Yêu cầu Ubuntu 22.04+ (hiện: $VERSION_ID)"; exit 1; }
fi

# 1.2 Kiến trúc CPU
arch=$(dpkg --print-architecture)
[[ "$arch" == "amd64" ]] || { echo "❌ Node v24 chỉ hỗ trợ amd64 (hiện: $arch)"; exit 1; }

# 1.3 Kiểm tra sudo
sudo -n true 2>/dev/null || echo "⚠️  User không có sudo không mật khẩu – sẽ được hỏi khi cần."

# 1.4 Kết nối Internet
ping -c1 -W2 raw.githubusercontent.com >/dev/null 2>&1 || { echo "❌ Không thể ping GitHub"; exit 1; }

# 1.5 Công cụ tải
for cmd in curl wget awk tar; do
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
    
    export PNPM_HOME="$REAL_HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"
    
    if ! grep -q "PNPM_HOME" "$REAL_HOME/.bashrc"; then
        echo -e "\n# OpenClaw pnpm PATH\nexport PNPM_HOME=\"$PNPM_HOME\"\nexport PATH=\"\$PNPM_HOME:\$PATH\"" >> "$REAL_HOME/.bashrc"
    fi
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
    [[ -d "node_modules" ]]
}

install_dependencies() {
    echo "📦 Đang cài đặt thư viện tinh gọn (bỏ qua mô hình AI cục bộ)…"
    export PNPM_SKIP_ASK=1
    pnpm install --production --no-frozen-lockfile --omit=optional
}

check_config() {
    [[ -f ".env" ]]
}

setup_config() {
    echo "⚙️  Khởi tạo file cấu hình .env mặc định..."
    if [[ -f ".env.example" ]]; then
        cp .env.example .env
    else
        touch .env
    fi
}

check_service_active() {
    systemctl is-active --quiet openclaw
}

install_service() {
    # Tạo thư mục bin cục bộ của user nếu chưa có
    USER_BIN_DIR="$REAL_HOME/.local/bin"
    mkdir -p "$USER_BIN_DIR"

    # GIẢI PHÁP TRIỆT ĐỂ: Tạo liên kết mềm hệ thống thay cho lệnh pnpm link/install -g lỗi
    ln -sf "$INSTALL_DIR/dist/index.js" "$USER_BIN_DIR/openclaw"
    chmod +x "$INSTALL_DIR/dist/index.js" 2>/dev/null || true

    # Đảm bảo hệ thống nhận diện được PATH của CLI mới tạo
    if ! grep -q "$USER_BIN_DIR" "$REAL_HOME/.bashrc"; then
        echo -e "\n# User Local BIN\nexport PATH=\"$USER_BIN_DIR:\$PATH\"" >> "$REAL_HOME/.bashrc"
    fi

    sudo tee /etc/systemd/system/openclaw.service > /dev/null <<EOF
[Unit]
Description=OpenClaw daemon (Tối ưu hóa e2-micro)
After=network.target

[Service]
Type=simple
User=${REAL_USER}
WorkingDirectory=${INSTALL_DIR}
Environment=COREPACK_DISABLE=1 NODE_ENV=production
# GIỚI HẠN BỘ NHỚ NODE TỐI ĐA 300MB ĐỂ TRÁNH LÀM SẬP VPS E2-MICRO
ExecStart=/usr/bin/node --max-old-space-size=300 ${INSTALL_DIR}/dist/index.js gateway start
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now openclaw.service
}

# ----------------------------------------------------------------------
# 5️⃣ Thực hiện kiểm tra & cài đặt
# ----------------------------------------------------------------------
INSTALL_DIR="${REAL_HOME}/openclaw-agent"

# 5.1 Node.js
if ! check_node; then
    install_node
fi

export PNPM_HOME="$REAL_HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$REAL_HOME/.local/bin:$PATH"

# 5.2 pnpm
if ! check_pnpm; then
    install_pnpm
else
    echo "✅ pnpm đã có – bỏ qua cài đặt."
fi

# 5.3 Release
if ! check_release; then
    echo "🚀 Tải và giải nén bản phát hành OpenClaw…"
    download_release
else
    echo "✅ Release đã tồn tại trong $INSTALL_DIR"
fi

# 5.4 Cấu hình & Phụ thuộc Node
cd "$INSTALL_DIR"

if ! check_config; then
    setup_config
else
    echo "✅ File cấu hình .env đã tồn tại."
fi

if ! check_dependencies; then
    install_dependencies
else
    echo "✅ Các thư viện Node đã được cài đặt."
fi

# 5.5 Service daemon chạy ngầm
if ! check_service_active; then
    echo "🚀 Đăng ký và khởi động daemon systemd..."
    install_service
else
    echo "✅ Daemon openclaw đang chạy ngầm."
fi

# ----------------------------------------------------------------------
# 6️⃣ Xác minh cuối cùng
# ----------------------------------------------------------------------
echo "================================================="
echo "🔎 KIỂM TRA TRẠNG THÁI CUỐI CÙNG"
echo "• Node.js      : $(node -v)"
echo "• pnpm         : $(pnpm -v)"
echo "• Thư mục cài  : $INSTALL_DIR"
echo "• Cấu hình     : $([[ -f "$INSTALL_DIR/.env" ]] && echo "Đã có (.env)" || echo "Thiếu")"
echo "• Service      : $(systemctl is-active openclaw)"
echo "• Giới hạn RAM : 300MB (--max-old-space-size)"
echo "================================================="
echo "✅ Cài đặt hoàn tất! Hãy chạy lệnh dưới đây để nạp lại cấu hình:"
echo "   source ~/.bashrc"
echo ""
echo "Bạn có thể quản lý Agent bằng các lệnh:"
echo "   openclaw gateway status"
echo "   openclaw onboard"
echo "================================================="

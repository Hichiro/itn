#!/data/data/com.termux/files/usr/bin/bash
# install_picoclaw_termux.sh
# Tự động check và cài đặt phiên bản PicoClaw mới nhất từ GitHub
# Version: 8

set -Eeuo pipefail

SCRIPT_VERSION="8"

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

section() { printf "\n${BLUE}==>${NC} %s\n" "$*"; }
success() { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
error() { printf "${RED}[✗]${NC} %s\n" "$*" >&2; }
info() { printf "${YELLOW}[i]${NC} %s\n" "$*"; }
die() { error "$*"; exit 1; }

# ---------- Phát hiện môi trường chroot ----------
if [ -d "/usr/etc" ] && [ ! -d "/data/data/com.termux" ]; then
    IS_CHROOT=true
    TERMUX_BIN="/usr/bin"
    CONF_DIR="/home/.picoclaw"
    WORKSPACE_DIR="/home/.picoclaw/workspace"
    CERT_PATH="/usr/etc/tls/cert.pem"
else
    IS_CHROOT=false
    TERMUX_BIN="/data/data/com.termux/files/usr/bin"
    CONF_DIR="$HOME/.picoclaw"
    WORKSPACE_DIR="/home/.picoclaw/workspace"
    CERT_PATH="/data/data/com.termux/files/usr/etc/tls/cert.pem"
fi

# ---------- Remove PicoClaw ----------
remove_picoclaw() {
    section "Removing PicoClaw"
    if [ -f "$TERMUX_BIN/picoclaw" ]; then
        rm -f "$TERMUX_BIN/picoclaw"
        success "Removed PicoClaw binary"
    else
        info "PicoClaw binary not found"
    fi
    if [ -d "$CONF_DIR" ]; then
        read -p "Remove PicoClaw config directory ($CONF_DIR)? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$CONF_DIR"
            success "Removed config directory"
        fi
    fi
    success "PicoClaw removal complete"
    exit 0
}

# ---------- Show Version ----------
show_version() {
    echo "install_picoclaw_termux.sh version $SCRIPT_VERSION"
    exit 0
}

# ---------- Configure PicoClaw ----------
configure_picoclaw() {
    section "Configuring PicoClaw"
    
    echo "Nhập Token Bot Telegram của bạn:"
    read -p "Token: " TG_TOKEN
    
    if [ -z "$TG_TOKEN" ]; then
        error "Không có Token. Bỏ qua cấu hình nâng cao."
        return 1
    fi

    mkdir -p "$CONF_DIR"
    
    cat > "$CONF_DIR/config.json" << EOF
{
  "session": { "dimensions": ["chat"] },
  "version": 3,
  "isolation": {},
  "agents": {
    "defaults": {
      "workspace": "$WORKSPACE_DIR",
      "restrict_to_workspace": true,
      "allow_read_outside_workspace": false,
      "model_name": "gemini-3.1-flash-lite",
      "max_tokens": 4096,
      "max_tool_iterations": 15
    }
  },
  "channel_list": {
    "pico": {
      "enabled": true,
      "type": "pico",
      "allow_from": ["*"],
      "settings": { "max_connections": 100 }
    },
    "telegram": {
      "enabled": true,
      "type": "telegram",
      "allow_from": ["734974005"],
      "placeholder": { "enabled": true, "text": ["Thinking... 💬"] },
      "settings": {
        "token": "$TG_TOKEN",
        "streaming": { "enabled": true, "throttle_seconds": 3, "min_growth_chars": 200 }
      }
    }
  },
  "model_list": [
    { "model_name": "gemini-3.1-flash-lite", "model": "gemini/gemini-3.1-flash-lite", "rpm": 15 },
    { "model_name": "gemini-2.5-flash-lite", "model": "gemini/gemini-2.5-flash-lite", "rpm": 10 },
    { "model_name": "llama-3.3-70b", "model": "groq/llama-3.3-70b-versatile", "api_base": "https://api.groq.com/openai/v1", "rpm": 30 },
    { "model_name": "nemotron-3-super-120b", "model": "openrouter/nvidia/nemotron-3-super-120b-a12b:free", "api_base": "https://openrouter.ai/api/v1", "rpm": 20 }
  ],
  "gateway": {
    "host": "0.0.0.0",
    "port": 18790,
    "hot_reload": false,
    "log_level": "warn"
  }
}
EOF
    
    success "Cấu hình được lưu thành công tại $CONF_DIR/config.json"
    return 0
}

# ---------- Parse Args ----------
if [ $# -gt 0 ]; then
    case "$1" in
        --remove|-r) remove_picoclaw ;;
        --version|-v) show_version ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "  -r, --remove      Remove PicoClaw"
            echo "  -v, --version     Show version"
            exit 0
            ;;
    esac
fi

info "install_picoclaw_termux.sh version $SCRIPT_VERSION"

# ---------- Cài đặt gói nền tảng ----------
section "Cài đặt/Cập nhật các gói hệ thống"
pkg update -y || true
pkg install -y wget tar ca-certificates grep curl || die "Cài đặt gói nền tảng thất bại"

# Đảm bảo biến môi trường SSL luôn được nạp khi khởi động terminal
if ! grep -q "SSL_CERT_FILE" ~/.bashrc; then
    echo "export SSL_CERT_FILE=$CERT_PATH" >> ~/.bashrc
fi

# ---------- Tự động quét tìm Version mới nhất ----------
section "Đang tìm phiên bản PicoClaw mới nhất..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/sipeed/picoclaw/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    info "Không thể quét qua API GitHub, sử dụng phiên bản dự phòng v0.2.8"
    LATEST_VERSION="v0.2.8"
else
    success "Đã tìm thấy phiên bản mới nhất: $LATEST_VERSION"
fi

# ---------- Tải & Giải nén bản mới nhất ----------
section "Tải về PicoClaw $LATEST_VERSION"
cd "$HOME"
DOWNLOAD_URL="https://github.com/sipeed/picoclaw/releases/download/${LATEST_VERSION}/picoclaw_Linux_arm64.tar.gz"

wget -O picoclaw.tar.gz "${DOWNLOAD_URL}" || die "Tải PicoClaw thất bại. Có thể cấu trúc đặt tên file trên Release đã thay đổi."
tar -xzvf picoclaw.tar.gz || die "Giải nén gói cài đặt thất bại"
chmod +x picoclaw

section "Đưa vào hệ thống lưu trữ lệnh"
mv picoclaw "$TERMUX_BIN/picoclaw"
rm -f picoclaw.tar.gz

section "Kiểm tra phiên bản thực tế vừa cài"
export SSL_CERT_FILE=$CERT_PATH
picoclaw --version || true

# ---------- Cấu hình ----------
if [ -f "$CONF_DIR/config.json" ]; then
    read -p "Phát hiện file cấu hình cũ. Bạn có muốn ghi đè cấu hình mới không? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        configure_picoclaw
    fi
else
    configure_picoclaw
fi

# ---------- Hoàn tất ----------
section "Cài đặt thành công PicoClaw phiên bản mới nhất!"
echo "Để chạy bot, vui lòng gõ lệnh:"
echo "  source ~/.bashrc"
echo "  picoclaw"
echo

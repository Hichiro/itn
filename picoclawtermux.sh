#!/data/data/com.termux/files/usr/bin/bash
# install_picoclaw_termux.sh
# Interactive installer for PicoClaw on Android with OpenRouter config
# Version: 6

set -Eeuo pipefail

SCRIPT_VERSION="6"

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

# ---------- Remove PicoClaw ----------
remove_picoclaw() {
    section "Removing PicoClaw"
    local BIN_PATH="/data/data/com.termux/files/usr/bin/picoclaw"
    if [ -f "$BIN_PATH" ]; then
        rm -f "$BIN_PATH"
        success "Removed $BIN_PATH"
    else
        info "PicoClaw not found at $BIN_PATH"
    fi
    if [ -d "$HOME/.picoclaw" ]; then
        read -p "Remove PicoClaw config directory ($HOME/.picoclaw)? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$HOME/.picoclaw"
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

# ---------- Configure OpenRouter ----------
configure_openrouter() {
    section "Configuring OpenRouter"
    
    echo
    echo "Select a model:"
    echo "1) Qwen3 80B (free) - qwen/qwen3-next-80b-a3b-instruct:free"
    echo "2) DeepSeek V3 - deepseek/deepseek-chat"
    echo "3) Llama 3.3 70B (free) - meta-llama/llama-3.3-70b-instruct:free"
    echo "4) Custom model"
    echo
    read -p "Enter choice [1-4]: " model_choice
    
    case $model_choice in
        1)
            MODEL="qwen/qwen3-next-80b-a3b-instruct:free"
            MODEL_NAME="qwen3-free"
            ;;
        2)
            MODEL="deepseek/deepseek-chat"
            MODEL_NAME="deepseek-chat"
            ;;
        3)
            MODEL="meta-llama/llama-3.3-70b-instruct:free"
            MODEL_NAME="llama-3.3-70b"
            ;;
        4)
            read -p "Enter model name (e.g., openai/gpt-4): " MODEL
            read -p "Enter model alias (e.g., gpt-4): " MODEL_NAME
            ;;
        *)
            MODEL="qwen/qwen3-next-80b-a3b-instruct:free"
            MODEL_NAME="qwen3-free"
            ;;
    esac
    
    echo
    read -p "Enter your OpenRouter API key (sk-or-v1-...): " API_KEY
    
    if [ -z "$API_KEY" ]; then
        error "No API key provided. Skipping config."
        return 1
    fi
    
    mkdir -p "$HOME/.picoclaw"
    
    cat > "$HOME/.picoclaw/config.json" << EOF
{
  "agents": {
    "defaults": {
      "workspace": "~/.picoclaw/workspace",
      "restrict_to_workspace": true,
      "model_name": "$MODEL_NAME",
      "max_tokens": 8192,
      "temperature": 0.7,
      "max_tool_iterations": 20
    }
  },
  "model_list": [
    {
      "model_name": "$MODEL_NAME",
      "model": "openrouter/$MODEL",
      "api_key": "$API_KEY",
      "api_base": "https://openrouter.ai/api/v1"
    }
  ],
  "channels": {
    "whatsapp": { "enabled": false, "bridge_url": "ws://localhost:3001", "allow_from": [] },
    "telegram": { "enabled": false, "token": "", "allow_from": [] },
    "discord": { "enabled": false, "token": "", "allow_from": [] }
  },
  "tools": {
    "web": {
      "duckduckgo": { "enabled": true, "max_results": 5 }
    }
  },
  "heartbeat": { "enabled": true, "interval": 30 },
  "gateway": { "host": "127.0.0.1", "port": 18790 }
}
EOF
    
    success "Config saved to ~/.picoclaw/config.json"
    info "Model: $MODEL"
    return 0
}

# ---------- Parse Args ----------
if [ $# -gt 0 ]; then
    case "$1" in
        --remove|-r)
            remove_picoclaw
            ;;
        --version|-v)
            show_version
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -r, --remove     Remove PicoClaw installation"
            echo "  -v, --version    Show script version"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
    esac
fi

info "install_picoclaw_termux.sh version $SCRIPT_VERSION"

# ---------- Config ----------
PICOCLAW_VERSION="v0.1.1"
PICOCLAW_BINARY="picoclaw-linux-arm64"
DOWNLOAD_URL="https://github.com/sipeed/picoclaw/releases/download/${PICOCLAW_VERSION}/${PICOCLAW_BINARY}"
TERMUX_BIN="/data/data/com.termux/files/usr/bin"

# ---------- Termux baseline ----------
section "Request storage access"
termux-setup-storage || true

section "Update Termux packages"
yes | pkg update || true
yes | pkg upgrade || true

section "Install wget"
pkg install -y wget || die "Failed to install wget"
pkg install -y termux-api || true

# ---------- PicoClaw ----------
section "Download PicoClaw ${PICOCLAW_VERSION}"
cd "$HOME"
wget -O picoclaw "${DOWNLOAD_URL}" || die "Failed to download PicoClaw"
chmod +x picoclaw

section "Install PicoClaw"
mv picoclaw "$TERMUX_BIN/picoclaw"
ls -la "$TERMUX_BIN/picoclaw" || die "Failed to install picoclaw"

section "Verify installation"
which picoclaw || die "picoclaw not in PATH"
picoclaw --version 2>/dev/null || true

# ---------- Configure ----------
section "Configuration"
echo
read -p "Configure OpenRouter now? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    configure_openrouter
else
    info "Skipping config. Run 'picoclaw onboard' later."
fi

# ---------- Final steps ----------
section "Installation Complete!"
echo
echo "Usage:"
echo "  picoclaw agent -m 'Hello'    # Single message"
echo "  picoclaw agent               # Interactive mode"
echo "  picoclaw gateway             # Start gateway"
echo "  picoclaw status              # Check status"
echo
echo "Config: ~/.picoclaw/config.json"
echo

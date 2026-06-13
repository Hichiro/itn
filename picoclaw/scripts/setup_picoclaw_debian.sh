#!/bin/bash

# ========================================================
# HÀM TIỆN ÍCH
# ========================================================

create_picoclaw_service() {
    local exec_path="$1"
    local exec_args="$2"
    local service_name="$3"

    sudo tee /etc/systemd/system/${service_name}.service > /dev/null <<EOF
[Unit]
Description=PicoClaw ${service_name} Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME
Environment=TZ=Asia/Ho_Chi_Minh
ExecStart=${exec_path} ${exec_args}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable ${service_name} &>/dev/null
}

print_access_links() {
    echo "• Các địa chỉ WebUI có thể truy cập:"
    echo "  - Trực tiếp trên máy: http://localhost:18800"
    # Liệt kê tất cả IP LAN
    for ip in $(hostname -I 2>/dev/null); do
        echo "  - Qua mạng LAN:       http://$ip:18800"
    done
    # Liệt kê IP Public
    PUBLIC_IP=$(curl -s --max-time 2 ifconfig.me)
    if [ -n "$PUBLIC_IP" ]; then
        echo "  - Qua IP Public:      http://$PUBLIC_IP:18800"
    fi
}

# ========================================================
# CHƯƠNG TRÌNH CHÍNH
# ========================================================

echo "================================================="
echo "   CÀI ĐẶT & CẤU HÌNH PICOCLAW THÔNG MINH VM     "
echo "================================================="

sudo apt-get update -y && sudo apt-get install -y curl procps bc jq tar

mkdir -p $HOME/go/bin $HOME/.picoclaw /tmp
VERSION_FILE="$HOME/.picoclaw/.version"
HAS_CHANGES=false

# ====================== BƯỚC 0: KIỂM TRA SỨC KHỎE ======================
SERVICE_FILE="/etc/systemd/system/picoclaw.service"
IS_INSTALLED=false
if [ -f "$HOME/go/bin/picoclaw" ] && [ -f "$SERVICE_FILE" ]; then IS_INSTALLED=true; fi

if [ "$IS_INSTALLED" = true ]; then
    echo ""
    echo "=== 0. KIỂM TRA SỨC KHỎE HỆ THỐNG ==="
    if systemctl is-active --quiet picoclaw; then
        PID=$(systemctl show -p MainPID --value picoclaw)
        echo "🟢 Dịch vụ picoclaw ĐANG CHẠY ổn định (PID: $PID)."
    else
        echo "🔴 Dịch vụ picoclaw ĐANG DỪNG hoặc gặp lỗi."
    fi
else
    echo "💡 Thông báo: Thiết lập PicoClaw mới..."
    HAS_CHANGES=true
fi

# ====================== BƯỚC 1: CẤU HÌNH CONFIG ======================
echo ""
echo "=== 1. KIỂM TRA CẤU HÌNH ==="
if [ ! -f "$HOME/.picoclaw/config.json" ] || [ ! -f "$HOME/.picoclaw/.security.yml" ]; then
    read -p "🔍 Thiếu file cấu hình. Tải mẫu? (y/n, Mặc định: y): " config_choice </dev/tty
    config_choice=${config_choice:-y}
    if [[ "$config_choice" == [Yy] ]]; then
        mkdir -p $HOME/.picoclaw
        curl -L -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/picoclaw/config.json" -o $HOME/.picoclaw/config.json
        curl -L -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/picoclaw/.security.yml" -o $HOME/.picoclaw/.security.yml
        HAS_CHANGES=true
    fi
fi

# ====================== BƯỚC 2: CẬP NHẬT ======================
echo ""
echo "=== 2. KIỂM TRA PHIÊN BẢN ==="
LATEST_TAG=$(curl -s https://api.github.com/repos/sipeed/picoclaw/releases/latest | jq -r '.tag_name')
[ -z "$LATEST_TAG" ] && LATEST_TAG="latest"
LOCAL_VERSION=$( [ -f "$VERSION_FILE" ] && cat "$VERSION_FILE" || echo "none" )

if [ "$LOCAL_VERSION" != "$LATEST_TAG" ]; then
    echo "🔥 Phát hiện phiên bản mới: $LATEST_TAG"
    read -p "🔄 Cập nhật ngay? (y/n, Mặc định: y): " update_choice </dev/tty
    update_choice=${update_choice:-y}
    if [[ "$update_choice" == [Yy] ]]; then
        DOWNLOAD_URL="https://github.com/sipeed/picoclaw/releases/download/${LATEST_TAG}/picoclaw_Linux_x86_64.tar.gz"
        cd /tmp && curl -L -fsSL "$DOWNLOAD_URL" -o picoclaw.tar.gz
        tar -xzf picoclaw.tar.gz -C /tmp && cp -f /tmp/picoclaw $HOME/go/bin/ && chmod +x $HOME/go/bin/picoclaw
        echo "$LATEST_TAG" > "$VERSION_FILE"
        HAS_CHANGES=true
    fi
fi

# ====================== BƯỚC 3: LAUNCHER ======================
echo ""
echo "=== 3. CHẾ ĐỘ CHẠY (LAUNCHER) ==="
IS_LAUNCHER=$(grep -q "picoclaw-launcher" "$SERVICE_FILE" && echo true || echo false)
FINAL_LAUNCHER=false
read -p "🖥️ Bật WebUI Launcher? (y/n): " launcher_choice </dev/tty
if [[ "$launcher_choice" == [Yy] ]]; then FINAL_LAUNCHER=true; fi

if [ "$FINAL_LAUNCHER" != "$IS_LAUNCHER" ]; then HAS_CHANGES=true; fi

if [ "$FINAL_LAUNCHER" = true ]; then
    create_picoclaw_service "$HOME/go/bin/picoclaw-launcher" "--public --port 18800 -no-browser" "picoclaw"
    RUNNING_MODE="PicoClaw Launcher (WebUI)"
else
    create_picoclaw_service "$HOME/go/bin/picoclaw" "onboard --port 18800" "picoclaw"
    RUNNING_MODE="PicoClaw Core (No WebUI)"
fi

# ====================== BƯỚC 4: KHỞI CHẠY ======================
echo ""
echo "=== 4. TRẠNG THÁI HỆ THỐNG ==="
if [ "$HAS_CHANGES" = false ] && systemctl is-active --quiet picoclaw; then
    echo "✅ Không có thay đổi. Dịch vụ đang chạy ổn định."
    [ "$FINAL_LAUNCHER" = true ] && print_access_links
    exit 0
fi

if [ "$HAS_CHANGES" = false ]; then
    read -p "⚠️ Dịch vụ đang dừng. Khởi động lại? (y/n, Mặc định: y): " restart_choice </dev/tty
    restart_choice=${restart_choice:-y}
    [[ "$restart_choice" != [Yy] ]] && exit 0
fi

echo "🚀 Áp dụng cấu hình và khởi chạy..."
sudo systemctl restart picoclaw
sleep 2

if systemctl is-active --quiet picoclaw; then
    echo "================================================="
    echo "       🎉 HỆ THỐNG HOẠT ĐỘNG ỔN ĐỊNH!            "
    echo "================================================="
    echo "• Chế độ: $RUNNING_MODE"
    [ "$FINAL_LAUNCHER" = true ] && print_access_links
    echo "================================================="
else
    echo "❌ Lỗi khởi chạy. Kiểm tra logs:"
    sudo journalctl -u picoclaw -n 5 --no-pager
fi

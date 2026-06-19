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
    echo "  - Qua mạng LAN:      $(hostname -I | awk '{print "http://"$1":18800"}' | tr ' ' '\n' | sed 's/$/\n  - Qua mạng LAN:       /' | head -n -1)"
    
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

# ====================== BỔ SUNG: CẤU HÌNH PATH VĨNH VIỄN ======================
if ! grep -q 'go/bin' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/go/bin:$PATH"' >> "$HOME/.bashrc"
    echo "✓ Đã tự động cấu hình PATH vĩnh viễn vào .bashrc"
    HAS_CHANGES=true
fi
export PATH="$HOME/go/bin:$PATH"

# ====================== BƯỚC KIỂM TRA SƠ BỘ TÌNH TRẠNG CÀI ĐẶT ======================
SERVICE_FILE="/etc/systemd/system/picoclaw.service"
IS_INSTALLED=false

if [ -f "$HOME/go/bin/picoclaw" ] && [ -f "$SERVICE_FILE" ]; then
    IS_INSTALLED=true
fi

# ====================== 0. KIỂM TRA SỨC KHỎE (NẾU ĐÃ CÀI ĐẶT) ======================
if [ "$IS_INSTALLED" = true ]; then
    echo ""
    echo "=== 0. KIỂM TRA SỨC KHỎE HỆ THỐNG HIỆN TẠI ==="
    if systemctl is-active --quiet picoclaw; then
        PID=$(systemctl show -p MainPID --value picoclaw)
        CPU_USAGE=$(ps -p $PID -o %cpu | tail -n 1 | tr -d '[:space:]')
        RAM_USAGE=$(ps -p $PID -o %mem | tail -n 1 | tr -d '[:space:]')
        
        echo "🟢 Dịch vụ picoclaw ĐANG CHẠY ổn định (PID: $PID)."
        echo "📊 Tài nguyên thực tế: CPU: $CPU_USAGE% | RAM: $RAM_USAGE%"
    else
        echo "🔴 Dịch vụ picoclaw ĐÃ ĐƯỢC CÀI ĐẶT nhưng hiện tại ĐÁNG DỪNG hoặc gặp lỗi."
        echo "⚠️ Nhật ký lỗi gần nhất từ hệ thống:"
        sudo journalctl -u picoclaw -n 3 --no-pager
    fi
else
    echo ""
    echo "💡 Thông báo: Phát hiện PicoClaw CHƯA TỪNG ĐƯỢC CÀI ĐẶT trên máy ảo này. Bắt đầu thiết lập mới..."
    HAS_CHANGES=true
fi

# ====================== 1. KIỂM TRA FILE CẤU HÌNH ======================
echo ""
echo "=== 1. KIỂM TRA CẤU HÌNH CONFIG ==="
MISSING_CONFIG=false
if [ ! -f "$HOME/.picoclaw/config.json" ] || [ ! -f "$HOME/.picoclaw/.security.yml" ]; then
    MISSING_CONFIG=true
fi

if [ "$MISSING_CONFIG" = true ]; then
    read -p "🔍 Thiếu file cấu hình trong .picoclaw. Tải bộ cấu hình sẵn mẫu? (y/n, Mặc định: y): " config_choice </dev/tty
    config_choice=${config_choice:-y}
    if [[ "$config_choice" == [Yy] ]]; then
        mkdir -p $HOME/.picoclaw
        curl -L -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/picoclaw/config.json" -o $HOME/.picoclaw/config.json
        curl -L -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/picoclaw/.security.yml" -o $HOME/.picoclaw/.security.yml
        echo "✓ Đã tải cấu hình mẫu vào $HOME/.picoclaw"
        HAS_CHANGES=true
    fi
else
    echo "✓ Đã có sẵn đầy đủ file cấu hình tại $HOME/.picoclaw."
fi

# ====================== 2. TỰ ĐỘNG KIỂM TRA UPDATE ======================
echo ""
echo "=== 2. KIỂM TRA PHIÊN BẢN CẬP NHẬT ==="
LATEST_TAG=$(curl -s https://api.github.com/repos/sipeed/picoclaw/releases/latest | jq -r '.tag_name')

if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" == "null" ]; then
    LATEST_TAG="latest"
    DOWNLOAD_URL="https://github.com/sipeed/picoclaw/releases/latest/download/picoclaw_Linux_x86_64.tar.gz"
else
    DOWNLOAD_URL="https://github.com/sipeed/picoclaw/releases/download/${LATEST_TAG}/picoclaw_Linux_x86_64.tar.gz"
fi

LOCAL_VERSION="Chưa rõ"
if [ -f "$VERSION_FILE" ]; then
    LOCAL_VERSION=$(cat "$VERSION_FILE")
fi

NEED_DOWNLOAD=false

if [ "$IS_INSTALLED" = false ]; then
    echo "📥 Đang tiến hành cài đặt phiên bản mới nhất ($LATEST_TAG)..."
    NEED_DOWNLOAD=true
else
    if [ "$LATEST_TAG" == "latest" ]; then
        read -p "⚠️ Lỗi mạng, không xác định được phiên bản. Bạn có muốn tải lại file không? (y/n, Mặc định: n): " update_choice </dev/tty
        update_choice=${update_choice:-n}
        if [[ "$update_choice" == [Yy] ]]; then NEED_DOWNLOAD=true; fi
    elif [ "$LOCAL_VERSION" == "$LATEST_TAG" ]; then
        echo "✓ Phiên bản trên máy ($LOCAL_VERSION) đã là mới nhất. Bỏ qua tải về."
    else
        echo "🔥 Phát hiện phiên bản mới: $LATEST_TAG (Bản trên máy: $LOCAL_VERSION)"
        read -p "🔄 Bạn có muốn cập nhật lên bản $LATEST_TAG không? (y/n, Mặc định: y): " update_choice </dev/tty
        update_choice=${update_choice:-y}
        if [[ "$update_choice" == [Yy] ]]; then NEED_DOWNLOAD=true; fi
    fi
fi

if [ "$NEED_DOWNLOAD" = true ]; then
    echo "📥 Đang tải gói PicoClaw từ GitHub..."
    cd /tmp && curl -L -fsSL "$DOWNLOAD_URL" -o picoclaw.tar.gz
    if [ -s picoclaw.tar.gz ]; then
        mkdir -p /tmp/picoclaw_extracted
        tar -xzf picoclaw.tar.gz -C /tmp/picoclaw_extracted
        [ -f /tmp/picoclaw_extracted/picoclaw ] && cp -f /tmp/picoclaw_extracted/picoclaw $HOME/go/bin/picoclaw && chmod +x $HOME/go/bin/picoclaw
        [ -f /tmp/picoclaw_extracted/picoclaw-launcher ] && cp -f /tmp/picoclaw_extracted/picoclaw-launcher $HOME/go/bin/picoclaw-launcher && chmod +x $HOME/go/bin/picoclaw-launcher
        rm -rf /tmp/picoclaw.tar.gz /tmp/picoclaw_extracted
        
        echo "$LATEST_TAG" > "$VERSION_FILE"
        echo "✓ Cập nhật file thực thi hoàn tất."
        HAS_CHANGES=true
    else
        echo "❌ Lỗi: Không thể tải file từ GitHub. Script sẽ dùng file hiện tại trên máy (nếu có)."
    fi
fi

# ====================== 3. KIỂM TRA TRẠNG THÁI LAUNCHER HIỆN TẠI ======================
echo ""
echo "=== 3. KIỂM TRA & THIẾT LẬP CHẾ ĐỘ CHẠY (LAUNCHER) ==="

IS_LAUNCHER_RUNNING=false
if [ "$IS_INSTALLED" = true ] && grep -q "picoclaw-launcher" "$SERVICE_FILE"; then
    IS_LAUNCHER_RUNNING=true
fi

FINAL_LAUNCHER=false

if [ "$IS_INSTALLED" = false ]; then
    read -p "🖥️ Bạn có muốn kích hoạt giao diện WebUI (Launcher) không? (y/n, Mặc định: n): " launcher_choice </dev/tty
    launcher_choice=${launcher_choice:-n}
    if [[ "$launcher_choice" == [Yy] ]]; then
        FINAL_LAUNCHER=true
    fi
else
    if [ "$IS_LAUNCHER_RUNNING" = true ]; then
        echo "💡 Cấu hình hiện tại: Giao diện WebUI (Launcher) ĐÁNG ĐƯỢC CHỌN."
        read -p "🔄 Bạn có muốn THAY ĐỔI (Tắt Launcher dể quay về bản Core trần) không? (y/n, Mặc định: n): " change_choice </dev/tty
        change_choice=${change_choice:-n}
        if [[ "$change_choice" == [Yy] ]]; then
            FINAL_LAUNCHER=false
            echo "➔ Sẽ sửa cấu hình chuyển về chế độ Core."
            HAS_CHANGES=true
        else
            FINAL_LAUNCHER=true
            echo "➔ Giữ nguyên cấu hình chế độ Launcher."
        fi
    else
        echo "💡 Cấu hình hiện tại: Bản Core trần (Launcher ĐÁNG TẮT)."
        read -p "🔄 Bạn có muốn THAY ĐỔI (Bật giao diện WebUI Launcher lên) không? (y/n, Mặc định: n): " change_choice </dev/tty
        change_choice=${change_choice:-n}
        if [[ "$change_choice" == [Yy] ]]; then
            FINAL_LAUNCHER=true
            echo "➔ Sẽ sửa cấu hình kích hoạt chế độ Launcher."
            HAS_CHANGES=true
        else
            FINAL_LAUNCHER=false
            echo "➔ Giữ nguyên cấu hình chế độ Core."
        fi
    fi
fi

if [ "$FINAL_LAUNCHER" = true ] && [ -f "$HOME/go/bin/picoclaw-launcher" ]; then
    create_picoclaw_service "$HOME/go/bin/picoclaw-launcher" "--public --port 18800 -no-browser" "picoclaw"
    RUNNING_MODE="PicoClaw Launcher (WebUI)"
elif [ -f "$HOME/go/bin/picoclaw" ]; then
    create_picoclaw_service "$HOME/go/bin/picoclaw" "onboard --port 18800" "picoclaw"
    RUNNING_MODE="PicoClaw Core (No WebUI)"
else
    echo "❌ Lỗi nghiêm trọng: Không tìm thấy file thực thi nào trong go/bin dể tạo service!"
    exit 1
fi

# ====================== 4. ÁP DỤNG CẤU HÌNH ======================
echo ""
echo "=== 4. TRẠNG THÁI HỆ THỐNG ==="

if [ "$HAS_CHANGES" = false ]; then
    if systemctl is-active --quiet picoclaw; then
        echo "✅ Dịch vụ PicoClaw ĐÁNG CHẠY ổn định."
        [ "$FINAL_LAUNCHER" = true ] && print_access_links
        exit 0
    fi
fi

echo "🚀 Đáng áp dụng cấu hình và khởi chạy dịch vụ..."
sudo systemctl restart picoclaw
sleep 2

if systemctl is-active --quiet picoclaw; then
    echo "================================================="
    echo "       🎉 HỆ THỐNG HOẠT ĐỘNG ỔN ĐỊNH!            "
    echo "================================================="
    echo "• Chế độ: $RUNNING_MODE"
    if [ "$FINAL_LAUNCHER" = true ]; then
        echo "• Các địa chỉ WebUI có thể truy cập:"
        echo "  - Trực tiếp trên máy: http://localhost:18800"
        echo "  - Trực tiếp trên máy: http://127.0.0.1:18800"
        
        for ip in $(hostname -I 2>/dev/null); do
            echo "  - Qua mạng LAN:       http://$ip:18800"
        done
        
        PUBLIC_IP=$(curl -s --max-time 2 ifconfig.me)
        if [ -n "$PUBLIC_IP" ]; then
            echo "  - Qua IP Public:      http://$PUBLIC_IP:18800"
        fi
    fi
    echo "================================================="
else
    echo "================================================="
    echo "  ❌ LỖI KHỞI CHẠY TIẾN TRÌNH!                   "
    echo "================================================="
    sudo journalctl -u picoclaw -n 10 --no-pager
    echo "================================================="
fi

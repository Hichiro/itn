#!/bin/bash

# ========================================================
# HÀM TIỆN ÍCH
# ========================================================

create_picoclaw_service() {
    local exec_path="$1"
    local exec_args="$2"
    local service_name="$3"

    echo "⚙️ Đang cập nhật file cấu hình dịch vụ hệ thống cho $service_name..."
    
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

# ========================================================
# CHƯƠNG TRÌNH CHÍNH
# ========================================================

echo "================================================="
echo "   CÀI ĐẶT & CẤU HÌNH PICOCLAW THÔNG MINH VM     "
echo "================================================="

sudo apt-get update -y && sudo apt-get install -y curl procps bc jq tar

mkdir -p $HOME/go/bin $HOME/.picoclaw /tmp

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
        echo "🔴 Dịch vụ picoclaw ĐÃ ĐƯỢC CÀI ĐẶT nhưng hiện tại ĐANG DỪNG hoặc gặp lỗi."
        echo "⚠️ Nhật ký lỗi gần nhất từ hệ thống:"
        sudo journalctl -u picoclaw -n 3 --no-pager
    fi
else
    echo ""
    echo "💡 Thông báo: Phát hiện PicoClaw CHƯA TỪNG ĐƯỢC CÀI ĐẶT trên máy ảo này. Bắt đầu thiết lập mới..."
fi

# ====================== 1. KIỂM TRA FILE CẤU HÌNH ======================
echo ""
echo "=== 1. KIỂM TRA CẤU HÌNH CONFIG ==="
MISSING_CONFIG=false
if [ ! -f "$HOME/.picoclaw/config.json" ] || [ ! -f "$HOME/.picoclaw/.security.yml" ]; then
    MISSING_CONFIG=true
fi

if [ "$MISSING_CONFIG" = true ]; then
    read -p "🔍 Thiếu file cấu hình trong .picoclaw. Tải bộ cấu hình sẵn mẫu? (y/n, Mặc định: y): " config_choice </dev/tty
    config_choice=${config_choice:-y}
    if [[ "$config_choice" == [Yy] ]]; then
        mkdir -p $HOME/.picoclaw
        curl -L -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/picoclaw/config.json" -o $HOME/.picoclaw/config.json
        curl -L -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/picoclaw/.security.yml" -o $HOME/.picoclaw/.security.yml
        echo "✓ Đã tải cấu hình mẫu vào $HOME/.picoclaw"
    fi
else
    echo "✓ Đã có sẵn đầy đủ file cấu hình tại $HOME/.picoclaw."
fi

# ====================== 2. TỰ ĐỘNG KIỂM TRA UPDATE ======================
echo ""
echo "=== 2. KIỂM TRA PHIÊN BẢN CẬP NHẬT ==="
LATEST_TAG=$(curl -s https://api.github.com/repos/sipeed/picoclaw/releases/latest | jq -r '.tag_name')

# [CẢI TIẾN LOGIC 1]: Fallback phòng trường hợp GitHub API trả về rỗng/null
if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" == "null" ]; then
    LATEST_TAG="latest"
    DOWNLOAD_URL="https://github.com/sipeed/picoclaw/releases/latest/download/picoclaw_Linux_x86_64.tar.gz"
else
    DOWNLOAD_URL="https://github.com/sipeed/picoclaw/releases/download/${LATEST_TAG}/picoclaw_Linux_x86_64.tar.gz"
fi

NEED_DOWNLOAD=true
if [ "$IS_INSTALLED" = true ]; then
    read -p "🔄 Bạn có muốn kiểm tra và tải đè bản mới nhất ($LATEST_TAG) từ GitHub không? (y/n, Mặc định: y): " update_choice </dev/tty
    update_choice=${update_choice:-y}
    if [[ "$update_choice" != [Yy] ]]; then
        NEED_DOWNLOAD=false
    fi
else
    echo "📥 Đang tiến hành tải phiên bản mới nhất ($LATEST_TAG)..."
fi

if [ "$NEED_DOWNLOAD" = true ]; then
    echo "📥 Đang tải gói PicoClaw từ GitHub..."
    cd /tmp && curl -L -fsSL "$DOWNLOAD_URL" -o picoclaw.tar.gz
    if [ -s picoclaw.tar.gz ]; then
        mkdir -p /tmp/picoclaw_extracted
        tar -xzf picoclaw.tar.gz -C /tmp/picoclaw_extracted
        [ -f /tmp/picoclaw_extracted/picoclaw ] && cp -f /tmp/picoclaw_extracted/picoclaw $HOME/go/bin/picoclaw && chmod +x $HOME/go/bin/picoclaw
        [ -f /tmp/picoclaw_extracted/picoclaw-launcher ] && cp -f /tmp/picoclaw_extracted/picoclaw-launcher $HOME/go/bin/picoclaw-launcher && chmod +x $HOME/go/bin/picoclaw-launcher
        rm -rf /tmp/picoclaw.tar.gz /tmp/picoclaw_extracted
        echo "✓ Cập nhật file thực thi hoàn tất."
    else
        echo "❌ Lỗi: Không thể tải file từ GitHub. Script sẽ dùng file hiện tại trên máy (nếu có)."
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
    read -p "🖥️ Bạn có muốn kích hoạt giao diện WebUI (Launcher) không? (y/n, Mặc định: n): " launcher_choice </dev/tty
    launcher_choice=${launcher_choice:-n}
    if [[ "$launcher_choice" == [Yy] ]]; then
        FINAL_LAUNCHER=true
    fi
else
    if [ "$IS_LAUNCHER_RUNNING" = true ]; then
        echo "💡 Cấu hình hiện tại: Giao diện WebUI (Launcher) ĐANG ĐƯỢC CHỌN."
        read -p "🔄 Bạn có muốn THAY ĐỔI (Tắt Launcher để quay về bản Core trần) không? (y/n, Mặc định: n): " change_choice </dev/tty
        change_choice=${change_choice:-n}
        if [[ "$change_choice" == [Yy] ]]; then
            FINAL_LAUNCHER=false
            echo "➔ Sẽ sửa cấu hình chuyển về chế độ Core."
        else
            FINAL_LAUNCHER=true
            echo "➔ Giữ nguyên cấu hình chế độ Launcher."
        fi
    else
        echo "💡 Cấu hình hiện tại: Bản Core trần (Launcher ĐANG TẮT)."
        read -p "🔄 Bạn có muốn THAY ĐỔI (Bật giao diện WebUI Launcher lên) không? (y/n, Mặc định: n): " change_choice </dev/tty
        change_choice=${change_choice:-n}
        if [[ "$change_choice" == [Yy] ]]; then
            FINAL_LAUNCHER=true
            echo "➔ Sẽ sửa cấu hình kích hoạt chế độ Launcher."
        else
            FINAL_LAUNCHER=false
            echo "➔ Giữ nguyên cấu hình chế độ Core."
        fi
    fi
fi

export PATH="$HOME/go/bin:$PATH"

# [CẢI TIẾN LOGIC 3]: Kiểm tra file nhị phân có tồn tại thực tế trước khi tạo Service
if [ "$FINAL_LAUNCHER" = true ] && [ -f "$HOME/go/bin/picoclaw-launcher" ]; then
    create_picoclaw_service "$HOME/go/bin/picoclaw-launcher" "--public --port 18800 -no-browser" "picoclaw"
    RUNNING_MODE="PicoClaw Launcher (WebUI)"
elif [ -f "$HOME/go/bin/picoclaw" ]; then
    create_picoclaw_service "$HOME/go/bin/picoclaw" "onboard --port 18800" "picoclaw"
    RUNNING_MODE="PicoClaw Core (No WebUI)"
else
    echo "❌ Lỗi nghiêm trọng: Không tìm thấy file thực thi nào trong go/bin để tạo service!"
    exit 1
fi

# ====================== 4. HỎI NGƯỜI DÙNG TRƯỚC KHI KHỔI ĐỘNG LẠI ======================
echo ""
echo "=== 4. ÁP DỤNG CẤU HÌNH ==="

# [CẢI TIẾN LOGIC 2]: Thay đổi giá trị mặc định của câu hỏi Khởi động tùy theo kịch bản cài đặt
if [ "$IS_INSTALLED" = false ]; then
    DEFAULT_CHOICE="y"
    PROMPT_MSG="🚀 Phát hiện cài mới, bạn có muốn KHỔI ĐỘNG dịch vụ ngay bây giờ không? (y/n, Mặc định: y): "
else
    DEFAULT_CHOICE="n"
    PROMPT_MSG="🚀 Bạn có muốn KHỔI ĐỘNG LẠI dịch vụ ngay bây giờ để áp dụng thay đổi không? (y/n, Mặc định: n): "
fi

read -p "$PROMPT_MSG" restart_choice </dev/tty
restart_choice=${restart_choice:-$DEFAULT_CHOICE}

if [[ "$restart_choice" == [Yy] ]]; then
    echo "🔄 Đang kích hoạt dịch vụ picoclaw..."
    sudo systemctl restart picoclaw
    sleep 2

    if systemctl is-active --quiet picoclaw; then
        echo "================================================="
        echo "       🎉 HỆ THỐNG HOẠT ĐỘNG ỔN ĐỊNH!            "
        echo "================================================="
        echo "• Chế độ: $RUNNING_MODE"
        [ "$FINAL_LAUNCHER" = true ] && echo "• WebUI URL: http://<IP_MÁY_ẢO_CỦA_BẠN>:18800"
        echo "================================================="
    else
        echo "================================================="
        echo "   ❌ LỖI KHỞI CHẠY TIẾN TRÌNH!                  "
        echo "================================================="
        sudo journalctl -u picoclaw -n 4 --no-pager
        echo "================================================="
    fi
else
    echo "⏭️ Đã bỏ qua bước khởi động. Cấu hình mới đã được ghi nhận vào hệ thống."
fi

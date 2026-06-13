#!/bin/bash

# ========================================================
# HÀM TIỆN ÍCH: TỰ ĐỘNG KHỞI ĐỘNG CÙNG HỆ THỐNG (SYSTEMD)
# ========================================================

create_picoclaw_service() {
    local exec_path="$1"
    local exec_args="$2"
    local service_name="$3"

    echo "⚙️ Đang cấu hình dịch vụ hệ thống cho $service_name..."
    
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
    sudo systemctl enable ${service_name}
    sudo systemctl restart ${service_name}
    echo "✓ Đã thiết lập chạy ngầm và tự khởi động cùng máy ảo cho ${service_name}."
}

# ========================================================
# CHƯƠNG TRÌNH CHÍNH
# ========================================================

echo "================================================="
echo "   CÀI ĐẶT & CẤU HÌNH PICOCLAW TRÊN DEBIAN VM    "
echo "================================================="

# Cài đặt thêm tar để giải nén file cấu trúc mới
sudo apt-get update && sudo apt-get install -y curl procps bc jq tar

mkdir -p $HOME/go/bin $HOME/.picoclaw /tmp

# Lấy thông tin phiên bản mới nhất từ GitHub
echo "🔍 Đang kiểm tra phiên bản mới nhất trên GitHub..."
LATEST_TAG=$(curl -s https://api.github.com/repos/sipeed/picoclaw/releases/latest | jq -r '.tag_name')

if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" == "null" ]; then
    echo "⚠️ Không thể kết nối tới GitHub API. Sẽ dùng fallback link cấu trúc mới."
    DOWNLOAD_URL="https://github.com/sipeed/picoclaw/releases/latest/download/picoclaw_Linux_x86_64.tar.gz"
    LATEST_TAG="latest"
else
    echo "🔥 Phát hiện phiên bản ổn định mới nhất: $LATEST_TAG"
    DOWNLOAD_URL="https://github.com/sipeed/picoclaw/releases/download/${LATEST_TAG}/picoclaw_Linux_x86_64.tar.gz"
fi

# ====================== 1. TỰ ĐỘNG TÍNH TOÁN VÀ TẠO SWAP ======================
echo ""
echo "=== 1. KIỂM TRA VÀ CẤU HÌNH SWAP (RAM ẢO) ==="
CURRENT_SWAP=$(free -m | awk '/^Swap:/{print $2}')

if [ "$CURRENT_SWAP" -gt 0 ]; then
    echo "✓ Máy ảo đã có sẵn ${CURRENT_SWAP}MB Swap."
else
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    SWAP_SIZE_MB=$((TOTAL_RAM * 2))
    
    echo "Phát hiện RAM vật lý: ${TOTAL_RAM}MB."
    read -p "Bạn có muốn tự động tạo ${SWAP_SIZE_MB}MB Swap (Gấp 2 lần RAM) không? (y/n, Mặc định: y): " swap_choice </dev/tty
    swap_choice=${swap_choice:-y}
    
    if [[ "$swap_choice" == [Yy] ]]; then
        echo "Đang khởi tạo ${SWAP_SIZE_MB}MB Swap..."
        sudo fallocate -l ${SWAP_SIZE_MB}M /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=${SWAP_SIZE_MB}
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        
        echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
        sudo sysctl -p > /dev/null
        echo "✓ Đã kích hoạt và tối ưu Swap thành công."
    fi
fi

# ====================== 2 & 3. TẢI VÀ GIẢI NÉN GÓI PICOCLAW TRỌN GÓI ======================
echo ""
echo "=== 2. KIỂM TRA VÀ CÀI ĐẶT PICOCLAW ==="
NEED_DOWNLOAD=true

if [ -f "$HOME/go/bin/picoclaw" ]; then
    echo "✓ Đã tìm thấy bản PicoClaw cũ trên máy."
    read -p "Bạn có muốn kiểm tra và tải đè phiên bản mới nhất ($LATEST_TAG) không? (y/n, Mặc định: y): " update_choice </dev/tty
    update_choice=${update_choice:-y}
    if [[ "$update_choice" != [Yy] ]]; then
        NEED_DOWNLOAD=false
    fi
fi

if [ "$NEED_DOWNLOAD" = true ]; then
    echo "Đang tải gói PicoClaw ($LATEST_TAG)..."
    cd /tmp
    curl -L -fsSL "$DOWNLOAD_URL" -o picoclaw.tar.gz
    
    if [ $? -eq 0 ] && [ -s picoclaw.tar.gz ]; then
        echo "📦 Đang giải nén gói cài đặt..."
        # Tạo thư mục tạm để xả nén
        mkdir -p /tmp/picoclaw_extracted
        tar -xzf picoclaw.tar.gz -C /tmp/picoclaw_extracted
        
        # Di chuyển các file thực thi (Core và Launcher) vào thư mục go/bin
        if [ -f /tmp/picoclaw_extracted/picoclaw ]; then
            cp -f /tmp/picoclaw_extracted/picoclaw $HOME/go/bin/picoclaw
            chmod +x $HOME/go/bin/picoclaw
            echo "✓ Đã cập nhật PicoClaw Core."
        fi
        
        if [ -f /tmp/picoclaw_extracted/picoclaw-launcher ]; then
            cp -f /tmp/picoclaw_extracted/picoclaw-launcher $HOME/go/bin/picoclaw-launcher
            chmod +x $HOME/go/bin/picoclaw-launcher
            echo "✓ Đã cập nhật PicoClaw Launcher."
        fi
        
        # Dọn dẹp rác sau khi giải nén xong
        rm -rf /tmp/picoclaw.tar.gz /tmp/picoclaw_extracted
    else
        echo "❌ Lỗi: Không thể tải file từ GitHub. Giữ nguyên bản cũ (nếu có)."
    fi
else
    echo "⏭️ Bỏ qua tải dữ liệu (Đang sử dụng phiên bản hiện tại)."
fi

# ====================== QUÉT VÀ THÊM FILE CONFIG NẾU THIẾU ======================
echo ""
echo "=== 2.5 KIỂM TRA CẤU HÌNH CONFIG TRÊN MÁY ==="

MISSING_CONFIG=false
if [ ! -f "$HOME/.picoclaw/config.json" ]; then
    echo "🔍 Không tìm thấy file config.json tại $HOME/.picoclaw"
    MISSING_CONFIG=true
fi
if [ ! -f "$HOME/.picoclaw/.security.yml" ]; then
    echo "🔍 Không tìm thấy file .security.yml tại $HOME/.picoclaw"
    MISSING_CONFIG=true
fi

if [ "$MISSING_CONFIG" = true ]; then
    read -p "Phát hiện máy chưa có đủ file cấu hình trong thư mục .picoclaw. Bạn có muốn tải thêm bộ config sẵn từ GitHub không? (y/n, Mặc định: y): " config_choice </dev/tty
    config_choice=${config_choice:-y}
    
    if [[ "$config_choice" == [Yy] ]]; then
        echo "⚙️ Đang tải cấu hình sẵn về $HOME/.picoclaw..."
        
        if [ ! -f "$HOME/.picoclaw/config.json" ]; then
            curl -L -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/picoclaw/config.json" -o $HOME/.picoclaw/config.json
            [ $? -eq 0 ] && [ -s $HOME/.picoclaw/config.json ] && echo "✓ Đã tải config.json về thư mục .picoclaw" || echo "⚠️ Lỗi tải config.json"
        fi
        
        if [ ! -f "$HOME/.picoclaw/.security.yml" ]; then
            curl -L -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/picoclaw/.security.yml" -o $HOME/.picoclaw/.security.yml
            [ $? -eq 0 ] && [ -s $HOME/.picoclaw/.security.yml ] && echo "✓ Đã tải .security.yml về thư mục .picoclaw" || echo "⚠️ Lỗi tải .security.yml"
        fi
    fi
else
    echo "✓ Máy ảo đã có sẵn đầy đủ file cấu hình tại $HOME/.picoclaw (config.json & .security.yml)."
fi

# Hỏi tùy chọn bật WebUI (Launcher) hay chạy Core trần
echo ""
echo "=== 3. LỰA CHỌN CHẾ ĐỘ CHẠY ==="
INSTALL_LAUNCHER=false
read -p "Bạn có muốn kích hoạt giao diện WebUI (Launcher) không? (y/n, Mặc định: n): " launcher_choice </dev/tty
launcher_choice=${launcher_choice:-n}

if [[ "$launcher_choice" == [Yy] ]]; then
    if [ -f "$HOME/go/bin/picoclaw-launcher" ]; then
        INSTALL_LAUNCHER=true
    else
        echo "⚠️ Cảnh báo: File launcher không tồn tại trong gói phần mềm. Mặc định lùi về bản Core."
    fi
fi

# Cập nhật PATH hệ thống
if ! grep -q 'go/bin' ~/.bashrc; then
    echo 'export PATH="$HOME/go/bin:$PATH"' >> ~/.bashrc
fi
export PATH="$HOME/go/bin:$PATH"

# ====================== 4. KÍCH HOẠT DỊCH VỤ CHẠY NGẦM ======================
echo ""
echo "=== 4. THIẾT LẬP DỊCH VỤ CHẠY NGẦM CLOUD ==="

sudo systemctl stop picoclaw 2>/dev/null
pkill -f "picoclaw" 2>/dev/null
sleep 1

if [ "$INSTALL_LAUNCHER" = true ]; then
    echo "Khởi chạy phiên bản có giao diện WebUI..."
    create_service_args="--public --port 18800 -no-browser"
    create_picoclaw_service "$HOME/go/bin/picoclaw-launcher" "$create_service_args" "picoclaw"
    RUNNING_MODE="PicoClaw Launcher (WebUI) - Bản: $LATEST_TAG"
    URL_INFO="• Web UI: http://<IP_MÁY_ẢO_GOOGLE>:18800"
else
    if

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

sudo apt-get update && sudo apt-get install -y curl procps bc

mkdir -p $HOME/go/bin $HOME/.picoclaw /tmp

# ====================== 1. TỰ ĐỘNG TÍNH TOÁN VÀ TẠO SWAP ======================
echo ""
echo "=== 1. KIỂM TRA VÀ CẤU HÌNH SWAP (RAM ẢO) ==="
CURRENT_SWAP=$(free -m | awk '/^Swap:/{print $2}')

if [ "$CURRENT_SWAP" -gt 0 ]; then
    echo "✓ Máy ảo đã có sẵn ${CURRENT_SWAP}MB Swap."
else
    # Lấy dung lượng RAM vật lý (tính bằng MB)
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    # Tính toán Swap bằng 2 lần RAM
    SWAP_SIZE_MB=$((TOTAL_RAM * 2))
    
    echo "Phát hiện RAM vật lý: ${TOTAL_RAM}MB."
    read -p "Bạn có muốn tự động tạo ${SWAP_SIZE_MB}MB Swap (Gấp 2 lần RAM) không? (y/n, Mặc định: y): " swap_choice
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

# ====================== 2. PICOCLAW CORE (MẶC ĐỊNH KHỞI CHẠY) ======================
echo ""
echo "=== 2. KIỂM TRA VÀ CÀI ĐẶT PICOCLAW CORE ==="
if [ -f "$HOME/go/bin/picoclaw" ]; then
    echo "✓ Đã tìm thấy file thực thi PicoClaw Core."
fi

read -p "Bạn có muốn tải/cập nhật PicoClaw Core không? (y/n, Mặc định: y): " core_choice
core_choice=${core_choice:-y}

if [[ "$core_choice" == [Yy] ]]; then
    echo "Đang tải PicoClaw Core..."
    cd /tmp
    curl -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/picoclaw/picoclaw" -o picoclaw
    cp -f picoclaw $HOME/go/bin/picoclaw
    chmod +x $HOME/go/bin/picoclaw
    echo "✓ Đã cập nhật file chạy PicoClaw Core."
fi

# ====================== 3. PICOCLAW LAUNCHER (WEBUI - TÙY CHỌN, MẶC ĐỊNH KHÔNG) ======================
echo ""
echo "=== 3. KIỂM TRA VÀ CÀI ĐẶT PICOCLAW LAUNCHER (WEBUI) ==="
INSTALL_LAUNCHER=false

if [ -f "$HOME/go/bin/picoclaw-launcher" ]; then
    echo "✓ Đã tìm thấy file thực thi PicoClaw Launcher."
    INSTALL_LAUNCHER=true
fi

read -p "Bạn có muốn cài đặt/cập nhật PicoClaw Launcher (WebUI) không? (y/n, Mặc định: n): " launcher_choice
launcher_choice=${launcher_choice:-n}

if [[ "$launcher_choice" == [Yy] ]]; then
    echo "Đang tải PicoClaw Launcher..."
    cd /tmp
    curl -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/picoclaw/picoclaw-launcher" -o picoclaw-launcher
    cp -f picoclaw-launcher $HOME/go/bin/picoclaw-launcher
    chmod +x $HOME/go/bin/picoclaw-launcher
    echo "✓ Đã cập nhật file chạy PicoClaw Launcher."
    INSTALL_LAUNCHER=true
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

# Kiểm tra lựa chọn cấu hình để chạy dịch vụ tương ứng
if [ "$INSTALL_LAUNCHER" = true ] && [ -f "$HOME/go/bin/picoclaw-launcher" ]; then
    echo "Khởi chạy phiên bản có giao diện WebUI..."
    create_service_args="--public --port 18800 -no-browser"
    create_picoclaw_service "$HOME/go/bin/picoclaw-launcher" "$create_service_args" "picoclaw"
    RUNNING_MODE="PicoClaw Launcher (WebUI)"
    URL_INFO="• Web UI: http://<IP_MÁY_ẢO_GOOGLE>:18800"
else
    if [ -f "$HOME/go/bin/picoclaw" ]; then
        echo "Khởi chạy phiên bản Core tĩnh (Mặc định)..."
        create_service_args="onboard --port 18800"
        create_picoclaw_service "$HOME/go/bin/picoclaw" "$create_service_args" "picoclaw"
        RUNNING_MODE="PicoClaw Core (No WebUI)"
        URL_INFO="• Chế độ: Chạy nền lõi Core (Cổng dịch vụ nội bộ: 18800)"
    else
        echo "❌ Lỗi: Không tìm thấy file thực thi nào để khởi chạy dịch vụ."
        exit 1
    fi
fi

echo ""
echo "================================================="
echo "           HOÀN TẤT CÀI ĐẶT TRÊN VM!"
echo "================================================="
echo "• Chế độ hoạt động: $RUNNING_MODE"
echo "$URL_INFO"
echo "• Trạng thái dịch vụ: Chạy ngầm 24/7 bằng Systemd"
echo "================================================="

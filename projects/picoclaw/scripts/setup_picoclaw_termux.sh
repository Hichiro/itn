#!/bin/bash
# ========================================================
# HÀM TIỆN ÍCH: TỰ ĐỘNG KHỞI ĐỘNG CÁC DỊCH VỤ CÙNG TERMUX
# ========================================================

enable_ssh_autostart() {
    sed -i '/# Tự động chạy SSH/,/fi/d' ~/.bashrc
    cat << 'SSH_BOOT' >> ~/.bashrc
# Tự động chạy SSH khi mở Termux nếu chưa chạy
if command -v sshd >/dev/null 2>&1 && ! pgrep -x "sshd" > /dev/null; then
    sshd
fi
SSH_BOOT
    echo "✓ Đã thiết lập tự động khởi động SSH cùng Termux."
}

enable_9router_autostart() {
    sed -i '/# Tự động khởi động 9Router/,/fi/d' ~/.bashrc
    cat << 'ROUTER_BOOT' >> ~/.bashrc
# Tự động khởi động 9Router bằng pm2 nếu chưa chạy
if command -v pm2 >/dev/null 2>&1; then
    if ! pm2 jlist | grep -q '"name":"9router"'; then
        pm2 start 9router --name "9router" > /dev/null 2>&1
    fi
elif command -v 9router >/dev/null 2>&1 && ! pgrep -f "9router" > /dev/null; then
    nohup 9router > /dev/null 2>&1 &
fi
ROUTER_BOOT
    echo "✓ Đã thiết lập tự động khởi động 9Router cùng Termux."
}

enable_picoclaw_core_autostart() {
    sed -i '/# Tự động khởi động PicoClaw Core/,/fi/d' ~/.bashrc
    cat << 'CORE_BOOT' >> ~/.bashrc
# Tự động khởi động PicoClaw Core
if [ -f "$HOME/go/bin/picoclaw" ] && ! pgrep -f "picoclaw" > /dev/null; then
    TZ="$USER_TZ" nohup "$HOME/go/bin/picoclaw" onboard --port 18800 > /dev/null 2>&1 &
    echo "[PicoClaw Core] Khởi động"
fi
CORE_BOOT
    echo "✓ Đã thiết lập tự động khởi động PicoClaw Core."
}

enable_picoclaw_launcher_autostart() {
    sed -i '/# Tự động khởi động PicoClaw Launcher/,/fi/d' ~/.bashrc
    cat << 'LAUNCHER_BOOT' >> ~/.bashrc
# Tự động khởi động PicoClaw Launcher (WebUI)
if [ -f "$HOME/go/bin/picoclaw-launcher" ] && ! pgrep -f "picoclaw-launcher" > /dev/null; then
    TZ="Asia/Ho_Chi_Minh" nohup "$HOME/go/bin/picoclaw-launcher" --public --port 18800 -no-browser > /dev/null 2>&1 &
    echo "[PicoClaw Launcher] Khởi động WebUI (port 18800, public mode)"
fi
LAUNCHER_BOOT
    echo "✓ Đã thiết lập tự động khởi động PicoClaw Launcher (WebUI)."
}

# ========================================================
# CHƯƠNG TRÌNH CHÍNH
# ========================================================

echo "=== Cài đặt & Cấu hình các dịch vụ Termux ==="

mkdir -p $HOME/go/bin $HOME/.picoclaw /tmp
touch ~/.bashrc

# Phát hiện múi giờ
USER_TZ=$(getprop persist.sys.timezone 2>/dev/null)
[ -z "$USER_TZ" ] && [ -L /etc/localtime ] && USER_TZ=$(readlink /etc/localtime | sed 's#.*/zoneinfo/##')
[ -z "$USER_TZ" ] && USER_TZ="Asia/Ho_Chi_Minh"

# ====================== 1. SSH ======================
echo "=== 1. KIỂM TRA VÀ CẤU HÌNH SSH ==="
if pgrep -x "sshd" > /dev/null; then
    echo "✓ SSH đang chạy."
    enable_ssh_autostart
else
    echo "SSH chưa chạy."
    read -p "Bạn có muốn kích hoạt SSH không? (y/n): " choice </dev/tty
    if [[ "$choice" == [Yy] ]]; then
        pkg install openssh -y
        chsh -s bash
        passwd </dev/tty
        sshd
        enable_ssh_autostart
    fi
fi

# ====================== 2. 9ROUTER ======================
echo "=== 2. KIỂM TRA VÀ CẤU HÌNH 9ROUTER ==="
if pgrep -f "9router" > /dev/null; then
    echo "✓ 9Router đang chạy."
    enable_9router_autostart
else
    read -p "Bạn có muốn cài/kích hoạt 9Router không? (y/n): " router_choice </dev/tty
    if [[ "$router_choice" == [Yy] ]]; then
        pkg install nodejs -y
        npm install -g 9router pm2
        pm2 start 9router --name "9router" > /dev/null 2>&1 || nohup 9router > /dev/null 2>&1 &
        enable_9router_autostart
    fi
fi

# ====================== 3. PICOCLAW CORE ======================
echo "=== 3. KIỂM TRA VÀ CÀI ĐẶT PICOCLAW CORE ==="
if pgrep -f "picoclaw" > /dev/null; then
    echo "✓ PicoClaw Core đang chạy."
    enable_picoclaw_core_autostart
else
    read -p "Bạn có muốn cài đặt/cập nhật PicoClaw Core không? (y/n): " core_choice </dev/tty
    if [[ "$core_choice" == [Yy] ]]; then
        echo "Đang tải PicoClaw Core..."
        cd /tmp || mkdir -p /tmp && cd /tmp
        curl -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/projects/picoclaw/picoclaw" -o picoclaw
        cp -f picoclaw $HOME/go/bin/picoclaw
        chmod +x $HOME/go/bin/picoclaw
        echo "✓ Đã cài PicoClaw Core"
        enable_picoclaw_core_autostart
    fi
fi

# ====================== 4. PICOCLAW LAUNCHER ======================
echo "=== 4. KIỂM TRA VÀ CÀI ĐẶT PICOCLAW LAUNCHER (WebUI) ==="
if pgrep -f "picoclaw-launcher" > /dev/null; then
    echo "✓ PicoClaw Launcher đang chạy."
    enable_picoclaw_launcher_autostart
else
    read -p "Bạn có muốn cài đặt PicoClaw Launcher (WebUI) không? (y/n): " launcher_choice </dev/tty
    if [[ "$launcher_choice" == [Yy] ]]; then
        echo "Đang tải PicoClaw Launcher..."
        cd /tmp || mkdir -p /tmp && cd /tmp
        curl -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/projects/picoclaw/picoclaw-launcher" -o picoclaw-launcher
        cp -f picoclaw-launcher $HOME/go/bin/picoclaw-launcher
        chmod +x $HOME/go/bin/picoclaw-launcher
        echo "✓ Đã cài PicoClaw Launcher (WebUI)"
        enable_picoclaw_launcher_autostart
    fi
fi

# Cập nhật PATH
if ! grep -q 'go/bin' ~/.bashrc; then
    echo 'export PATH="$HOME/go/bin:$PATH"' >> ~/.bashrc
fi
export PATH="$HOME/go/bin:$PATH"

# ====================== KHỞI ĐỘNG NGAY ======================
echo "=== 5. KHỞI ĐỘNG DỊCH VỤ ==="

pkill -f "picoclaw" 2>/dev/null
sleep 1

if [ -f "$HOME/go/bin/picoclaw-launcher" ]; then
    echo "Khởi động PicoClaw Launcher (WebUI)..."
    TZ="Asia/Ho_Chi_Minh" nohup "$HOME/go/bin/picoclaw-launcher" --public --port 18800 -no-browser > /dev/null 2>&1 &
else
    echo "Khởi động PicoClaw Core..."
    TZ="$USER_TZ" nohup "$HOME/go/bin/picoclaw" onboard --port 18800 > /dev/null 2>&1 &
fi

echo ""
echo "================================================="
echo "          HOÀN TẤT CÀI ĐẶT!"
echo "================================================="
echo "• Web UI: http://localhost:18800   (hoặc IP máy)"
echo "• Mode: Public + No Browser"
echo "================================================="

source ~/.bashrc 2>/dev/null

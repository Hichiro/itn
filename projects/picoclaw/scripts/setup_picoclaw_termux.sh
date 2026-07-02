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

# Hàm tải file từ GitHub có kiểm tra lỗi
download_binary() {
    local url=$1
    local dest=$2
    echo "Đang tải $dest..."
    if curl -fsSL "$url" -o "$dest"; then
        chmod +x "$dest"
        return 0
    else
        echo "❌ Lỗi: Tải $dest thất bại. Vui lòng kiểm tra kết nối mạng hoặc link GitHub."
        return 1
    fi
}

# Hàm hỏi xác nhận (Mặc định là Yes)
ask_confirm() {
    local prompt=$1
    local default="Y"
    read -p "$prompt [$default/n]: " choice </dev/tty
    if [[ -z "$choice" ]]; then
        echo "$default"
    else
        echo "$choice"
    fi
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
    # Hỏi đổi mật khẩu (mặc định là Không)
    read -p "Bạn có muốn đổi mật khẩu SSH không? [y/N]: " change_pwd </dev/tty
    if [[ "$change_pwd" =~ ^[Yy]$ ]]; then
        until passwd; do
            echo "❌ Mật khẩu không khớp, vui lòng nhập lại."
        done
        echo "✓ Đã đổi mật khẩu thành công."
    fi
    enable_ssh_autostart
else
    echo "SSH chưa chạy."
    if [[ $(ask_confirm "Bạn có muốn kích hoạt SSH không?") =~ ^[Yy]$ ]]; then
        pkg install openssh -y
        chsh -s bash
        # Vòng lặp đảm bảo mật khẩu được thiết lập đúng
        until passwd; do
            echo "❌ Mật khẩu không khớp, vui lòng nhập lại."
        done
        sshd
        enable_ssh_autostart
    fi
fi

# ====================== 2. PICOCLAW CORE ======================
echo "=== 2. KIỂM TRA VÀ CÀI ĐẶT PICOCLAW CORE ==="
core_exists=false

if pgrep -f "picoclaw" > /dev/null || [ -f "$HOME/go/bin/picoclaw" ]; then
    echo "✓ PicoClaw Core đã có sẵn hoặc đang chạy."
    core_exists=true
    enable_picoclaw_core_autostart
else
    if [[ $(ask_confirm "Bạn có muốn cài đặt PicoClaw Core không?") =~ ^[Yy]$ ]]; then
        cd /tmp || exit
        if download_binary "https://raw.githubusercontent.com/Hichiro/itn/main/projects/picoclaw/picoclaw" "/tmp/picoclaw"; then
            cp -f /tmp/picoclaw $HOME/go/bin/picoclaw
            echo "✓ Đã cài PicoClaw Core"
            core_exists=true
            enable_picoclaw_core_autostart
        fi
    fi
fi

# ====================== 3. PICOCLAW LAUNCHER ======================
# Chỉ chạy bước này nếu Core đã tồn tại/cài đặt thành công
if [ "$core_exists" = true ]; then
    echo "=== 3. KIỂM TRA VÀ CÀI ĐẶT PICOCLAW LAUNCHER (WebUI) ==="
    if pgrep -f "picoclaw-launcher" > /dev/null || [ -f "$HOME/go/bin/picoclaw-launcher" ]; then
        echo "✓ PicoClaw Launcher đã có sẵn hoặc đang chạy."
        enable_picoclaw_launcher_autostart
    else
        if [[ $(ask_confirm "Bạn có muốn cài đặt PicoClaw Launcher (WebUI) không?") =~ ^[Yy]$ ]]; then
            cd /tmp || exit
            if download_binary "https://raw.githubusercontent.com/Hichiro/itn/main/projects/picoclaw/picoclaw-launcher" "/tmp/picoclaw-launcher"; then
                cp -f /tmp/picoclaw-launcher $HOME/go/bin/picoclaw-launcher
                echo "✓ Đã cài PicoClaw Launcher (WebUI)"
                enable_picoclaw_launcher_autostart
            fi
        fi
    fi
else
    echo "⏭️ Bỏ qua cài đặt Launcher vì PicoClaw Core chưa được cài đặt."
fi

# Cập nhật PATH
if ! grep -q 'go/bin' ~/.bashrc; then
    echo 'export PATH="$HOME/go/bin:$PATH"' >> ~/.bashrc
fi
export PATH="$HOME/go/bin:$PATH"

# ====================== KHỞI ĐỘNG NGAY ======================
echo "=== 4. KHỞI ĐỘNG DỊCH VỤ ==="
pkill -f "picoclaw" 2>/dev/null
sleep 1

if [ -f "$HOME/go/bin/picoclaw-launcher" ]; then
    echo "Khởi động PicoClaw Launcher (WebUI)..."
    TZ="Asia/Ho_Chi_Minh" nohup "$HOME/go/bin/picoclaw-launcher" --public --port 18800 -no-browser > /dev/null 2>&1 &
elif [ -f "$HOME/go/bin/picoclaw" ]; then
    echo "Khởi động PicoClaw Core..."
    TZ="$USER_TZ" nohup "$HOME/go/bin/picoclaw" onboard --port 18800 > /dev/null 2>&1 &
else
    echo "Không có dịch vụ nào để khởi động."
fi

echo ""
echo "================================================="
echo "          HOÀN TẤT CÀI ĐẶT!"
echo "================================================="
echo "• Web UI: http://localhost:18800   (hoặc IP máy)"
echo "• Mode: Public + No Browser"
echo "================================================="
source ~/.bashrc 2>/dev/null

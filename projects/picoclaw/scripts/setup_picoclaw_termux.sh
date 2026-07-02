#!/bin/bash

# ========================================================
# HÀM TIỆN ÍCH: TỰ ĐỘNG KHỞI ĐỘNG
# ========================================================

enable_ssh_autostart() {
    sed -i '/# Tự động chạy SSH/,/fi/d' ~/.bashrc
    cat << 'SSH_BOOT' >> ~/.bashrc
# Tự động chạy SSH khi mở Termux nếu chưa chạy
if command -v sshd >/dev/null 2>&1 && ! pgrep -x "sshd" > /dev/null; then
    sshd
fi
SSH_BOOT
    echo "✓ Đã thiết lập tự động khởi động SSH."
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
    echo "✓ Đã thiết lập tự động khởi động PicoClaw Launcher."
}

# Hàm tải trực tiếp vào bin một cách an toàn
download_direct() {
    local url=$1
    local final_path=$2
    local tmp_path="${final_path}.tmp"
    
    echo "Đang tải $final_path..."
    # Tải về file tạm .tmp trước để tránh ghi đè file đang chạy nếu tải lỗi
    if curl -fsSL "$url" -o "$tmp_path"; then
        chmod +x "$tmp_path"
        mv -f "$tmp_path" "$final_path" # Tải xong mới ghi đè file chính
        return 0
    else
        echo "❌ Lỗi: Tải thất bại. Vui lòng kiểm tra mạng."
        [ -f "$tmp_path" ] && rm -f "$tmp_path" # Xóa file rác nếu tải lỗi
        return 1
    fi
}

ask_confirm() {
    local prompt=$1
    local default=$2
    local def_char="n"
    [ "$default" == "Y" ] && def_char="Y"
    
    read -p "$prompt [$def_char/${def_char#?}]: " choice </dev/tty
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
mkdir -p $HOME/go/bin $HOME/.picoclaw
touch ~/.bashrc

USER_TZ=$(getprop persist.sys.timezone 2>/dev/null)
[ -z "$USER_TZ" ] && [ -L /etc/localtime ] && USER_TZ=$(readlink /etc/localtime | sed 's#.*/zoneinfo/##')
[ -z "$USER_TZ" ] && USER_TZ="Asia/Ho_Chi_Minh"

# ====================== 1. SSH ======================
echo "=== 1. KIỂM TRA VÀ CẤU HÌNH SSH ==="
if pgrep -x "sshd" > /dev/null; then
    echo "✓ SSH đang chạy."
    read -p "Bạn có muốn đổi mật khẩu SSH không? [y/N]: " change_pwd </dev/tty
    if [[ "$change_pwd" =~ ^[Yy]$ ]]; then
        success=false
        for i in {1..3}; do
            echo "Lần thử $i/3: Nhập mật khẩu mới (2 lần):"
            passwd </dev/tty
            if [ $? -eq 0 ]; then
                echo "✓ Thành công."
                success=true
                break
            else
                echo "❌ Mật khẩu không khớp!"
            fi
        done
        [ "$success" = false ] && echo "⚠️ Thất bại 3 lần. Bỏ qua."
    fi
    enable_ssh_autostart
else
    echo "SSH chưa chạy."
    if [[ $(ask_confirm "Bạn có muốn kích hoạt SSH không?" "N") =~ ^[Yy]$ ]]; then
        pkg install openssh -y
        chsh -s bash
        success=false
        for i in {1..3}; do
            echo "Lần thử $i/3: Thiết lập mật khẩu (2 lần):"
            passwd </dev/tty
            if [ $? -eq 0 ]; then
                echo "✓ Thành công."
                success=true
                break
            else
                echo "❌ Mật khẩu không khớp!"
            fi
        done
        [ "$success" = false ] && echo "⚠️ Không thể thiết lập mật khẩu."
        sshd
        enable_ssh_autostart
    fi
fi

# ====================== 2. PICOCLAW CORE ======================
echo "=== 2. KIỂM TRA PICOCLAW CORE ==="
core_exists=false
if [ -f "$HOME/go/bin/picoclaw" ]; then
    if [[ $(ask_confirm "Đã có PicoClaw Core. Cập nhật bản mới nhất?" "Y") =~ ^[Yy]$ ]]; then
        if download_direct "https://raw.githubusercontent.com/Hichiro/itn/main/projects/picoclaw/picoclaw" "$HOME/go/bin/picoclaw"; then
            echo "✓ Đã cập nhật PicoClaw Core."
        fi
    fi
    core_exists=true
    enable_picoclaw_core_autostart
else
    if [[ $(ask_confirm "Bạn có muốn cài đặt PicoClaw Core không?" "N") =~ ^[Yy]$ ]]; then
        if download_direct "https://raw.githubusercontent.com/Hichiro/itn/main/projects/picoclaw/picoclaw" "$HOME/go/bin/picoclaw"; then
            echo "✓ Đã cài đặt PicoClaw Core."
            core_exists=true
            enable_picoclaw_core_autostart
        fi
    fi
fi

# ====================== 3. PICOCLAW LAUNCHER ======================
if [ "$core_exists" = true ]; then
    echo "=== 3. KIỂM TRA PICOCLAW LAUNCHER ==="
    if [ -f "$HOME/go/bin/picoclaw-launcher" ]; then
        if [[ $(ask_confirm "Đã có PicoClaw Launcher. Cập nhật bản mới nhất?" "Y") =~ ^[Yy]$ ]]; then
            if download_direct "https://raw.githubusercontent.com/Hichiro/itn/main/projects/picoclaw/picoclaw-launcher" "$HOME/go/bin/picoclaw-launcher"; then
                echo "✓ Đã cập nhật PicoClaw Launcher."
            fi
        fi
        enable_picoclaw_launcher_autostart
    else
        if [[ $(ask_confirm "Bạn có muốn cài đặt PicoClaw Launcher (WebUI) không?" "N") =~ ^[Yy]$ ]]; then
            if download_direct "https://raw.githubusercontent.com/Hichiro/itn/main/projects/picoclaw/picoclaw-launcher" "$HOME/go/bin/picoclaw-launcher"; then
                echo "✓ Đã cài đặt PicoClaw Launcher."
                enable_picoclaw_launcher_autostart
            fi
        fi
    fi
else
    echo "⏭️ Bỏ qua Launcher vì Core chưa được cài đặt."
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
fi

# ====================== LẤY ĐỊA CHỈ IP ======================
LOCAL_IP=$(ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | sed 's/addr://')
[ -z "$LOCAL_IP" ] && LOCAL_IP=$(hostname -I | awk '{print $1}')
[ -z "$LOCAL_IP" ] && LOCAL_IP="Không xác định"

echo ""
echo "================================================="
echo "          HOÀN TẤT CÀI ĐẶT!"
echo "================================================="
echo "• IP Máy của bạn: $LOCAL_IP"
echo "• Web UI: http://$LOCAL_IP:18800"
echo "• Local: http://localhost:18800"
echo "================================================="
source ~/.bashrc 2>/dev/null

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

check_for_update() {
    local repo_path=$1
    local hash_file="$HOME/.picoclaw/$2"
    local remote_sha=$(curl -s "https://api.github.com/repos/Hichiro/itn/main/contents/$repo_path" | jq -r '.sha')
    
    if [ -z "$remote_sha" ] || [ "$remote_sha" == "null" ]; then
        return 0
    fi

    local local_sha=""
    [ -f "$hash_file" ] && local_sha=$(cat "$hash_file")

    if [ "$remote_sha" != "$local_sha" ]; then
        echo "$remote_sha"
        return 1
    else
        return 0
    fi
}

download_direct() {
    local url=$1
    local final_path=$2
    local hash_file=$3
    local tmp_path="${final_path}.tmp"
    
    echo "Đang tải..."
    if curl -fsSL "$url" -o "$tmp_path"; then
        chmod +x "$tmp_path"
        mv -f "$tmp_path" "$final_path"
        local filename=$(basename "$final_path")
        local repo_path="projects/picoclaw/$filename"
        local new_sha=$(curl -s "https://api.github.com/repos/Hichiro/itn/main/contents/$repo_path" | jq -r '.sha')
        echo "$new_sha" > "$hash_file"
        return 0
    else
        echo "❌ Lỗi: Tải thất bại."
        [ -f "$tmp_path" ] && rm -f "$tmp_path"
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

if ! command -v jq >/dev/null 2>&1; then
    echo "Đang cài đặt công cụ hỗ trợ kiểm tra phiên bản (jq)..."
    pkg install jq -y
fi

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
    if ! check_for_update "projects/picoclaw/picoclaw" ".core_sha" > /dev/null; then
        if [[ $(ask_confirm "Có bản cập nhật mới cho PicoClaw Core. Cập nhật?" "Y") =~ ^[Yy]$ ]]; then
            if download_direct "https://raw.githubusercontent.com/Hichiro/itn/main/projects/picoclaw/picoclaw" "$HOME/go/bin/picoclaw" "$HOME/.picoclaw/.core_sha"; then
                echo "✓ Đã cập nhật PicoClaw Core."
            fi
        fi
    else
        echo "✓ PicoClaw Core đã ở phiên bản mới nhất."
    fi
    core_exists=true
    enable_picoclaw_core_autostart
else
    if [[ $(ask_confirm "Bạn có muốn cài đặt PicoClaw Core không?" "N") =~ ^[Yy]$ ]]; then
        if download_direct "https://raw.githubusercontent.com/Hichiro/itn/main/projects/picoclaw/picoclaw" "$HOME/go/bin/picoclaw" "$HOME/.picoclaw/.core_sha"; then
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
        if ! check_for_update "projects/picoclaw/picoclaw-launcher" ".launcher_sha" > /dev/null; then
            if [[ $(ask_confirm "Có bản cập nhật mới cho PicoClaw Launcher. Cập nhật?" "Y") =~ ^[Yy]$ ]]; then
                if download_direct "https://raw.githubusercontent.com/Hichiro/itn/main/projects/picoclaw/picoclaw-launcher" "$HOME/go/bin/picoclaw-launcher" "$HOME/.picoclaw/.launcher_sha"; then
                    echo "✓ Đã cập nhật PicoClaw Launcher."
                fi
            fi
        else
            echo "✓ PicoClaw Launcher đã ở phiên bản mới nhất."
        fi
        enable_picoclaw_launcher_autostart
    else
        if [[ $(ask_confirm "Bạn có muốn cài đặt PicoClaw Launcher (WebUI) không?" "N") =~ ^[Yy]$ ]]; then
            if download_direct "https://raw.githubusercontent.com/Hichiro/itn/main/projects/picoclaw/picoclaw-launcher" "$HOME/go/bin/picoclaw-launcher" "$HOME/.picoclaw/.launcher_sha"; then
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

# ====================== KHỞI ĐỘNG VÀ KIỂM TRA ======================
echo "=== 4. KHỞI ĐỘNG DỊCH VỤ ==="
pkill -f "picoclaw" 2>/dev/null
sleep 1

SERVICE_NAME=""
if [ -f "$HOME/go/bin/picoclaw-launcher" ]; then
    SERVICE_NAME="picoclaw-launcher"
    echo "Khởi động PicoClaw Launcher (WebUI)..."
    TZ="Asia/Ho_Chi_Minh" nohup "$HOME/go/bin/picoclaw-launcher" --public --port 18800 -no-browser > /dev/null 2>&1 &
elif [ -f "$HOME/go/bin/picoclaw" ]; then
    SERVICE_NAME="picoclaw"
    echo "Khởi động PicoClaw Core..."
    TZ="$USER_TZ" nohup "$HOME/go/bin/picoclaw" onboard --port 18800 > /dev/null 2>&1 &
fi

if [ -n "$SERVICE_NAME" ]; then
    echo -n "Đang xác thực dịch vụ... "
    sleep 2
    if pgrep -f "$SERVICE_NAME" > /dev/null; then
        echo "✓ THÀNH CÔNG!"
    else
        echo "❌ THẤT BẠI! (Tiến trình bị sập)"
    fi
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
echo "👉 Vui lòng chạy lệnh sau để áp dụng thay đổi:"
echo "   source ~/.bashrc"
echo "================================================="

source ~/.bashrc 2>/dev/null

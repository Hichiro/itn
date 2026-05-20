#!/bin/bash

enable_ssh_autostart() {
    if ! grep -q 'sshd' ~/.bashrc; then
        cat << 'SSH_BOOT' >> ~/.bashrc

# Tự động chạy SSH khi mở Termux nếu chưa chạy
if command -v sshd >/dev/null 2>&1 && ! pgrep -x "sshd" > /dev/null; then 
    sshd
fi
SSH_BOOT
        echo "✅ Đã thiết lập tự động khởi động SSH cùng Termux."
    fi
}

echo "=== 1. KIỂM TRA VÀ CẤU HÌNH SSH ==="
touch ~/.bashrc

if pgrep -x "sshd" > /dev/null; then
    echo "✅ Dịch vụ SSH hiện đang hoạt động bình thường."
    enable_ssh_autostart
else
    echo "⚠️ Dịch vụ SSH hiện tại KHÔNG hoạt động."
    read -p "❓ Bạn có muốn kích hoạt và sử dụng SSH không? (y/n): " choise </dev/tty
    if [[ "$choise" == [Yy] ]]; then
        if ! command -v sshd >/dev/null 2>&1; then
            echo "🔄 Đang cập nhật kho ứng dụng và cài đặt openssh..."
            pkg update -y && pkg install openssh -y
        fi
        echo "🔑 Thiết lập/Cập nhật mật khẩu đăng nhập SSH cho Termux:"
        chsh -s bash
        passwd </dev/tty
        sshd
        echo "🚀 Đã kích hoạt dịch vụ SSH thành công."
        enable_ssh_autostart
    else
        echo "⏭️ Đã bỏ qua cấu hình SSH theo yêu cầu."
    fi
fi

echo "=== 2. KHỔI TẠO ĐƯỜNG DẪN HỆ THỐNG ==="
mkdir -p $HOME/.cargo/bin
mkdir -p $HOME/.zeroclaw

echo "=== 3. KIỂM TRA PHIÊN BẢN QUA REMOTE MD5 ==="
echo "🔍 Đang kiểm tra bản cập nhật..."

# Giải pháp thay thế: Tải trực tiếp file md5 hoặc thông số raw để tránh bị chặn API
# Nếu không có file md5 riêng, ta lấy trực tiếp header dung lượng file/ngày cập nhật (Etag) từ GitHub Raw
MY_REMOTE_HASH=$(curl -sI "https://raw.githubusercontent.com/Hichiro/itn/main/zeroclaw/zeroclaw" | grep -i etag | tr -d '\r' | cut -d '"' -f 2)
LOCAL_HASH=$(cat $HOME/.zeroclaw/last_build_commit.txt 2>/dev/null || echo "")

NEED_UPDATE=false

if [ -z "$MY_REMOTE_HASH" ]; then
    echo "⚠️ Vẫn không thể kết nối tới GitHub Raw để check file."
    read -p "❓ Bạn có muốn ép buộc tải lại/cài đặt file binary không? (y/n): " force_choice </dev/tty
    if [[ "$force_choice" == [Yy] ]]; then
        NEED_UPDATE=true
    fi
elif [ "$MY_REMOTE_HASH" = "$LOCAL_HASH" ] && [ -f "$HOME/.cargo/bin/zeroclaw" ]; then
    echo "✅ Bạn đang sử dụng bản build mới nhất. Không cần tải lại."
else
    echo "🔥 Phát hiện có thay đổi mới trên GitHub!"
    read -p "❓ Bạn có muốn cập nhật lên phiên bản mới không? (y/n): " update_choice </dev/tty
    if [[ "$update_choice" == [Yy] ]]; then
        NEED_UPDATE=true
    fi
fi

if [ "$NEED_UPDATE" = true ]; then
    echo "🛑 Đang tạm dừng các tiến trình ZeroClaw ngầm để mở khóa file..."
    pkill -f zeroclaw > /dev/null 2>&1
    killall zeroclaw > /dev/null 2>&1
    sleep 1 

    echo "📥 Đang tải file binary từ: Hichiro/itn..."
    curl -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/zeroclaw/zeroclaw" -o $HOME/.cargo/bin/zeroclaw

    if [ $? -eq 0 ] && [ -s "$HOME/.cargo/bin/zeroclaw" ]; then
        echo "🎉 Cập nhật thành công bản build mới!"
        if [ ! -z "$MY_REMOTE_HASH" ]; then
            echo "$MY_REMOTE_HASH" > $HOME/.zeroclaw/last_build_commit.txt
        fi
    else
        echo "❌ Lỗi: Không thể tải file từ GitHub hoặc file tải về bị rỗng."
        exit 1
    fi
else
    echo "⏭️ Đã bỏ qua bước tải/cập nhật phiên bản theo yêu cầu."
fi

echo "=== 4. CẤP QUYỀN VÀ ĐỒNG BỘ PATH ==="
chmod +x $HOME/.cargo/bin/zeroclaw

if ! grep -q '\.cargo/bin' ~/.bashrc; then
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
fi
export PATH="$HOME/.cargo/bin:$PATH"

echo "=== 5. THIẾT LẬP TỰ ĐỘNG KHỞI ĐỘNG ZEROCLAW ==="
if ! grep -q 'zeroclaw daemon' ~/.bashrc; then
    cat << 'ZEROCLAW_BOOT' >> ~/.bashrc

# Tự động khởi động ZeroClaw ngầm nếu chưa chạy và đã có cấu hình hoàn chỉnh
if [ -f "$HOME/.zeroclaw/config.toml" ] && ! pgrep -x "zeroclaw" > /dev/null; then
    nohup zeroclaw daemon > /dev/null 2>&1 &
fi
ZEROCLAW_BOOT
    echo "✅ Đã thiết lập cấu hình tự động khởi động ZeroClaw cùng Termux."
fi

if [ -f "$HOME/.zeroclaw/config.toml" ] && [ "$NEED_UPDATE" = true ]; then
    echo "🔄 Đang kích hoạt lại ZeroClaw chạy ngầm..."
    nohup zeroclaw daemon > /dev/null 2>&1 &
fi

echo "================================================="
echo " ✅ QUY TRÌNH HOÀN TẤT THÀNH CÔNG!"
echo "================================================="

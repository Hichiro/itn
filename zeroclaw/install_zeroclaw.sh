#!/bin/bash

# Hàm tiện ích: Ghi cấu hình tự động bật SSH vào .bashrc nếu chưa có
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
        else
            echo "ℹ️ Gói OpenSSH đã được cài đặt từ trước."
        fi
        
        echo "🔑 Thiết lập/Cập nhật mật khẩu đăng nhập SSH cho Termux:"
        chsh -s bash
        passwd </dev/tty
        
        sshd
        echo "🚀 Đã kích hoạt dịch vụ SSH thành công."
        enable_ssh_autostart
        
        echo "----------------------------------------"
        echo "📌 Tên đăng nhập (Username) của bạn: $(whoami)"
        echo "📌 Cổng kết nối (Port mặc định): 8022"
        echo "👉 Câu lệnh kết nối từ máy tính: ssh $(whoami)@<IP_ĐIỆN_THOẠI> -p 8022"
        echo "----------------------------------------"
    else
        echo "⏭️ Đã bỏ qua cấu hình SSH theo yêu cầu."
    fi
fi

echo "=== 2. KHỔI TẠO ĐƯỜNG DẪN HỆ THỐNG ==="
mkdir -p $HOME/.cargo/bin
mkdir -p $HOME/.zeroclaw

echo "=== 3. KIỂM TRA PHIÊN BẢN VÀ HỎI Ý KIẾN UPDATE ==="
echo "🔍 Đang kiểm tra lịch sử build trên GitHub của bạn..."

# Check mã commit mới nhất của file zeroclaw trên kho của bạn
MY_REMOTE_COMMIT=$(curl -sSL https://api.github.com/repos/Hichiro/itn/commits?path=zeroclaw/zeroclaw\&page=1\&per_page=1 | grep '^  "sha"' | head -n 1 | cut -d '"' -f 4)

# Kiểm tra mã commit cũ đã lưu tại máy
LOCAL_COMMIT=$(cat $HOME/.zeroclaw/last_build_commit.txt 2>/dev/null || echo "")

NEED_UPDATE=false

if [ -z "$MY_REMOTE_COMMIT" ]; then
    echo "⚠️ Không thể check lịch sử GitHub."
    read -p "❓ Bạn có muốn ép buộc tải lại/cài đặt file binary không? (y/n): " force_choice </dev/tty
    if [[ "$force_choice" == [Yy] ]]; then
        NEED_UPDATE=true
    fi
elif [ "$MY_REMOTE_COMMIT" = "$LOCAL_COMMIT" ] && [ -f "$HOME/.cargo/bin/zeroclaw" ]; then
    echo "✅ Bạn đang sử dụng bản build mới nhất (${LOCAL_COMMIT:0:7}). Không cần tải lại."
else
    echo "🔥 Phát hiện bản build mới trên GitHub!"
    echo "   - Bản hiện tại trên máy: ${LOCAL_COMMIT:0:7}"
    echo "   - Bản mới trên GitHub  : ${MY_REMOTE_COMMIT:0:7}"
    
    read -p "❓ Bạn có muốn cập nhật lên phiên bản mới này không? (y/n): " update_choice </dev/tty
    if [[ "$update_choice" == [Yy] ]]; then
        NEED_UPDATE=true
    fi
fi

# Thực hiện tải file nếu được đồng ý cập nhật
if [ "$NEED_UPDATE" = true ]; then
    echo "🛑 Đang tạm dừng các tiến trình ZeroClaw ngầm để mở khóa file..."
    pkill -f zeroclaw > /dev/null 2>&1
    killall zeroclaw > /dev/null 2>&1
    sleep 1 

    echo "📥 Đang tải file binary từ: Hichiro/itn..."
    curl -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/zeroclaw/zeroclaw" -o $HOME/.cargo/bin/zeroclaw

    if [ $? -eq 0 ] && [ -s "$HOME/.cargo/bin/zeroclaw" ]; then
        echo "🎉 Cập nhật thành công bản build mới!"
        if [ ! -z "$MY_REMOTE_COMMIT" ]; then
            echo "$MY_REMOTE_COMMIT" > $HOME/.zeroclaw/last_build_commit.txt
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

# KHẮC PHỤC: Kiểm tra đúng file config ở thư mục mới .zeroclaw để tự khởi động lại ngay
if [ -f "$HOME/.zeroclaw/config.toml" ] && [ "$NEED_UPDATE" = true ]; then
    echo "🔄 Đang kích hoạt lại ZeroClaw chạy ngầm..."
    nohup zeroclaw daemon > /dev/null 2>&1 &
fi

echo "================================================="
echo " ✅ QUY TRÌNH HOÀN TẤT THÀNH CÔNG!"
echo " - Gõ 'zeroclaw onboard' nếu cài lần đầu."
echo "================================================="

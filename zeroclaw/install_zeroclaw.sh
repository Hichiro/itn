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
    # Sử dụng </dev/tty để ép nhận lệnh nhập từ bàn phím chính xác
    read -p "❓ Bạn có muốn kích hoạt và sử dụng SSH không? (y/n): " choise </dev/tty
    if [[ "$choise" == [Yy] ]]; then
        
        if ! command -v sshd >/dev/null 2>&1; then
            echo "🔄 Đang cập nhật kho ứng dụng và cài đặt openssh..."
            pkg update -y && pkg install openssh -y
        else
            echo "ℹ️ Gói OpenSSH đã được cài đặt từ trước."
        fi
        
        echo "🔑 Thiết lập/Cập nhật mật khẩu đăng nhập SSH cho Termux:"
        passwd
        
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

echo "=== 2. KHỞI TẠO ĐƯỜNG DẪN HỆ THỐNG ==="
mkdir -p $HOME/.cargo/bin
mkdir -p $HOME/.config/zeroclaw

echo "=== 3. KIỂM TRA PHIÊN BẢN VÀ TẢI FILE BINARY ==="
# Lấy mã commit mới nhất từ kho gốc upstream
echo "🔍 Đang kiểm tra phiên bản mới nhất từ kho gốc..."
UPSTREAM_COMMIT=$(curl -sSL https://api.github.com/repos/zeroclaw-labs/zeroclaw/commits/HEAD | grep '^  "sha"' | cut -d '"' -f 4)

# Kiểm tra mã commit cũ đã lưu tại máy
LOCAL_COMMIT=$(cat $HOME/.config/zeroclaw/last_build_commit.txt 2>/dev/null || echo "")

# Nếu không lấy được mã từ internet (lỗi mạng), mặc định bỏ qua kiểm tra để tải lại cho an toàn
if [ -z "$UPSTREAM_COMMIT" ]; then
    echo "⚠️ Không thể kết nối tới GitHub để check phiên bản. Tiến hành tải lại file..."
    NEED_UPDATE=true
elif [ "$UPSTREAM_COMMIT" = "$LOCAL_COMMIT" ] && [ -f "$HOME/.cargo/bin/zeroclaw" ]; then
    echo "✅ Bạn đang sử dụng phiên bản ZeroClaw mới nhất. Không cần tải lại."
    NEED_UPDATE=false
else
    echo "🔥 Đã tìm thấy bản cập nhật mới (hoặc cài lần đầu)!"
    NEED_UPDATE=true
fi

# Thực hiện tải file nếu có bản update
if [ "$NEED_UPDATE" = true ]; then
    echo "📥 Đang tải file binary từ GitHub Actions của bạn..."
    curl -fsSL https://raw.githubusercontent.com/Hichiro/itn/main/zeroclaw/zeroclaw -o $HOME/.cargo/bin/zeroclaw

    if [ $? -eq 0 ]; then
        echo "🎉 Tải file thành công!"
        # Lưu lại mã commit mới để làm dấu cho lần check sau
        if [ ! -z "$UPSTREAM_COMMIT" ]; then
            echo "$UPSTREAM_COMMIT" > $HOME/.config/zeroclaw/last_build_commit.txt
        fi
    else
        echo "❌ Lỗi: Không thể tải file từ GitHub."
        exit 1
    fi
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
if [ -f "$HOME/.config/zeroclaw/config.toml" ] && ! pgrep -x "zeroclaw" > /dev/null; then
    nohup zeroclaw daemon > /dev/null 2>&1 &
fi
ZEROCLAW_BOOT
    echo "✅ Đã thiết lập cấu hình tự động khởi động ZeroClaw cùng Termux."
fi

echo "================================================="
echo " ✅ QUY TRÌNH HOÀN TẤT THÀNH CÔNG!"
echo " - Gõ 'zeroclaw onboard' nếu cài lần đầu."
echo "================================================="

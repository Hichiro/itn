#!/bin/bash

echo "=== 1. KIỂM TRA VÀ CẤU HÌNH SSH ==="
# Kiểm tra xem lệnh sshd đã tồn tại trong hệ thống chưa
if command -v sshd >/dev/null 2>&1; then
    echo "ℹ️ OpenSSH đã được cài đặt trên hệ thống."
    # Nếu đã cài nhưng chưa chạy thì bật lên
    if ! pgrep -x "sshd" > /dev/null; then
        sshd
        echo "🚀 Đã kích hoạt SSH chạy ngầm."
    fi
else
    echo "⚠️ Hệ thống chưa cài đặt OpenSSH."
    read -p "❓ Bạn có muốn cài đặt và cấu hình SSH không? (y/n): " choise
    if [[ "$choise" == [Yy] ]]; then
        echo "🔄 Đang cập nhật kho ứng dụng và cài đặt openssh..."
        pkg update -y && pkg install openssh -y
        
        echo "🔑 Thiết lập mật khẩu đăng nhập SSH cho Termux:"
        passwd
        
        # Bật SSH ngay lập tức
        sshd
        echo "🚀 Đã kích hoạt dịch vụ SSH."
        
        # Hiển thị thông tin kết nối cho người dùng
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
touch ~/.bashrc

echo "=== 3. TẢI FILE BINARY TỪ GITHUB ACTIONS ==="
curl -fsSL https://raw.githubusercontent.com/Hichiro/itn/main/zeroclaw/zeroclaw -o $HOME/.cargo/bin/zeroclaw

if [ $? -eq 0 ]; then
    echo "🎉 Tải file thành công!"
else
    echo "❌ Lỗi: Không thể tải file từ GitHub."
    exit 1
fi

echo "=== 4. CẤP QUYỀN VÀ ĐỒNG BỘ PATH ==="
chmod +x $HOME/.cargo/bin/zeroclaw

if ! grep -q '\.cargo/bin' ~/.bashrc; then
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
fi
export PATH="$HOME/.cargo/bin:$PATH"

echo "=== 5. THIẾT LẬP TỰ ĐỘNG KHỞI ĐỘNG (AUTO-START) ==="
# Gộp cả SSH và ZeroClaw vào một khối kiểm tra để cấu hình .bashrc gọn gàng
if ! grep -q '# AUTO-START SERVICES' ~/.bashrc; then
    cat << 'END_AUTOSTART' >> ~/.bashrc

# AUTO-START SERVICES BY SCRIPT
# Tự động chạy SSH khi mở Termux nếu chưa chạy
if command -v sshd >/dev/null 2>&1 && ! pgrep -x "sshd" > /dev/null; then 
    sshd
fi

# Tự động khởi động ZeroClaw ngầm nếu chưa chạy
if ! pgrep -x "zeroclaw" > /dev/null; then
    nohup zeroclaw daemon > /dev/null 2>&1 &
fi
END_AUTOSTART
    echo "✅ Đã thiết lập tự động khởi động SSH & ZeroClaw cùng Termux."
else
    echo "ℹ️ Thiết lập tự động khởi động đã tồn tại, bỏ qua."
fi

echo "================================================="
echo " ✅ QUY TRÌNH HOÀN TẤT THÀNH CÔNG!"
echo " - Gõ 'zeroclaw onboard' nếu cài lần đầu."
echo " - Từ giờ SSH và Bot sẽ tự khởi động cùng Termux."
echo "================================================="

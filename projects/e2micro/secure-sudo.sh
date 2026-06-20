#!/bin/bash

# 1. Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo "❌ LỖI: Script này cần chạy với quyền root (sudo)." 
   exit 1
fi

USER_NAME="u_hichiro"
MAIN_SUDOERS="/etc/sudoers"
GOOGLE_SUDOERS="/etc/sudoers.d/google_sudoers"
NEW_CONFIG="/etc/sudoers.d/u_hichiro-apt"

echo "--- 🛡️ ĐANG BẮT ĐẦU QUY TRÌNH SIẾT CHẶT BẢO MẬT ---"

# 2. Vô hiệu hóa quyền "God Mode" từ Google (Không cần logout)
if [ -f "$GOOGLE_SUDOERS" ]; then
    echo "🔍 Đang vô hiệu hóa quyền trong $GOOGLE_SUDOERS..."
    # Tìm dòng có %google-sudoers và thêm dấu # vào đầu dòng
    sed -i "s/^%google-sudoers/# %google-sudoers/" "$GOOGLE_SUDOERS"
    echo "✅ Đã vô hiệu hóa quyền của group google-sudoers."
else
    echo "ℹ️ Không tìm thấy file $GOOGLE_SUDOERS, bỏ qua."
fi

# 3. Dọn dẹp file /etc/sudoers chính (Tránh trùng lặp và rác)
if grep -q "$USER_NAME" "$MAIN_SUDOERS"; then
    echo "🔍 Đang dọn dẹp các dòng cấu hình cũ của $USER_NAME trong $MAIN_SUDOERS..."
    # Tìm dòng có chứa tên user và apt-get, sau đó comment nó lại
    sed -i "/$USER_NAME.*apt-get/s/^/# /" "$MAIN_SUDOERS"
    echo "✅ Đã comment các dòng cũ trong file chính."
else
    echo "ℹ️ Không tìm thấy cấu hình cũ của $USER_NAME trong $MAIN_SUDOERS."
fi

# 4. Thiết lập quyền mới, sạch sẽ và chuyên nghiệp
echo "🔍 Đang thiết lập quyền giới hạn mới tại $NEW_CONFIG..."
echo "$USER_NAME ALL=(ALL) NOPASSWD: /usr/bin/apt-get update, /usr/bin/apt-get install, /usr/bin/apt-get upgrade" > "$NEW_CONFIG"
chmod 0440 "$NEW_CONFIG"
echo "✅ Đã tạo file cấu hình mới."

# 5. Kiểm tra kết quả cuối cùng
echo ""
echo "--- 🏁 QUY TRÌNH HOÀN TẤT! ---"
echo "--- 📊 KẾT QUẢ KIỂM TRA QUYỀN CỦA $USER_NAME: ---"
# Sử dụng sudo -l -U để kiểm tra chính xác quyền của user đó
sudo -l -U "$USER_NAME"

echo ""
echo "💡 Ghi chú: Nếu bạn vẫn thấy dòng 'ALL', hãy chạy lệnh: 'sudo gpasswd -d $USER_NAME google-sudoers' và đăng nhập lại."

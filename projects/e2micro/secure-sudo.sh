#!/bin/bash

# 1. Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo "❌ LỖI: Script này cần chạy với quyền root." 
   exit 1
fi

echo "--- 📋 DANH SÁCH CÁC USER CÓ THỂ ĐĂNG NHẬP ---"

# Lấy danh sách user (loại bỏ root và các user hệ thống không có shell)
# Chỉ lấy các user có /bin/bash hoặc /bin/sh
USERS=($(grep -E '/bin/bash|/bin/sh' /etc/passwd | grep -v 'root' | cut -d: -f1))

# 2. Hiển thị menu chọn
PS3="👉 Hãy chọn số thứ tự của user bạn muốn siết quyền: "
select USER_NAME in "${USERS[@]}" "Thoát"; do
    case $USER_NAME in
        "Thoát")
            echo "Đã thoát."
            exit 0
            ;;
        *)
            if [ -n "$USER_NAME" ]; then
                echo "✅ Bạn đã chọn: $USER_NAME"
                break
            else
                echo "❌ Lựa chọn không hợp lệ."
            fi
            ;;
    esac
done

# 3. Thực hiện siết quyền cho user đã chọn
echo "--- 🛡️ ĐANG SIẾT CHẶT BẢO MẬT CHO: $USER_NAME ---"

# Vô hiệu hóa NOPASSWD của google-sudoers
GOOGLE_SUDOERS="/etc/sudoers.d/google_sudoers"
if [ -f "$GOOGLE_SUDOERS" ]; then
    sed -i "s/^%google-sudoers.*NOPASSWD:ALL/%google-sudoers ALL=(ALL:ALL) ALL/" "$GOOGLE_SUDOERS"
    echo "✅ Đã chuyển google-sudoers sang chế độ yêu cầu mật khẩu."
fi

# Thiết lập quyền giới hạn cho user đã chọn
NEW_CONFIG="/etc/sudoers.d/${USER_NAME}-apt"
echo "$USER_NAME ALL=(ALL) NOPASSWD: /usr/bin/apt-get update, /usr/bin/apt-get install, /usr/bin/apt-get upgrade" > "$NEW_CONFIG"
chmod 0440 "$NEW_CONFIG"

echo "✅ Đã tạo file cấu hình giới hạn tại $NEW_CONFIG."
echo "--- 🏁 HOÀN TẤT! ---"
sudo -l -U "$USER_NAME"

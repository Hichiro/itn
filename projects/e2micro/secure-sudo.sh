#!/bin/bash

# 1. Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo "Script này cần chạy với quyền root (sudo)." 
   exit 1
fi

USER_NAME="u_hichiro"

echo "--- Đang bắt đầu siết chặt bảo mật cho $USER_NAME ---"

# 2. Loại bỏ user khỏi group google-sudoers (Lựa chọn 1)
if getent group google-sudoers > /dev/null; then
    if groups $USER_NAME | grep -q "\bgoogle-sudoers\b"; then
        echo "Đang loại bỏ $USER_NAME khỏi group google-sudoers..."
        gpasswd -d $USER_NAME google-sudoers
    else
        echo "$USER_NAME không nằm trong group google-sudoers."
    fi
else
    echo "Không tìm thấy group google-sudoers, bỏ qua bước này."
fi

# 3. Thiết lập quyền giới hạn trong /etc/sudoers.d/pico-secure
echo "Đang thiết lập quyền giới hạn cho apt-get..."
CONFIG_FILE="/etc/sudoers.d/pico-secure"
echo "$USER_NAME ALL=(ALL) NOPASSWD: /usr/bin/apt-get update, /usr/bin/apt-get install, /usr/bin/apt-get upgrade" | tee $CONFIG_FILE
chmod 0440 $CONFIG_FILE

# 4. Kiểm tra lại kết quả
echo "--- Hoàn tất! Kiểm tra quyền hiện tại: ---"
sudo -l -U $USER_NAME

echo "Lưu ý: Nếu bạn vẫn thấy quyền cũ, hãy thử đăng xuất và đăng nhập lại (SSH session)."

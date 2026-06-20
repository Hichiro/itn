#!/bin/bash

*Chính sách mới*
POLICY="/usr/bin/apt-get update, /usr/bin/apt-get install, /usr/bin/apt-get upgrade"

if [ "$EUID" -ne 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

*1. Chọn user*
users=($(getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1}'))
for i in "${!users[@]}"; do echo "$((i+1))) ${users[$i]}"; done
read -p "Chọn user: " choice
target_user=${users[$((choice-1))]}

*2. Xóa các quyền sudo cũ của user này (Cẩn thận!)*
*Lệnh này sẽ comment lại các dòng chứa ALL=(ALL) ALL của user đó*
sed -i "/$target_user.*ALL=(ALL) ALL/s/^/#/" /etc/sudoers

*3. Thêm quyền mới*
config_line="$target_user ALL=(ALL) NOPASSWD: $POLICY"

*4. Kiểm tra và áp dụng*
echo "$config_line" > /tmp/sudoers_test
if visudo -cf /tmp/sudoers_test > /dev/null 2>&1; then
    echo "$config_line" >> /etc/sudoers
    echo "✅ Đã áp dụng chính sách mới và vô hiệu hóa quyền root toàn phần cũ cho $target_user"
else
    echo "❌ Lỗi cú pháp, không áp dụng."
fi
rm /tmp/sudoers_test

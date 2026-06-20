#!/bin/bash

# --- Cấu hình ---
POLICY="/usr/bin/apt-get update, /usr/bin/apt-get install, /usr/bin/apt-get upgrade"

# --- Hàm hỗ trợ ---
log() { echo -e "[$(date +'%Y-%m-%dT%H:%M:%S')] $1"; }
error_exit() { log "❌ $1"; exit 1; }

# --- Kiểm tra quyền Root ---
if [ "$EUID" -ne 0 ]; then
    error_exit "Script này cần chạy với sudo. Ví dụ: curl ... | sudo bash"
fi

# --- Chọn User ---
log "Danh sách người dùng hệ thống:"
users=($(getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1}'))
for i in "${!users[@]}"; do echo "$((i+1))) ${users[$i]}"; done

# Ép buộc đọc từ terminal (/dev/tty)
read -p "Chọn user để giới hạn quyền: " choice < /dev/tty
target_user=${users[$((choice-1))]}

[ -z "$target_user" ] && error_exit "User không hợp lệ."

# --- Thực hiện thay đổi ---
log "Đang cấu hình cho user: $target_user"

# 1. Vô hiệu hóa quyền root toàn phần cũ
sed -i "/$target_user.*ALL=(ALL) ALL/s/^/# [SECURE-MOD] /" /etc/sudoers

# 2. Tạo dòng cấu hình mới
config_line="$target_user ALL=(ALL) NOPASSWD: $POLICY"

# 3. Kiểm tra cú pháp (Phải bao gồm cả user để visudo hiểu)
echo "$config_line" > /tmp/sudoers_test
visudo -cf /tmp/sudoers_test > /dev/null 2>&1 || error_exit "Cấu hình mới bị lỗi cú pháp!"

# 4. Áp dụng
echo "$config_line" >> /etc/sudoers
rm /tmp/sudoers_test

log "✅ Hoàn tất! User '$target_user' hiện chỉ có quyền apt-get."

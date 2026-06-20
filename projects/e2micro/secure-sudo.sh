#!/bin/bash

# ==============================================================================
# Script: secure-sudo.sh
# Description: Giới hạn quyền sudo của user chỉ ở mức apt-get (update/install/upgrade)
# Author: PicoClaw Assistant
# ==============================================================================

# --- Cấu hình ---
POLICY="/usr/bin/apt-get update, /usr/bin/apt-get install, /usr/bin/apt-get upgrade"

# --- Hàm hỗ trợ ---
log() { echo -e "[$(date +'%Y-%m-%dT%H:%M:%S')] $1"; }
error_exit() { log "❌ $1"; exit 1; }

# --- Kiểm tra quyền Root ---
# Thay vì tự sudo, chúng ta yêu cầu người dùng chạy lệnh đúng ngay từ đầu
if [ "$EUID" -ne 0 ]; then
    echo "----------------------------------------------------------------"
    echo "❌ LỖI: Script này yêu cầu quyền ROOT để chỉnh sửa /etc/sudoers."
    echo "Vui lòng chạy lại bằng lệnh sau:"
    echo ""
    echo "    curl -sSL https://raw.githubusercontent.com/Hichiro/itn/refs/heads/main/projects/security/secure-sudo.sh | sudo bash"
    echo "----------------------------------------------------------------"
    exit 1
fi

# --- Chọn User ---
log "Danh sách người dùng hệ thống:"
users=($(getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1}'))
for i in "${!users[@]}"; do echo "$((i+1))) ${users[$i]}"; done
read -p "Chọn user để giới hạn quyền: " choice
target_user=${users[$((choice-1))]}

[ -z "$target_user" ] && error_exit "User không hợp lệ."

# --- Thực hiện thay đổi ---
log "Đang cấu hình cho user: $target_user"

# 1. Vô hiệu hóa quyền root toàn phần cũ (comment lại)
sed -i "/$target_user.*ALL=(ALL) ALL/s/^/# [SECURE-MOD] /" /etc/sudoers || log "⚠️ Không tìm thấy quyền root toàn phần cũ để comment."

# 2. Tạo dòng cấu hình mới
config_line="$target_user ALL=(ALL) NOPASSWD: $POLICY"

# 3. Kiểm tra cú pháp visudo trước khi áp dụng
echo "$config_line" > /tmp/sudoers_test
visudo -cf /tmp/sudoers_test > /dev/null 2>&1 || error_exit "Cấu hình mới bị lỗi cú pháp! Không áp dụng."

# 4. Áp dụng
echo "$config_line" >> /etc/sudoers
rm /tmp/sudoers_test

log "✅ Hoàn tất! User '$target_user' hiện chỉ có quyền apt-get."
log "Kiểm tra lại bằng lệnh: sudo -l -U $target_user"

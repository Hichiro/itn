#!/bin/bash

# ==============================================================================
# Tên Script: vm-init-setup.sh
# Mô tả: Cấu hình SWAP và tối ưu log hệ thống. Tự động nhận diện OS.
# CHẠY TRÊN: Chạy ngầm TỰ ĐỘNG bên trong VM thông qua quyền hệ thống khi khởi động.
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

echo "=== ĐANG CẤU HÌNH HỆ THỐNG TỰ ĐỘNG ==="

# 1. TỰ ĐỘNG KHỞI TẠO VÀ BẬT SWAP 2GB THEO HỆ ĐIỀU HÀNH
if [ -d '/var' ] && [ ! -w '/' ]; then
    IS_COS=true
    SWAP_PATH='/var/swapfile' # Thư mục ghi được duy nhất trên COS
else
    HEX_COS=false
    SWAP_PATH='/swapfile'     # Mặc định trên Debian
fi

if [ ! -f "$SWAP_PATH" ]; then
    dd if=/dev/zero of="$SWAP_PATH" bs=1M count=2048
    chmod 600 "$SWAP_PATH"
    mkswap "$SWAP_PATH"
fi
swapon "$SWAP_PATH" 2>/dev/null

# Ghi cấu hình SWAP vĩnh viễn nếu file hệ thống cho phép ghi (Debian)
if [ -w '/etc/fstab' ]; then
    if ! grep -q "$SWAP_PATH" /etc/fstab; then
        echo "$SWAP_PATH none swap sw 0 0" >> /etc/fstab
    fi
fi

# 2. GIỚI HẠN DUNG LƯỢNG LOG HỆ THỐNG (CHỈ ÁP DỤNG TRÊN DEBIAN)
if [ -d '/etc/systemd/' ]; then
    mkdir -p /etc/systemd/journald.conf.d/
    echo -e '[Journal]\nSystemMaxUse=50M' > /etc/systemd/journald.conf.d/maxuse.conf
    systemctl restart systemd-journald 2>/dev/null
fi

# 3. CẤU HÌNH MÚI GIỜ & UTF-8 (CHỈ DÀNH CHO DEBIAN)
if command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-timezone Asia/Ho_Chi_Minh
    if [ -f '/etc/locale.gen' ]; then
        sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
        /usr/sbin/locale-gen 2>/dev/null
        /usr/sbin/update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 2>/dev/null
    fi
fi

echo "=== TỰ ĐỘNG KHỞI TẠO HỆ THỐNG HOÀN TẤT ==="

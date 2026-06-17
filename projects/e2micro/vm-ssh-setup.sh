#!/bin/bash

# ==============================================================================
# Tên Script: vm-password-setup.sh (Script 3)
# Mô tả: Đặt mật khẩu và cấu hình mở quyền truy cập SSH bằng mật khẩu cho Debian.
# CHẠY TRÊN: Có thể chạy từ Cloud Shell (tự động kết nối) hoặc chạy trực tiếp trong VM.
# ==============================================================================

# 1. PHẦN TỰ ĐỘNG HÓA KẾT NỐI (CHẠY TRÊN CLOUD SHELL NẾU ĐƯỢC GỌI TỪ NGOÀI)
if [ -n "$DEVSHELL_PROJECT_ID" ]; then
    echo "--- Phát hiện Cloud Shell: Đang kết nối vào VM... ---"
    gcloud compute ssh e2micro --project=free-e2micro --zone=us-west1-b --tunnel-through-iap --command="bash -s" < "$0"
    exit
fi

# 2. PHẦN CẤU HÌNH TRONG VM
if [ "$EUID" -ne 0 ]; then
    echo "Đang yêu cầu nâng quyền root bằng sudo..."
    exec sudo "$0" "$@"
fi

# Tự động phát hiện hệ điều hành để tránh lỗi trên COS
if [ -d '/var' ] && [ ! -w '/' ]; then
    echo "[LƯU Ý] Phát hiện hệ điều hành Container-Optimized OS (COS)."
    echo "COS không hỗ trợ xác thực SSH bằng mật khẩu do phân vùng hệ thống bị khóa."
    echo "Tiến hành bỏ qua bước cấu hình file sshd_config..."
    IS_COS=true
else
    IS_COS=false
fi

echo "=== TIẾN HÀNH ĐẶT MẬT KHẨU TRÊN VM ==="

# 1. Thiết lập mật khẩu cho root
echo "Thiết lập mật khẩu mới cho tài khoản [root]:"
passwd root

# 2. Tự động quét tìm User thực tế trong thư mục /home để đổi mật khẩu
REAL_USER=$(ls -l /home | grep '^d' | awk '{print $NF}' | head -n 1)

if [ -n "$REAL_USER" ]; then
    echo "-------------------------------------------------"
    echo "Thiết lập mật khẩu mới cho tài khoản user [$REAL_USER]:"
    passwd "$REAL_USER"
else
    echo "Không tìm thấy tài khoản user phụ trong /home."
fi

# 3. CẤU HÌNH CHO PHÉP ĐĂNG NHẬP SSH BẰNG MẬT KHẨU (CHỈ CHẠY NẾU LÀ DEBIAN)
if [ "$IS_COS" = false ]; then
    SSHD_CONFIG="/etc/ssh/sshd_config"
    if [ -f "$SSHD_CONFIG" ]; then
        cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

        echo "-------------------------------------------------"
        echo "Đang mở cấu hình cho phép đăng nhập SSH bằng mật khẩu..."
        sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG"
        sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG"
        sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
        sed -i 's/^KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' "$SSHD_CONFIG"
        sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"

        # Kiểm tra cú pháp an toàn trước khi khởi động lại dịch vụ SSH
        if /usr/sbin/sshd -t 2>/dev/null; then
            systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
            echo "🎉 Cấu hình SSH hoàn tất! Bạn hiện có thể kết nối từ xa bằng mật khẩu."
        else
            echo "❌ Phát hiện lỗi cấu hình SSH. Đã khôi phục trạng thái file cũ."
            mv "${SSHD_CONFIG}.bak" "$SSHD_CONFIG"
            systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
        fi
    fi
else
    echo "-------------------------------------------------"
    echo "🎉 Đã hoàn tất đặt mật khẩu cục bộ cho các tài khoản trên COS!"
    echo "-------------------------------------------------"
fi

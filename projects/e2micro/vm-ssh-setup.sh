#!/bin/bash

# ==============================================================================
# Tên Script: vm-ssh-setup.sh (Script 3)
# Mô tả: Đặt mật khẩu và cấu hình mở quyền truy cập SSH bằng mật khẩu cho Debian.
#
# CÁCH CHẠY DUY NHẤT TỪ CLOUD SHELL (Copy dán và ấn Enter):
#   bash <(curl -sL https://raw.githubusercontent.com/xxx/itn/refs/heads/main/projects/e2micro/vm-password-setup.sh)
# ==============================================================================

# Link raw của chính Script 3 trên GitHub của bạn
SCRIPT_3_URL="https://raw.githubusercontent.com/Hichiro/itn/refs/heads/main/projects/e2micro/vm-ssh-setup.sh"

# 1. PHẦN XỬ LÝ KHI CHẠY TỪ CLOUD SHELL (Tự động SSH vào VM và ra lệnh tải file an toàn)
if [ -n "$DEVSHELL_PROJECT_ID" ]; then
    echo "--- Phát hiện Cloud Shell: Đang kết nối trực tiếp vào VM... ---"
    
    # Ép VM phải tự dùng curl để tải script từ GitHub, giữ sạch luồng gõ bàn phím (stdin)
    gcloud compute ssh e2micro \
        --project=free-e2micro \
        --zone=us-west1-b \
        --tunnel-through-iap \
        --command="bash <(curl -sL $SCRIPT_3_URL)"
    exit
fi

# 2. PHẦN CẤU HÌNH BÊN TRONG VM (Chỉ chạy khi lệnh SSH phía trên được kích hoạt)
if [ "$EUID" -ne 0 ]; then
    echo "Đang yêu cầu nâng quyền root bằng sudo..."
    exec sudo bash <(curl -sL $SCRIPT_3_URL)
fi

# Tự động phát hiện hệ điều hành để tránh lỗi trên COS
if [ -d '/var' ] && [ ! -w '/' ]; then
    echo "[LƯU Ý] Phát hiện hệ điều hành Container-Optimized OS (COS)."
    echo "COS không hỗ trợ xác thực SSH bằng mật khẩu do phân vùng hệ thống bị khóa."
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

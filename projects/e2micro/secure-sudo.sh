#!/bin/bash

# --- 🛠️ CẤU HÌNH ---
CURRENT_USER=${SUDO_USER:-$USER}

# 1. Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
    echo "❌ LỖI: Script này cần chạy với quyền root (sudo)."
    exit 1
fi

# Tự động tìm đường dẫn visudo chuẩn xác
VISUDO_CMD=$(command -v visudo 2>/dev/null)
if [ -z "$VISUDO_CMD" ]; then
    if [ -x /usr/sbin/visudo ]; then VISUDO_CMD="/usr/sbin/visudo"
    elif [ -x /usr/bin/visudo ]; then VISUDO_CMD="/usr/bin/visudo"
    else echo "❌ LỖI: Không tìm thấy lệnh visudo trên hệ thống."; exit 1; fi
fi

echo "===================================================="
echo "         🛡️  HỆ THỐNG PHÂN QUYỀN PICOCLAW           "
echo "===================================================="

# 2. Lấy danh sách user có shell đăng nhập hợp lệ
mapfile -t USERS < <(grep -E '/bin/bash|/bin/sh' /etc/passwd | grep -v 'root' | cut -d: -f1)

if [ ${#USERS[@]} -eq 0 ]; then
    echo "❌ LỖI: Không tìm thấy user nào hợp lệ trên hệ thống!"
    exit 1
fi

# 3. Vòng lặp chính - Chọn User
while true; do
    echo -e "\n--- 📋 DANH SÁCH CÁC USER CÓ THỂ ĐĂNG NHẬP ---"
    for i in "${!USERS[@]}"; do
        printf "%2d) %s\n" "$((i+1))" "${USERS[$i]}"
    done
    echo " 0) Thoát"
    echo "----------------------------------------------------"

    read -p "👉 Nhập số thứ tự bạn chọn: " input </dev/tty

    if [[ -z "$input" ]]; then
        echo "⚠️  Bạn chưa nhập gì cả! Vui lòng nhập một con số."
        continue
    fi

    if ! [[ "$input" =~ ^[0-9]+$ ]]; then
        echo "⚠️  Lựa chọn không hợp lệ! Vui lòng chỉ nhập số."
        continue
    fi

    choice=$((10#$input))

    if [ "$choice" -eq 0 ]; then
        echo "👋 Đã thoát."
        exit 0
    fi

    if [ "$choice" -gt "${#USERS[@]}" ]; then
        echo "❌ Lựa chọn không hợp lệ. Thử lại nhé!"
        continue
    fi

    index=$((choice - 1))
    USER_NAME="${USERS[$index]}"

    if [[ -z "$USER_NAME" ]]; then
         continue
    fi

    echo "✅ Bạn đã chọn: $USER_NAME"
    break
done

# 4. Cơ chế tự bảo vệ
if [ "$USER_NAME" == "$CURRENT_USER" ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "🚨 CẢNH BÁO: Bạn đang chọn chính mình ($USER_NAME)!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    read -p "Nhập đúng chữ 'YES' để xác nhận tiếp tục: " CONFIRM </dev/tty
    if [ "$CONFIRM" != "YES" ]; then
        echo "❌ Đã hủy thao tác."
        exit 1
    fi
fi

# 5. Thực hiện cấu hình quyền
echo -e "\n--- 🛡️  ĐANG THỰC THI CẤU HÌNH ---"

# Tạo file cấu hình riêng cho user trong /etc/sudoers.d/
NEW_CONFIG="/etc/sudoers.d/z_${USER_NAME}-picoclaw-custom"
echo "📝 Đang thiết lập quyền cho: $USER_NAME"

TMP_SUDO=$(mktemp)

# QUY TẮC:
# 1. Cho phép làm mọi thứ nhưng PHẢI nhập mật khẩu (ALL=(ALL:ALL) ALL)
# 2. Riêng apt update/upgrade thì KHÔNG cần mật khẩu (NOPASSWD)
cat <<EOF > "$TMP_SUDO"
# Cấp quyền sudo toàn diện nhưng yêu cầu mật khẩu cho mọi lệnh
$USER_NAME ALL=(ALL:ALL) ALL

# Ngoại lệ: Không yêu cầu mật khẩu cho 2 lệnh apt cụ thể
$USER_NAME ALL=(ALL:ALL) NOPASSWD: /usr/bin/apt update, /usr/bin/apt upgrade
EOF

# Kiểm tra cú pháp bằng visudo trước khi áp dụng để tránh treo hệ thống
if "$VISUDO_CMD" -cf "$TMP_SUDO"; then
    cat "$TMP_SUDO" > "$NEW_CONFIG"
    chmod 0440 "$NEW_CONFIG"
    echo "✅ Cấu hình thành công!"
    echo "👉 Kết quả: 'apt update/upgrade' không mật khẩu, các lệnh khác yêu cầu mật khẩu."
else
    echo "❌ LỖI NGHIÊM TRỌNG: Cú pháp sudoers sai!"
    cat "$TMP_SUDO"
    echo "Hủy bỏ để bảo vệ hệ thống."
fi
rm -f "$TMP_SUDO"

# 6. Kiểm tra kết quả
echo -e "\n--- 🏁 HOÀN TẤT QUY TRÌNH! ---"
echo "🔍 Quyền hạn hiện tại của $USER_NAME:"
sudo -l -U "$USER_NAME"
echo "===================================================="

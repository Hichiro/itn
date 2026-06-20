#!/bin/bash

# --- 🛠️ CẤU HÌNH ---
GOOGLE_SUDOERS="/etc/sudoers.d/google_sudoers"
CURRENT_USER=${SUDO_USER:-$USER}

# 1. Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
    echo "❌ LỖI: Script này cần chạy với quyền root (sudo)."
    exit 1
fi

echo "===================================================="
echo "    🛡️  HỆ THỐNG SIẾT CHẶT QUYỀN SUDO (APT-ONLY)     "
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
        echo "❌ Lựa chọn không hợp lệ (Số $choice vượt quá danh sách). Thử lại nhé!"
        continue
    fi

    index=$((choice - 1))
    USER_NAME="${USERS[$index]}"

    if [[ -z "$USER_NAME" ]]; then
         echo "❌ Lỗi hệ thống: Không xác định được user. Vui lòng thử lại!"
         continue
    fi

    echo "✅ Bạn đã chọn: $USER_NAME"
    break
done

# 4. Cơ chế tự bảo vệ (Safety Guard)
if [ "$USER_NAME" == "$CURRENT_USER" ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "🚨 CẢNH BÁO NGUY HIỂM: 🚨"
    echo "Bạn đang chọn chính mình ($USER_NAME)!"
    echo "Nếu bạn làm việc này, bạn sẽ bị mất quyền sudo"
    echo "ngoại trừ lệnh apt-get. Bạn có chắc chắn không?"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    read -p "Nhập 'YES' để xác nhận: " CONFIRM </dev/tty
    if [ "$CONFIRM" != "YES" ]; then
        echo "❌ Đã hủy thao tác để bảo vệ bạn."
        exit 1
    fi
fi

# 5. Thực hiện siết quyền
echo -e "\n--- 🛡️  ĐANG THỰC THI QUY TRÌNH ---"

# A. Kiểm tra trạng thái google_sudoers (Giữ nguyên cấu hình gốc của bạn nếu đã chuẩn)
if [ -f "$GOOGLE_SUDOERS" ]; then
    if grep -q "NOPASSWD:ALL" "$GOOGLE_SUDOERS"; then
        echo "📦 Phát hiện NOPASSWD:ALL cũ, đang tiến hành siết lại về mặc định..."
        cp "$GOOGLE_SUDOERS" "${GOOGLE_SUDOERS}.bak"
        TMP_SUDOERS=$(mktemp)
        cp "$GOOGLE_SUDOERS" "$TMP_SUDOERS"
        sed -i 's/NOPASSWD:ALL/ALL/' "$TMP_SUDOERS"
        sed -i "s/^%google-sudoers.*/%google-sudoers ALL=(ALL:ALL) ALL/" "$TMP_SUDOERS"

        if visudo -cf "$TMP_SUDOERS" &>/dev/null; then
            cat "$TMP_SUDOERS" > "$GOOGLE_SUDOERS"
            echo "✅ Đã cấu hình google-sudoers yêu cầu mật khẩu thành công."
        else
            echo "❌ LỖI: Cú pháp sửa đổi google_sudoers không hợp lệ. Giữ nguyên file cũ."
        fi
        rm -f "$TMP_SUDOERS"
    else
        echo "ℹ️  Nhóm google-sudoers hiện tại đã yêu cầu mật khẩu mặc định. Giữ nguyên."
    fi
fi

# B. Thiết lập đặc quyền NOPASSWD riêng cho apt-get
# Đổi tên file thành z_${USER_NAME}-apt để đảm bảo được load CUỐI CÙNG
NEW_CONFIG="/etc/sudoers.d/z_${USER_NAME}-apt"
echo "📝 Đang cấu hình đặc quyền apt-get không mật khẩu cho: $USER_NAME"

TMP_APT=$(mktemp)
# Cú pháp chuẩn chỉnh, chỉ bỏ qua mật khẩu cho đúng 3 lệnh apt-get
echo "$USER_NAME ALL=(ALL) NOPASSWD: /usr/bin/apt-get update, /usr/bin/apt-get install, /usr/bin/apt-get upgrade" > "$TMP_APT"

if visudo -cf "$TMP_APT" &>/dev/null; then
    cat "$TMP_APT" > "$NEW_CONFIG"
    chmod 0440 "$NEW_CONFIG"
    echo "✅ Đã tạo file cấu hình: $NEW_CONFIG"
else
    echo "❌ LỖI NGHIÊM TRỌNG: Cú pháp cấp quyền không hợp lệ! Không ghi đè hệ thống."
fi
rm -f "$TMP_APT"

# 6. Kiểm tra kết quả trực quan
echo -e "\n--- 🏁 HOÀN TẤT! ---"
echo "🔍 Quyền hạn thực tế áp dụng cho $USER_NAME:"
sudo -l -U "$USER_NAME"
echo "===================================================="

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
echo "    🛡️  HỆ THỐNG SIẾT CHẶT QUYỀN SUDO (LOOPING)     "
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

    # Khắc phục Octal Bug: Ép về hệ cơ số 10 (ví dụ: biến '08' thành '8')
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
    
    # SỬA LỖI TRÔI LỆNH: Thêm </dev/tty tại đây
    read -p "Nhập 'YES' để xác nhận: " CONFIRM </dev/tty
    if [ "$CONFIRM" != "YES" ]; then
        echo "❌ Đã hủy thao tác để bảo vệ bạn."
        exit 1
    fi
fi

# 5. Thực hiện siết quyền
echo -e "\n--- 🛡️  ĐANG THỰC THI QUY TRÌNH ---"

# A. Xử lý sửa đổi file google_sudoers an toàn
if [ -f "$GOOGLE_SUDOERS" ]; then
    echo "📦 Đang sao lưu $GOOGLE_SUDOERS -> ${GOOGLE_SUDOERS}.bak"
    cp "$GOOGLE_SUDOERS" "${GOOGLE_SUDOERS}.bak"

    if grep -q "NOPASSWD:ALL" "$GOOGLE_SUDOERS"; then
        # Tạo file nháp để test trước cú pháp
        TMP_SUDOERS=$(mktemp)
        cp "$GOOGLE_SUDOERS" "$TMP_SUDOERS"
        sed -i 's/NOPASSWD:ALL/ALL/' "$TMP_SUDOERS"
        sed -i "s/^%google-sudoers.*/%google-sudoers ALL=(ALL:ALL) ALL/" "$TMP_SUDOERS"

        # CHỐT CHẶN KIỂM TRA VISUDO
        if visudo -cf "$TMP_SUDOERS" &>/dev/null; then
            cat "$TMP_SUDOERS" > "$GOOGLE_SUDOERS"
            echo "✅ Đã vô hiệu hóa NOPASSWD cho nhóm google-sudoers."
        else
            echo "❌ LỖI: Phát hiện sai cú pháp khi sửa đổi google_sudoers! Hủy áp dụng để giữ an toàn."
        fi
        rm -f "$TMP_SUDOERS"
    else
        echo "ℹ️  google-sudoers đã không có NOPASSWD. Bỏ qua."
    fi
else
    echo "⚠️  Không tìm thấy $GOOGLE_SUDOERS. Bỏ qua."
fi

# B. Thiết lập quyền giới hạn cho user mới chọn
NEW_CONFIG="/etc/sudoers.d/${USER_NAME}-apt"
echo "📝 Đang cấu hình quyền apt-get cho: $USER_NAME"

# Viết vào file tạm để kiểm tra trước
TMP_APT=$(mktemp)
echo "$USER_NAME ALL=(ALL) NOPASSWD: /usr/bin/apt-get update, /usr/bin/apt-get install, /usr/bin/apt-get upgrade" > "$TMP_APT"

# CHỐT CHẶN KIỂM TRA VISUDO
if visudo -cf "$TMP_APT" &>/dev/null; then
    cat "$TMP_APT" > "$NEW_CONFIG"
    chmod 0440 "$NEW_CONFIG"
    echo "✅ Đã thiết lập file cấu hình: $NEW_CONFIG"
else
    echo "❌ LỖI NGHIÊM TRỌNG: Cấu pháp sudo cấp cho $USER_NAME không hợp lệ! Không ghi đè hệ thống."
fi
rm -f "$TMP_APT"

# 6. Kiểm tra kết quả trực quan
echo -e "\n--- 🏁 HOÀN TẤT! ---"
echo "🔍 Kiểm tra quyền hiện tại của $USER_NAME:"
sudo -l -U "$USER_NAME"
echo "===================================================="

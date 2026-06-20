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
echo "   🛡️  HỆ THỐNG SIẾT CHẶT QUYỀN SUDO (LOOPING)    "
echo "===================================================="

# 2. Lấy danh sách user
USERS=($(grep -E '/bin/bash|/bin/sh' /etc/passwd | grep -v 'root' | cut -d: -f1))

# 3. Vòng lặp chính - Sẽ lặp lại cho đến khi chọn đúng hoặc chọn Thoát
while true; do
    echo -e "\n--- 📋 DANH SÁCH CÁC USER CÓ THỂ ĐĂNG NHẬP ---"
    for i in "${!USERS[@]}"; do
        printf "%2d) %s\n" "$((i+1))" "${USERS[$i]}"
    done
    echo " 0) Thoát"
    echo "----------------------------------------------------"

    read -p "👉 Nhập số thứ tự bạn chọn: " input

    # Lấy duy nhất các chữ số từ input (để chống copy-paste lỗi)
    choice=$(echo "$input" | tr -dc '0-9')

    # TRƯỜNG HỢP 1: Người dùng nhấn Enter mà không nhập gì (chuỗi rỗng)
    if [[ -z "$choice" ]]; then
        echo "⚠️  Bạn chưa nhập gì cả! Vui lòng nhập một con số."
        continue # Quay lại đầu vòng lặp
    fi

    # TRƯỜNG HỢP 2: Người dùng chọn Thoát (số 0)
    if [ "$choice" -eq 0 ]; then
        echo "👋 Đã thoát."
        exit 0
    fi

    # TRƯỜNG HỢP 3: Số nhập vào nằm ngoài phạm vi danh sách
    if [ "$choice" -gt "${#USERS[@]}" ]; then
        echo "❌ Lựa chọn không hợp lệ (Số $choice vượt quá danh sách). Thử lại nhé!"
        continue # Quay lại đầu vòng lặp
    fi

    # NẾU ĐÃ ĐẾN ĐÂY, NGHĨA LÀ LỰA CHỌN ĐÃ HỢP LỆ
    index=$((choice - 1))
    USER_NAME="${USERS[$index]}"
    echo "✅ Bạn đã chọn: $USER_NAME"
    break # Thoát khỏi vòng lặp while để đi tiếp xuống phần thực thi
done

# 4. Cơ chế tự bảo vệ (Safety Guard)
if [ "$USER_NAME" == "$CURRENT_USER" ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "🚨 CẢNH BÁO NGUY HIỂM: 🚨"
    echo "Bạn đang chọn chính mình ($USER_NAME)!"
    echo "Nếu bạn làm việc này, bạn sẽ bị mất quyền sudo"
    echo "ngoại trừ lệnh apt-get. Bạn có chắc chắn không?"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    read -p "Nhập 'YES' để xác nhận: " CONFIRM
    if [ "$CONFIRM" != "YES" ]; then
        echo "❌ Đã hủy thao tác để bảo vệ bạn."
        exit 1
    fi
fi

# 5. Thực hiện siết quyền
echo -e "\n--- 🛡️  ĐANG THỰC THI QUY TRÌNH ---"

# A. Xử lý google_sudoers
if [ -f "$GOOGLE_SUDOERS" ]; then
    echo "📦 Đang sao lưu $GOOGLE_SUDOERS -> ${GOOGLE_SUDOERS}.bak"
    cp "$GOOGLE_SUDOERS" "${GOOGLE_SUDOERS}.bak"

    if grep -q "NOPASSWD:ALL" "$GOOGLE_SUDOERS"; then
        sed -i 's/NOPASSWD:ALL/ALL/' "$GOOGLE_SUDOERS"
        sed -i "s/^%google-sudoers.*/%google-sudoers ALL=(ALL:ALL) ALL/" "$GOOGLE_SUDOERS"
        echo "✅ Đã vô hiệu hóa NOPASSWD cho nhóm google-sudoers."
    else
        echo "ℹ️  google-sudoers đã không có NOPASSWD. Bỏ qua."
    fi
else
    echo "⚠️  Không tìm thấy $GOOGLE_SUDOERS. Bỏ qua."
fi

# B. Thiết lập quyền giới hạn cho user
NEW_CONFIG="/etc/sudoers.d/${USER_NAME}-apt"
echo "📝 Đang tạo file cấu hình: $NEW_CONFIG"

echo "$USER_NAME ALL=(ALL) NOPASSWD: /usr/bin/apt-get update, /usr/bin/apt-get install, /usr/bin/apt-get upgrade" > "$NEW_CONFIG"
chmod 0440 "$NEW_CONFIG"
echo "✅ Đã thiết lập quyền apt-get cho $USER_NAME."

# 6. Kiểm tra kết quả
echo -e "\n--- 🏁 HOÀN TẤT! ---"
echo "🔍 Kiểm tra quyền hiện tại của $USER_NAME:"
sudo -l -U "$USER_NAME"
echo "===================================================="

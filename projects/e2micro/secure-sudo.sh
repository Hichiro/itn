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

# 2. Lấy danh sách user (Dùng mapfile an toàn hơn)
mapfile -t USERS < <(grep -E '/bin/bash|/bin/sh' /etc/passwd | grep -v 'root' | cut -d: -f1)

if [ ${#USERS[@]} -eq 0 ]; then
    echo "❌ LỖI: Không tìm thấy user nào hợp lệ trên hệ thống!"
    exit 1
fi

# 3. Vòng lặp chính - Sẽ lặp lại cho đến khi chọn đúng
while true; do
    echo -e "\n--- 📋 DANH SÁCH CÁC USER CÓ THỂ ĐĂNG NHẬP ---"
    for i in "${!USERS[@]}"; do
        printf "%2d) %s\n" "$((i+1))" "${USERS[$i]}"
    done
    echo " 0) Thoát"
    echo "----------------------------------------------------"

    read -p "👉 Nhập số thứ tự bạn chọn: " input </dev/tty

    # TRƯỜNG HỢP 1: Chuỗi rỗng (Chỉ bấm Enter)
    if [[ -z "$input" ]]; then
        echo "⚠️  Bạn chưa nhập gì cả! Vui lòng nhập một con số."
        continue
    fi

    # TRƯỜNG HỢP 2: Lọc đầu vào (Chỉ chấp nhận số nguyên dương hoặc số 0)
    if ! [[ "$input" =~ ^[0-9]+$ ]]; then
        echo "⚠️  Lựa chọn không hợp lệ! Vui lòng chỉ nhập số."
        continue
    fi

    # Gán biến sau khi chắc chắn đầu vào là số
    choice="$input"

    # TRƯỜNG HỢP 3: Người dùng chọn Thoát
    if [ "$choice" -eq 0 ]; then
        echo "👋 Đã thoát."
        exit 0
    fi

    # TRƯỜNG HỢP 4: Số vượt quá danh sách
    if [ "$choice" -gt "${#USERS[@]}" ]; then
        echo "❌ Lựa chọn không hợp lệ (Số $choice vượt quá danh sách). Thử lại nhé!"
        continue
    fi

    # TRƯỜNG HỢP 5: Xử lý lựa chọn hợp lệ
    index=$((choice - 1))
    USER_NAME="${USERS[$index]}"

    # Chốt chặn cuối: Đảm bảo biến USER_NAME thực sự có dữ liệu
    if [[ -z "$USER_NAME" ]]; then
         echo "❌ Lỗi hệ thống: Không xác định được user. Vui lòng thử lại!"
         continue
    fi

    echo "✅ Bạn đã chọn: $USER_NAME"
    break # Bẻ gãy vòng lặp để đi tiếp
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

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
echo "   🛡️  HỆ THỐNG SIẾT CHẶT QUYỀN SUDO (BULLETPROOF) "
echo "===================================================="

# 2. Lấy danh sách user
USERS=($(grep -E '/bin/bash|/bin/sh' /etc/passwd | grep -v 'root' | cut -d: -f1))

# 3. Hiển thị menu
echo "--- 📋 DANH SÁCH CÁC USER CÓ THỂ ĐĂNG NHẬP ---"
for i in "${!USERS[@]}"; do
    printf "%2d) %s\n" "$((i+1))" "${USERS[$i]}"
done
echo " 0) Thoát"
echo "----------------------------------------------------"

# 4. Nhập lựa chọn - SỬ DỤNG LOGIC MỚI
read -p "👉 Nhập số thứ tự bạn chọn: " input

# CHIÊU CUỐI: Chỉ giữ lại các chữ số, loại bỏ mọi ký tự khác (khoảng trắng, dấu ngoặc, chữ...)
# Ví dụ: "1) u_hichiro" -> "1" | "  2  " -> "2" | "abc" -> ""
choice=$(echo "$input" | tr -dc '0-9')

# Kiểm tra nếu không có số nào được nhập hoặc nhập số 0
if [[ -z "$choice" || "$choice" -eq 0 ]]; then
    echo "👋 Đã thoát hoặc lựa chọn không hợp lệ."
    exit 0
fi

# Kiểm tra xem số có nằm trong phạm vi danh sách không
if [ "$choice" -gt "${#USERS[@]}" ]; then
    echo "❌ Lựa chọn không hợp lệ (Số $choice vượt quá danh sách)."
    exit 1
fi

# Chuyển số thành index
index=$((choice - 1))
USER_NAME="${USERS[$index]}"

echo "✅ Bạn đã chọn: $USER_NAME"

# 5. Cơ chế tự bảo vệ (Safety Guard)
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

# 6. Thực hiện siết quyền
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

# 7. Kiểm tra kết quả
echo -e "\n--- 🏁 HOÀN TẤT! ---"
echo "🔍 Kiểm tra quyền hiện tại của $USER_NAME:"
sudo -l -U "$USER_NAME"
echo "===================================================="

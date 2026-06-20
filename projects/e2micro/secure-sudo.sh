#!/bin/bash

# --- 🛠️ CẤU HÌNH ---
GOOGLE_SUDOERS="/etc/sudoers.d/google_sudoers"
CURRENT_USER=${SUDO_USER:-$USER} # Lấy user thực tế đang chạy lệnh

# 1. Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo "❌ LỖI: Script này cần chạy với quyền root (sudo)." 
   exit 1
fi

echo "===================================================="
echo "   🛡️  HỆ THỐNG SIẾT CHẶT QUYỀN SUDO (PRO VERSION)  "
echo "===================================================="

# 2. Lấy danh sách user (loại bỏ root và các user hệ thống)
USERS=($(grep -E '/bin/bash|/bin/sh' /etc/passwd | grep -v 'root' | cut -d: -f1))

# 3. Hiển thị menu chọn
PS3="👉 Hãy chọn số thứ tự của user bạn muốn siết quyền: "
select USER_NAME in "${USERS[@]}" "Thoát"; do
    case $USER_NAME in
        "Thoát")
            echo "👋 Đã thoát."
            exit 0
            ;;
        *)
            if [ -n "$USER_NAME" ]; then
                # --- ⚠️ CƠ CHẾ TỰ BẢO VỆ (SAFETY GUARD) ---
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
                echo "✅ Bạn đã chọn: $USER_NAME"
                break
            else
                echo "❌ Lựa chọn không hợp lệ."
            fi
            ;;
    esac
done

# 4. Thực hiện siết quyền
echo -e "\n--- 🛡️  ĐANG THỰC THI QUY TRÌNH ---"

# A. Xử lý google_sudoers (Vô hiệu hóa NOPASSWD)
if [ -f "$GOOGLE_SUDOERS" ]; then
    echo "📦 Đang sao lưu $GOOGLE_SUDOERS -> ${GOOGLE_SUDOERS}.bak"
    cp "$GOOGLE_SUDOERS" "${GOOGLE_SUDOERS}.bak"

    # Sử dụng sed để tìm dòng có NOPASSWD và thay thế bằng dòng yêu cầu mật khẩu
    # Cách này an toàn hơn vì nó chỉ thay đổi phần NOPASSWD
    if grep -q "NOPASSWD:ALL" "$GOOGLE_SUDOERS"; then
        sed -i 's/NOPASSWD:ALL/ALL/' "$GOOGLE_SUDOERS"
        # Nếu sau khi thay bằng ALL mà dòng vẫn chưa chuẩn, ta ép nó về chuẩn:
        sed -i "s/^%google-sudoers.*/%google-sudoers ALL=(ALL:ALL) ALL/" "$GOOGLE_SUDOERS"
        echo "✅ Đã vô hiệu hóa NOPASSWD cho nhóm google-sudoers."
    else
        echo "ℹ️  google-sudoers đã không có NOPASSWD. Bỏ qua."
    fi
else
    echo "⚠️  Không tìm thấy $GOOGLE_SUDOERS. Bỏ qua bước này."
fi

# B. Thiết lập quyền giới hạn cho user đã chọn
NEW_CONFIG="/etc/sudoers.d/${USER_NAME}-apt"
echo "📝 Đang tạo file cấu hình: $NEW_CONFIG"

# Kiểm tra nếu file đã tồn tại để tránh ghi đè nhầm
if [ -f "$NEW_CONFIG" ]; then

    echo "⚠️  File $NEW_CONFIG đã tồn tại. Đang ghi đè..."
fi

echo "$USER_NAME ALL=(ALL) NOPASSWD: /usr/bin/apt-get update, /usr/bin/apt-get install, /usr/bin/apt-get upgrade" > "$NEW_CONFIG"
chmod 0440 "$NEW_CONFIG"
echo "✅ Đã thiết lập quyền apt-get cho $USER_NAME."

# 5. Kiểm tra kết quả
echo -e "\n--- 🏁 HOÀN TẤT! ---"
echo "🔍 Kiểm tra quyền hiện tại của $USER_NAME:"
sudo -l -U "$USER_NAME"
echo "===================================================="

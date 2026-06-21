#!/bin/bash

# --- 🛠️ CẤU HÌNH ---
GOOGLE_SUDOERS="/etc/sudoers.d/google_sudoers"
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

# --- TÙY CHỌN LOẠI BỎ QUYỀN ADMIN TOÀN DIỆN ---
echo -e "\n🛡️  TÙY CHỌN PHÂN QUYỀN:"
echo "👉 Bạn có muốn TƯỚC TOÀN BỘ quyền Admin khác của '$USER_NAME' không?"
echo "   (Nếu CHỌN: User này SẼ KHÔNG THỂ chạy bất kỳ lệnh sudo nào khác ngoại trừ các lệnh được chỉ định bên dưới)"
read -p "🤔 Lựa chọn của bạn (Y/n) [Mặc định: Y]: " opt_remove </dev/tty

if [[ -z "$opt_remove" || "$opt_remove" =~ ^[Yy]$ ]]; then
    STRIP_ADMIN=true
    echo "🔹 Trạng thái chọn: ĐỒNG Ý tước quyền Admin gốc."
else
    STRIP_ADMIN=false
    echo "🔹 Trạng thái chọn: GIỮ NGUYÊN quyền Admin gốc (Vẫn bắt nhập mật khẩu cho lệnh khác)."
fi

# 4. Cơ chế tự bảo vệ
if [ "$USER_NAME" == "$CURRENT_USER" ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "🚨 CẢNH BÁO NGUY HIỂM CHẾT NGƯỜI: Bạn đang chọn chính mình ($USER_NAME)!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    read -p "Nhập đúng chữ 'YES' để xác nhận chịu rủi ro: " CONFIRM </dev/tty
    if [ "$CONFIRM" != "YES" ]; then
        echo "❌ Đã hủy thao tác."
        exit 1
    fi
fi

# 5. Thực hiện siết quyền
echo -e "\n--- 🛡️  ĐANG THỰC THI QUY TRÌNH ---"

# A. Tước quyền Admin khỏi nhóm google-sudoers
if [ "$STRIP_ADMIN" = true ]; then
    if id -nG "$USER_NAME" | grep -q "google-sudoers"; then
        echo "✂️  Đang xóa '$USER_NAME' khỏi nhóm 'google-sudoers'..."
        gpasswd -d "$USER_NAME" google-sudoers &>/dev/null
    fi
else
    echo "ℹ️  Giữ nguyên tư cách thành viên nhóm Admin cho '$USER_NAME'."
fi

# B. Kiểm tra và dọn dẹp file google_sudoers
if [ -f "$GOOGLE_SUDOERS" ]; then
    if grep -q "NOPASSWD:[[:space:]]*ALL" "$GOOGLE_SUDOERS"; then
        echo "📦 Đang siết lại NOPASSWD:ALL trong file cấu hình gốc..."
        cp "$GOOGLE_SUDOERS" "${GOOGLE_SUDOERS}.bak"
        TMP_SUDOERS=$(mktemp)
        cp "$GOOGLE_SUDOERS" "$TMP_SUDOERS"
        sed -i 's/NOPASSWD:[[:space:]]*ALL/ALL/g' "$TMP_SUDOERS"
        sed -i "s/^%google-sudoers.*/%google-sudoers ALL=(ALL:ALL) ALL/" "$TMP_SUDOERS"

        if "$VISUDO_CMD" -cf "$TMP_SUDOERS" &>/dev/null; then
            cat "$TMP_SUDOERS" > "$GOOGLE_SUDOERS"
        fi
        rm -f "$TMP_SUDOERS"
    fi
fi

# C. Cấu hình giới hạn
NEW_CONFIG="/etc/sudoers.d/z_${USER_NAME}-picoclaw-restricted"
echo "📝 Đang cấu hình giới hạn quyền cho: $USER_NAME"

TMP_APT=$(mktemp)

cat <<EOF > "$TMP_APT"
$USER_NAME ALL=(ALL:ALL) NOPASSWD: /usr/bin/apt update, /usr/bin/apt upgrade
EOF

if "$VISUDO_CMD" -cf "$TMP_APT"; then
    cat "$TMP_APT" > "$NEW_CONFIG"
    chmod 0440 "$NEW_CONFIG"
    echo "✅ Đã khóa quyền! Cấu hình hoàn tất."
else
    echo "❌ LỖI NGHIÊM TRỌNG: Cú pháp sai!"
    cat "$TMP_APT"
    echo "Hủy bỏ để tránh lỗi hệ thống."
fi
rm -f "$TMP_APT"

# 6. Kiểm tra kết quả
echo -e "\n--- 🏁 HOÀN TẤT QUY TRÌNH! ---"
echo "🔍 Quyền hạn thực tế cuối cùng áp dụng cho $USER_NAME:"
sudo -l -U "$USER_NAME"
echo "===================================================="

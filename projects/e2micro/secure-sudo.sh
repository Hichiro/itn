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
echo "     🛡️  HỆ THỐNG SIẾT CHẶT QUYỀN SUDO (APT-ONLY)     "
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

# --- 🆕 BƯỚC MỚI: TÙY CHỌN LOẠI BỎ QUYỀN ADMIN TOÀN DIỆN ---
echo -e "\n🛡️  TÙY CHỌN PHÂN QUYỀN:"
echo "👉 Bạn có muốn TƯỚC TOÀN BỘ quyền Admin khác của '$USER_NAME' không?"
echo "   (Nếu CHỌN: User này SẼ KHÔNG THỂ chạy bất kỳ lệnh sudo nào khác ngoài apt)"
read -p "🤔 Lựa chọn của bạn (Y/n) [Mặc định: Y]: " opt_remove </dev/tty

if [[ -z "$opt_remove" || "$opt_remove" =~ ^[Yy]$ ]]; then
    STRIP_ADMIN=true
    echo "🔹 Trạng thái chọn: ĐỒNG Ý tước quyền Admin gốc (Chỉ giữ lại apt)."
else
    STRIP_ADMIN=false
    echo "🔹 Trạng thái chọn: GIỮ NGUYÊN quyền Admin gốc (Vẫn bắt nhập mật khẩu cho lệnh khác)."
fi


# 4. Cơ chế tự bảo vệ (Safety Guard nâng cấp)
if [ "$USER_NAME" == "$CURRENT_USER" ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "🚨 CẢNH BÁO NGUY HIỂM CHẾT NGƯỜI: 🚨"
    echo "Bạn đang chọn chính mình ($USER_NAME)!"
    if [ "$STRIP_ADMIN" = true ]; then
        echo "⚠️  BẠN ĐANG TỰ TƯỚC QUYỀN ADMIN CỦA CHÍNH MÌNH!"
        echo "Sau lệnh này, bạn sẽ bị KHOÁ CHẶT SUDO, không thể cấu hình hệ thống nữa!"
    fi
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    read -p "Nhập đúng chữ 'YES' để xác nhận chịu rủi ro: " CONFIRM </dev/tty
    if [ "$CONFIRM" != "YES" ]; then
        echo "❌ Đã hủy thao tác để bảo vệ quyền Root của bạn."
        exit 1
    fi
fi


# 5. Thực hiện siết quyền
echo -e "\n--- 🛡️  ĐANG THỰC THI QUY TRÌNH ---"

# A. Tước quyền Admin khỏi nhóm google-sudoers (Nếu người dùng chọn Có)
if [ "$STRIP_ADMIN" = true ]; then
    if id -nG "$USER_NAME" | grep -q "google-sudoers"; then
        echo "✂️  Đang tiến hành xóa '$USER_NAME' ra khỏi nhóm quyền lực 'google-sudoers'..."
        if gpasswd -d "$USER_NAME" google-sudoers &>/dev/null; then
            echo "✅ Đã tước quyền Admin gốc thành công."
        else
            echo "⚠️  Có lỗi xảy ra khi xóa user khỏi nhóm (hoặc cần gỡ thủ công)."
        fi
    else
        echo "ℹ️  User '$USER_NAME' vốn đã không nằm trong nhóm google-sudoers. Bỏ qua."
    fi
else
    echo "ℹ️  Giữ nguyên tư cách thành viên nhóm Admin cho '$USER_NAME' theo yêu cầu."
fi

# B. Kiểm tra và dọn dẹp file google_sudoers nếu chứa NOPASSWD nguy hiểm
if [ -f "$GOOGLE_SUDOERS" ]; then
    if grep -q "NOPASSWD:ALL" "$GOOGLE_SUDOERS"; then
        echo "📦 Phát hiện NOPASSWD:ALL cũ trong file gốc, đang siết lại về mặc định..."
        cp "$GOOGLE_SUDOERS" "${GOOGLE_SUDOERS}.bak"
        TMP_SUDOERS=$(mktemp)
        cp "$GOOGLE_SUDOERS" "$TMP_SUDOERS"
        sed -i 's/NOPASSWD:ALL/ALL/' "$TMP_SUDOERS"
        sed -i "s/^%google-sudoers.*/%google-sudoers ALL=(ALL:ALL) ALL/" "$TMP_SUDOERS"

        if visudo -cf "$TMP_SUDOERS" &>/dev/null; then
            cat "$TMP_SUDOERS" > "$GOOGLE_SUDOERS"
            echo "✅ Đã cấu hình nhóm google-sudoers về trạng thái đòi mật khẩu."
        fi
        rm -f "$TMP_SUDOERS"
    fi
fi

# C. Thiết lập đặc quyền NOPASSWD riêng cho apt (Đã loại bỏ lệnh install)
NEW_CONFIG="/etc/sudoers.d/z_${USER_NAME}-apt"
echo "📝 Đang mở khoá đặc quyền apt không mật khẩu cho: $USER_NAME"

TMP_APT=$(mktemp)
# Chỉ cho phép chạy lệnh apt update và apt upgrade (bao gồm cả full-upgrade) không cần mật khẩu
echo "$USER_NAME ALL=(ALL) NOPASSWD: /usr/bin/apt update, /usr/bin/apt upgrade, /usr/bin/apt full-upgrade" > "$TMP_APT"

if visudo -cf "$TMP_APT" &>/dev/null; then
    cat "$TMP_APT" > "$NEW_CONFIG"
    chmod 0440 "$NEW_CONFIG"
    echo "✅ Đã áp dụng file cấu hình đặc quyền: $NEW_CONFIG"
else
    echo "❌ LỖI NGHIÊM TRỌNG: Cú pháp cấp quyền apt sai! Hủy bỏ để tránh lỗi hệ thống."
fi
rm -f "$TMP_APT"


# 6. Kiểm tra kết quả trực quan
echo -e "\n--- 🏁 HOÀN TẤT QUY TRÌNH! ---"
echo "🔍 Quyền hạn thực tế cuối cùng áp dụng cho $USER_NAME:"
sudo -l -U "$USER_NAME"
echo "===================================================="

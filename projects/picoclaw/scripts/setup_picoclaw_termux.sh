#!/bin/bash

# Hàm tiện ích: Ghi cấu hình tự động bật SSH vào .bashrc nếu chưa có
enable_ssh_autostart() {
    if ! grep -q 'sshd' ~/.bashrc; then
        cat << 'SSH_BOOT' >> ~/.bashrc

# Tự động chạy SSH khi mở Termux nếu chưa chạy
if command -v sshd >/dev/null 2>&1 && ! pgrep -x "sshd" > /dev/null; then 
    sshd
fi
SSH_BOOT
        echo "Da thiet lap tu dong khoi dong SSH cung Termux."
    fi
}

echo "=== 1. KIEM TRA VA CAU HINH SSH ==="
touch ~/.bashrc
if pgrep -x "sshd" > /dev/null; then
    echo "Dich vu SSH hien dang hoat dong binh thuong."
    enable_ssh_autostart
else
    echo "Canh bao: Dich vu SSH hien tai KHONG hoat dong."
    read -p "Ban co muon kich hoat va su dung SSH khong? (y/n): " choice </dev/tty
    if [[ "$choice" == [Yy] ]]; then
        if ! command -v sshd >/dev/null 2>&1; then
            echo "Dang cap nhat kho ung dung va cai dat openssh..."
            pkg update -y -o Dpkg::Options::="--force-confnew" && pkg install openssh -y
        fi
        echo "Thiet lap/Cap nhat mat khau dang nhap SSH cho Termux:"
        chsh -s bash
        passwd </dev/tty
        sshd
        echo "Da kich hoat dich vu SSH thanh cong."
        enable_ssh_autostart
    else
        echo "Da bo qua cau hinh SSH theo yeu cau."
    fi
fi

echo "=== 2. KHOI TAO DUONG DAN HE THONG PICOCLAW ==="
mkdir -p $HOME/go/bin
mkdir -p $HOME/.picoclaw

echo "=== 3. KIEM TRA VA TAI PHIEN BAN PICOCLAW MOI NHAT ==="
echo "Dang doc ma commit tu GitHub cua ban..."
MY_REMOTE_COMMIT=$(curl -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/projects/picoclaw/last_build_commit.txt" | tr -d '\r\n ' )
LOCAL_COMMIT=$(cat $HOME/.picoclaw/last_build_commit.txt 2>/dev/null || echo "")
NEED_UPDATE=false

if [ -z "$MY_REMOTE_COMMIT" ]; then
    echo "Canh bao: Khong the doc file last_build_commit.txt tu GitHub."
    read -p "Ban co muon ep buoc tai lai/cai dat file binary khong? (y/n): " force_choice </dev/tty
    if [[ "$force_choice" == [Yy] ]]; then
        NEED_UPDATE=true
    fi
elif [ "$MY_REMOTE_COMMIT" = "$LOCAL_COMMIT" ] && [ -f "$HOME/go/bin/picoclaw" ]; then
    echo "Ban dang su dung ban build PicoClaw moi nhat (${LOCAL_COMMIT:0:7}). Khong can tai lai."
else
    echo "Phat hien ban build PicoClaw moi tren GitHub!"
    echo "   - Ban hien tai tren may: ${LOCAL_COMMIT:-none}"
    echo "   - Ban moi tren GitHub  : ${MY_REMOTE_COMMIT:0:7}"
    
    read -p "Ban co muon cai dat/cap nhat phien ban nay khong? (y/n): " update_choice </dev/tty
    if [[ "$update_choice" == [Yy] ]]; then
        NEED_UPDATE=true
    fi
fi

if [ "$NEED_UPDATE" = true ]; then
    echo "Dang dung cac tien trinh PicoClaw cu de giai phong file..."
    pkill -f "picoclaw gateway" > /dev/null 2>&1
    killall picoclaw > /dev/null 2>&1
    sleep 1 

    echo "Dang tai file binary picoclaw tu GitHub..."
    curl -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/projects/picoclaw/picoclaw" -o $HOME/go/bin/picoclaw

    if [ $? -eq 0 ] && [ -s "$HOME/go/bin/picoclaw" ]; then
        echo "Tai file binary PicoClaw thanh cong!"
        if [ ! -z "$MY_REMOTE_COMMIT" ]; then
            echo "$MY_REMOTE_COMMIT" > $HOME/.picoclaw/last_build_commit.txt
        fi
    else
        echo "Loi: Khong the tai file tu GitHub hoac file tai ve bi rong."
        exit 1
    fi
else
    echo "Da bo qua buoc tai/cap nhat phien ban."
fi

echo "=== 4. CAP QUYEN VA DONG BO PATH ==="
chmod +x $HOME/go/bin/picoclaw
if ! grep -q 'go/bin' ~/.bashrc; then
    echo 'export PATH="$HOME/go/bin:$PATH"' >> ~/.bashrc
fi
export PATH="$HOME/go/bin:$PATH"

echo "=== 5. CAU HINH MUI GIO (TIMEZONE) BROWSER ==="
echo "Dang tu dong kiem tra mui gio he thong..."
USER_TZ=$(getprop persist.sys.timezone 2>/dev/null)
if [ -z "$USER_TZ" ] && [ -L /etc/localtime ]; then
    USER_TZ=$(readlink /etc/localtime | sed 's#.*/zoneinfo/##')
fi
if [ -z "$USER_TZ" ]; then
    USER_TZ="Asia/Ho_Chi_Minh"
fi
echo "-> Da phat hien mui gio he thong: $USER_TZ"

echo "=== 6. THIET LAP TU DONG KHOI DONG PICOCLAW ==="
# Giải pháp an toàn: Dùng sed xóa chính xác dựa vào chuỗi định danh, tránh xóa nhầm khối lệnh khác
sed -i '/# Tự động khởi động PicoClaw/,/fi/d' ~/.bashrc

cat << PICOCLAW_BOOT >> ~/.bashrc
# Tự động khởi động PicoClaw gateway ngầm nếu đã có file config.json và chưa chạy
if [ -f "\$HOME/.picoclaw/config.json" ] && ! pgrep -f "picoclaw gateway" > /dev/null; then
    TZ="$USER_TZ" nohup picoclaw gateway > /dev/null 2>&1 &
fi
PICOCLAW_BOOT
echo "Da thiet lap cau hinh tu dong khoi dong PicoClaw kem mui gio cung Termux."

# KHỞI CHẠY NGAY NẾU ĐỦ ĐIỀU KIỆN
if [ -f "$HOME/.picoclaw/config.json" ]; then
    if ! pgrep -f "picoclaw gateway" > /dev/null; then
        echo "Dang kich hoat PicoClaw gateway chay ngam voi mui gio $USER_TZ..."
        TZ="$USER_TZ" nohup picoclaw gateway > /dev/null 2>&1 &
    else
        echo "PicoClaw gateway dang chay ngam roi. (De ap dung mui gio moi vui long khoi dong lai Termux)."
    fi
else
    echo "Lưu ý: Bạn cần cấu hình file '~/.picoclaw/config.json' và '~/.picoclaw/.security.yml' để khởi chạy dịch vụ."
fi

echo "================================================="
echo " CÀI ĐẶT MỚI PICOCLAW HOÀN TẤT THÀNH CÔNG!"
echo "================================================="

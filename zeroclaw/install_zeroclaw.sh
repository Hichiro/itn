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
    read -p "Ban co muon kich hoat va su dung SSH khong? (y/n): " choise </dev/tty
    if [[ "$choise" == [Yy] ]]; then
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

echo "=== 2. KHOI TAO DUONG DAN HE THONG ==="
mkdir -p $HOME/.cargo/bin
mkdir -p $HOME/.zeroclaw

echo "=== 3. KIEM TRA PHIEN BAN TU FILE COMMIT TREN GITHUB ==="
echo "Dang doc ma commit tu GitHub cua ban..."

# Tải trực tiếp nội dung file text mã commit do GitHub Actions tạo ra
MY_REMOTE_COMMIT=$(curl -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/zeroclaw/last_build_commit.txt" | tr -d '\r\n ' )
LOCAL_COMMIT=$(cat $HOME/.zeroclaw/last_build_commit.txt 2>/dev/null || echo "")

NEED_UPDATE=false

if [ -z "$MY_REMOTE_COMMIT" ]; then
    echo "Canh bao: Khong the doc file last_build_commit.txt tu GitHub."
    read -p "Ban co muon ep buoc tai lai/cai dat file binary khong? (y/n): " force_choice </dev/tty
    if [[ "$force_choice" == [Yy] ]]; then
        NEED_UPDATE=true
    fi
elif [ "$MY_REMOTE_COMMIT" = "$LOCAL_COMMIT" ] && [ -f "$HOME/.cargo/bin/zeroclaw" ]; then
    echo "Ban dang su dung ban build moi nhat (${LOCAL_COMMIT:0:7}). Khong can tai lai."
else
    echo "Phat hien ban build moi tren GitHub!"
    echo "   - Ban hien tai tren may: ${LOCAL_COMMIT:-none}"
    echo "   - Ban moi tren GitHub  : ${MY_REMOTE_COMMIT:0:7}"
    
    read -p "Ban co muon cap nhat len phien ban moi nay khong? (y/n): " update_choice </dev/tty
    if [[ "$update_choice" == [Yy] ]]; then
        NEED_UPDATE=true
    fi
fi

if [ "$NEED_UPDATE" = true ]; then
    echo "Dang tam dung cac tien trinh ZeroClaw ngam de mo khoa file..."
    pkill -f zeroclaw > /dev/null 2>&1
    killall zeroclaw > /dev/null 2>&1
    sleep 1 

    echo "Dang tai file binary tu: Hichiro/itn..."
    curl -fsSL "https://raw.githubusercontent.com/Hichiro/itn/main/zeroclaw/zeroclaw" -o $HOME/.cargo/bin/zeroclaw

    if [ $? -eq 0 ] && [ -s "$HOME/.cargo/bin/zeroclaw" ]; then
        echo "Cap nhat thanh cong ban build moi!"
        if [ ! -z "$MY_REMOTE_COMMIT" ]; then
            echo "$MY_REMOTE_COMMIT" > $HOME/.zeroclaw/last_build_commit.txt
        fi
    else
        echo "Loi: Khong the tai file tu GitHub hoac file tai ve bi rong."
        exit 1
    fi
else
    echo "Da bo qua buoc tai/cap nhat phien ban theo yeu cau."
fi

echo "=== 4. CAP QUYEN VA DONG BO PATH ==="
chmod +x $HOME/.cargo/bin/zeroclaw

if ! grep -q '\.cargo/bin' ~/.bashrc; then
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
fi
export PATH="$HOME/.cargo/bin:$PATH"

echo "=== 5. THIET LAP TU DONG KHOI DONG ZEROCLAW ==="
# Kiểm tra và thêm vào .bashrc nếu chưa có
if ! grep -q 'zeroclaw daemon' ~/.bashrc; then
    cat << 'ZEROCLAW_BOOT' >> ~/.bashrc

# Tự động khởi động ZeroClaw ngầm nếu chưa chạy và đã có cấu hình hoàn chỉnh
if [ -f "$HOME/.zeroclaw/config.toml" ] && ! pgrep -f "zeroclaw daemon" > /dev/null; then
    nohup zeroclaw daemon > /dev/null 2>&1 &
fi
ZEROCLAW_BOOT
    echo "Da thiet lap cau hinh tu dong khoi dong ZeroClaw cung Termux."
fi

# KHỞI CHẠY NGAY: Nếu có file config và chưa chạy thì bật luôn không quan tâm có update hay không
if [ -f "$HOME/.zeroclaw/config.toml" ] && ! pgrep -f "zeroclaw daemon" > /dev/null; then
    echo "Dang kich hoat ZeroClaw chay ngam..."
    nohup zeroclaw daemon > /dev/null 2>&1 &
fi

echo "================================================="
echo " QUY TRINH HOAN TAT THANH CONG!"
echo "================================================="

echo "================================================="
echo " QUY TRINH HOAN TAT THANH CONG!"
echo "================================================="

#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# SCRIPT CÀI ĐẶT KLIPPER QUA KIAUH TRÊN TERMUX (YÊU CẦU MÁY ĐÃ ROOT)
# Quy định: Chạy toàn bộ script để cấu hình môi trường
# ==============================================================================

set -e # Dừng script nếu có lỗi xảy ra

echo "===================================================="
echo " BẮT ĐẦU CẤU HÌNH KLIPPER TRÊN TERMUX (ROOTED)      "
echo "===================================================="

# 1. Cập nhật hệ thống Termux
echo "[1/5] Đang cập nhật package hệ thống..."
pkg update -y && pkg upgrade -y

# 2. Cài đặt các công cụ cần thiết
echo "[2/5] Cài đặt git, tsu (để chạy root trong termux)..."
pkg install git tsu -y

# 3. Cấp quyền truy cập bộ nhớ cho Termux
echo "[3/5] Yêu cầu quyền truy cập bộ nhớ (Vui lòng bấm 'Cho phép' trên màn hình)..."
termux-setup-storage
sleep 3

# 4. Tải script KIAUH chính thức từ Github
echo "[4/5] Tải KIAUH..."
cd $HOME
if [ -d "kiauh" ]; then
    echo "Thư mục kiauh đã tồn tại, tiến hành cập nhật..."
    cd kiauh && git pull
else
    git clone https://github.com/dw-0/kiauh.git
    cd kiauh
fi
chmod +x kiauh.sh

# 5. Tạo script phụ để tự động kích hoạt quyền Root cho cổng USB máy in
echo "[5/5] Tạo script cấu hình cổng USB máy in bằng quyền Root..."
cat << 'EOF' > $HOME/fix_usb_root.sh
#!/data/data/com.termux/files/usr/bin/bash
echo "Đang yêu cầu quyền Root để mở cổng USB..."
tsu -c "
  echo 'Đang tìm kiếm cổng USB máy in...'
  # Cấp quyền đọc/ghi cho tất cả các thiết bị ttyUSB và ttyACM kết nối vào máy
  if [ -e /dev/ttyUSB* ]; then chmod 666 /dev/ttyUSB*; echo 'Đã mở quyền cổng ttyUSB!'; fi
  if [ -e /dev/ttyACM* ]; then chmod 666 /dev/ttyACM*; echo 'Đã mở quyền cổng ttyACM!'; fi
"
EOF
chmod +x $HOME/fix_usb_root.sh

echo "===================================================="
echo " CẤU HÌNH HOÀN TẤT! VUI LÒNG LÀM THEO CÁC BƯỚC SAU: "
echo "===================================================="
echo "Bước 1: Cắm cáp OTG từ điện thoại vào bo mạch máy in 3D."
echo "Bước 2: Chạy lệnh sau để cấp quyền USB (Điện thoại sẽ hỏi quyền Root, hãy đồng ý):"
echo "        ./fix_usb_root.sh"
echo ""
echo "Bước 3: Chạy lệnh dưới đây để mở giao diện cài đặt KIAUH:"
echo "        ./kiauh/kiauh.sh"
echo "        (Tại menu KIAUH, chọn 1 -> Cài đặt lần lượt Klipper, Moonraker, Mainsail/Fluidd)"
echo "===================================================="

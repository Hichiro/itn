#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# SCRIPT TỔNG HỢP: SỬA LỖI PKG/APT, CÀI PYTHON MỚI VÀ CẤU HÌNH BỎ QUA SYSTEMD
# Quy định: Gửi toàn bộ script khi phản hồi
# ==============================================================================

set -e # Dừng script nếu có lỗi chí mạng xảy ra

echo "===================================================="
echo " BẮT ĐẦU QUY TRÌNH TỰ ĐỘNG HÓA TỔNG HỢP KLIPPER     "
echo "===================================================="

# ------------------------------------------------------------------------------
# PHẦN 1: TỰ ĐỘNG GỠ LỖI HỆ THỐNG & ĐÓNG KHOÁ PACKAGE
# ------------------------------------------------------------------------------
echo "[1/7] Đang kiểm tra và gỡ lỗi bộ nhớ đệm Termux..."
rm -f /data/data/com.termux/files/usr/var/lib/dpkg/lock-frontend
rm -f /data/data/com.termux/files/usr/var/lib/dpkg/lock
dpkg --configure -a || true
apt-get install -f -y || true
apt-get update -y || true

# ------------------------------------------------------------------------------
# PHẦN 2: CẬP NHẬT HỆ THỐNG & ÉP BUỘC GIỮ CẤU HÌNH CŨ (TRÁNH LỖI STDIN)
# ------------------------------------------------------------------------------
echo "[2/7] Đang nâng cấp hệ thống Termux cốt lõi..."
pkg update -y && pkg upgrade -y -o Dpkg::Options::="--force-confold"

# ------------------------------------------------------------------------------
# PHẦN 3: ÉP CÀI ĐẶT PYTHON MỚI (>3.8) VÀ CÁC CÔNG CỤ CẦN THIẾT
# ------------------------------------------------------------------------------
echo "[3/7] Đang xử lý cài đặt Python và các gói phụ trợ..."
pkg install git tsu coreutils binutils -y -o Dpkg::Options::="--force-confold"

if pkg install python -y -o Dpkg::Options::="--force-confold"; then
    echo "-> Cài đặt Python thành công qua pkg!"
else
    echo "-> Kho mặc định lỗi, đang kích hoạt kho bổ sung tur-repo..."
    pkg install tur-repo -y || true
    pkg install python -y -o Dpkg::Options::="--force-confold" || pkg install python3 -y -o Dpkg::Options::="--force-confold"
fi

# Hiển thị kiểm tra phiên bản Python
PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
echo "-> Phiên bản Python hiện tại hệ thống nhận: $PYTHON_VERSION"

# ------------------------------------------------------------------------------
# PHẦN 4: CẤP QUYỀN TRUY CẬP BỘ NHỚ VÀ TẢI KIAUH
# ------------------------------------------------------------------------------
echo "[4/7] Cấp quyền bộ nhớ và chuẩn bị KIAUH..."
termux-setup-storage || true

cd $HOME
if [ -d "kiauh" ]; then
    cd kiauh && git pull
else
    git clone https://github.com/dw-0/kiauh.git
    cd kiauh
fi
chmod +x kiauh.sh

# ------------------------------------------------------------------------------
# PHẦN 5: TẠO SCRIPT FIX QUYỀN CỔNG USB CHO MÁY IN (YÊU CẦU ROOT)
# ------------------------------------------------------------------------------
echo "[5/7] Tạo script nạp quyền Root cổng USB..."
cat << 'EOF' > $HOME/fix_usb_root.sh
#!/data/data/com.termux/files/usr/bin/bash
echo "Đang yêu cầu quyền Root để mở cổng USB thiết bị..."
tsu -c "
  echo 'Đang quét thiết bị kết nối máy in...'
  if [ -e /dev/ttyUSB* ]; then chmod 666 /dev/ttyUSB*; echo 'Đã mở quyền cổng ttyUSB!'; fi
  if [ -e /dev/ttyACM* ]; then chmod 666 /dev/ttyACM*; echo 'Đã mở quyền cổng ttyACM!'; fi
"
EOF
chmod +x $HOME/fix_usb_root.sh

# ------------------------------------------------------------------------------
# PHẦN 6: TẠO SCRIPT KHỞI ĐỘNG THỦ CÔNG ĐỂ BỎ QUA LỖI SYSTEMD
# ------------------------------------------------------------------------------
echo "[6/7] Thiết lập cấu hình khởi động bỏ qua Systemd..."
KLIPPER_ENV="$HOME/klipper-env/bin/python"
KLIPPER_DIR="$HOME/klipper/klippy/klippy.py"
MOONRAKER_ENV="$HOME/moonraker-env/bin/python"
MOONRAKER_DIR="$HOME/moonraker/moonraker/moonraker.py"
PRINTER_CFG="$HOME/printer_data/config/printer.cfg"
MOONRAKER_CFG="$HOME/printer_data/config/moonraker.conf"
LOG_DIR="$HOME/printer_data/logs"

mkdir -p "$LOG_DIR"

# File chạy Klipper
cat << EOF > $HOME/start_klipper.sh
#!/data/data/com.termux/files/usr/bin/bash
echo "Đang khởi động Klipper (Quyền Root - Không cần Systemd)..."
tsu -c "$KLIPPER_ENV $KLIPPER_DIR $PRINTER_CFG -l $LOG_DIR/klipper.log -a /tmp/klippy_uds" &
echo "Klipper đang chạy ngầm."
EOF
chmod +x $HOME/start_klipper.sh

# File chạy Moonraker
cat << EOF > $HOME/start_moonraker.sh
#!/data/data/com.termux/files/usr/bin/bash
echo "Đang khởi động Moonraker (Không cần Systemd)..."
$MOONRAKER_ENV $MOONRAKER_DIR -c $MOONRAKER_CFG -l $LOG_DIR/moonraker.log &
echo "Moonraker đang chạy ngầm."
EOF
chmod +x $HOME/start_moonraker.sh

# ------------------------------------------------------------------------------
# PHẦN 7: HOÀN THÀNH VÀ HƯỚNG DẪN BƯỚC TIẾP THEO
# ------------------------------------------------------------------------------
echo "===================================================="
echo "      MÔI TRƯỜNG ĐÃ ĐƯỢC CHUẨN BỊ HOÀN HẢO!         "
echo "===================================================="
echo "Bước 1: Mở trình cài đặt KIAUH bằng lệnh:"
echo "        ./kiauh/kiauh.sh"
echo "        (Tiến hành cài đặt Klipper, Moonraker, Mainsail như thường)"
echo "        *Lưu ý: Nếu KIAUH báo lỗi dừng ở bước khởi động dịch vụ (Systemd), "
echo "         bạn cứ bấm Ctrl+C để thoát ra.*"
echo ""
echo "Bước 2: Cắm cáp máy in vào điện thoại rồi chạy lệnh cấp quyền USB:"
echo "        ./fix_usb_root.sh"
echo ""
echo "Bước 3: Khởi động hệ thống máy in bằng 2 lệnh độc lập:"
echo "        ./start_klipper.sh"
echo "        ./start_moonraker.sh"
echo "===================================================="

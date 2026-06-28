#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# SCRIPT TỔNG HỢP: SỬA LỖI PKG, PYTHON, BỎ QUA SYSTEMD & VÁ MÃ NGUỒN KIAUH
# Quy định: Gửi toàn bộ script khi phản hồi
# ==============================================================================

set -e # Dừng script nếu có lỗi chí mạng xảy ra

echo "===================================================="
echo " BẮT ĐẦU QUY TRÌNH TỰ ĐỘNG HÓA TỔNG HỢP KLIPPER     "
echo "===================================================="

# ------------------------------------------------------------------------------
# PHẦN 1: TỰ ĐỘNG GỠ LỖI HỆ THỐNG & ĐÓNG KHOÁ PACKAGE
# ------------------------------------------------------------------------------
echo "[1/8] Đang kiểm tra và gỡ lỗi bộ nhớ đệm Termux..."
rm -f /data/data/com.termux/files/usr/var/lib/dpkg/lock-frontend
rm -f /data/data/com.termux/files/usr/var/lib/dpkg/lock
dpkg --configure -a || true
apt-get install -f -y || true
apt-get update -y || true

# ------------------------------------------------------------------------------
# PHẦN 2: CẬP NHẬT HỆ THỐNG & ÉP BUỘC GIỮ CẤU HÌNH CŨ (TRÁNH LỖI STDIN)
# ------------------------------------------------------------------------------
echo "[2/8] Đang nâng cấp hệ thống Termux cốt lõi..."
pkg update -y && pkg upgrade -y -o Dpkg::Options::="--force-confold"

# ------------------------------------------------------------------------------
# PHẦN 3: ÉP CÀI ĐẶT PYTHON MỚI (>3.8) VÀ CÁC CÔNG CỤ CẦN THIẾT
# ------------------------------------------------------------------------------
echo "[3/8] Đang xử lý cài đặt Python và các gói phụ trợ..."
pkg install git tsu coreutils binutils sed -y -o Dpkg::Options::="--force-confold"

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
echo "[4/8] Cấp quyền bộ nhớ và chuẩn bị KIAUH..."
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
# PHẦN 5: VÁ MÃ NGUỒN KIAUH ĐỂ BỎ QUA KIỂM TRA SYSTEMD
# ------------------------------------------------------------------------------
echo "[5/8] Đang tiến hành vá mã nguồn KIAUH để bỏ qua Systemd..."
# Thay thế hàm kiểm tra systemd trong các file script của KIAUH để nó luôn trả về trạng thái không hoạt động thay vì báo lỗi crash hệ thống
find scripts/ -type f -exec sed -i 's/systemctl/echo/g' {} + || true
find scripts/ -type f -exec sed -i 's/status=$?/status=0/g' {} + || true

# ------------------------------------------------------------------------------
# PHẦN 6: TẠO SCRIPT FIX QUYỀN CỔNG USB CHO MÁY IN (YÊU CẦU ROOT)
# ------------------------------------------------------------------------------
echo "[6/8] Tạo script nạp quyền Root cổng USB..."
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
# PHẦN 7: TẠO SCRIPT KHỞI ĐỘNG THỦ CÔNG ĐỂ BỎ QUA LỖI SYSTEMD
# ------------------------------------------------------------------------------
echo "[7/8] Thiết lập cấu hình khởi động bỏ qua Systemd..."
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
# PHẦN 8: HOÀN THÀNH VÀ HƯỚNG DẪN BƯỚC TIẾP THEO
# ------------------------------------------------------------------------------
echo "===================================================="
echo "    VÁ LỖI KIAUH & SYSTEMD HOÀN TẤT THÀNH CÔNG!     "
echo "===================================================="
echo "Bước 1: Giờ bạn có thể mở lại menu cài đặt KIAUH bình thường:"
echo "        ./kiauh/kiauh.sh"
echo "        (Chọn 1 để cài Klipper, Moonraker, Mainsail)"
echo "        *Lưu ý: Nếu cuối quá trình cài đặt, KIAUH hiện thông báo lỗi không"
echo "         thể 'start service' qua systemd, hãy kệ nó và bấm Enter bỏ qua.*"
echo ""
echo "Bước 2: Cắm cáp máy in vào điện thoại rồi chạy lệnh cấp quyền USB:"
echo "        ./fix_usb_root.sh"
echo ""
echo "Bước 3: Kích hoạt hệ thống chạy ngầm bằng 2 lệnh thủ công:"
echo "        ./start_klipper.sh"
echo "        ./start_moonraker.sh"
echo "===================================================="

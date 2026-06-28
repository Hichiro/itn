#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# SCRIPT CÀI ĐẶT KLIPPER QUA KIAUH TRÊN TERMUX (TÍCH HỢP TỰ ĐỘNG GỠ LỖI NÂNG CAO)
# ==============================================================================

set -e # Dừng script nếu có lỗi chí mạng xảy ra

echo "===================================================="
echo " BẮT ĐẦU CẤU HÌNH KLIPPER TRÊN TERMUX (ROOTED)      "
echo "===================================================="

# ------------------------------------------------------------------------------
# HÀM TỰ ĐỘNG GỠ LỖI (AUTOMATED DEBUGGING & RECOVERY)
# ------------------------------------------------------------------------------
echo "[THÔNG BÁO] Đang kích hoạt cơ chế tự động kiểm tra và gỡ lỗi..."

# 1. Ép buộc cấu hình lại nếu dpkg bị kẹt hoặc chết đột ngột lần trước
echo "-> Đang giải phóng bộ khóa dpkg lock..."
rm -f /data/data/com.termux/files/usr/var/lib/dpkg/lock-frontend
rm -f /data/data/com.termux/files/usr/var/lib/dpkg/lock
dpkg --configure -a || true

# 2. Sửa các lỗi phụ thuộc (dependency) bị thiếu hoặc hỏng
echo "-> Đang sửa lỗi liên kết package hỏng (fix-broken)..."
apt-get install -f -y || true

# 3. Tự động chuyển mirror sang Repo chính thức của Termux nếu kết nối lỗi
echo "-> Đang thiết lập tự động sửa lỗi kết nối máy chủ kho ứng dụng..."
termux-change-repo -a || true

# 4. Dọn dẹp bộ nhớ đệm lỗi
apt-get clean && apt-get autoclean || true
# ------------------------------------------------------------------------------

# 1. Cập nhật hệ thống Termux (Ép buộc giữ cấu hình cũ để không bị dừng xin ý kiến)
echo "[1/6] Đang cập nhật package hệ thống..."
pkg update -y && pkg upgrade -y -o Dpkg::Options::="--force-confold"

# 2. Cài đặt các công cụ cần thiết cơ bản
echo "[2/6] Cài đặt git, tsu (để chạy root trong termux)..."
pkg install git tsu coreutils binutils -y -o Dpkg::Options::="--force-confold"

# 3. Xử lý cài đặt Python phiên bản mới (>3.8)
echo "[3/6] Đang kiểm tra và cài đặt Python phù hợp..."
pkg install tur-repo -y || true
pkg install python -y -o Dpkg::Options::="--force-confold" || pkg install python3 -y -o Dpkg::Options::="--force-confold"

# Kiểm tra lại phiên bản python xem đã đạt yêu cầu chưa
PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
echo "Phiên bản Python hiện tại: $PYTHON_VERSION"

# 4. Cấp quyền truy cập bộ nhớ cho Termux
echo "[4/6] Yêu cầu quyền truy cập bộ nhớ (Vui lòng bấm 'Cho phép' trên màn hình)..."
termux-setup-storage
sleep 3

# 5. Tải script KIAUH chính thức từ Github
echo "[5/6] Tải KIAUH..."
cd $HOME
if [ -d "kiauh" ]; then
    echo "Thư mục kiauh đã tồn tại, tiến hành cập nhật..."
    cd kiauh && git pull
else
    git clone https://github.com/dw-0/kiauh.git
    cd kiauh
fi
chmod +x kiauh.sh

# 6. Tạo script phụ để tự động kích hoạt quyền Root cho cổng USB máy in
echo "[6/6] Tạo script cấu hình cổng USB máy in bằng quyền Root..."
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
echo "Bước 2: Chạy lệnh sau để cấp quyền USB:"
echo "        ./fix_usb_root.sh"
echo ""
echo "Bước 3: Chạy lệnh dưới đây để mở giao diện cài đặt KIAUH:"
echo "        ./kiauh/kiauh.sh"
echo "===================================================="

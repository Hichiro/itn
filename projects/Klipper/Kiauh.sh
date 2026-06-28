#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# SCRIPT TỔNG HỢP: KHỞI TẠO DEBIAN PROOT, CHECK OS ĐÃ CÀI & BYPASS CHECK ROOT KIAUH
# Quy định: Gửi toàn bộ script khi phản hồi
# ==============================================================================

set -e

echo "===================================================="
echo " BẮT ĐẦU CÀI ĐẶT CƠ CHẾ LINUX VÀ SỬA TRIỆT ĐỂ LỖI ROOT"
echo "===================================================="

# 1. Gỡ lỗi package lock nền nếu có
rm -f /data/data/com.termux/files/usr/var/lib/dpkg/lock-frontend || true
dpkg --configure -a || true

# 2. Cập nhật và cài đặt công cụ ảo hóa proot-distro từ Termux gốc
echo "[1/5] Đang thiết lập Termux gốc..."
pkg update -y && pkg upgrade -y -o Dpkg::Options::="--force-confold"
pkg install proot-distro tsu git coreutils -y -o Dpkg::Options::="--force-confold"

# 3. KIỂM TRA TỰ ĐỘNG: Bỏ qua nếu OS Debian đã được cài đặt
echo "[2/5] Đang kiểm tra trạng thái cài đặt hệ điều hành..."
if proot-distro list | grep -q "installed.*debian"; then
    echo "-> [TỰ ĐỘNG BỎ QUA] Hệ điều hành Debian đã được cài đặt sẵn từ trước. Tiến hành cấu hình phần mềm..."
else
    echo "-> Chưa phát hiện Debian. Tiến hành tải và cài đặt Debian container sạch..."
    proot-distro install debian
fi

# 4. Truy cập vào Debian để cài đặt Python, KIAUH và áp dụng bản vá Root tối cao
echo "[3/5] Đang cấu hình và vô hiệu hóa cơ chế chặn Root của KIAUH..."
proot-distro login debian -- bash -c "
  apt-get update && apt-get upgrade -y
  apt-get install python3 python3-pip python3-venv git curl sudo sed -y
  
  cd /root
  if [ -d 'kiauh' ]; then
      cd kiauh && git pull
  else
      git clone https://github.com/dw-0/kiauh.git
  fi
  chmod +x kiauh/kiauh.sh

  # Vá lỗi check systemd của KIAUH
  find kiauh/scripts/ -type f -exec sed -i 's/systemctl/echo/g' {} + || true
  find kiauh/scripts/ -type f -exec sed -i 's/status=\$?/status=0/g' {} + || true

  # BẢN VÁ TỐI CAO: Định nghĩa lại hàm id() ở đầu file kiauh.sh để luôn trả về UID bằng 1000 (Không phải root)
  # Nhằm vượt qua hoàn toàn bộ lọc chặn root của KIAUH
  if ! grep -q 'id() {' kiauh/kiauh.sh; then
      sed -i '2i id() { echo 1000; }' kiauh/kiauh.sh
  fi
"

# 5. Tạo script nạp quyền truy cập cổng USB từ Android gốc vào Debian (Yêu cầu Root Magisk/KernelSU)
echo "[4/5] Tạo script cấu hình cổng USB bằng quyền siêu người dùng (Root)..."
cat << 'EOF' > $HOME/fix_usb_root.sh
#!/data/data/com.termux/files/usr/bin/bash
echo "Đang yêu cầu hệ thống Android cấp quyền Superuser (Root)..."
tsu -c "
  echo 'Đang giải phóng và gán quyền đọc/ghi cho cổng kết nối OTG...'
  if [ -e /dev/ttyUSB* ]; then 
    chmod 666 /dev/ttyUSB*
    echo '-> Đã mở quyền thành công cho cổng ttyUSB!'
  fi
  if [ -e /dev/ttyACM* ]; then 
    chmod 666 /dev/ttyACM*
    echo '-> Đã mở quyền thành công cho cổng ttyACM!'
  fi
"
EOF
chmod +x $HOME/fix_usb_root.sh

# 6. Tạo cổng khởi động nhanh cho các dịch vụ nền Klipper/Moonraker chạy trực tiếp với quyền root
echo "[5/5] Cấu hình script chạy dịch vụ Klipper bằng quyền Root liên kết..."
cat << 'EOF' > $HOME/start_klipper_services.sh
#!/data/data/com.termux/files/usr/bin/bash
echo "Đang kích hoạt Klipper và Moonraker chạy ngầm dưới quyền Root..."

tsu -c "proot-distro login debian -- bash -c \"
  echo 'Khởi động Klipper daemon...'
  /root/klipper-env/bin/python /root/klipper/klippy/klippy.py /root/printer_data/config/printer.cfg -l /root/printer_data/logs/klipper.log -a /tmp/klippy_uds &
  sleep 2
  echo 'Khởi động Moonraker daemon...'
  /root/moonraker-env/bin/python /root/moonraker/moonraker/moonraker.py -c /root/printer_data/config/moonraker.conf -l /root/printer_data/logs/moonraker.log &
\"" &

echo "===================================================="
echo "Các tiến trình Klipper đã được nạp thẳng vào Root hệ thống!"
echo "===================================================="
EOF
chmod +x $HOME/start_klipper_services.sh

# Tạo lối tắt để vào thẳng giao diện KIAUH của Debian khi cài đặt (kèm giả lập biến USER)
cat << 'EOF' > $HOME/run_kiauh.sh
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login debian -- bash -c "export USER=klipper; cd /root/kiauh && ./kiauh.sh"
EOF
chmod +x $HOME/run_kiauh.sh

echo "===================================================="
echo "        CẤU HÌNH MÔI TRƯỜNG DEBIAN HOÀN TẤT!         "
echo "===================================================="
echo "Bước 1: Chạy lệnh mở trình cài đặt KIAUH (Không còn lỗi chặn root):"
echo "        ./run_kiauh.sh"
echo ""
echo "Bước 2: Cắm cáp máy in vào điện thoại rồi chạy lệnh cấp quyền USB:"
echo "        ./fix_usb_root.sh"
echo ""
echo "Bước 3: Khởi động hệ thống Klipper bằng quyền Root:"
echo "        ./start_klipper_services.sh"
echo "===================================================="

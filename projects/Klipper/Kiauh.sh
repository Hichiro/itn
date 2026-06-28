#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# SCRIPT TỔNG HỢP: KHỞI TẠO KLIPPER TRÊN MÔI TRƯỜNG DEBIAN PROOT
# Quy định: Gửi toàn bộ script khi phản hồi
# ==============================================================================

set -e

echo "===================================================="
echo " BẮT ĐẦU CÀI ĐẶT CƠ CHẾ LINUX ỔN ĐỊNH VỚI DEBIAN     "
echo "===================================================="

# 1. Gỡ lỗi package lock nền nếu có
rm -f /data/data/com.termux/files/usr/var/lib/dpkg/lock-frontend || true
dpkg --configure -a || true

# 2. Cập nhật và cài đặt công cụ ảo hóa proot-distro từ Termux gốc
echo "[1/5] Đang thiết lập Termux gốc..."
pkg update -y && pkg upgrade -y -o Dpkg::Options::="--force-confold"
pkg install proot-distro tsu git coreutils -y -o Dpkg::Options::="--force-confold"

# 3. Tạo và cài đặt môi trường Linux Debian
echo "[2/5] Đang khởi tạo container Debian sạch để chạy Klipper..."
if proot-distro list | grep -q "installed.*debian"; then
    echo "-> Debian container đã được cài đặt sẵn."
else
    proot-distro install debian
fi

# 4. Truy cập vào Debian để cài đặt Python, KIAUH và toàn bộ công cụ nền
echo "[3/5] Đang nạp các package cần thiết, Python mới và KIAUH vào Debian..."
proot-distro login debian -- bash -c "
  apt-get update && apt-get upgrade -y
  # Cài thêm sudo vì Debian gốc không đi kèm sudo, cần thiết cho KIAUH chạy lệnh
  apt-get install python3 python3-pip python3-venv git curl sudo sed -y
  
  # Tạo thư mục và clone KIAUH bên trong Debian
  cd /root
  if [ -d 'kiauh' ]; then
      cd kiauh && git pull
  else
      git clone https://github.com/dw-0/kiauh.git
  fi
  chmod +x kiauh/kiauh.sh

  # Vá lỗi systemd của KIAUH ngay bên trong Debian
  find kiauh/scripts/ -type f -exec sed -i 's/systemctl/echo/g' {} + || true
  find kiauh/scripts/ -type f -exec sed -i 's/status=\$?/status=0/g' {} + || true
"

# 5. Tạo script nạp quyền truy cập cổng USB từ Android gốc vào Debian (Yêu cầu Root)
echo "[4/5] Tạo script cấu hình cổng USB chuyển tiếp thiết bị..."
cat << 'EOF' > $HOME/fix_usb_root.sh
#!/data/data/com.termux/files/usr/bin/bash
echo "Đang yêu cầu quyền Root để giải phóng cổng USB..."
tsu -c "
  if [ -e /dev/ttyUSB* ]; then chmod 666 /dev/ttyUSB*; echo 'Đã mở quyền cổng ttyUSB!'; fi
  if [ -e /dev/ttyACM* ]; then chmod 666 /dev/ttyACM*; echo 'Đã mở quyền cổng ttyACM!'; fi
"
EOF
chmod +x $HOME/fix_usb_root.sh

# 6. Tạo cổng khởi động nhanh cho các dịch vụ nền Klipper/Moonraker thủ công
echo "[5/5] Cấu hình script khởi tạo dịch vụ Klipper..."
cat << 'EOF' > $HOME/start_klipper_services.sh
#!/data/data/com.termux/files/usr/bin/bash
echo "Kích hoạt cụm dịch vụ Klipper thông qua môi trường ảo hóa Debian..."

# Lệnh khởi chạy ngầm Klipper và Moonraker bên trong không gian Debian proot
proot-distro login debian -- bash -c "
  echo 'Đang khởi động Klipper daemon...'
  /root/klipper-env/bin/python /root/klipper/klippy/klippy.py /root/printer_data/config/printer.cfg -l /root/printer_data/logs/klipper.log -a /tmp/klippy_uds" &
  sleep 2
  echo 'Đang khởi động Moonraker daemon...'
  /root/moonraker-env/bin/python /root/moonraker/moonraker/moonraker.py -c /root/printer_data/config/moonraker.conf -l /root/printer_data/logs/moonraker.log &
"
echo "Các tiến trình đã được nạp vào nền Debian thành công!"
EOF
chmod +x $HOME/start_klipper_services.sh

# Tạo lối tắt để vào thẳng giao diện KIAUH của Debian khi cài đặt
cat << 'EOF' > $HOME/run_kiauh.sh
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login debian -- bash -c "cd /root/kiauh && ./kiauh.sh"
EOF
chmod +x $HOME/run_kiauh.sh

echo "===================================================="
echo "        CẤU HÌNH MÔI TRƯỜNG DEBIAN HOÀN TẤT!         "
echo "===================================================="
echo "Bước 1: Chạy script kích hoạt KIAUH trên Debian:"
echo "        ./run_kiauh.sh"
echo ""
echo "Bước 2: Cắm cáp OTG nối máy in và chạy lệnh nạp quyền USB:"
echo "        ./fix_usb_root.sh"
echo ""
echo "Bước 3: Chạy cụm dịch vụ máy in 3D ngầm:"
echo "        ./start_klipper_services.sh"
echo "===================================================="

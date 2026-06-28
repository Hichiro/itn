#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# SCRIPT KHẮC PHỤC LỖI SYSTEMD VÀ KHỞI ĐỘNG KLIPPER THỦ CÔNG (ROOTED)
# Quy định: Gửi toàn bộ script
# ==============================================================================

set -e

echo "===================================================="
echo " ĐANG XỬ LÝ LỖI SYSTEMD TRÊN TERMUX...               "
echo "===================================================="

# 1. Định nghĩa các đường dẫn mặc định của Klipper sau khi cài bằng KIAUH
KLIPPER_ENV="$HOME/klipper-env/bin/python"
KLIPPER_DIR="$HOME/klipper/klippy/klippy.py"
MOONRAKER_ENV="$HOME/moonraker-env/bin/python"
MOONRAKER_DIR="$HOME/moonraker/moonraker/moonraker.py"

# Thư mục chứa cấu hình máy in (mặc định của KIAUH)
PRINTER_CFG="$HOME/printer_data/config/printer.cfg"
MOONRAKER_CFG="$HOME/printer_data/config/moonraker.conf"
LOG_DIR="$HOME/printer_data/logs"

# Tạo thư mục log nếu chưa có
mkdir -p "$LOG_DIR"

# 2. Tạo script khởi động Klipper thủ công bỏ qua Systemd
echo "[1/2] Đang tạo script khởi động Klipper độc lập..."
cat << EOF > $HOME/start_klipper.sh
#!/data/data/com.termux/files/usr/bin/bash
echo "Đang khởi động Klipper ngầm (Bỏ qua systemd)..."

# Chạy Klipper bằng quyền root để có thể giao tiếp trực tiếp với cổng USB OTG
tsu -c "$KLIPPER_ENV $KLIPPER_DIR $PRINTER_CFG -l $LOG_DIR/klipper.log -a /tmp/klippy_uds" &

echo "Klipper đã được kích hoạt trong nền."
EOF
chmod +x $HOME/start_klipper.sh

# 3. Tạo script khởi động Moonraker thủ công bỏ qua Systemd
echo "[2/2] Đang tạo script khởi động Moonraker độc lập..."
cat << EOF > $HOME/start_moonraker.sh
#!/data/data/com.termux/files/usr/bin/bash
echo "Đang khởi động Moonraker ngầm (Bỏ qua systemd)..."

# Chạy Moonraker kết nối với Klipper
$MOONRAKER_ENV $MOONRAKER_DIR -c $MOONRAKER_CFG -l $LOG_DIR/moonraker.log &

echo "Moonraker đã được kích hoạt trong nền."
EOF
chmod +x $HOME/start_moonraker.sh

echo "===================================================="
echo " ĐÃ CẤU HÌNH XONG GIẢI PHÁP THAY THẾ SYSTEMD!        "
echo "===================================================="
echo "Kể từ bây giờ, mỗi khi mở Termux lên để chạy máy in,"
echo "bạn chỉ cần chạy 2 lệnh này thay vì dùng systemctl:"
echo ""
echo "  1. Khởi động Klipper:   ./start_klipper.sh"
echo "  2. Khởi động Moonraker: ./start_moonraker.sh"
echo "===================================================="

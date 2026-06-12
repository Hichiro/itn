#!/bin/bash

# ==============================================================================
# SCRIPT TỰ ĐỘNG CÀI ĐẶT MÔI TRƯỜNG PICOCLAW TRÊN GOOGLE CLOUD (DEBIAN)
# (Phiên bản: Tự động cấu hình SWAP 2GB + Tối ưu hóa ổ đĩa)
# ==============================================================================

# Định nghĩa các biến cấu hình
PORT=18800
INSTALL_DIR="$HOME/picoclaw"

# Định dạng màu sắc hiển thị cho Log
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== BẮT ĐẦU QUÁ TRÌNH CÀI ĐẶT MÔI TRƯỜNG PICOCLAW TRÊN DEBIAN ===${NC}"

# Kiểm tra quyền root/sudo
if [ "$EUID" -ne 0 ] && ! command -v sudo &> /dev/null; then
    echo -e "${YELLOW}Cảnh báo: Không tìm thấy lệnh 'sudo'. Đang cố gắng cài đặt sudo bằng quyền root...${NC}"
    echo "Vui lòng nhập mật khẩu root nếu được yêu cầu:"
    su -c "apt update && apt install sudo -y" || { echo "Không thể cài đặt sudo. Vui lòng chạy script này bằng quyền root."; exit 1; }
fi

# 1. Tự động cấu hình bộ nhớ RAM ảo (SWAP) 2GB
echo -e "${YELLOW}[1/6] Đang cấu hình bộ nhớ ảo SWAP 2GB cho hệ thống...${NC}"
if [ -f /swapfile ]; then
    echo -e "${GREEN}Hệ thống đã có SWAP, bỏ qua bước này.${NC}"
else
    sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    # Tối ưu độ nhạy SWAP (chỉ dùng khi thực sự thiếu RAM vật lý)
    sudo sysctl vm.swappiness=10
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    echo -e "${GREEN}Cấu hình SWAP thành công!${NC}"
fi

# 2. Cập nhật hệ thống và cài đặt các gói phụ trợ cho Debian
echo -e "${YELLOW}[2/6] Đang cập nhật hệ thống và cài đặt phụ kiện cho Debian...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install wget curl git unzip screen ufw -y

# 3. Cấu hình tường lửa cục bộ (UFW)
echo -e "${YELLOW}[3/6] Đang cấu hình tường lửa UFW mở cổng $PORT...${NC}"
sudo ufw allow $PORT/tcp
sudo ufw --force enable

# 4. Tạo cấu trúc thư mục ứng dụng
echo -e "${YELLOW}[4/6] Đang khởi tạo cấu trúc thư mục PicoClaw...${NC}"
mkdir -p "$INSTALL_DIR/Data/.picoclaw"
cd "$INSTALL_DIR"

# Tạo file chạy giả lập/đại diện nếu chưa có file binary chính thức
if [ ! -f "picoclaw-launcher" ]; then
    touch picoclaw-launcher
    chmod +x picoclaw-launcher
fi

# 5. Tạo script khởi chạy nhanh ứng dụng trong Screen ẩn
echo -e "${YELLOW}[5/6] Đang tạo lệnh khởi chạy tự động...${NC}"
cat <<EOF > start_agent.sh
#!/bin/bash
echo "Đang kích hoạt PicoClaw trong màn hình ngầm (Screen)..."
screen -dmS picoclaw_session ./picoclaw-launcher -host 0.0.0.0 -port $PORT -console
echo "Kích hoạt thành công!"
echo "Sử dụng lệnh: 'screen -r picoclaw_session' để xem log hệ thống."
EOF
chmod +x start_agent.sh

# 6. Dọn dẹp dung lượng hệ thống để tối ưu ổ đĩa 10GB
echo -e "${YELLOW}[6/6] Đang dọn dẹp các gói cài đặt thừa để tối ưu ổ cứng...${NC}"
sudo apt-get autoremove -y && sudo apt-get autoclean -y && sudo apt-get clean -y
sudo journalctl --vacuum-size=50M

echo -e "${GREEN}=== CÀI ĐẶT MÔI TRƯỜNG HOÀN TẤT ===${NC}"
echo -e "${BLUE}Thư mục ứng dụng:${NC} $INSTALL_DIR"
echo -e "${BLUE}Cổng dịch vụ mở sẵn:${NC} $PORT"
echo -e "${YELLOW}HƯỚNG DẪN TIẾP THEO:${NC}"
echo -e "1. Hãy tự tạo hoặc tải file cấu hình của bạn vào thư mục:"
echo -e "   $INSTALL_DIR/Data/.picoclaw/"
echo -e "2. Sau đó chạy lệnh './start_agent.sh' để kích hoạt ứng dụng."

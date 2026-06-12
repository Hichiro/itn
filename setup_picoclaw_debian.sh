#!/bin/bash

# ==============================================================================
# SCRIPT TỰ ĐỘNG CÀI ĐẶT MÔI TRƯỜNG PICOCLAW TRÊN GOOGLE CLOUD (DEBIAN)
# (Phiên bản: Không tự động tạo file cấu hình)
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

# 1. Cập nhật hệ thống và cài đặt các gói phụ trợ cho Debian
echo -e "${YELLOW}[1/4] Đang cập nhật hệ thống và cài đặt phụ kiện cho Debian...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install wget curl git unzip screen ufw -y

# 2. Cấu hình tường lửa cục bộ (UFW)
echo -e "${YELLOW}[2/4] Đang cấu hình tường lửa UFW mở cổng $PORT...${NC}"
sudo ufw allow $PORT/tcp
sudo ufw --force enable

# 3. Tạo cấu trúc thư mục ứng dụng
echo -e "${YELLOW}[3/4] Đang khởi tạo cấu trúc thư mục PicoClaw...${NC}"
mkdir -p "$INSTALL_DIR/Data/.picoclaw"
cd "$INSTALL_DIR"

# Tạo file chạy giả lập/đại diện nếu chưa có file binary chính thức
if [ ! -f "picoclaw-launcher" ]; then
    touch picoclaw-launcher
    chmod +x picoclaw-launcher
fi

# 4. Tạo script khởi chạy nhanh ứng dụng trong Screen ẩn
echo -e "${YELLOW}[4/4] Đang tạo lệnh khởi chạy tự động...${NC}"
cat <<EOF > start_agent.sh
#!/bin/bash
echo "Đang kích hoạt PicoClaw trong màn hình ngầm (Screen)..."
screen -dmS picoclaw_session ./picoclaw-launcher -host 0.0.0.0 -port $PORT -console
echo "Kích hoạt thành công!"
echo "Sử dụng lệnh: 'screen -r picoclaw_session' để xem log hệ thống."
EOF
chmod +x start_agent.sh

echo -e "${GREEN}=== CÀI ĐẶT MÔI TRƯỜNG HOÀN TẤT ===${NC}"
echo -e "${BLUE}Thư mục ứng dụng:${NC} $INSTALL_DIR"
echo -e "${BLUE}Cổng dịch vụ mở sẵn:${NC} $PORT"
echo -e "${YELLOW}HƯỚNG DẪN TIẾP THEO:${NC}"
echo -e "1. Hãy tự tạo hoặc tải file cấu hình của bạn vào thư mục:"
echo -e "   $INSTALL_DIR/Data/.picoclaw/"
echo -e "2. Sau đó chạy lệnh './start_agent.sh' để kích hoạt ứng dụng."

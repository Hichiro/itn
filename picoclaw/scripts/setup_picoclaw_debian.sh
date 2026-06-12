#!/bin/bash

# ==============================================================================
# SCRIPT PICOCLAW TỐI ƯU CHO GOOGLE CLOUD FREE TIER (DEBIAN - 1GB RAM)
# (Phiên bản ẩn: Không tạo file cấu hình - Tự động bật SWAP chống treo máy)
# ==============================================================================

PORT=18800
INSTALL_DIR="$HOME/picoclaw"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== BẮT ĐẦU CÀI ĐẶT TỐI ƯU CHO VPS FREE TIER ===${NC}"

# Kiểm tra quyền sudo/root
if [ "$EUID" -ne 0 ] && ! command -v sudo &> /dev/null; then
    echo "Vui lòng nhập mật khẩu root để cấu hình hệ thống:"
    su -c "apt update && apt install sudo -y" || { echo "Lỗi: Cần quyền root."; exit 1; }
fi

# 1. TẠO RAM ẢO (SWAP 2GB) - BẮT BUỘC CHO MÁY 1GB RAM ĐỂ CHỐNG SẬP
if [ [ $(sudo swapon --show | wc -l) -eq 0 ]]; then
    echo -e "${YELLOW}[1/5] Khởi tạo 2GB RAM ảo (Swapfile) giúp máy không bị treo...${NC}"
    sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo -e "${GREEN}-> Đã bật Swap 2GB thành công.${NC}"
else
    echo -e "${GREEN}[1/5] Hệ thống đã có RAM ảo (Swap). Bỏ qua...${NC}"
fi

# 2. CẬP NHẬT & CÀI ĐẶT GÓI PHỤ TRỢ MINIMAL (RÚT GỌN)
echo -e "${YELLOW}[2/5] Cập nhật hệ thống tối giản...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install wget curl git unzip screen ufw -y
sudo apt clean # Dọn dẹp bộ đệm bộ cài đặt ngay lập tức để tiết kiệm đĩa

# 3. CẤU HÌNH TƯỜNG LỬA CỤC BỘ
echo -e "${YELLOW}[3/5] Mở cổng tường lửa nội bộ $PORT...${NC}"
sudo ufw allow $PORT/tcp
sudo ufw --force enable

# 4. KHỞI TẠO THƯ MỤC ẨN TRONG $HOME
echo -e "${YELLOW}[4/5] Tạo thư mục ẩn $INSTALL_DIR...${NC}"
mkdir -p "$INSTALL_DIR/Data/.picoclaw"
cd "$INSTALL_DIR"

# Tạo file binary giả lập nếu chưa có sẵn file thật
if [ ! -f "picoclaw-launcher" ]; then
    touch picoclaw-launcher
    chmod +x picoclaw-launcher
fi

# 5. TẠO SCRIPT KHỞI CHẠY TIẾT KIỆM TÀI NGUYÊN
echo -e "${YELLOW}[5/5] Tạo lệnh khởi chạy start_agent.sh...${NC}"
cat <<EOF > start_agent.sh
#!/bin/bash
# Kiểm tra nếu file chạy thực tế tồn tại và có dung lượng > 0
if [ ! -s "./picoclaw-launcher" ]; then
    echo "Lỗi: File 'picoclaw-launcher' đang trống hoặc chưa được thay thế bằng file binary thật."
    echo "Vui lòng copy file chạy của bạn vào thư mục: $INSTALL_DIR trước."
    exit 1
fi

echo "Đang kích hoạt PicoClaw chạy ẩn trong Screen..."
screen -dmS picoclaw_session ./picoclaw-launcher -host 0.0.0.0 -port $PORT -console
echo "Kích hoạt thành công!"
echo "Xem log bằng lệnh: 'screen -r picoclaw_session'"
EOF
chmod +x start_agent.sh

echo -e "${GREEN}=== CÀI ĐẶT HOÀN TẤT (ĐÃ TỐI ƯU CẤU HÌNH YẾU) ===${NC}"
echo -e "${BLUE}Thư mục ứng dụng ẩn:${NC} $INSTALL_DIR"
echo -e "${BLUE}Cổng mở sẵn:${NC} $PORT"
echo -e "${YELLOW}Khuyên dùng:${NC} Nhớ cấu hình Target Tag ngoài trang GCP Console cho cổng $PORT."

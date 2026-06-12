#!/bin/bash

# ==============================================================================
# SCRIPT PICOCLAW TỐI ƯU CHO GOOGLE CLOUD (DEBIAN) - SỬA LỖI PERMISSION & SYSTEMD
# (Tự động tính SWAP theo RAM - Không tạo config - Chạy ngầm Systemd)
# ==============================================================================

PORT=18800
INSTALL_DIR="$HOME/picoclaw"
CURRENT_USER=$USER

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== BẮT ĐẦU CÀI ĐẶT TỐI ƯU HỆ THỐNG ===${NC}"

# Kiểm tra quyền sudo/root
if [ "$EUID" -ne 0 ] && ! command -v sudo &> /dev/null; then
    echo "Vui lòng nhập mật khẩu root để cấu hình hệ thống:"
    su -c "apt update && apt install sudo -y" || { echo "Lỗi: Cần quyền root."; exit 1; }
fi

# 1. TỰ ĐỘNG TÍNH TOÁN VÀ CẤU HÌNH RAM ẢO (SWAP) THEO RAM THỰC TẾ
HAS_SWAP=$(sudo swapon --show | wc -l)
if [ "$HAS_SWAP" -eq 0 ]; then
    # Lấy tổng dung lượng RAM thực tế (đơn vị MB)
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    echo -e "${BLUE}Phát hiện RAM vật lý của hệ thống:${NC} ${TOTAL_RAM} MB"

    # Tính toán dung lượng SWAP tối ưu (đơn vị MB)
    if [ "$TOTAL_RAM" -le 2048 ]; then
        SWAP_SIZE=$((TOTAL_RAM * 2))
    elif [ "$TOTAL_RAM" -gt 2048 ] && [ "$TOTAL_RAM" -le 8192 ]; then
        SWAP_SIZE=$TOTAL_RAM
    else
        SWAP_SIZE=4096
    fi

    echo -e "${YELLOW}[1/5] Đang khởi tạo ${SWAP_SIZE}MB RAM ảo (Swapfile) tự động...${NC}"
    
    sudo dd if=/dev/zero of=/swapfile bs=1M count=$SWAP_SIZE status=progress
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo -e "${GREEN}-> Đã bật Swap ${SWAP_SIZE}MB thành công.${NC}"
else
    echo -e "${GREEN}[1/5] Hệ thống đã có RAM ảo (Swap). Bỏ qua bước này...${NC}"
fi

# 2. CẬP NHẬT & CÀI ĐẶT GÓI PHỤ TRỢ MINIMAL (RÚT GỌN)
echo -e "${YELLOW}[2/5] Cập nhật hệ thống tối giản...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install wget curl git unzip ufw -y
sudo apt clean 

# 3. CẤU HÌNH TƯỜNG LỬA CỤC BỘ
echo -e "${YELLOW}[3/5] Mở cổng tường lửa nội bộ $PORT...${NC}"
sudo ufw allow $PORT/tcp
sudo ufw --force enable

# 4. KHỞI TẠO THƯ MỤC ẨN TRONG $HOME
echo -e "${YELLOW}[4/5] Tạo thư mục ẩn $INSTALL_DIR...${NC}"
mkdir -p "$INSTALL_DIR/Data/.picoclaw"
cd "$INSTALL_DIR"

if [ ! -f "picoclaw-launcher" ]; then
    touch picoclaw-launcher
    chmod +x picoclaw-launcher
fi

# 5. CẤU HÌNH TỰ KHỞI ĐỘNG CÙNG HỆ THỐNG (SỬ DỤNG TEE ĐỂ TRÁNH LỖI PERMISSION DENIED)
echo -e "${YELLOW}[5/5] Đang cấu hình Systemd Service tự khởi động...${NC}"
sudo tee /etc/systemd/system/picoclaw.service > /dev/null <<EOF
[Unit]
Description=PicoClaw Agent Service
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/picoclaw-launcher -host 0.0.0.0 -port $PORT -console
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Nạp lại cấu hình dịch vụ hệ thống và kích hoạt
sudo systemctl daemon-reload
sudo systemctl enable picoclaw.service

echo -e "${GREEN}=== CÀI ĐẶT HOÀN TẤT VÀ SỬA LỖI SYSTEMD THÀNH CÔNG ===${NC}"
echo -e "${BLUE}Thư mục ứng dụng ẩn:${NC} $INSTALL_DIR"
echo -e "${BLUE}Cổng mở sẵn:${NC} $PORT"
echo -e "${YELLOW}HƯỚNG DẪN TIẾP THEO:${NC}"
echo -e "Hãy nạp file cấu hình và file chạy của bạn vào rồi gõ lệnh: ${GREEN}sudo systemctl start picoclaw${NC}"

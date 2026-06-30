#!/bin/bash

# ================================================
# OmniRoute Docker Installer - Optimized Version
# ================================================

# Màu sắc để dễ theo dõi
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

APP_DIR="$HOME/omniroute"
DATA_DIR="$HOME/omniroute-data"

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   CÀI ĐẶT OMNIROUTE DOCKER (v2.0)        ${NC}"
echo -e "${GREEN}=========================================${NC}"

# 1. Hàm kiểm tra công cụ hệ thống
check_dependencies() {
    for cmd in curl openssl docker docker-compose; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}❌ Lỗi: Máy bạn chưa cài $cmd. Vui lòng cài đặt trước khi chạy script.${NC}"
            exit 1
        fi
    done
}

# 2. Hàm đọc input an toàn (Hỗ trợ cả chạy tự động)
safe_read() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"

    if [ ! -t 0 ]; then
        # Nếu không có terminal (non-interactive), dùng giá trị mặc định
        eval "$var_name=\"$default\""
    else
        # Nếu có terminal, cho phép người dùng nhập
        read -p "$prompt [$default]: " input
        eval "$var_name=\"${input:-$default}\""
    fi
}

# Bắt đầu thực hiện
check_dependencies

# Tạo thư mục
mkdir -p "$APP_DIR"
mkdir -p "$DATA_DIR"
chmod -R 777 "$DATA_DIR" # Tránh lỗi Permission denied cho Docker
cd "$APP_DIR"

# 3. Xử lý container cũ
if docker ps -a --format '{{.Names}}' | grep -q "^omniroute$"; then
    echo -e "${YELLOW}⚠️ Phát hiện container omniroute cũ đang tồn tại.${NC}"
    safe_read "Bạn có muốn xóa container cũ để cài mới không?" "Y" confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "🗑️ Đang dọn dẹp container cũ..."
        docker compose down 2>/dev/null || true
        docker rm -f omniroute 2>/dev/null || true
    else
        echo -e "${RED}⛔ Đã hủy cài đặt theo yêu cầu.${NC}"
        exit 0
    fi
fi

# 4. Tạo file docker-compose.yml
echo "--> Đang tạo cấu hình docker-compose.yml..."
cat > docker-compose.yml <<EOF
services:
  omniroute:
    image: diegosouzapw/omniroute:latest
    container_name: omniroute
    restart: unless-stopped
    stop_grace_period: 40s
    ports:
      - "20128:20128"
    volumes:
      - $DATA_DIR:/app/data
    env_file:
      - .env
EOF

# 5. Xử lý file .env và Secret Keys
if [ ! -f .env ]; then
    echo "--> Đang tải file .env mẫu từ GitHub..."
    if curl -fsSL https://raw.githubusercontent.com/diegosouzapw/OmniRoute/main/.env.example -o .env; then
        echo -e "${GREEN}✅ Tải file .env thành công.${NC}"
    else
        echo -e "${YELLOW}⚠️ Không thể tải file .env, đang tạo file tạm thời...${NC}"
        echo "JWT_SECRET=" > .env
        echo "API_KEY_SECRET=" >> .env
        echo "INITIAL_PASSWORD=admin123" >> .env
    fi
fi

# Kiểm tra và điền Secret keys nếu còn trống
if ! grep -q "^JWT_SECRET=.\+" .env || ! grep -q "^API_KEY_SECRET=.\+" .env; then
    echo "--> Đang tạo ngẫu nhiên JWT_SECRET và API_KEY_SECRET..."
    
    # Tạo secret bằng openssl, nếu lỗi thì dùng date
    JWT_S=$(openssl rand -base64 48 2>/dev/null || echo "jwt-$(date +%s%N)")
    API_S=$(openssl rand -hex 32 2>/dev/null || echo "api-$(date +%s%N)")
    
    # Sử dụng dấu | làm phân cách cho sed để tránh lỗi nếu secret có chứa dấu /
    sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$JWT_S|" .env
    sed -i "s|^API_KEY_SECRET=.*|API_KEY_SECRET=$API_S|" .env
    echo -e "${GREEN}✅ Đã hoàn thiện các mã bảo mật.${NC}"
fi

# Thông báo cho người dùng
echo -e "${YELLOW}⚠️ Lưu ý: Bạn có thể thay đổi mật khẩu khởi tạo trong file $APP_DIR/.env${NC}"
if [ -t 0 ]; then
    safe_read "Nhấn Enter để tiếp tục khởi chạy..." "" dummy
fi

# 6. Khởi chạy Docker
echo "--> Đang khởi chạy OmniRoute..."
if docker compose up -d; then
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}         CÀI ĐẶT THÀNH CÔNG!             ${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo -e "📂 Thư mục cài đặt : $APP_DIR"
    echo -e "📂 Data lưu tại    : $DATA_DIR"
    echo -e "🌐 Truy cập        : http://$(curl -s ifconfig.me || echo "localhost"):20128"
    echo -e "📜 Kiểm tra log    : cd $APP_DIR && docker compose logs -f"
else
    echo -e "${RED}❌ Có lỗi xảy ra khi khởi chạy Docker. Vui lòng kiểm tra 'docker compose logs'.${NC}"
    exit 1
fi

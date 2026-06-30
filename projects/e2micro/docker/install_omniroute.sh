#!/bin/bash
# ================================================
# OmniRoute Docker Installer - Tối ưu (Data user + Secret)
# ================================================

set -e

APP_DIR="$HOME/omniroute"
DATA_DIR="$HOME/omniroute-data"

echo "========================================="
echo " CÀI ĐẶT OMNIROUTE DOCKER"
echo "========================================="

# Hàm đọc input an toàn cho curl | bash
safe_read() {
    if [ -t 0 ]; then
        read "$@"
    else
        read "$@" </dev/tty
    fi
}

# 1. Tạo thư mục
mkdir -p "$APP_DIR"
mkdir -p "$DATA_DIR"
cd "$APP_DIR"

# 2. Hỏi xóa container cũ
if docker ps -a --format '{{.Names}}' | grep -q "^omniroute$"; then
    echo "⚠️ Phát hiện container cũ."
    safe_read -p "Bạn có muốn xóa container cũ không? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]] || [[ -z "$confirm" ]]; then
        echo "🗑️ Đang xóa..."
        docker compose down 2>/dev/null || true
        docker rm -f omniroute 2>/dev/null || true
    else
        echo "⛔ Hủy cài đặt."
        exit 0
    fi
fi

# 3. Tạo docker-compose.yml (không version)
echo "--> Tạo docker-compose.yml..."
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

# 4. Tạo .env + secret (chỉ 1 lần)
if [ ! -f .env ]; then
    echo "--> Tạo .env và secret..."
    curl -fsSL https://raw.githubusercontent.com/diegosouzapw/OmniRoute/main/.env.example -o .env
    
    JWT_SECRET=$(openssl rand -base64 48 2>/dev/null || echo "super-secret-jwt-$(date +%s)")
    API_KEY_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "super-secret-api-key-$(date +%s)")
    
    sed -i "s|JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" .env
    sed -i "s|API_KEY_SECRET=.*|API_KEY_SECRET=$API_KEY_SECRET|" .env
fi

echo "⚠️ Kiểm tra INITIAL_PASSWORD"
echo "   nano .env"
safe_read -p "Nhấn Enter sau khi chỉnh xong..."

# 5. Khởi chạy
echo "--> Khởi chạy OmniRoute..."
docker compose up -d

echo "========================================="
echo " HOÀN TẤT!"
echo "========================================="
echo "Thư mục cài đặt : $APP_DIR"
echo "Data lưu tại    : $DATA_DIR"
echo "Truy cập        : http://localhost:20128"
echo ""
echo "Kiểm tra log    : cd $APP_DIR && docker compose logs -f"

#!/bin/bash
# ================================================
# OmniRoute Installer - Data lưu thư mục user
# ================================================

DATA_DIR=~/omniroute-data

echo "🚀 OmniRoute Installer (Data lưu tại $DATA_DIR)"

# Dọn dẹp container cũ
echo "🧹 Dọn dẹp container cũ..."
docker stop omniroute 2>/dev/null || true
docker rm -f omniroute 2>/dev/null || true

# Tạo thư mục data
mkdir -p "$DATA_DIR"

# Tạo .env nếu chưa có
if [ ! -f .env ]; then
    echo "📥 Tải file cấu hình..."
    curl -fsSL https://raw.githubusercontent.com/diegosouzapw/OmniRoute/main/.env.example -o .env
    echo ""
    echo "⚠️ Vui lòng chỉnh sửa file .env (đặc biệt INITIAL_PASSWORD)"
    echo "   nano .env"
    read -p "Nhấn Enter sau khi chỉnh xong..."
fi

# Khởi chạy
echo "🚀 Khởi chạy OmniRoute..."
docker run -d \
  --name omniroute \
  --restart unless-stopped \
  --stop-timeout 40 \
  --env-file .env \
  -p 20128:20128 \
  -v "$DATA_DIR:/app/data" \
  --memory=512m \
  --memory-swap=512m \
  diegosouzapw/omniroute:latest

echo ""
echo "✅ Cài đặt hoàn tất!"
echo "🌐 Truy cập: http://localhost:20128"
echo ""
echo "📁 Data được lưu tại: $DATA_DIR"
echo ""
echo "🔧 Lệnh hữu ích:"
echo "   docker logs -f omniroute"
echo "   docker restart omniroute"

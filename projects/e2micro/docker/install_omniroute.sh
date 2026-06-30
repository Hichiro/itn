#!/bin/bash
# ================================================
# OmniRoute Installer - Data lưu thư mục user
# Theo Docker Guide chính thức
# ================================================

DATA_DIR=~/omniroute-data

echo "🚀 OmniRoute Installer (Data lưu tại ~/omniroute-data)"

# ==================== KIỂM TRA & DỌN CŨ ====================
if docker ps -a --format '{{.Names}}' | grep -q "^omniroute$"; then
    echo "⚠️  Phát hiện container cũ."
    read -p "Bạn có muốn xóa container cũ không? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]] || [[ -z "$confirm" ]]; then
        docker stop omniroute 2>/dev/null || true
        docker rm -f omniroute 2>/dev/null || true
        echo "✅ Đã xóa container cũ."
    else
        echo "⛔ Hủy cài đặt."
        exit 0
    fi
fi

# ==================== TẠO THƯ MỤC DATA ====================
mkdir -p "$DATA_DIR"

echo "📁 Data sẽ được lưu tại: $DATA_DIR"

# ==================== .ENV ====================
if [ ! -f .env ]; then
    echo "📥 Tạo file .env..."
    curl -fsSL https://raw.githubusercontent.com/diegosouzapw/OmniRoute/main/.env.example -o .env
    echo "⚠️ Vui lòng chỉnh sửa file .env (đặc biệt INITIAL_PASSWORD)"
    echo "   nano .env"
    read -p "Nhấn Enter sau khi chỉnh xong..."
fi

# ==================== KHỞI CHẠY ====================
echo "🚀 Khởi chạy OmniRoute..."
docker run -d \
  --name omniroute \
  --restart unless-stopped \
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
echo "📁 Data đang lưu tại: $DATA_DIR"
echo ""
echo "🔧 Lệnh hữu ích:"
echo "   docker logs -f omniroute"
echo "   docker restart omniroute"
echo "   docker stats omniroute"

#!/bin/bash
# ================================================
# OmniRoute Installer - Data lưu thư mục user + Xác nhận xóa
# ================================================

PROJECT_DIR=~/omniroute
DATA_DIR=~/omniroute-data

echo "🚀 OmniRoute Installer (Data lưu tại ~/omniroute-data)"

# ==================== KIỂM TRA CONTAINER ====================
echo "🔍 Đang kiểm tra container OmniRoute..."
if docker ps -a --format '{{.Names}}' | grep -q "^omniroute$"; then
    echo "⚠️  Phát hiện container 'omniroute' đã tồn tại."
    read -p "Bạn có muốn xóa container cũ để cài mới không? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]] || [[ -z "$confirm" ]]; then
        echo "🗑️  Đang xóa container cũ..."
        docker stop omniroute 2>/dev/null || true
        docker rm -f omniroute 2>/dev/null || true
        echo "✅ Đã xóa container cũ."
    else
        echo "⛔ Hủy cài đặt."
        exit 0
    fi
else
    echo "ℹ️  Không tìm thấy container cũ."
fi

# ==================== TẠO THƯ MỤC ====================
mkdir -p "$DATA_DIR"
mkdir -p "$PROJECT_DIR"

# ==================== KHỞI CHẠY ====================
echo "🚀 Khởi chạy OmniRoute Base Image..."
docker run -d \
  --name omniroute \
  --restart unless-stopped \
  -p 20128:20128 \
  -v "$DATA_DIR:/app/data" \
  --memory=512m \
  --memory-swap=512m \
  yourusername/omniroute:base     # ← Thay yourusername bằng username Docker Hub của bạn

echo ""
echo "✅ Cài đặt hoàn tất!"
echo "🌐 Truy cập: http://localhost:20128"
echo ""
echo "📁 Data được lưu tại: $DATA_DIR"
echo ""
echo "🔧 Lệnh hữu ích:"
echo "   docker logs -f omniroute"
echo "   docker restart omniroute"
echo "   docker stats omniroute"

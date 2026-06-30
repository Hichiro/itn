#!/bin/bash
# ================================================
# OmniRoute Installer - Fix confirm khi curl | bash
# ================================================

set -e

DATA_DIR=~/omniroute-data

echo "🚀 OmniRoute Installer (Data lưu tại ~/omniroute-data)"

# Hàm đọc input an toàn (bắt buộc dùng /dev/tty)
safe_read() {
    if [ -t 0 ]; then
        read "$@"
    else
        read "$@" </dev/tty
    fi
}

# ==================== KIỂM TRA CONTAINER CŨ ====================
if docker ps -a --format '{{.Names}}' | grep -q "^omniroute$"; then
    echo "⚠️  Phát hiện container cũ."
    safe_read -p "Bạn có muốn xóa container cũ để cài mới không? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]] || [[ -z "$confirm" ]]; then
        echo "🗑️ Đang xóa container cũ..."
        docker stop omniroute 2>/dev/null || true
        docker rm -f omniroute 2>/dev/null || true
        echo "✅ Đã xóa xong."
    else
        echo "⛔ Hủy cài đặt."
        exit 0
    fi
fi

# ==================== TẠO THƯ MỤC ====================
mkdir -p "$DATA_DIR"
echo "📁 Data sẽ lưu tại: $DATA_DIR"

# ==================== .ENV ====================
if [ ! -f .env ]; then
    echo "📥 Tải file .env..."
    curl -fsSL https://raw.githubusercontent.com/diegosouzapw/OmniRoute/main/.env.example -o .env
    echo "⚠️ Vui lòng chỉnh sửa file .env (đặc biệt INITIAL_PASSWORD)"
    echo "   nano .env"
    safe_read -p "Nhấn Enter sau khi chỉnh xong..."
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
echo "📁 Data: $DATA_DIR"
echo ""
echo "🔧 Lệnh hữu ích:"
echo "   docker logs -f omniroute"
echo "   docker restart omniroute"

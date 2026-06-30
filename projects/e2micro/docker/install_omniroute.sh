#!/bin/bash
# ================================================
# OmniRoute Docker Hub Installer
# Tự động theo RAM + Fix curl | bash + Xác nhận xóa container
# ================================================
set -e

PROJECT_DIR=~/omniroute
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

echo "🚀 OmniRoute Docker Hub Installer (Tối ưu theo RAM)"

# ==================== KIỂM TRA RAM ====================
echo "🔍 Đang kiểm tra RAM hệ thống..."
TOTAL_RAM_MB=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
AVAILABLE_RAM_MB=$(grep MemAvailable /proc/meminfo | awk '{print int($2/1024)}')

echo "📊 RAM hiện tại:"
echo "   Tổng RAM     : ${TOTAL_RAM_MB} MB"
echo "   RAM khả dụng : ${AVAILABLE_RAM_MB} MB"

RECOMMEND_PERCENT=65
RECOMMEND_MB=$((AVAILABLE_RAM_MB * RECOMMEND_PERCENT / 100))

if [ "$RECOMMEND_MB" -lt 512 ]; then
    RECOMMEND_MB=512
elif [ "$RECOMMEND_MB" -gt 4096 ]; then
    RECOMMEND_MB=4096
fi

RECOMMEND_GB=$(awk "BEGIN {printf \"%.1f\", $RECOMMEND_MB/1024}")

echo ""
echo "💡 Đề xuất: Giới hạn container = ${RECOMMEND_GB}GB (${RECOMMEND_PERCENT}% RAM khả dụng)"

# ==================== XÁC NHẬN TỪ NGƯỜI DÙNG ====================
safe_read() {
    if [ -t 0 ]; then
        read "$@"
    else
        read "$@" </dev/tty
    fi
}

echo ""
safe_read -p "Bạn có muốn dùng giới hạn ${RECOMMEND_GB}GB không? (Y/n) hoặc nhập giá trị thủ công (ví dụ: 1.5g, 1536m): " choice

if [[ "$choice" =~ ^[0-9] ]]; then
    RAM_LIMIT="$choice"
    echo "→ Sử dụng giá trị bạn nhập: $RAM_LIMIT"
else
    if [[ "$choice" =~ ^[Nn] ]]; then
        safe_read -p "Nhập giới hạn RAM (ví dụ: 1g, 1536m, 2.5g): " RAM_LIMIT
    else
        RAM_LIMIT="${RECOMMEND_GB}g"
        echo "→ Sử dụng giá trị đề xuất: $RAM_LIMIT"
    fi
fi

# ==================== TÍNH NODE HEAP ====================
echo ""
echo "Đang tính Node.js Heap..."

# Chuẩn hóa RAM_LIMIT
if [[ "$RAM_LIMIT" =~ ^[0-9]*\.?[0-9]+$ ]]; then
    # Người dùng chỉ nhập số (ví dụ: 0.3, 512, 1.5) → mặc định hiểu là GB
    RAM_LIMIT="${RAM_LIMIT}g"
    echo "→ Tự động hiểu ${RAM_LIMIT} (GB)"
fi

if [[ "$RAM_LIMIT" =~ ^[0-9]+(\.[0-9]+)?[gG]?$ ]]; then
    # Là GB
    NUM=$(echo "$RAM_LIMIT" | sed 's/[gG]//i')
    NODE_HEAP_MB=$(awk "BEGIN {printf \"%.0f\", $NUM * 1024 * 0.55}")
elif [[ "$RAM_LIMIT" =~ ^[0-9]+[mM]?$ ]]; then
    # Là MB
    NUM=$(echo "$RAM_LIMIT" | sed 's/[mM]//i')
    NODE_HEAP_MB=$(awk "BEGIN {printf \"%.0f\", $NUM * 0.55}")
else
    NODE_HEAP_MB=512
fi

# Giới hạn tối thiểu
if [ "$NODE_HEAP_MB" -lt 384 ]; then 
    NODE_HEAP_MB=384
fi

echo "🛡️ Cấu hình cuối cùng:"
echo "   Docker RAM Limit : $RAM_LIMIT"
echo "   Node.js Heap     : ${NODE_HEAP_MB}MB"

# ==================== XỬ LÝ CONTAINER CŨ (CÓ XÁC NHẬN) ====================
echo ""
if docker ps -a --format '{{.Names}}' | grep -q "^omniroute$"; then
    echo "⚠️  Phát hiện container cũ tên 'omniroute'."
    safe_read -p "Bạn có muốn xóa container cũ để cài mới không? (Y/n): " del_choice
    
    if [[ "$del_choice" =~ ^[Yy]$ ]] || [[ -z "$del_choice" ]]; then
        echo "🗑️  Đang xóa container cũ..."
        docker stop omniroute 2>/dev/null || true
        docker rm -f omniroute 2>/dev/null || true
        echo "✅ Đã xóa container cũ."
    else
        echo "⛔ Hủy cài đặt. Container cũ vẫn giữ nguyên."
        exit 0
    fi
else
    echo "ℹ️  Không tìm thấy container cũ."
fi

# Tạo volume dữ liệu
docker volume create omniroute-data 2>/dev/null || true

# ==================== TẢI .ENV ====================
if [ ! -f .env ]; then
    echo "📥 Tải file .env..."
    curl -fsSL https://raw.githubusercontent.com/diegosouzapw/OmniRoute/main/.env.example -o .env || \
    wget -q https://raw.githubusercontent.com/diegosouzapw/OmniRoute/main/.env.example -O .env

    echo "🔑 Tạo secret ngẫu nhiên..."
    sed -i "s|JWT_SECRET=.*|JWT_SECRET=$(openssl rand -base64 48 2>/dev/null || echo 'super-secret-jwt-change-me')|" .env
    sed -i "s|API_KEY_SECRET=.*|API_KEY_SECRET=$(openssl rand -hex 32 2>/dev/null || echo 'super-secret-api-key-change-me')|" .env
fi

echo "⚠️ Vui lòng chỉnh sửa file .env (đặc biệt INITIAL_PASSWORD):"
echo "   nano .env"
safe_read -p "Nhấn Enter sau khi chỉnh xong..."

# ==================== CHỌN PROFILE ====================
echo ""
echo "🔧 Chọn Profile:"
echo "1) base - Nhẹ nhất (khuyến nghị cho RAM thấp)"
echo "2) cli  - Đầy đủ tính năng"
echo "3) host - Dùng CLI từ host"
safe_read -p "Nhập lựa chọn [1-3] (mặc định=1): " pchoice

case $pchoice in
    2) PROFILE="cli" ;;
    3) PROFILE="host" ;;
    *) PROFILE="base" ;;
esac

# ==================== KHỞI CHẠY CONTAINER ====================
echo "🚀 Khởi chạy OmniRoute latest..."
docker run -d \
  --name omniroute \
  --restart unless-stopped \
  --env-file .env \
  -e OMNIROUTE_MEMORY_MB=$NODE_HEAP_MB \
  -p 20128:20128 \
  -v omniroute-data:/app/data \
  --memory="$RAM_LIMIT" \
  --memory-swap="$RAM_LIMIT" \
  --label profile="$PROFILE" \
  diegosouzapw/omniroute:latest

echo ""
echo "✅ Cài đặt hoàn tất!"
echo "🌐 Truy cập: http://localhost:20128"
echo ""
echo "🔧 Lệnh hữu ích:"
echo "   docker logs -f omniroute"
echo "   docker stats omniroute"
echo "   docker restart omniroute"

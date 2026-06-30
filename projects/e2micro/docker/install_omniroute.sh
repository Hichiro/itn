#!/bin/bash
# ================================================
# OmniRoute Build Optimizer + Tự động giới hạn RAM
# ================================================

PROJECT_DIR=~/OmniRoute
cd ~

echo "🚀 OmniRoute Build Optimizer (Tự động theo RAM)"

# ==================== KIỂM TRA RAM ====================
TOTAL_RAM_MB=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
AVAILABLE_RAM_MB=$(grep MemAvailable /proc/meminfo | awk '{print int($2/1024)}')

echo "📊 RAM hiện tại:"
echo "   Tổng RAM      : ${TOTAL_RAM_MB} MB"
echo "   RAM khả dụng  : ${AVAILABLE_RAM_MB} MB"

# Tự động tính RAM limit cho container (70% RAM khả dụng, giới hạn min/max)
if [ "$AVAILABLE_RAM_MB" -le 512 ]; then
    CONTAINER_RAM="256m"
    NODE_MEMORY="192"
elif [ "$AVAILABLE_RAM_MB" -le 1024 ]; then
    CONTAINER_RAM="512m"
    NODE_MEMORY="320"
elif [ "$AVAILABLE_RAM_MB" -le 2048 ]; then
    CONTAINER_RAM="1g"
    NODE_MEMORY="640"
else
    CONTAINER_RAM="2g"
    NODE_MEMORY="1024"
fi

echo "🔧 Tự động giới hạn:"
echo "   Container RAM : $CONTAINER_RAM"
echo "   Node Memory   : ${NODE_MEMORY}MB"

# ==================== CLONE REPO ====================
if [ -d "$PROJECT_DIR" ]; then
    echo "📂 Cập nhật repo..."
    cd "$PROJECT_DIR"
    git pull
else
    echo "📥 Clone repo..."
    git clone https://github.com/diegosouzapw/OmniRoute.git "$PROJECT_DIR"
    cd "$PROJECT_DIR"
fi

# ==================== DỌN DẸP CŨ ====================
echo "🧹 Dọn dẹp container cũ..."
docker compose down --remove-orphans 2>/dev/null || true

# ==================== BUILD VỚI GIỚI HẠN ====================
echo "🔨 Đang build profile 'base'..."
echo "   (Giới hạn Node memory = ${NODE_MEMORY}MB)"

docker compose --profile base build \
  --build-arg NODE_OPTIONS="--max-old-space-size=${NODE_MEMORY}" \
  --progress=plain

if [ $? -eq 0 ]; then
    echo "✅ Build thành công!"
    echo "🚀 Khởi chạy với RAM limit ${CONTAINER_RAM}..."
    
    docker compose --profile base up -d \
      --no-build \
      --memory="$CONTAINER_RAM" \
      --memory-swap="$CONTAINER_RAM"
else
    echo "❌ Build thất bại."
    echo "💡 Gợi ý: Dùng docker run thay vì build."
fi

echo ""
echo "🌐 Truy cập: http://localhost:20128"

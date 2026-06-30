#!/bin/bash
# ================================================
# OmniRoute Docker Compose Installer
# ================================================

PROJECT_DIR=~/OmniRoute
cd ~

echo "🚀 OmniRoute Docker Compose Installer"

# Clone hoặc update repo
if [ -d "$PROJECT_DIR" ]; then
    echo "📂 Repo đã tồn tại, đang cập nhật..."
    cd "$PROJECT_DIR"
    git pull
else
    echo "📥 Đang clone repo..."
    git clone https://github.com/diegosouzapw/OmniRoute.git "$PROJECT_DIR"
    cd "$PROJECT_DIR"
fi

# Tạo .env nếu chưa có
if [ ! -f .env ]; then
    cp .env.example .env
    echo "⚠️ Vui lòng chỉnh sửa file .env (đặc biệt INITIAL_PASSWORD)"
    echo "   nano .env"
    read -p "Nhấn Enter sau khi chỉnh xong..."
fi

# Chọn Profile
echo ""
echo "🔧 Chọn Profile:"
echo "1) base - Nhẹ nhất (khuyến nghị cho RAM thấp)"
echo "2) cli  - Đầy đủ CLI tools bên trong container"
echo "3) host - Sử dụng CLI từ host machine (Linux)"
echo "4) web  - Hỗ trợ web-cookie providers (Gemini, Claude...)"
read -p "Nhập lựa chọn [1-4] (mặc định=1): " pchoice

case $pchoice in
    2) PROFILE="cli" ;;
    3) PROFILE="host" ;;
    4) PROFILE="web" ;;
    *) PROFILE="base" ;;
esac

# Dừng container cũ
docker compose down --remove-orphans 2>/dev/null || true

# Build image (bắt buộc)
echo "🔨 Đang build image cho profile '$PROFILE'..."
echo "⚠️ Lần đầu có thể mất 8-20 phút tùy máy..."
docker compose --profile $PROFILE build

# Khởi chạy
echo "🚀 Khởi chạy với profile: $PROFILE"
docker compose --profile $PROFILE up -d

echo ""
echo "✅ Cài đặt hoàn tất với profile '$PROFILE'!"
echo "🌐 Truy cập: http://localhost:20128"
echo ""
echo "🔧 Lệnh hữu ích:"
echo "   docker compose logs -f"
echo "   docker compose restart"
echo "   docker compose down"
echo "   docker compose --profile $PROFILE up -d"

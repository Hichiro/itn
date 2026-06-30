#!/bin/bash
# ================================================
# OmniRoute Docker Compose Installer (Theo repo chính thức)
# ================================================

PROJECT_DIR=~/OmniRoute
cd ~

echo "🚀 OmniRoute Docker Compose Installer"

# ==================== KIỂM TRA CONTAINER CŨ ====================
echo "🔍 Đang kiểm tra container cũ..."
if docker ps -a --format '{{.Names}}' | grep -q "omniroute"; then
    echo "⚠️  Phát hiện container OmniRoute cũ đang tồn tại."
    read -p "Bạn có muốn dọn dẹp (xóa) container cũ không? (Y/n): " cleanup
    if [[ "$cleanup" =~ ^[Yy]$ ]] || [[ -z "$cleanup" ]]; then
        echo "🗑️  Đang dọn dẹp container cũ..."
        docker compose down --remove-orphans 2>/dev/null || true
        docker rm -f omniroute 2>/dev/null || true
        echo "✅ Đã dọn dẹp xong."
    else
        echo "⛔ Hủy cài đặt mới."
        exit 0
    fi
else
    echo "ℹ️  Không tìm thấy container cũ."
fi

# ==================== CLONE / UPDATE REPO ====================
if [ -d "$PROJECT_DIR" ]; then
    echo "📂 Repo đã tồn tại, đang cập nhật..."
    cd "$PROJECT_DIR"
    git pull
else
    echo "📥 Đang clone repo..."
    git clone https://github.com/diegosouzapw/OmniRoute.git "$PROJECT_DIR"
    cd "$PROJECT_DIR"
fi

# ==================== .ENV ====================
if [ ! -f .env ]; then
    cp .env.example .env
    echo "⚠️ Vui lòng chỉnh sửa file .env (đặc biệt INITIAL_PASSWORD)"
    echo "   nano .env"
    read -p "Nhấn Enter sau khi chỉnh xong..."
fi

# ==================== CHỌN PROFILE ====================
echo ""
echo "🔧 Chọn Profile:"
echo "1) base - Nhẹ nhất (khuyến nghị cho RAM thấp)"
echo "2) cli  - Đầy đủ CLI tools"
echo "3) host - Sử dụng CLI từ host"
echo "4) web  - Hỗ trợ web-cookie providers"
read -p "Nhập lựa chọn [1-4] (mặc định=1): " pchoice

case $pchoice in
    2) PROFILE="cli" ;;
    3) PROFILE="host" ;;
    4) PROFILE="web" ;;
    *) PROFILE="base" ;;
esac

# ==================== BUILD & RUN ====================
echo "🔨 Đang build image cho profile '$PROFILE' (lần đầu có thể lâu)..."
docker compose --profile $PROFILE build

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

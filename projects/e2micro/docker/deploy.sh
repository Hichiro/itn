#!/bin/bash
set -e

GITHUB_RAW_URL="https://raw.githubusercontent.com/Hichiro/itn/refs/heads/main/projects/e2micro/docker/docker-compose.yml"

echo "========================================="
echo " TRIỂN KHAI DOCKER (Tối ưu - chỉ restart khi cần)"
echo "========================================="

APP_DIR="$HOME/apps"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Hàm dcompose
dcompose() {
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$PWD:$PWD" \
      -w "$PWD" \
      --user $(id -u):$(id -g) \
      docker/compose-bin:latest compose "$@"
}

# Tải compose mới
echo "--> Đang kiểm tra cập nhật compose..."
curl -sSL "$GITHUB_RAW_URL" -o docker-compose.yml.new

if ! cmp -s docker-compose.yml docker-compose.yml.new 2>/dev/null; then
    mv docker-compose.yml.new docker-compose.yml
    echo "--> Compose thay đổi → Update & Restart"
    UPDATE=true
else
    rm docker-compose.yml.new
    echo "--> Compose không thay đổi"
    UPDATE=false
fi

# Pull image
echo "--> Kiểm tra image mới..."
dcompose pull --quiet

# Khởi chạy
echo "--> Khởi chạy container..."
if [ "$UPDATE" = true ]; then
    dcompose up -d --remove-orphans
else
    dcompose up -d --remove-orphans --no-recreate
fi

# Dọn dẹp
echo "--> Dọn rác..."
docker image prune -f

# Alias lzd
if ! grep -q "alias lzd=" ~/.bashrc; then
    echo "alias lzd='docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker:/var/lib/docker:ro lazyteam/lazydocker:latest'" >> ~/.bashrc
    source ~/.bashrc
fi

echo "========================================="
echo " HOÀN TẤT!"
echo "========================================="
dcompose ps

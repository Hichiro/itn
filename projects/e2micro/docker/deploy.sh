#!/bin/bash
set -e

GITHUB_RAW_URL="https://raw.githubusercontent.com/Hichiro/itn/refs/heads/main/projects/e2micro/docker/docker-compose.yml"

echo "========================================="
echo " TRIỂN KHAI DOCKER"
echo "========================================="

APP_DIR="$HOME"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

dcompose() {
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$PWD:$PWD" \
      -w "$PWD" \
      docker:cli docker compose "$@"
}

# Tải compose
echo "--> Đang cập nhật docker-compose.yml..."
curl -sSL "$GITHUB_RAW_URL" -o docker-compose.yml.new

if ! cmp -s docker-compose.yml docker-compose.yml.new 2>/dev/null; then
    mv docker-compose.yml.new docker-compose.yml
    UPDATE=true
else
    rm docker-compose.yml.new
    UPDATE=false
fi

# Pull & Up
echo "--> Khởi chạy container..."
dcompose pull --quiet

if [ "$UPDATE" = true ]; then
    dcompose up -d --remove-orphans
else
    dcompose up -d --remove-orphans --no-recreate
fi

# Dọn dẹp
echo "--> Dọn rác..."
echo "--> Dang tu dong xoa tat ca Images thua (ngoai tru cong cu he thong)..."
docker image prune -a -f --filter "label!=org.opencontainers.image.title=Docker CLI" \
                         --filter "label!=maintainer=LazyTeam" \
                         2>/dev/null || true
echo "--> Dang tu dong xoa tat ca Networks thua..."
docker network prune -f
echo "--> Kiem tra va quet cac Volume dang o trang thai thua:"
UNUSED_VOLUMES=$(docker volume ls -q -f dangling=true)
if [ -z "$UNUSED_VOLUMES" ]; then
    echo "--> Khong co Volume thua nao can don dep."
else
    for vol_name in $UNUSED_VOLUMES; do
        echo "-----------------------------------------"
        echo "Canh bao: Tim thay Volume khong gan voi container nao: $vol_name"
        read -p "Ban co chac chan muon XOA Volume nay khong? (y/N): " choice
        case "$choice" in 
            [yY][eE][sS]|[yY]) 
                echo "--> Dang xoa Volume: $vol_name..."
                docker volume rm "$vol_name"
                ;;
            *)
                echo "--> Bo qua, giu lai Volume."
                ;;
        esac
    done
fi

# Alias lazydocker
if ! grep -q "alias lzd=" ~/.bashrc; then
    echo "alias lzd='docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker:/var/lib/docker:ro lazyteam/lazydocker:latest'" >> ~/.bashrc
    source ~/.bashrc
fi

echo "========================================="
echo " HOÀN TẤT!"
echo "========================================="
dcompose ps

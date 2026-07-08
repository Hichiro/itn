#!/bin/bash
set -e

echo "========================================="
echo " TRIEN KHAI DOCKER"
echo "========================================="

# Chuyen ve lam viec tai thu muc goc
APP_DIR="/"
cd "$APP_DIR"

# Kiem tra neu chua co file docker-compose.yml thi bao loi va tao file trong
if [ ! -f "docker-compose.yml" ]; then
    echo "[Error] Khong tim thay file docker-compose.yml tai thu muc goc ($APP_DIR)!"
    echo "--> Dang tu dong tao file docker-compose.yml trong..."
    touch docker-compose.yml
fi

dcompose() {
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$PWD:$PWD" \
      -w "$PWD" \
      docker:cli docker compose "$@"
}

# Pull & Up
echo "--> Khoi chay container..."
dcompose pull
dcompose up -d --remove-orphans

# Don dep
echo "--> Don rac..."
echo "--> Dang tu dong xoa tat ca Images khong dung (ngoai tru cong cu he thong)..."

docker images --format "{{.Repository}}:{{.Tag}}|{{.ID}}" | while read -r line; do
    repo_tag=$(echo "$line" | cut -d'|' -f1)
    img_id=$(echo "$line" | cut -d'|' -f2)
    
    if [[ "$repo_tag" =~ "docker" ]] || [[ "$repo_tag" =~ "lazydocker" ]]; then
        continue
    fi
    
    if [ -z "$(docker ps -a -q --filter=ancestor="$img_id")" ]; then
        docker rmi -f "$img_id" 2>/dev/null || true
    fi
done

echo "--> Dang tu dong xoa tat ca Networks khong dung..."
docker network prune -f

echo "--> Kiem tra va quet cac Volume dang o trang thai thua:"
UNUSED_VOLUMES=$(docker volume ls -q -f dangling=true)
if [ -z "$UNUSED_VOLUMES" ]; then
    echo "--> Khong co Volume thua nao can don dep."
else
    for vol_name in $UNUSED_VOLUMES; do
        echo "-----------------------------------------"
        echo "Canh bao: Tim thay Volume khong gan voi container nao: $vol_name"
        read -p "Ban co chac chan muon XOA Volume nay khong? (y/N): " choice </dev/tty
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
NEED_RELOAD=false
if [ -f "$HOME/.bashrc" ]; then
    if ! grep -q "alias lzd=" "$HOME/.bashrc"; then
        echo "alias lzd='docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker:/var/lib/docker:ro lazyteam/lazydocker:latest'" >> "$HOME/.bashrc"
        NEED_RELOAD=true
    fi
fi

echo "========================================="
echo " HOAN TAT!"
echo "========================================="
dcompose ps

# Hien thi thong bao nap lai bashrc neu co thay doi alias
if [ "$NEED_RELOAD" = true ]; then
    echo ""
    echo "--------------------------------------------------------"
    echo "[INFO] Da them alias 'lzd' vao ~/.bashrc."
    echo "De su dung ngay lap tuc, hay chay lenh sau:"
    echo "source ~/.bashrc"
    echo "--------------------------------------------------------"
fi

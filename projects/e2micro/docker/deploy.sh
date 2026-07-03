#!/bin/bash
set -e

GITHUB_RAW_URL="https://raw.githubusercontent.com/Hichiro/itn/refs/heads/main/projects/e2micro/docker/docker-compose.yml"

echo "========================================="
echo " TRIỂN KHAI & TỐI ƯU RAM DOCKER"
echo "========================================="

APP_DIR="$HOME/apps"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Hàm nhẹ
dcompose() {
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$PWD:$PWD" \
      -w "$PWD" \
      docker/compose-bin:latest compose "$@"
}

# === TỐI ƯU DAEMON.JSON ===
echo "--> Kiểm tra & tối ưu Docker daemon..."
DAEMON_FILE="/etc/docker/daemon.json"

if [ ! -f "$DAEMON_FILE" ]; then
    sudo tee "$DAEMON_FILE" > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "memory": "800m",
  "live-restore": true,
  "storage-driver": "overlay2",
  "mtu": 1460
}
EOF
else
    # Merge với file hiện có
    sudo python3 - <<EOF
import json
with open('$DAEMON_FILE', 'r') as f:
    data = json.load(f)

data.setdefault('log-driver', 'json-file')
opts = data.setdefault('log-opts', {})
opts.update({'max-size': '10m', 'max-file': '3'})
data['memory'] = '800m'

with open('$DAEMON_FILE', 'w') as f:
    json.dump(data, f, indent=2)
EOF
fi

sudo systemctl restart docker
echo "--> Docker daemon đã tối ưu RAM + Log"

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
docker image prune -f
docker system prune -f --volumes 2>/dev/null || true

echo "========================================="
echo " HOÀN TẤT!"
echo "========================================="
dcompose ps

# Tự động tạo lệnh phím tắt 'lzd' cho hệ thống nếu chưa có
if ! grep -q "alias lzd=" ~/.bashrc; then
    echo "alias lzd='docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker:/var/lib/docker:ro lazyteam/lazydocker:latest'" >> ~/.bashrc
    source ~/.bashrc
fi

echo "========================================="
echo " ĐÃ CẬP NHẬT VÀ DỌN SẠCH HỆ THỐNG!"
echo "========================================="
dcompose ps

#!/bin/bash
# ==============================================================================
# Tên Script: deploy-n8n-gcp.sh
# Mô tả: 
#   Tự động khởi tạo máy ảo Compute Engine (e2-micro) chạy hệ điều hành 
#   Container-Optimized OS (COS) trên Google Cloud Platform (GCP).
#   Sau khi khởi tạo, máy ảo sẽ tự động cấu hình bộ nhớ và khởi chạy 
#   container n8n bản mới nhất, cấu hình dọn dẹp log tự động và mở cổng 5678.
#
# HƯỚNG DẪN CHẠY BẰNG GCLOUD:
# ------------------------------------------------------------------------------
# Cách 1: Chạy trực tiếp từ xa qua URL GitHub (Nhanh nhất, không cần tải file)
#   Mở Terminal/Cloud Shell trên máy tính của bạn và chạy lệnh sau:
#   curl -sL https://raw.githubusercontent.com/Hichiro/itn/refs/heads/main/agents/e2micro/cloud-shell-n8n-install.sh | bash
#
# Cách 2: Tải file script về máy rồi thực thi
#   1. Tải file: 
#      curl -O https://raw.githubusercontent.com/Hichiro/itn/refs/heads/main/agents/e2micro/cloud-shell-n8n-install.sh
#   2. Cấp quyền chạy: 
#      chmod +x deploy-n8n-gcp.sh
#   3. Thực thi: 
#      ./deploy-n8n-gcp.sh
# ==============================================================================

gcloud compute instances create e2-micro \
    --project=free-e2micro \
    --zone=us-west1-b \
    --machine-type=e2-micro \
    --image-family=cos-stable \
    --image-project=cos-cloud \
    --boot-disk-size=30GB \
    --boot-disk-type=pd-standard \
    --tags=n8n-server \
    --metadata=startup-script-url=https://raw.githubusercontent.com/Hichiro/itn/refs/heads/main/agents/e2micro/e2micro-cos,startup-script="#! /bin/bash
# 1. Tạo thư mục lưu trữ dữ liệu bền vững trên Host
mkdir -p /var/n8n_data
chown -R 1000:1000 /var/n8n_data

# 2. Dọn dẹp các container cũ để tránh xung đột cổng
docker rm -f n8n || true

# 3. Chạy n8n Container với đầy đủ các cấu hình bạn yêu cầu
docker run -d --name n8n \
    -p 5678:5678 \
    --restart always \
    -v /var/n8n_data:/home/node/.n8n \
    -e EXECUTIONS_DATA_PRUNE=true \
    -e EXECUTIONS_DATA_MAX_AGE=72 \
    -e EXECUTIONS_DATA_PRUNE_TIMEOUT=3600 \
    docker.io/n8nio/n8n:latest"

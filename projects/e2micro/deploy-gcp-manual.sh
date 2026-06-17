#!/bin/bash

# ==============================================================================
# Tên Script: deploy-gcp-manual.sh (Script 1)
# Mô tả: 
# Mô tả: Tự động tạo máy ảo cấu hình MIỄN PHÍ (e2-micro) trên GCP.
#        Đã tích hợp tính năng tắt các dịch vụ giám sát chạy ngầm để tiết kiệm tài nguyên.
# CHẠY TRÊN: Cloud Shell hoặc máy cá nhân có cài gcloud CLI.
#
# HƯỚNG DẪN CHẠY:
#   bash <(curl -sL https://raw.githubusercontent.com/Hichiro/itn/refs/heads/main/projects/e2micro/deploy-gcp-manual.sh)
# ==============================================================================

echo "=== CẤU HÌNH THÔNG TIN MÁY ẢO GCP ==="

# 1. Tự động lấy Project ID hiện tại từ hệ thống gcloud
DETECTED_PROJECT=$(gcloud config get-value project 2>/dev/null)

if [ -n "$DETECTED_PROJECT" ]; then
    read -p "Tìm thấy Project ID hiện tại là [$DETECTED_PROJECT]. Nhấn Enter để dùng luôn hoặc nhập Project ID mới: " PROJECT_ID
    PROJECT_ID=${PROJECT_ID:-$DETECTED_PROJECT}
else
    read -p "Không tìm thấy project mặc định. Vui lòng nhập GCP Project ID của bạn: " PROJECT_ID
    if [ -z "$PROJECT_ID" ]; then echo "[ERROR] Project ID không được để trống!"; exit 1; fi
fi

# 2. Hỏi VM Name (Mặc định: e2micro-vm)
read -p "Nhập tên Máy ảo muốn tạo (mặc định: e2micro-vm): " VM_NAME
VM_NAME=${VM_NAME:-e2micro-vm}

# 3. Lựa chọn IMAGE_FAMILY
echo "------------------------------------------------"
echo "Chọn Hệ điều hành:"
echo "1) Debian 12 (Bản chuẩn, cực nhẹ cho e2-micro, khuyên dùng)"
echo "2) Container-Optimized OS - COS (Chuyên chạy Docker)"
echo "3) Tự nhập Image Family khác"
read -p "Nhập lựa chọn của bạn (1-3): " IMAGE_CHOICE

case $IMAGE_CHOICE in
    1) IMAGE_FAMILY="debian-12"; IMAGE_PROJECT="debian-cloud" ;;
    2) IMAGE_FAMILY="cos-stable"; IMAGE_PROJECT="cos-cloud" ;;
    3) 
        read -p "Nhập chính xác tên IMAGE_FAMILY: " IMAGE_FAMILY
        read -p "Nhập chính xác tên IMAGE_PROJECT: " IMAGE_PROJECT
        ;;
    *) echo "[ERROR] Lựa chọn không hợp lệ!"; exit 1 ;;
esac

ZONE="us-west1-b" # Vùng miễn phí
MACHINE_TYPE="e2-micro" # Máy ảo miễn phí
BOOT_DISK_SIZE="30GB" # Dung lượng tối đa miễn phí
BOOT_DISK_TYPE="pd-standard" # Loại ổ đĩa tiêu chuẩn miễn phí

# Link raw của Script 2 trên GitHub để VM tự tải về thực thi khi boot
SCRIPT_2_URL="https://raw.githubusercontent.com/xxx/itn/refs/heads/main/projects/e2micro/vm-init-setup.sh"

# =====================================================================
# EXECUTION
# =====================================================================
echo "------------------------------------------------"
echo "=== [GCP] 1. Thiết lập dự án: $PROJECT_ID ==="
gcloud config set project "$PROJECT_ID"

echo "=== [GCP] 2. Tắt các dịch vụ giám sát ngầm để tránh phát sinh chi phí ==="
gcloud services disable networkmanagement.googleapis.com --force 2>/dev/null
gcloud services disable networkintelligence.googleapis.com --force 2>/dev/null
gcloud services disable recommender.googleapis.com --force 2>/dev/null
gcloud services disable monitoring.googleapis.com --force 2>/dev/null
gcloud services disable clouderrorreporting.googleapis.com --force 2>/dev/null
echo "Đã vô hiệu hóa các dịch vụ Network Analyzer, Cloud Monitoring và Error Reporting."

echo "=== [GCP] 3. Đang tiến hành tạo máy ảo miễn phí... ==="
gcloud compute instances create "$VM_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --network-interface=network-tier=STANDARD,subnet=default \
    --no-restart-on-failure \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --create-disk=auto-delete=yes,boot=yes,image-family="$IMAGE_FAMILY",image-project="$IMAGE_PROJECT",mode=rw,size="$BOOT_DISK_SIZE",type="$BOOT_DISK_TYPE" \
    --metadata=startup-script-url="$SCRIPT_2_URL"

if [ $? -eq 0 ]; then
    echo "---------------------------------------------------------------------"
    echo "[SUCCESS] Máy ảo $VM_NAME đã được tạo thành công!"
    echo "---------------------------------------------------------------------"
    echo "Kết nối vào máy ảo bằng lệnh:"
    echo "gcloud compute ssh --zone \"$ZONE\" \"$VM_NAME\" --project \"$PROJECT_ID\""
    echo "---------------------------------------------------------------------"
else
    echo "[ERROR] Quá trình tạo máy ảo thất bại."
    exit 1
fi

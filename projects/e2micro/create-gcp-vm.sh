#!/bin/bash
# Mô tả: 
#   Tự động khởi tạo máy ảo Compute Engine cấu hình MIỄN PHÍ (e2-micro) trên
#   Google Cloud Platform (GCP). Script hỗ trợ tương tác nhập Project ID, tên VM 
#   và lựa chọn hệ điều hành tối ưu (Debian 12 hoặc COS).
#   Máy ảo sau khi tạo sẽ tự động kích hoạt 2GB RAM ảo (SWAP) phù hợp theo từng OS.
#
# HƯỚNG DẪN CHẠY BẰNG GCLOUD CLI:
#   Chạy trực tiếp từ xa qua URL GitHub (Nhanh nhất, không cần tải file)
#   Mở Terminal hoặc Cloud Shell của bạn và thực thi lệnh sau:
#   curl -sL https://raw.githubusercontent.com/<Tên_User>/<Tên_Repo>/main/create-gcp-vm.sh | bash

echo "=== CẤU HÌNH THÔNG TIN MÁY ẢO GCP ==="

# 1. Hỏi Project ID
read -p "Nhập GCP Project ID của bạn: " PROJECT_ID
if [ -z "$PROJECT_ID" ]; then echo "[ERROR] Project ID không được để trống!"; exit 1; fi

# 2. Hỏi VM Name
read -p "Nhập tên Máy ảo muốn tạo (mặc định: openclaw-vm): " VM_NAME
VM_NAME=${VM_NAME:-e2micro}

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

# =====================================================================
# EXECUTION
# =====================================================================
echo "------------------------------------------------"
echo "=== [GCP] 1. Thiết lập dự án: $PROJECT_ID ==="
gcloud config set project "$PROJECT_ID"

echo "=== [GCP] 2. Đang tiến hành tạo máy ảo miễn phí... ==="
gcloud compute instances create "$VM_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --network-interface=network-tier=STANDARD,subnet=default \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --tags=mcp-node \
    --create-disk=auto-delete=yes,boot=yes,image-family="$IMAGE_FAMILY",image-project="$IMAGE_PROJECT",mode=rw,size="$BOOT_DISK_SIZE",type="$BOOT_DISK_TYPE" \
    --metadata=startup-script="#! /bin/bash
    # Xác định đường dẫn file SWAP an toàn dựa trên OS (COS bắt buộc dùng /var)
    if [ -d '/var' ] && [ ! -w '/' ]; then
        SWAP_PATH='/var/swapfile'
    else
        SWAP_PATH='/swapfile'
    fi

    # Tối ưu log hệ thống (chỉ áp dụng nếu là Debian)
    if [ -d '/etc/systemd/' ]; then
        mkdir -p /etc/systemd/journald.conf.d/
        echo -e '[Journal]\nSystemMaxUse=50M' > /etc/systemd/journald.conf.d/maxuse.conf
        systemctl restart systemd-journald 2>/dev/null
    fi

    # CẤU HÌNH TỰ ĐỘNG BẬT SWAP 2GB
    if [ ! -f \"\$SWAP_PATH\" ]; then
        dd if=/dev/zero of=\"\$SWAP_PATH\" bs=1M count=2048
        chmod 600 \"\$SWAP_PATH\"
        mkswap \"\$SWAP_PATH\"
    fi
    
    swapon \"\$SWAP_PATH\"

    # Ghi cấu hình vĩnh viễn nếu hệ thống cho phép sửa fstab (Debian)
    if [ -w '/etc/fstab' ]; then
        if ! grep -q \"\$SWAP_PATH\" /etc/fstab; then
            echo \"\$SWAP_PATH none swap sw 0 0\" >> /etc/fstab
        fi
    fi
    "

if [ $? -eq 0 ]; then
    echo "---------------------------------------------------------------------"
    echo "[SUCCESS] Máy ảo $VM_NAME đã được tạo và cấu hình SWAP tự động thành công!"
    echo "---------------------------------------------------------------------"
    echo "Kết nối vào máy ảo bằng lệnh:"
    echo "gcloud compute ssh --zone \"$ZONE\" \"$VM_NAME\" --project \"$PROJECT_ID\""
    echo "---------------------------------------------------------------------"
else
    echo "[ERROR] Quá trình tạo máy ảo thất bại."
    exit 1
fi

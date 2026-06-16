#!/bin/bash

# ==============================================================================
# TÓM TẮT:
# Script tự động cấu hình và kích hoạt 2GB bộ nhớ ảo (SWAP) trên hệ điều hành 
# Container-Optimized OS (COS) của Google Cloud Platform bằng cách liên kết với GitHub.
#
# TÁC DỤNG:
# 1. Khắc phục giới hạn Read-only của COS bằng cách tạo SWAP trong thư mục /var.
# 2. Tạo "lưới bảo hiểm" 2GB RAM ảo, giúp máy ảo e2-micro (1GB RAM) không bị
#    treo hoặc sập nguồn khi các container (như n8n) xử lý tác vụ nặng đột xuất.
# 3. Tự động cập nhật: Mỗi khi bạn sửa đổi script này trên GitHub, máy ảo sẽ
#    tự động áp dụng phiên bản mới nhất ở lần khởi động kế tiếp.
#
# CÁCH CÀI ĐẶT TRÊN GIAO DIỆN GCP (GOOGLE CLOUD):
#   Bước 1: Đẩy file này lên GitHub -> Bấm nút [Raw] để lấy đường dẫn trực tiếp.
#           (Link sẽ có dạng: https://raw.githubusercontent.com/.../swap.sh)
#   Bước 2: Vào danh sách VM Compute Engine -> Bấm vào tên con máy ảo COS.
#   Bước 3: Bấm nút [EDIT] (Chỉnh sửa) ở thanh công cụ phía trên.
#   Bước 4: Cuộn xuống mục [Metadata]. Bấm [Add Item].
#   Bước 5: Cấu hình chính xác thông số sau:
#           - Ô Key điền: startup-script-url
#           - Ô Value điền: [Dán đường link Raw từ GitHub ở Bước 1 vào]
#   Bước 6: Bấm [SAVE] ở dưới cùng để hoàn tất.
# ==============================================================================

# Đường dẫn file SWAP (COS cho phép ghi vào thư mục /var)
SWAP_PATH="/var/swapfile"
SWAP_SIZE_MB=2048

echo "=== Bắt đầu kiểm tra và thiết lập SWAP từ GitHub vào COS ==="

# 1. Kiểm tra xem hệ thống đã bật SWAP chưa
if grep -q "$SWAP_PATH" /proc/swaps; then
    echo "SWAP đã được kích hoạt trên hệ thống từ trước."
    echo "=== Trạng thái bộ nhớ hiện tại ==="
    free -m
    exit 0
fi

# 2. Nếu file SWAP chưa tồn tại thì tiến hành tạo mới
if [ ! -f "$SWAP_PATH" ]; then
    echo "Không tìm thấy file SWAP. Đang tiến hành tạo file dung lượng ${SWAP_SIZE_MB}MB..."
    
    # Tạo file trống với dung lượng 2GB
    dd if=/dev/zero of="$SWAP_PATH" bs=1M count=$SWAP_SIZE_MB
    
    # Phân quyền bảo mật (chỉ tài khoản root được phép đọc/ghi)
    chmod 600 "$SWAP_PATH"
    
    # Định dạng file thành phân vùng SWAP
    mkswap "$SWAP_PATH"
    
    echo "Tạo file SWAP thành công."
else
    echo "File SWAP đã tồn tại sẵn trên ổ đĩa nhưng chưa được kích hoạt."
fi

# 3. Kích hoạt SWAP lên hệ thống
echo "Đang kích hoạt SWAP..."
swapon "$SWAP_PATH"

# 4. Hiển thị lại trạng thái bộ nhớ để kiểm tra kết quả
echo "=== Cấu hình hoàn tất! Trạng thái bộ nhớ hiện tại ==="
free -m

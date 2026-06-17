#!/bin/bash

# ==============================================================================
# Tên Script: install-openclaw-native.sh
# Mô tả: Tự động cài đặt OpenClaw AI trực tiếp trên Debian không dùng Docker.
#        Script tự động cấu hình Node.js, PM2 (quản lý chạy ngầm) và tải mã nguồn.
# CHẠY TRÊN: Chạy trực tiếp bên trong VM Debian với quyền root hoặc sudo.
# ==============================================================================

# 1. KIỂM TRA QUYỀN SUDO/ROOT
if [ "$EUID" -ne 0 ]; then
    echo "Đang yêu cầu nâng quyền root bằng sudo..."
    exec sudo bash "$0" "$@"
fi

# Tự động dừng script nếu có lỗi xảy ra
set -e

echo "================================================="
echo "🚀 BẮT ĐẦU CÀI ĐẶT OPENCLAW AI (NATIVE DEBIAN)"
echo "================================================="

# 2. CẬP NHẬT HỆ THỐNG VÀ CÀI ĐẶT PHỤ THUỘC CƠ BẢN
echo "--- [1/6] Đang cập nhật hệ thống và cài đặt công cụ nền... ---"
apt-get update -y
apt-get install -y curl git build-essential supervisor

# 3. CÀI ĐẶT NODE.JS (PHIÊN BẢN LTS MỚI NHẤT)
echo "--- [2/6] Đang cài đặt môi trường Node.js... ---"
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
    echo "✅ Đã cài đặt Node.js v$(node -v)"
else
    echo "➡️ Node.js đã được cài đặt từ trước (v$(node -v)), bỏ qua..."
fi

# 4. CÀI ĐẶT QUẢN LÝ TIẾN TRÌNH PM2 (Thay thế tính năng chạy ngầm của Docker)
echo "--- [3/6] Đang cài đặt PM2 để quản lý ứng dụng chạy ngầm... ---"
if ! command -v pm2 &> /dev/null; then
    npm install -p g pm2
    echo "✅ Đã cài đặt PM2 thành công."
else
    echo "➡️ PM2 đã được cài đặt từ trước, bỏ qua..."
fi

# 5. TẢI MÃ NGUỒN OPENCLAW AI TỪ GITHUB
echo "--- [4/6] Đang tải mã nguồn OpenClaw AI từ GitHub... ---"
INSTALL_DIR="/opt/openclaw"

if [ ! -d "$INSTALL_DIR" ]; then
    git clone https://github.com/openclaw/openclaw.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
else
    echo "➡️ Thư mục $INSTALL_DIR đã tồn tại. Tiến hành cập nhật mã nguồn..."
    cd "$INSTALL_DIR"
    git pull
fi

# 6. CÀI ĐẶT CÁC GÓI PHỤ THUỘC CỦA DỰ ÁN (NPM PACKAGES)
echo "--- [5/6] Đang cài đặt các thư viện phụ thuộc của ứng dụng... ---"
npm install --production

# 7. KHỞI TẠO FILE CẤU HÌNH (.ENV)
echo "--- [6/6] Thiết lập file cấu hình môi trường... ---"
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "✅ Đã tạo file .env từ mẫu .env.example."
    else
        touch .env
        echo "⚠️ Không tìm thấy file mẫu, đã khởi tạo file .env trống."
    fi
else
    echo "➡️ File .env đã tồn tại, giữ nguyên cấu hình cũ."
fi

# 8. KHỞI CHẠY ỨNG DỤNG CHẠY NGẦM VỚI PM2
echo "-------------------------------------------------"
echo "Đang khởi chạy OpenClaw AI bằng PM2..."

# Tìm file thực thi chính (thường là app.js, index.js hoặc dist/main.js tùy cấu trúc nguồn)
MAIN_FILE=""
for file in "index.js" "app.js" "server.js" "dist/main.js"; do
    if [ -f "$file" ]; then
        MAIN_FILE="$file"
        break
    fi
done

if [ -n "$MAIN_FILE" ]; then
    # Khởi chạy ứng dụng và đặt tên tiến trình là openclaw
    pm2 start "$MAIN_FILE" --name "openclaw"
    
    # Cấu hình tự khởi động PM2 cùng hệ thống khi reboot máy ảo
    pm2 save
    env PATH=$PATH:/usr/bin pm2 startup systemd -u root --hp /root || true
    
    echo "================================================="
    echo "🎉 CHÚC MỪNG! OPENCLAW AI ĐÃ CÀI ĐẶT HOÀN TẤT!"
    echo "================================================="
    echo "• Trạng thái tiến trình hệ thống:"
    pm2 status
    echo "-------------------------------------------------"
    echo "• Xem log thời gian thực: pm2 logs openclaw"
    echo "• Dừng ứng dụng: pm2 stop openclaw"
    echo "• Khởi động lại ứng dụng: pm2 restart openclaw"
    echo "================================================="
else
    echo "⚠️ Không tìm thấy file khởi chạy mặc định (index.js/app.js)."
    echo "Vui lòng truy cập vào cd $INSTALL_DIR và chạy thủ công bằng lệnh: pm2 start [file_chính.js] --name openclaw"
fi

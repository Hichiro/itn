#!/bin/bash

# ==============================================================================
# SCRIPT: install_omniroute_termux.sh
# THÔNG TIN: Tự động hóa quy trình thiết lập OmniRoute trên môi trường Android
# TÁC DỤNG: Cập nhật hệ thống, cấu hình Node.js, Python, Build Tools và cài đặt OmniRoute
# CÁCH CHẠY NHANH (CURL GITHUB):
# curl -sSL https://raw.githubusercontent.com/Hichiro/itn/refs/heads/main/projects/picoclaw/scripts/setup_OmniRoute_termux.sh | bash
# ==============================================================================

echo "🚀 Bắt đầu quy trình cấu hình và cài đặt OmniRoute..."
echo "----------------------------------------------------"

# 1. Cập nhật các kho lưu trữ và gói hệ thống
echo "🔄 [1/3] Đang cập nhật hệ thống Termux..."
pkg update && pkg upgrade -y

# 2. Cài đặt Node.js và các công cụ biên dịch bắt buộc
echo "📦 [2/3] Đang cài đặt Node.js, Python và Build Tools..."
pkg install nodejs python binutils make clang -y

# 3. Cài đặt OmniRoute toàn cục qua NPM
echo "🌐 [3/3] Đang tải và cài đặt OmniRoute từ NPM..."
npm install -g omniroute

# 4. Kiểm tra và hoàn tất
echo "----------------------------------------------------"
if command -v omniroute &> /dev/null; then
    echo "🎉 CÀI ĐẶT THÀNH CÔNG OMNIROUTE TRÊN TERMUX!"
    echo ""
    echo "👉 Lệnh khởi chạy:     omniroute"
    echo "👉 Địa chỉ truy cập:   http://localhost:20128"
    echo ""
    echo "⚠️  LƯU Ý CHẠY NGẦM:"
    echo "Hãy vuốt thanh thông báo trạng thái của Android xuống,"
    echo "ở thông báo của Termux, nhấn chọn 'Acquire changelock'"
    echo "để hệ điều hành không tự động tắt OmniRoute khi bạn tắt màn hình."
else
    echo "❌ LỖI: Quá trình cài đặt gặp sự cố."
    echo "Vui lòng kiểm tra dung lượng bộ nhớ hoặc kết nối mạng và thử lại."
fi
echo "----------------------------------------------------"

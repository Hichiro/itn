#!/bin/bash

echo "=== 1. KHỞI TẠO ĐƯỜNG DẪN HỆ THỐNG ==="
mkdir -p $HOME/.cargo/bin

echo "=== 2. TẢI FILE BINARY TỪ GITHUB ACTIONS ==="
curl -fsSL https://raw.githubusercontent.com/Hichiro/itn/main/zeroclaw/zeroclaw -o $HOME/.cargo/bin/zeroclaw

if [ $? -eq 0 ]; then
    echo "🎉 Tải file thành công!"
else
    echo "❌ Lỗi: Không thể tải file từ GitHub."
    exit 1
fi

echo "=== 3. CẤP QUYỀN VÀ ĐỒNG BỘ PATH ==="
chmod +x $HOME/.cargo/bin/zeroclaw
touch ~/.bashrc

if ! grep -q '\.cargo/bin' ~/.bashrc; then
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
fi
export PATH="$HOME/.cargo/bin:$PATH"

echo "=== 4. THIẾT LẬP TỰ ĐỘNG KHỞI ĐỘNG (AUTO-START) ==="
if ! grep -q 'zeroclaw daemon' ~/.bashrc; then
    cat << 'END_AUTOSTART' >> ~/.bashrc

# Tự động khởi động ZeroClaw ngầm nếu chưa chạy
if ! pgrep -x "zeroclaw" > /dev/null; then
    nohup zeroclaw daemon > /dev/null 2>&1 &
fi
END_AUTOSTART
    echo "✅ Đã thiết lập tự động khởi động cùng Termux."
else
    echo "ℹ️ Thiết lập tự động khởi động đã tồn tại, bỏ qua."
fi

echo "================================================="
echo " ✅ QUY TRÌNH HOÀN TẤT THÀNH CÔNG!"
echo " - Gõ 'zeroclaw onboard' nếu cài lần đầu."
echo " - Bot sẽ tự chạy ngầm khi mở Termux."
echo "================================================="

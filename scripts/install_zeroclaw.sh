#!/bin/bash

echo "=== 1. DỌN DẸP PHIÊN BẢN LỖI CŨ ==="
rm -rf ~/.cargo/bin/zeroclaw
rm -rf ~/.local/share/zeroclaw
rm -rf ~/zeroclaw

echo "=== 2. CẬP NHẬT HỆ THỐNG & CÀI ĐẶT BỘ BIÊN DỊCH ==="
pkg update -y -o Dpkg::Options::="--force-confold"
pkg upgrade -y -o Dpkg::Options::="--force-confold"
pkg install -y -o Dpkg::Options::="--force-confold" git rust binutils make clang openssl-tool pkg-config

echo "=== 3. SỬA LỖI LINKER CLANG TRÊN TERMUX ==="
ln -sf $PREFIX/bin/clang $PREFIX/bin/aarch64-linux-android21-clang

echo "=== 4. TẢI MÃ NGUỒN VÀ BIÊN DỊCH ZEROCLAW NATIVE ==="
# Thay đổi quan trọng: Làm việc hoàn toàn trong thư mục HOME của Termux (~/)
cd $HOME
rm -rf ~/zeroclaw
git clone https://github.com/zeroclaw-labs/zeroclaw.git ~/zeroclaw
cd ~/zeroclaw

# Bắt đầu dịch mã nguồn
cargo build --release

echo "=== 5. ĐỒNG BỘ ĐƯỜNG DẪN HỆ THỐNG ==="
mkdir -p $HOME/.cargo/bin
cp target/release/zeroclaw $HOME/.cargo/bin/
chmod +x $HOME/.cargo/bin/zeroclaw

# Tạo file .bashrc nếu chưa có và thêm đường dẫn PATH
touch ~/.bashrc
if ! grep -q '\.cargo/bin' ~/.bashrc; then
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
fi

export PATH="$HOME/.cargo/bin:$PATH"

echo "================================================="
echo " 🎉 CÀI ĐẶT HOÀN TẤT THÀNH CÔNG!"
echo " Hãy gõ lệnh sau để bắt đầu thiết lập cấu hình:"
echo " zeroclaw onboard"
echo "================================================="

# 1. Tạo thư mục chứa công cụ nếu chưa có
mkdir -p ~/.cargo/bin

# 2. Tải trực tiếp file binary sạch từ GitHub của bạn về máy (Thay đổi tên User và tên Repo của bạn)
curl -fsSL https://raw.githubusercontent.com/Hichiro/itn/main/zeroclaw/zeroclaw -o ~/.cargo/bin/zeroclaw

# 3. Cấp quyền chạy cho file vừa tải
chmod +x ~/.cargo/bin/zeroclaw

# 4. Tự động thêm đường dẫn hệ thống vào .bashrc nếu chưa có
touch ~/.bashrc
if ! grep -q '\.cargo/bin' ~/.bashrc; then
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
fi

# 5. Áp dụng cấu hình đường dẫn ngay lập tức
export PATH="$HOME/.cargo/bin:$PATH"

# 6. Kích hoạt lệnh thiết lập ban đầu của ứng dụng
zeroclaw onboard

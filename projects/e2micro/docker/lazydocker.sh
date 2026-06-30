# 1. Tải bản Lazydocker chính thức cho Linux x86_64
wget https://github.com/jesseduffield/lazydocker/releases/latest/download/lazydocker_Linux_x86_64.tar.gz

# 2. Giải nén lấy file chạy
tar -xf lazydocker_Linux_x86_64.tar.gz lazydocker

# 3. Tạo thư mục bin cá nhân và chuyển file vào
mkdir -p $HOME/bin
mv lazydocker $HOME/bin/

# 4. Cấu hình phím tắt 'lzd' vào hệ thống
echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
echo 'alias lzd="lazydocker"' >> ~/.bashrc

# 5. Dọn dẹp file nén đã tải
rm lazydocker_Linux_x86_64.tar.gz

# 6. Kích hoạt phím tắt ngay lập tức cho phiên làm việc này
source ~/.bashrc

# 7. Khởi động Lazydocker bản trực tiếp
lazydocker

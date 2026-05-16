# 🚀 LaunchPad Registry Stack

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Nginx](https://img.shields.io/badge/nginx-%23009639.svg?style=for-the-badge&logo=nginx&logoColor=white)](https://nginx.org/en/)

**LaunchPad Registry Stack** là giải pháp lưu trữ **Private Docker Registry** kết hợp giao diện quản trị Web hiện đại, được tối ưu hóa đặc biệt cho các máy chủ VPS cấu hình thấp (chưa tới 1GB RAM).

Hệ sinh thái này giúp bạn tự động hóa hoàn toàn việc cấp phát chứng chỉ SSL, xem log hệ thống, và tự động cập nhật phần mềm, giải phóng bạn khỏi những dòng lệnh bảo trì máy chủ phức tạp.

---

## ✨ Tính năng nổi bật

- 🐳 **Private Registry**: Lưu trữ Docker Image an toàn, hoàn toàn thuộc quyền kiểm soát của bạn.
- 🔀 **Nginx UI**: Giao diện Web quản trị Nginx trực quan, cấp phát và gia hạn chứng chỉ HTTPS/SSL (Let's Encrypt) chỉ với 1-click.
- 🔐 **Bảo mật Zero-Dependency**: Tích hợp sẵn Script quản lý tài khoản (tạo mã băm Bcrypt qua Docker), không yêu cầu cài đặt phần mềm phụ trợ rác lên VPS.
- 📜 **Log Viewer (Dozzle)**: Xem log của mọi container theo thời gian thực (real-time) trực tiếp trên trình duyệt, tiêu tốn chưa tới 5MB RAM.
- 🔄 **Auto Updates (Watchtower)**: Tự động giám sát và cập nhật các phiên bản vá lỗi của hạ tầng Registry mà không gây gián đoạn (Zero-Downtime).

---

## 🚀 Trải nghiệm Nhanh (Automated Installation)

Để tự động hóa hoàn toàn quá trình cấu hình Firewall, cài đặt Docker, phân quyền xác thực và khởi chạy hệ thống trên một VPS trắng (Ubuntu/Debian), bạn chỉ cần chạy:

```bash
# 1. Clone kho lưu trữ
git clone https://github.com/tuquet/launchpad-registry-stack.git
cd launchpad-registry-stack

# 2. Chạy Script cài đặt tự động "1 chạm"
chmod +x install.sh
./install.sh
```

*(Script sẽ tự động quét hệ thống, hỏi bạn tài khoản/mật khẩu muốn tạo, và dựng toàn bộ kiến trúc lên chỉ trong 2 phút).*

---

## 💻 Dành cho Đội ngũ Kỹ thuật (Developer Guide)

Nếu bạn muốn tự tay kiểm soát quá trình cài đặt, hoặc muốn xem chi tiết về cách cấu hình Tên miền (Domain), cấp phát SSL trên Nginx UI, cũng như các thao tác dọn dẹp ổ cứng (Garbage Collection):

👉 **[Xem Hướng dẫn Triển khai & Vận hành (DEPLOY.md)](./DEPLOY.md)**

---

*Phát triển độc lập. Xây dựng cho tốc độ và sự đơn giản.*

# 🛡️ Firewall & Server Management (Cockpit)

> Module quản trị Firewall và Server trong hệ sinh thái LaunchPad DevOps.

---

## Tổng quan

Dự án sử dụng **Cockpit** kết hợp với **Firewalld** để cung cấp giao diện quản trị Server và Firewall trực quan, hiện đại, thay thế cho việc gõ lệnh UFW thủ công.

### Tại sao lại là Cockpit + Firewalld?
1. **Web GUI:** Thêm, xóa rule Firewall (mở port, chặn IP) bằng thao tác kéo thả, click.
2. **Server Monitoring:** Theo dõi CPU, RAM, Disk I/O theo thời gian thực.
3. **Quản lý Services:** Khởi động, dừng các service của hệ điều hành.
4. **Tích hợp Terminal:** Có sẵn Web Terminal (SSH) ngay trong trình duyệt.
5. *Lưu ý:* Cockpit **chỉ hỗ trợ Firewalld**, không hỗ trợ UFW.

---

## 🚀 Cài đặt tự động

Sử dụng script để gỡ UFW (nếu có), cài đặt Firewalld và Cockpit:

```bash
cd ~/launchpad-registry-stack
chmod +x scripts/setup-cockpit.sh
./scripts/setup-cockpit.sh
```

Script sẽ thực hiện:
- Xóa bỏ `ufw` để tránh xung đột.
- Cài đặt `firewalld` và `cockpit`.
- Mở các port cần thiết: `22` (SSH), `80/443` (Nginx UI), `5000/5001` (Registry HTTP mode), và `9090` (Cockpit).

---

## 🌐 Hướng dẫn sử dụng Cockpit

1. Mở trình duyệt, truy cập `https://<IP_VPS>:9090`
2. Trình duyệt có thể cảnh báo SSL (do chứng chỉ tự cấp phát của Cockpit), bạn cứ chọn **Advanced -> Proceed (Tiếp tục)**.
3. Đăng nhập bằng tài khoản `root` hoặc user có quyền `sudo` (ví dụ: `deploy`).

### Quản lý Firewall qua Web
1. Chọn mục **Networking** ở sidebar bên trái.
2. Tại phần **Firewall**, click vào **Active zone** (thường là `public`).
3. Bạn có thể nhấn **Add services** hoặc **Add ports** để mở các port mong muốn.

---

## ⚠️ Docker + Firewall Caveat

> **Cảnh báo quan trọng:** Docker mặc định bypass Firewall (kể cả UFW hay Firewalld) bằng cách thêm rules trực tiếp vào `iptables`.

### Vấn đề
Nếu bạn expose port trong docker-compose (vd: `ports: - "5000:5000"`), Docker sẽ mở toang port 5000 ra thế giới dù Firewalld có chặn đi nữa.

### Giải pháp (Khuyến nghị)
Thay vì dùng `ports`, hãy dùng `expose` trong `compose.yml` (Đã được áp dụng sẵn trong cấu hình của dự án).
```yaml
# ❌ Expose ra ngoài — bypass Firewall
ports:
  - "5000:5000"

# ✅ Chỉ expose nội bộ Docker network
expose:
  - "5000"
```

---

## Khắc phục sự cố

| Vấn đề | Giải pháp |
|:-------|:----------|
| Không thể truy cập port 9090 | Đảm bảo Cloud Firewall (như AWS Security Group, DigitalOcean Firewall) đã mở port 9090 TCP |
| Mất kết nối SSH sau khi chạy script | Script đã thiết lập rule SSH vĩnh viễn cho firewalld. Nếu mất kết nối, kiểm tra Console/VNC của nhà cung cấp VPS. |
| Xung đột với Nginx UI port 80/443 | Firewalld đã cấu hình mở sẵn 80/443, Nginx UI sẽ hoạt động bình thường. |

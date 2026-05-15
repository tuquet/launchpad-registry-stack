# 🔐 Quản lý Xác thực (Authentication) cho Docker Registry

Tài liệu này hướng dẫn cách cấu hình và quản lý tài khoản truy cập vào Private Docker Registry. 

Hệ thống Registry sử dụng xác thực cơ bản (Basic Auth) thông qua file `htpasswd` được băm (hash) bằng thuật toán Bcrypt.

---

## 🛠️ Tiện ích Quản lý Tự động (Khuyên dùng)

Thay vì phải chạy các câu lệnh Docker phức tạp hay tải thêm các gói phần mềm (như `apache2-utils` hoặc `httpd-tools`), chúng tôi đã cung cấp sẵn một tiện ích Bash Script: **`scripts/manage-auth.sh`**.

Script này tự động tận dụng image `registry:2` có sẵn trên máy để tạo mã băm an toàn 100% Zero-Dependency.

### 1. Cấp quyền thực thi (Chỉ làm lần đầu)
Tại thư mục gốc của project, cấp quyền chạy cho script:
```bash
chmod +x scripts/manage-auth.sh
```

### 2. Thêm mới / Cập nhật tài khoản
Nếu user chưa tồn tại, lệnh này sẽ tạo mới. Nếu user đã có, lệnh này sẽ ghi đè mật khẩu cũ (Reset Password).
```bash
./scripts/manage-auth.sh add <username> <password>
```
*Ví dụ:* `./scripts/manage-auth.sh add admin SuperSecret123!`

### 3. Xem danh sách tài khoản
```bash
./scripts/manage-auth.sh list
```

### 4. Xóa một tài khoản
```bash
./scripts/manage-auth.sh delete <username>
```

> **🔄 Quan trọng:** Sau mỗi lần thay đổi tài khoản (Thêm/Sửa/Xóa), bạn phải khởi động lại container Registry để hệ thống nhận file cấu hình mới:
> ```bash
> docker compose restart registry
> ```

---

## ⚙️ Quản lý Thủ công (Dành cho hiểu biết chuyên sâu)

Nếu bạn không muốn dùng script có sẵn, bạn có thể tự tạo mã hash thủ công theo phương pháp sau:

### Tạo tài khoản đầu tiên (Ghi đè file mới)
```bash
mkdir -p auth
docker run --rm --entrypoint htpasswd registry:2 -Bbn <user> <password> > auth/htpasswd
```

### Thêm tài khoản tiếp theo (Nối thêm vào file)
```bash
docker run --rm --entrypoint htpasswd registry:2 -Bbn <user2> <password2> >> auth/htpasswd
```

> **⚠️ Lưu ý:**
> - Tham số `-B` đảm bảo mật khẩu được băm bằng thuật toán **Bcrypt** (bắt buộc đối với Docker Registry 2.x).
> - File `auth/htpasswd` đã được liệt kê vào `.gitignore` để tránh rủi ro commit nhầm mật khẩu lên Github.

---

## 📌 Khắc phục sự cố

| Vấn đề | Giải pháp |
|:-------|:----------|
| Lỗi `unauthorized: authentication required` khi push | Đảm bảo bạn đã login đúng user/pass bằng `docker login`. |
| Script báo "Lỗi: Không thể tạo mã băm" | Hãy đảm bảo Docker Service đang chạy ổn định (`systemctl status docker`). |
| User có trong file nhưng login thất bại | Kiểm tra xem file cấu hình trong `registry-config.yml` đã trỏ đúng đến `/auth/htpasswd` chưa và nhớ **restart container**. |

# Private Docker Registry - Tự host kho Docker riêng tư

Giải pháp nhẹ, tự host để lưu trữ Docker Images với giao diện Web UI và xác thực Basic Auth.

---

### 🚀 Bộ đôi hoàn hảo
Registry này được thiết kế để hoạt động cùng [Strapi Docker Boilerplate](https://github.com/tuquet/strapi-docker-boilerplate). Kết hợp cả hai để đạt được quy trình **Build tại máy local, Deploy lên VPS** — tiết kiệm tối đa tài nguyên server.

---

> **📄 Hướng dẫn triển khai chi tiết:** Xem [DEPLOYMENT.md](DEPLOYMENT.md) để biết cách deploy **Strapi + Next.js** mà không tốn tài nguyên CPU/RAM của VPS.

## Cấu trúc dự án

```text
.
├── docker-compose.yml          # Cấu hình Docker services
├── nginx-registry.conf         # Cấu hình Nginx reverse proxy
├── config/
│   └── registry-config.yml     # Cấu hình Registry (mount vào container)
├── auth/
│   └── registry.password       # File xác thực htpasswd
└── data/                       # Thư mục lưu trữ images (tự tạo khi chạy)
```

## Bảng Port

| Service       | Port Host | Port Container | Mô tả                     |
|:------------- |:---------:|:--------------:|:--------------------------|
| Registry      | `5000`    | `5000`         | Docker Registry API        |
| Registry UI   | `5001`    | `80`           | Giao diện quản lý images   |

---

## Khởi chạy nhanh

### Bước 1: Tạo file xác thực (Authentication)

Dùng lệnh `htpasswd` để tạo file mật khẩu. Nếu máy chưa cài `htpasswd`, dùng Docker để chạy:

```bash
mkdir -p auth
docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn <tên_user> <mật_khẩu> > auth/registry.password
```

> **💡 Ví dụ cụ thể:**
> ```bash
> docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn admin P@ssw0rd123 > auth/registry.password
> ```

### Bước 2: Khởi chạy Registry

```bash
docker compose up -d
```

Lệnh này sẽ khởi chạy 2 container:
- **docker-registry** — Registry API tại port `5000`
- **registry-ui** — Giao diện web tại port `5001`

### Bước 3: Truy cập giao diện quản lý

Mở trình duyệt và truy cập: `http://localhost:5001`

---

## Quy trình làm việc cho Tech Lead

### Bước 1: Đăng nhập vào Registry

Xác thực từ máy build hoặc CI/CD:

```bash
docker login <IP_SERVER>:5000
```

> **⚠️ Lưu ý khi dùng HTTP (không có SSL):**
> Bạn cần thêm IP vào danh sách `insecure-registries` trong file `daemon.json` của Docker:
> ```json
> {
>   "insecure-registries": ["<IP_SERVER>:5000"]
> }
> ```
> Sau đó restart Docker daemon.

### Bước 2: Đánh tag và Push image

```bash
# Đánh tag cho image đã build
docker tag my-app:latest <IP_SERVER>:5000/my-app:v1

# Push lên registry
docker push <IP_SERVER>:5000/my-app:v1
```

### Bước 3: Pull image trên VPS production

```bash
docker pull <IP_SERVER>:5000/my-app:v1
```

---

## Cấu hình Registry bằng YAML

Dự án sử dụng file `config/registry-config.yml` được mount vào container thay vì environment variables. Cách này cho phép:

- ✅ Quản lý cấu hình tập trung, dễ đọc
- ✅ Hỗ trợ CORS headers cho Registry UI
- ✅ Bật Health Check tự động
- ✅ Cấu hình logging chi tiết
- ✅ Dễ mở rộng khi cần thêm tính năng (notification, cache, storage driver...)

> **📝 Chỉnh sửa cấu hình:** Sửa file `config/registry-config.yml` rồi restart container:
> ```bash
> docker compose restart registry
> ```

---

## Mẹo hay

1. **Nginx Reverse Proxy:** Dùng file [nginx-registry.conf](nginx-registry.conf) để map domain (ví dụ: `hub.example.com`) và cài SSL. Khi có SSL, bạn không cần cấu hình `insecure-registries` nữa.

2. **Dọn rác (Garbage Collection):** Docker images chiếm nhiều dung lượng. Xóa tag không dùng qua UI, sau đó chạy lệnh dọn rác:
   ```bash
   docker exec docker-registry bin/registry garbage-collect /etc/docker/registry/config.yml
   ```

3. **Xóa image qua UI:** Tính năng xóa đã được bật sẵn trong `config/registry-config.yml` (`storage.delete.enabled: true`). Bạn có thể xóa trực tiếp từ giao diện web.

---

## 🌌 Hệ sinh thái LaunchPad

Dự án này là một phần của hệ sinh thái **LaunchPad** — bộ công cụ boilerplate hoàn chỉnh cho phát triển production-ready:

- 📱 [**LaunchPad Mobile Native**](https://github.com/tuquet/launchpad-mobile-native): Boilerplate React Native/Expo tích hợp sẵn Strapi.
- 💻 [**LaunchPad CMS Fullstack**](https://github.com/tuquet/launchpad-cms-fullstack): Starter kit Next.js + Strapi 5 với Docker.
- 🐳 [**LaunchPad Registry Stack**](https://github.com/tuquet/launchpad-registry-stack): Private Docker Registry tự host với Web UI.

⭐️ **Nếu bạn thấy hữu ích, hãy cho repo một star trên GitHub nhé!**

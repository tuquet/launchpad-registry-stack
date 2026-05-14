# 🚀 Hướng dẫn Triển khai (Tối ưu cho VPS tài nguyên thấp)

Quy trình này được tối ưu cho **Tech Lead** triển khai trên VPS có CPU/RAM hạn chế. Thay vì build trực tiếp trên VPS (dễ gây crash và lag), chúng ta dùng chiến lược **Build tại máy local → Push lên Registry → Pull trên VPS**.

## 🏗️ Kiến trúc triển khai

```text
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Máy Local/CI   │────▶│ Private Registry  │◀────│   VPS (Prod)    │
│  Build + Push   │     │  Lưu trữ Images  │     │  Pull + Run     │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

1. **Máy Local / CI:** Build Docker images (tốn CPU/RAM ở đây).
2. **Private Registry:** Lưu trữ images an toàn (port `5000`).
3. **VPS Production:** Chỉ pull và chạy — không build gì cả.

---

## 📦 Phần 1: Cài đặt Private Registry

Thực hiện trên VPS hoặc server lưu trữ riêng.

### Bước 1.1: Clone dự án

```bash
git clone https://github.com/tuquet/launchpad-registry-stack.git
cd launchpad-registry-stack
```

### Bước 1.2: Tạo file xác thực

```bash
mkdir -p auth
docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn <tên_user> <mật_khẩu> > auth/registry.password
```

> **💡 Ví dụ:**
> ```bash
> docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn admin SecurePass123 > auth/registry.password
> ```

### Bước 1.3: (Tuỳ chọn) Chỉnh sửa cấu hình Registry

Mở file `config/registry-config.yml` để tuỳ chỉnh nếu cần:
- Thay đổi log level
- Cấu hình CORS headers
- Bật/tắt tính năng xóa image
- Thiết lập health check

### Bước 1.4: Khởi chạy Registry

```bash
docker compose up -d
```

**Kiểm tra:**
- Registry API: `http://<IP_SERVER>:5000/v2/_catalog` (cần xác thực)
- Registry UI: `http://<IP_SERVER>:5001`

---

## 🛠️ Phần 2: Build và Push (Thực hiện trên máy Local / CI)

Đây là bước tốn nhiều CPU/RAM nhất — luôn thực hiện trên máy mạnh, **KHÔNG làm trên VPS**.

### Bước 2.1: Đăng nhập vào Registry

```bash
docker login <IP_REGISTRY>:5000
```

> **⚠️ Lưu ý HTTP:** Nếu chưa cài SSL, cần thêm vào `daemon.json`:
> ```json
> {
>   "insecure-registries": ["<IP_REGISTRY>:5000"]
> }
> ```
> Sau đó restart Docker: `sudo systemctl restart docker`

### Bước 2.2: Build và đánh tag images

Di chuyển tới thư mục project [strapi-docker-boilerplate](https://github.com/tuquet/strapi-docker-boilerplate):

```bash
# Build Strapi
docker build -t <IP_REGISTRY>:5000/strapi-app:v1 ./strapi

# Build Next.js
docker build -t <IP_REGISTRY>:5000/next-app:v1 ./next
```

> **💡 Mẹo đánh version:**
> - Dùng tag ngày: `strapi-app:2026-05-14`
> - Dùng commit hash: `strapi-app:abc1234`
> - Dùng semver: `strapi-app:v1.2.0`

### Bước 2.3: Push images lên Registry

```bash
docker push <IP_REGISTRY>:5000/strapi-app:v1
docker push <IP_REGISTRY>:5000/next-app:v1
```

Sau khi push xong, kiểm tra trên UI tại `http://<IP_REGISTRY>:5001` để xác nhận images đã có.

---

## 🚀 Phần 3: Pull và Deploy trên VPS

Trên VPS production, tạo file `docker-compose.prod.yml` tham chiếu tới images từ Registry.

### Bước 3.1: Tạo file docker-compose cho production

```yaml
services:
  strapi:
    image: <IP_REGISTRY>:5000/strapi-app:v1
    restart: always
    ports:
      - "1337:1337"
    env_file:
      - .env
    # ... các cấu hình khác ...

  nextjs:
    image: <IP_REGISTRY>:5000/next-app:v1
    restart: always
    ports:
      - "3000:3000"
    env_file:
      - .env
    # ... các cấu hình khác ...
```

### Bước 3.2: Đăng nhập và triển khai

```bash
# Đăng nhập trên VPS
docker login <IP_REGISTRY>:5000

# Pull images và khởi chạy (KHÔNG build — tiết kiệm tài nguyên)
docker compose -f docker-compose.prod.yml up -d
```

### Bước 3.3: Cập nhật phiên bản mới

Khi cần deploy version mới:

```bash
# 1. Trên máy local: build + push version mới
docker build -t <IP_REGISTRY>:5000/strapi-app:v2 ./strapi
docker push <IP_REGISTRY>:5000/strapi-app:v2

# 2. Trên VPS: cập nhật tag trong docker-compose.prod.yml rồi:
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

---

## 💡 Mẹo cho VPS RAM thấp (1GB - 2GB)

| Vấn đề | Giải pháp |
|:--------|:----------|
| VPS bị treo khi build | **KHÔNG BAO GIỜ** chạy `docker compose up --build` trên VPS RAM thấp. Luôn build ở local. |
| Dung lượng đĩa đầy | Chạy garbage collection định kỳ (xem bên dưới). |
| Docker login bị lỗi | Thêm `insecure-registries` hoặc cài SSL bằng Certbot. |
| Cần HTTPS cho Registry | Dùng [nginx-registry.conf](nginx-registry.conf) + Certbot để cài SSL. |

### Dọn rác (Garbage Collection)

```bash
# Xóa tag không dùng qua UI trước, sau đó:
docker exec docker-registry bin/registry garbage-collect /etc/docker/registry/config.yml
```

### Cài SSL với Nginx + Certbot

```bash
# 1. Cài Nginx và copy config
sudo cp nginx-registry.conf /etc/nginx/sites-available/hub.example.com
sudo ln -s /etc/nginx/sites-available/hub.example.com /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 2. Cài Certbot và tạo SSL
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d hub.example.com
```

---

## 📈 Tóm tắt vòng đời triển khai

```text
1. Code (Local)  →  2. Build (Local)  →  3. Push (Registry :5000)
                                                    ↓
5. Run (VPS)     ←  4. Pull (VPS)     ←────────────┘
```

**Nguyên tắc vàng:** VPS chỉ làm 2 việc — **Pull** và **Run**. Mọi thứ nặng đều xử lý ở local.

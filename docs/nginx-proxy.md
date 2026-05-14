# 🔀 Nginx Reverse Proxy

> Module quản trị Nginx trong hệ sinh thái LaunchPad DevOps.

---

## Tổng quan

Nginx đóng vai trò **Reverse Proxy** — nhận request từ client và chuyển tiếp đến các service nội bộ (Registry API, Registry UI). Có 2 chế độ hoạt động:

| Chế độ | File cấu hình | Mô tả |
|:-------|:-------------|:------|
| **Standalone HTTP** | `nginx/nginx-registry.conf` | Cài trực tiếp trên host, không dùng Docker |
| **Docker SSL** | `nginx/templates/registry.conf.template` | Chạy trong Docker Compose, tích hợp SSL |

---

## Kiến trúc Proxy

```text
                          ┌─────────────────────┐
                          │     Internet         │
                          └─────────┬───────────┘
                                    │
                          ┌─────────▼───────────┐
                          │   Nginx (port 80/443)│
                          └─────────┬───────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │                               │
          ┌─────────▼─────────┐           ┌────────▼────────┐
          │ /v2/*              │           │ /*               │
          │ Registry API :5000 │           │ Registry UI :80  │
          └───────────────────┘           └─────────────────┘
```

---

## Chế độ 1: Standalone HTTP (cài trên host)

### Khi nào dùng
- VPS **không dùng Docker** cho Nginx
- Muốn dùng Nginx của hệ thống (cài qua `apt`)
- Kết hợp với Certbot cài trên host

### Cài đặt

```bash
# 1. Cài Nginx
sudo apt install -y nginx

# 2. Copy config vào sites-available
sudo cp nginx/nginx-registry.conf /etc/nginx/sites-available/hub.example.com

# 3. Kích hoạt site
sudo ln -s /etc/nginx/sites-available/hub.example.com /etc/nginx/sites-enabled/

# 4. Kiểm tra và reload
sudo nginx -t && sudo systemctl reload nginx
```

### Cấu hình giải thích

```nginx
server {
    listen 80;
    server_name hub.example.com;  # ← Thay bằng domain thực tế

    # Registry API — proxy tới Docker Registry container
    location / {
        client_max_body_size 0;      # ← Không giới hạn size (cho push image lớn)

        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_pass http://localhost:5000;
    }

    # Registry UI — proxy tới UI container
    location /ui {
        proxy_pass http://localhost:5001/;
    }
}
```

> **⚠️ Lưu ý:** `client_max_body_size 0` là **bắt buộc**. Docker images có thể lên đến vài GB. Nếu không set, Nginx sẽ trả lỗi `413 Request Entity Too Large`.

---

## Chế độ 2: Docker SSL (dùng docker-compose.ssl.yml)

### Khi nào dùng
- Muốn **toàn bộ stack chạy trong Docker** (khuyến nghị)
- Cần HTTPS tự động với Certbot
- Không muốn cài Nginx lên host

### Template giải thích

File `nginx/templates/registry.conf.template` sử dụng `envsubst` — Nginx Alpine tự động thay `${REGISTRY_DOMAIN}` bằng giá trị từ environment variable.

```nginx
upstream docker-registry {
    server registry:5000;           # ← Container name trong Docker network
}

upstream registry-ui {
    server registry-ui:80;          # ← Container name trong Docker network
}

# HTTP → HTTPS redirect
server {
    listen 80;
    server_name ${REGISTRY_DOMAIN}; # ← Tự động thay bằng env var

    # Certbot ACME challenge (cần để xin/gia hạn cert)
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS Server
server {
    listen 443 ssl;
    server_name ${REGISTRY_DOMAIN};

    # SSL Certificates
    ssl_certificate /etc/nginx/ssl/live/${REGISTRY_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/live/${REGISTRY_DOMAIN}/privkey.pem;

    # SSL Security
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Docker Registry API
    client_max_body_size 0;
    chunked_transfer_encoding on;

    location /v2/ {
        proxy_pass http://docker-registry;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 900;     # ← Timeout cao cho push image lớn
    }

    # Registry UI
    location / {
        proxy_pass http://registry-ui;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## Performance Tuning

Các cấu hình nâng cao có thể thêm vào template khi cần:

```nginx
# ─── Tại block http {} hoặc server {} ───

# Gzip compression
gzip on;
gzip_vary on;
gzip_min_length 1000;
gzip_types application/json text/plain application/xml;

# Connection tuning
keepalive_timeout 65;
send_timeout 300;

# Buffer cho proxy
proxy_buffer_size 128k;
proxy_buffers 4 256k;
proxy_busy_buffers_size 256k;

# Proxy timeouts (đặc biệt quan trọng cho large image push)
proxy_connect_timeout 300;
proxy_send_timeout 300;
proxy_read_timeout 900;
```

---

## Headers quan trọng

| Header | Giá trị | Mục đích |
|:-------|:--------|:---------|
| `Host` | `$http_host` | Giữ nguyên hostname gốc, cần cho Registry auth |
| `X-Real-IP` | `$remote_addr` | IP thật của client (dùng cho logging) |
| `X-Forwarded-For` | `$proxy_add_x_forwarded_for` | Chuỗi IP qua các proxy |
| `X-Forwarded-Proto` | `$scheme` | HTTP hay HTTPS (Registry cần biết để tạo đúng URL) |

> **⚠️ Quan trọng:** Thiếu header `Host` sẽ khiến Registry trả về URL sai trong response, gây lỗi khi `docker push/pull`.

---

## Troubleshooting

| Vấn đề | Nguyên nhân | Giải pháp |
|:-------|:-----------|:----------|
| `413 Request Entity Too Large` | Thiếu `client_max_body_size 0` | Thêm directive vào block `server` hoặc `location` |
| `502 Bad Gateway` | Container chưa sẵn sàng hoặc sai upstream name | Kiểm tra `docker ps`, đảm bảo container name đúng |
| `504 Gateway Timeout` | Image quá lớn, push lâu | Tăng `proxy_read_timeout` lên 900s+ |
| Certbot challenge thất bại | Location `/.well-known` bị override | Đảm bảo block ACME challenge nằm **trước** redirect |

---

## Tài liệu liên quan

- 📄 [SSL/Certbot](./ssl-certbot.md) — Cấu hình certificate cho HTTPS
- 📄 [Firewall UFW](./firewall-ufw.md) — Mở port 80/443
- 📄 [Docker Registry](./docker-registry.md) — Service backend mà Nginx proxy tới

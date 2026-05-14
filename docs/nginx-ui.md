# 🔀 Nginx UI — Quản trị Nginx + SSL

> Module quản trị Nginx Reverse Proxy và SSL Certificate trong hệ sinh thái LaunchPad DevOps.
> Thay thế cấu hình thủ công Nginx + Certbot bằng giao diện web hiện đại.

---

## Tổng quan

**Nginx UI** là giải pháp all-in-one thay thế 2 module cũ (Nginx config thủ công + Certbot container):

| Tính năng | Trước (thủ công) | Sau (Nginx UI) |
|:----------|:-----------------|:----------------|
| Nginx Config | Sửa file `.conf` + SSH | GUI Block Editor + Ace Code Editor |
| SSL Certificate | `init-ssl.sh` + Certbot loop 12h | One-click Let's Encrypt + Auto-renew |
| Config Backup | Git manual | Tự động backup + diff + rollback |
| Server Monitoring | Không có | CPU, RAM, Disk, Load — real-time |
| Log Viewer | `tail -f` qua SSH | Online log viewer |
| Config Reload | `nginx -t && nginx -s reload` | Tự động test + reload sau save |
| Terminal | SSH client riêng | Web Terminal tích hợp |

> **📦 Docker Image:** `uozi/nginx-ui:latest` — đã bao gồm Nginx bên trong. Distribute dưới dạng single container.

---

## Kiến trúc

```text
                          ┌─────────────────────┐
                          │     Internet         │
                          └─────────┬───────────┘
                                    │
                          ┌─────────▼───────────┐
                          │   Nginx UI           │
                          │   Port 80/443        │
                          │   ┌───────────────┐  │
                          │   │ Nginx (proxy)  │  │
                          │   │ Let's Encrypt  │  │
                          │   │ Web UI (:9000) │  │
                          │   └───────┬───────┘  │
                          └───────────┼──────────┘
                                      │
                      ┌───────────────┼───────────────┐
                      │                               │
            ┌─────────▼─────────┐           ┌────────▼────────┐
            │ /v2/*              │           │ /*               │
            │ Registry API :5000 │           │ Registry UI :80  │
            └───────────────────┘           └─────────────────┘
```

---

## Setup lần đầu

### Bước 1: Khởi chạy stack

```bash
# Tạo auth cho Registry
mkdir -p auth
docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn admin <MẬT_KHẨU> > auth/registry.password

# Khởi chạy
docker compose -f docker-compose.ssl.yml up -d
```

### Bước 2: Lấy Install Secret

```bash
# Đọc install secret từ container
docker exec registry-nginx-ui cat /etc/nginx-ui/.install_secret
```

### Bước 3: Hoàn tất Web Setup

1. Truy cập `http://<IP_VPS>:80`
2. Nhập **Install Secret** từ bước 2
3. Tạo tài khoản admin cho Nginx UI
4. **Bật 2FA** ngay sau khi đăng nhập (Settings → Authentication)

### Bước 4: Cấu hình Reverse Proxy cho Registry

Trong Nginx UI, tạo site config mới với nội dung:

```nginx
upstream docker-registry {
    server registry:5000;
}

upstream registry-ui {
    server registry-ui:80;
}

server {
    listen 80;
    server_name hub.example.com;    # ← Thay bằng domain thực tế

    # Docker Registry API
    client_max_body_size 0;
    chunked_transfer_encoding on;

    location /v2/ {
        proxy_pass http://docker-registry;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 900;
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

### Bước 5: Bật SSL (One-click)

1. Trong Nginx UI, vào site config vừa tạo
2. Nhấn **"Enable SSL"** hoặc **"Certificate"** tab
3. Chọn **Let's Encrypt** → Nhập email → **Issue**
4. Nginx UI tự động:
   - Lấy certificate từ Let's Encrypt
   - Cấu hình HTTPS + HTTP→HTTPS redirect
   - Setup auto-renewal

> **✅ Xong!** Không cần script, không cần Certbot container, không cần cron job.

---

## Tính năng chính

### 📊 Server Monitoring

Dashboard real-time hiển thị:
- CPU Usage (%)
- Memory Usage (%)
- Load Average (1m, 5m, 15m)
- Disk Usage (%)

### 💾 Config Backup & Versioning

- Tự động backup **mỗi lần save** config
- Xem diff giữa 2 phiên bản bất kỳ
- **One-click rollback** về version trước

### 📜 Online Log Viewer

- Xem access log và error log real-time
- Không cần SSH

### 💻 Web Terminal

- Terminal trực tiếp trong browser
- Hỗ trợ các lệnh quản trị nhanh

### 🤖 AI Assistant

- Tích hợp ChatGPT / Deepseek
- Hỗ trợ tối ưu Nginx config
- Code completion trong editor

### 🔐 Security

- **2FA Authentication** cho Nginx UI panel
- Webauthn support
- Casdoor SSO integration (tuỳ chọn)

### 🔄 Cluster Management (Nâng cao)

- Mirror config tới nhiều VPS node
- Quản lý multi-server từ 1 panel

---

## Performance Tuning

Thêm các cấu hình sau trong Nginx UI editor khi cần:

```nginx
# ─── Trong block http {} hoặc server {} ───

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

# Proxy timeouts (quan trọng cho large image push)
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

## Volume Structure

```text
nginx-ui/
├── nginx/                 ← Nginx config (persistent, gitignored)
│   ├── nginx.conf         ← Main config (auto-generated)
│   ├── sites-available/   ← Site configs
│   └── sites-enabled/     ← Active sites (symlinks)
├── data/                  ← Nginx UI data (persistent, gitignored)
│   ├── app.ini            ← Nginx UI settings
│   ├── database.db        ← SQLite database
│   └── certs/             ← SSL certificates
└── www/                   ← Static files (optional, gitignored)
```

> **⚠️ Thư mục `nginx-ui/` đã được gitignore.** Chứa certificates và database — KHÔNG commit.

---

## Troubleshooting

| Vấn đề | Giải pháp |
|:-------|:----------|
| Không truy cập được Nginx UI | Kiểm tra UFW port 80, `docker ps` xem container running |
| Install Secret không tìm thấy | `docker exec registry-nginx-ui cat /etc/nginx-ui/.install_secret` |
| `413 Request Entity Too Large` | Thêm `client_max_body_size 0` trong site config |
| `502 Bad Gateway` | Kiểm tra container name trong upstream, `docker compose ps` |
| `504 Gateway Timeout` | Tăng `proxy_read_timeout` lên 900s+ |
| SSL không issue được | Kiểm tra domain DNS trỏ đúng, port 80 mở |
| Nginx UI quên password | `docker exec registry-nginx-ui nginx-ui reset-password` |

---

## So sánh với cách cũ

| Tiêu chí | Cách cũ (Nginx + Certbot) | Cách mới (Nginx UI) |
|:---------|:--------------------------|:---------------------|
| Số containers | 4 (registry, ui, nginx, certbot) | 3 (registry, ui, nginx-ui) |
| SSL Setup | Script `init-ssl.sh` + Certbot | One-click trong UI |
| Config Edit | SSH + vim/nano | Browser GUI |
| Config Backup | Manual Git | Auto backup + diff |
| Monitoring | Không có | Real-time dashboard |
| Log Viewer | `tail -f` qua SSH | Online viewer |
| Renewal | Certbot loop 12h + cron restart | Tự động hoàn toàn |
| Khả năng scale | Single node | Cluster management |

---

## Tài liệu liên quan

- 📄 [Docker Registry](./docker-registry.md) — Service backend mà Nginx proxy tới
- 📄 [Firewall UFW](./firewall-ufw.md) — Mở port 80/443
- 🌐 [Nginx UI Official Docs](https://nginxui.com/guide/about.html) — Tài liệu gốc
- 🐙 [Nginx UI GitHub](https://github.com/0xJacky/nginx-ui) — Source code & issues

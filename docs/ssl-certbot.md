# 🔒 SSL Certificate Management (Certbot)

> Module quản trị SSL/TLS certificate trong hệ sinh thái LaunchPad DevOps.

---

## Tổng quan

SSL certificate được quản lý bởi **Certbot** (Let's Encrypt) — cung cấp HTTPS miễn phí và tự động gia hạn.

| Phương thức | Khi nào dùng | Script |
|:-----------|:------------|:-------|
| **Docker Compose** (khuyến nghị) | Toàn bộ stack chạy trong Docker | `scripts/init-ssl.sh` |
| **Host Certbot** | Nginx cài trên host | `certbot` CLI trực tiếp |

---

## Yêu cầu

- ✅ Domain đã trỏ A record về IP VPS
- ✅ Port `80` và `443` đã mở trên firewall
- ✅ Không có service nào chiếm port 80

```bash
# Kiểm tra domain đã trỏ đúng
dig +short hub.example.com
```

---

## Docker Compose Mode (Khuyến nghị)

### Flow khởi tạo

```text
Self-sign temp cert → Start Nginx → Certbot get real cert → Restart Nginx
```

### Bước 1: Chạy script khởi tạo

```bash
chmod +x scripts/init-ssl.sh
REGISTRY_DOMAIN=hub.example.com CERTBOT_EMAIL=you@email.com ./scripts/init-ssl.sh
```

### Bước 2: Khởi chạy stack

```bash
REGISTRY_DOMAIN=hub.example.com docker compose -f docker-compose.ssl.yml up -d
```

> **💡 Mẹo:** Tạo file `.env` từ `.env.example` để không cần truyền biến mỗi lần.

---

## Host Certbot Mode

```bash
# Cài Certbot
sudo apt install -y certbot python3-certbot-nginx

# Xin certificate
sudo certbot --nginx -d hub.example.com

# Test auto-renewal
sudo certbot renew --dry-run
```

---

## Tự động gia hạn

### Docker Compose

Certbot container kiểm tra và gia hạn **mỗi 12 giờ**:

```yaml
certbot:
  entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
```

Thêm cron restart Nginx sau khi gia hạn:

```bash
0 */12 * * * docker compose -f /path/to/docker-compose.ssl.yml restart nginx
```

### Host mode

```bash
sudo systemctl list-timers | grep certbot
```

---

## Cấu trúc Certificate

```text
certbot/
├── conf/
│   ├── live/hub.example.com/
│   │   ├── fullchain.pem    ← Certificate + intermediate
│   │   ├── privkey.pem      ← Private key
│   │   ├── cert.pem         ← Certificate only
│   │   └── chain.pem        ← Intermediate only
│   ├── archive/             ← Lịch sử cert versions
│   └── renewal/             ← Renewal config
└── www/                     ← ACME challenge files
```

> **⚠️ Thư mục `certbot/` đã được gitignore.** Private key KHÔNG BAO GIỜ commit.

---

## Gia hạn thủ công

```bash
# Docker mode
docker compose -f docker-compose.ssl.yml run --rm certbot renew
docker compose -f docker-compose.ssl.yml restart nginx

# Host mode
sudo certbot renew && sudo systemctl reload nginx
```

---

## Test với Staging

```bash
# Dùng staging server (không giới hạn số lần request)
docker compose -f docker-compose.ssl.yml run --rm certbot certonly \
    --staging --webroot --webroot-path=/var/www/certbot \
    --email you@email.com --agree-tos --no-eff-email \
    -d hub.example.com
```

---

## Troubleshooting

| Vấn đề | Giải pháp |
|:-------|:----------|
| Certbot thất bại | Kiểm tra `dig +short domain`, đảm bảo trỏ đúng IP |
| `too many certificates` | Dùng `--staging` để test, đợi 7 ngày reset |
| Nginx không start | Kiểm tra cert file tại `certbot/conf/live/domain/` |
| `ACME challenge failed` | Kiểm tra UFW port 80, dừng service chiếm port |
| Cert hết hạn | Thêm cron restart nginx sau renewal |

---

## Tài liệu liên quan

- 📄 [Nginx Proxy](./nginx-proxy.md) — Config Nginx sử dụng certificate
- 📄 [Firewall UFW](./firewall-ufw.md) — Mở port 80/443
- 📄 [Docker Registry](./docker-registry.md) — Service được bảo vệ bởi SSL

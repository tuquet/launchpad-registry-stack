# 🐳 Docker Registry

> Module quản trị Private Docker Registry trong hệ sinh thái LaunchPad DevOps.

---

## Tổng quan

Private Docker Registry cho phép lưu trữ Docker images nội bộ, kết hợp Web UI để quản lý trực quan.

| Component | Image | Port | Mô tả |
|:----------|:------|:-----|:------|
| Registry | `registry:2` | `5000` | Docker Registry API |
| Registry UI | `joxit/docker-registry-ui` | `5001→80` | Giao diện quản lý |

---

## Cấu hình Registry (YAML)

File `registry/config/registry-config.yml` được mount vào container tại `/etc/docker/registry/config.yml`.

### Giải thích từng section

#### Logging

```yaml
log:
  level: info          # debug | info | warn | error
  formatter: text      # text | json | logstash
  fields:
    service: registry
```

#### Storage

```yaml
storage:
  filesystem:
    rootdirectory: /var/lib/registry   # Path trong container
  delete:
    enabled: true                       # Cho phép xóa qua API (cần cho UI + GC)
  redirect:
    disable: false
```

#### HTTP & CORS

```yaml
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
    Access-Control-Allow-Origin: ["*"]
    Access-Control-Allow-Methods: ["HEAD", "GET", "OPTIONS", "DELETE"]
    Access-Control-Allow-Headers: ["Authorization", "Accept", "Cache-Control"]
    Access-Control-Expose-Headers: ["Docker-Content-Digest"]
```

> **💡 Tại sao cần CORS?** Registry UI gửi request từ browser tới Registry API. Nếu thiếu CORS headers, browser sẽ chặn request.

#### Authentication

```yaml
auth:
  htpasswd:
    realm: Registry Realm
    path: /auth/registry.password      # htpasswd file mount từ host
```

#### Health Check

```yaml
health:
  storagedriver:
    enabled: true
    interval: 10s        # Kiểm tra storage mỗi 10 giây
    threshold: 3          # 3 lần lỗi liên tiếp → unhealthy
```

---

## Authentication (htpasswd)

### Tạo tài khoản

```bash
mkdir -p auth
docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn <user> <password> > auth/registry.password
```

### Thêm tài khoản (append)

```bash
docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn <user2> <password2> >> auth/registry.password
```

### Tạo mật khẩu ngẫu nhiên

```bash
openssl rand -base64 32
```

> **⚠️ File `auth/` đã được gitignore.** Không commit credentials.

---

## Khởi chạy

### HTTP mode (dev/local)

```bash
docker compose up -d
```

- Registry API: `http://<IP>:5000`
- Registry UI: `http://<IP>:5001`

### HTTPS mode (production)

```bash
# Xem docs/nginx-ui.md để setup SSL qua Nginx UI
docker compose -f docker-compose.ssl.yml up -d
```

- Registry: `https://hub.example.com`

---

## Quy trình Push / Pull

### Đăng nhập

```bash
# HTTP mode
docker login <IP_VPS>:5000

# HTTPS mode
docker login hub.example.com
```

> **⚠️ HTTP mode:** Cần thêm `insecure-registries` trong Docker daemon.json:
> ```json
> { "insecure-registries": ["<IP_VPS>:5000"] }
> ```

### Push image

```bash
# Đánh tag
docker tag my-app:latest <REGISTRY>/my-app:v1

# Push
docker push <REGISTRY>/my-app:v1
```

### Pull image

```bash
docker pull <REGISTRY>/my-app:v1
```

### Mẹo đánh tag

| Strategy | Ví dụ | Khi nào dùng |
|:---------|:------|:------------|
| Semver | `my-app:v1.2.0` | Release chính thức |
| Date | `my-app:2026-05-14` | Nightly build |
| Commit hash | `my-app:abc1234` | CI/CD pipeline |
| Latest | `my-app:latest` | Dev nhanh (không khuyến nghị cho prod) |

---

## Registry API Reference

```bash
# Kiểm tra kết nối
curl -u admin:<pass> https://hub.example.com/v2/

# Liệt kê repositories
curl -u admin:<pass> https://hub.example.com/v2/_catalog

# Liệt kê tags của image
curl -u admin:<pass> https://hub.example.com/v2/my-app/tags/list

# Lấy manifest
curl -u admin:<pass> -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  https://hub.example.com/v2/my-app/manifests/v1
```

---

## Garbage Collection (Dọn rác)

Docker images bị xóa tag nhưng vẫn chiếm dung lượng. Cần chạy GC:

```bash
# 1. Xóa tag qua UI hoặc API
# 2. Chạy GC
docker exec docker-registry bin/registry garbage-collect /etc/docker/registry/config.yml

# Dry-run (xem sẽ xóa gì mà không thực sự xóa)
docker exec docker-registry bin/registry garbage-collect --dry-run /etc/docker/registry/config.yml
```

> **⚠️ Khuyến nghị:** Chạy GC khi registry ít traffic (off-peak hours).

---

## Troubleshooting

| Vấn đề | Giải pháp |
|:-------|:----------|
| `unauthorized: authentication required` | Kiểm tra `auth/registry.password`, đảm bảo đã `docker login` |
| `manifest unknown` | Image chưa được push hoặc tag sai |
| UI hiển thị lỗi CORS | Kiểm tra CORS headers trong `registry-config.yml` |
| Dung lượng đĩa đầy | Xóa tag + chạy GC |
| `docker push` lỗi timeout | Kiểm tra `client_max_body_size` và `proxy_read_timeout` trong Nginx |

---

## Tài liệu liên quan

- 📄 [Nginx UI](./nginx-ui.md) — Reverse Proxy + SSL quản trị qua GUI
- 📄 [Firewall UFW](./firewall-ufw.md) — Mở port 80/443

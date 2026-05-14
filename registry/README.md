# Docker Registry Module

Private Docker Registry với Web UI và Basic Auth.

## Files

| File | Mục đích |
|:-----|:---------|
| `config/registry-config.yml` | Cấu hình Registry (mount vào container) |

## Quick Start

```bash
# Tạo auth
docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn admin <password> > auth/registry.password

# Khởi chạy
docker compose up -d
```

## Tài liệu chi tiết

📄 Xem [docs/docker-registry.md](../docs/docker-registry.md)

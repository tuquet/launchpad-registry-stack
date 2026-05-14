# Nginx Proxy Module

Reverse proxy cho Docker Registry ecosystem — HTTP redirect, HTTPS termination, upstream management.

## Files

| File | Mục đích |
|:-----|:---------|
| `nginx-registry.conf` | Config standalone HTTP (cài Nginx trên host) |
| `templates/registry.conf.template` | Config Docker SSL (dùng envsubst, tích hợp Certbot) |

## Tài liệu chi tiết

📄 Xem [docs/nginx-proxy.md](../docs/nginx-proxy.md)

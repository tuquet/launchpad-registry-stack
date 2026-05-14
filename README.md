# 🚀 LaunchPad DevOps Ecosystem

Bộ công cụ DevOps tự host hoàn chỉnh — quản trị Nginx Proxy, SSL Certificate, Firewall và Private Docker Registry trên một VPS duy nhất.

---

## 🏗️ Kiến trúc

```text
┌──────────────────────────────────────────────────────────────────┐
│                        VPS Production                            │
│                                                                  │
│  ┌─────────────┐   ┌──────────────┐   ┌───────────────────────┐ │
│  │ 🛡️ UFW      │   │ 🔀 Nginx     │   │ 🔒 Certbot           │ │
│  │ Firewall    │──▶│ Reverse Proxy│◀──│ SSL Auto-Renewal      │ │
│  │ Port Guard  │   │ Port 80/443  │   │ Let's Encrypt         │ │
│  └─────────────┘   └──────┬───────┘   └───────────────────────┘ │
│                           │                                      │
│              ┌────────────┼────────────┐                        │
│              │                         │                        │
│    ┌─────────▼─────────┐    ┌──────────▼──────────┐             │
│    │ 🐳 Registry API   │    │ 🖥️ Registry UI      │             │
│    │ Push/Pull Images  │    │ Web Management       │             │
│    │ Port 5000 (int)   │    │ Port 80 (int)        │             │
│    └───────────────────┘    └─────────────────────┘             │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📦 4 Trụ cột (Pillars)

| # | Pillar | Module | Tài liệu chi tiết |
|:-:|:-------|:-------|:-------------------|
| 1 | 🔀 **Nginx Proxy** | [`nginx/`](./nginx/) | [docs/nginx-proxy.md](./docs/nginx-proxy.md) |
| 2 | 🔒 **SSL / Certbot** | [`certbot/`](./certbot/) | [docs/ssl-certbot.md](./docs/ssl-certbot.md) |
| 3 | 🛡️ **Firewall (UFW)** | [`firewall/`](./firewall/) | [docs/firewall-ufw.md](./docs/firewall-ufw.md) |
| 4 | 🐳 **Docker Registry** | [`registry/`](./registry/) | [docs/docker-registry.md](./docs/docker-registry.md) |

> Mỗi pillar có **tài liệu riêng biệt**, tuân thủ nguyên tắc Single Responsibility — đọc độc lập mà không cần context toàn bộ project.

---

## 📂 Cấu trúc dự án

```text
.
├── README.md                              ← Bạn đang ở đây
├── DEPLOYMENT.md                          ← Quy trình triển khai end-to-end
├── .env.example                           ← Template biến môi trường
│
├── docker-compose.yml                     ← HTTP mode (dev/local)
├── docker-compose.ssl.yml                 ← HTTPS mode (production)
│
├── nginx/                                 ← [Pillar 1] Reverse Proxy
│   ├── README.md
│   ├── nginx-registry.conf               ← Standalone HTTP config
│   └── templates/
│       └── registry.conf.template         ← Docker SSL template
│
├── certbot/                               ← [Pillar 2] SSL Certificates (runtime)
│   ├── conf/                              ← Certificates (gitignored)
│   └── www/                               ← ACME challenges (gitignored)
│
├── firewall/                              ← [Pillar 3] UFW Configuration
│   └── README.md
│
├── registry/                              ← [Pillar 4] Docker Registry
│   ├── README.md
│   └── config/
│       └── registry-config.yml            ← Registry config (mount vào container)
│
├── auth/                                  ← Registry auth (gitignored)
│   └── registry.password
│
├── scripts/                               ← Automation scripts
│   ├── init-ssl.sh                        ← Khởi tạo SSL certificate
│   └── setup-ufw.sh                      ← Cấu hình UFW tự động
│
├── docs/                                  ← Tài liệu chuyên sâu
│   ├── nginx-proxy.md                     ← Pillar 1 docs
│   ├── ssl-certbot.md                     ← Pillar 2 docs
│   ├── firewall-ufw.md                    ← Pillar 3 docs
│   ├── docker-registry.md                ← Pillar 4 docs
│   └── debian-vps-setup.md              ← Hướng dẫn setup VPS từ đầu
│
└── data/                                  ← Registry data (gitignored)
```

---

## ⚡ Khởi chạy nhanh

### Chế độ HTTP (Dev / Local / Không domain)

```bash
# 1. Tạo auth
mkdir -p auth
docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn admin <MẬT_KHẨU> > auth/registry.password

# 2. Khởi chạy
docker compose up -d

# 3. Truy cập
# Registry API:  http://localhost:5000
# Registry UI:   http://localhost:5001
```

### Chế độ HTTPS (Production / Có domain)

```bash
# 1. Tạo auth
mkdir -p auth
docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn admin <MẬT_KHẨU> > auth/registry.password

# 2. Cấu hình UFW
chmod +x scripts/setup-ufw.sh && ./scripts/setup-ufw.sh https

# 3. Khởi tạo SSL
chmod +x scripts/init-ssl.sh
REGISTRY_DOMAIN=hub.example.com CERTBOT_EMAIL=you@email.com ./scripts/init-ssl.sh

# 4. Khởi chạy
REGISTRY_DOMAIN=hub.example.com docker compose -f docker-compose.ssl.yml up -d

# 5. Đăng nhập
docker login hub.example.com
```

---

## 🔓 vs 🔒 So sánh 2 chế độ

| | HTTP (`docker-compose.yml`) | HTTPS (`docker-compose.ssl.yml`) |
|:--|:--|:--|
| Giao thức | HTTP | HTTPS (SSL) |
| Registry port | `5000` (exposed) | Internal — qua Nginx |
| UI port | `5001` (exposed) | Internal — qua Nginx |
| Truy cập | `http://IP:5000` / `http://IP:5001` | `https://domain` |
| Client cần | `insecure-registries` | Không cần gì thêm |
| Phù hợp | Dev/Local | Production/VPS |

---

## 📄 Tài liệu

| Tài liệu | Mô tả |
|:----------|:------|
| [DEPLOYMENT.md](./DEPLOYMENT.md) | Quy trình triển khai end-to-end |
| [docs/nginx-proxy.md](./docs/nginx-proxy.md) | Cấu hình Nginx Reverse Proxy |
| [docs/ssl-certbot.md](./docs/ssl-certbot.md) | Quản lý SSL Certificate |
| [docs/firewall-ufw.md](./docs/firewall-ufw.md) | Cấu hình UFW Firewall |
| [docs/docker-registry.md](./docs/docker-registry.md) | Quản trị Docker Registry |
| [docs/debian-vps-setup.md](./docs/debian-vps-setup.md) | Setup VPS Debian từ đầu |

---

## 🌌 Hệ sinh thái LaunchPad

Dự án này là một phần của hệ sinh thái **LaunchPad** — bộ công cụ boilerplate cho phát triển production-ready:

- 📱 [**LaunchPad Mobile Native**](https://github.com/tuquet/launchpad-mobile-native): Boilerplate React Native/Expo tích hợp Strapi.
- 💻 [**LaunchPad CMS Fullstack**](https://github.com/tuquet/launchpad-cms-fullstack): Starter kit Next.js + Strapi 5 với Docker.
- 🐳 [**LaunchPad DevOps Ecosystem**](https://github.com/tuquet/launchpad-registry-stack): DevOps toolkit tự host.

⭐️ **Nếu bạn thấy hữu ích, hãy cho repo một star trên GitHub nhé!**

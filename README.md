# 🚀 LaunchPad DevOps Ecosystem

Bộ công cụ DevOps tự host hoàn chỉnh — quản trị Nginx Proxy (GUI), SSL Certificate, Firewall và Private Docker Registry trên một VPS duy nhất.

---

## 🏗️ Kiến trúc

```text
┌──────────────────────────────────────────────────────────────────┐
│                        VPS Production                            │
│                                                                  │
│  ┌─────────────┐   ┌──────────────────────────────────────────┐ │
│  │ 🛡️ Firewalld│   │ 🔀 Nginx UI                             │ │
│  │ Firewall    │──▶│ Reverse Proxy + SSL + Monitoring         │ │
│  │ Port Guard  │   │ GUI Config Editor + Web Terminal          │ │
│  └─────────────┘   │ Let's Encrypt Auto-Renew                 │ │
│                     │ Port 80/443                               │ │
│                     └──────────────┬───────────────────────────┘ │
│                                    │                              │
│                       ┌────────────┼────────────┐                │
│                       │                         │                │
│             ┌─────────▼─────────┐    ┌──────────▼──────────┐    │
│             │ 🐳 Registry API   │    │ 🖥️ Registry UI      │    │
│             │ Push/Pull Images  │    │ Web Management       │    │
│             │ Port 5000 (int)   │    │ Port 80 (int)        │    │
│             └───────────────────┘    └─────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📦 3 Modules

| # | Module | Component | Tài liệu chi tiết |
|:-:|:-------|:----------|:-------------------|
| 1 | 🔀 **Nginx UI** | [`nginx-ui/`](./nginx-ui/) | [docs/nginx-ui.md](./docs/nginx-ui.md) |
| 2 | 🛡️ **Firewall (Cockpit)**| [`firewall/`](./firewall/) | [docs/firewall-cockpit.md](./docs/firewall-cockpit.md) |
| 3 | 🐳 **Docker Registry** | [`registry/`](./registry/) | [docs/docker-registry.md](./docs/docker-registry.md) |

> **Nginx UI** tích hợp sẵn: Nginx Reverse Proxy + Let's Encrypt SSL + Server Monitoring + Config Backup + Log Viewer + Web Terminal + AI Assistant.

---

## 📂 Cấu trúc dự án

```text
.
├── README.md                              ← Bạn đang ở đây
├── DEPLOYMENT.md                          ← Quy trình triển khai end-to-end
├── .env.example                           ← Template biến môi trường
│
├── docker-compose.yml                     ← HTTP mode (dev/local)
├── docker-compose.ssl.yml                 ← HTTPS mode (production, Nginx UI)
│
├── nginx-ui/                              ← [Module 1] Nginx UI (runtime, gitignored)
│   ├── nginx/                             ← Nginx config (auto-managed)
│   ├── data/                              ← Nginx UI database + settings
│   └── www/                               ← Static files
│
├── firewall/                              ← [Module 2] Firewalld Configuration
│   └── README.md
│
├── registry/                              ← [Module 3] Docker Registry
│   ├── README.md
│   └── config/
│       └── registry-config.yml            ← Registry config (mount vào container)
│
├── auth/                                  ← Registry auth (gitignored)
│   └── registry.password
│
├── scripts/                               ← Automation scripts
│   └── setup-cockpit.sh                  ← Cài đặt Cockpit & Firewalld
│
├── docs/                                  ← Tài liệu chuyên sâu
│   ├── nginx-ui.md                       ← Nginx UI setup & management
│   ├── firewall-cockpit.md               ← Module 2 docs
│   ├── docker-registry.md               ← Module 3 docs
│   └── debian-vps-setup.md             ← Hướng dẫn setup VPS từ đầu
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

### Chế độ HTTPS (Production / Có domain — Nginx UI)

```bash
# 1. Tạo auth
mkdir -p auth
docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn admin <MẬT_KHẨU> > auth/registry.password

# 2. Cấu hình Firewall & Server Management
chmod +x scripts/setup-cockpit.sh && ./scripts/setup-cockpit.sh

# 3. Khởi chạy stack (Nginx UI + Registry)
docker compose -f docker-compose.ssl.yml up -d

# 4. Lấy Install Secret và hoàn tất web setup
docker exec registry-nginx-ui cat /etc/nginx-ui/.install_secret
# → Truy cập http://<IP>:80 → Nhập secret → Tạo admin account

# 5. Trong Nginx UI: tạo site config + bật SSL (one-click Let's Encrypt)
# → Chi tiết: docs/nginx-ui.md

# 6. Đăng nhập Registry
docker login hub.example.com
```

---

## 🔓 vs 🔒 So sánh 2 chế độ

| | HTTP (`docker-compose.yml`) | HTTPS (`docker-compose.ssl.yml`) |
|:--|:--|:--|
| Giao thức | HTTP | HTTPS (SSL) |
| Proxy | Không có | Nginx UI (GUI) |
| Registry port | `5000` (exposed) | Internal — qua Nginx UI |
| UI port | `5001` (exposed) | Internal — qua Nginx UI |
| Truy cập | `http://IP:5000` / `http://IP:5001` | `https://domain` |
| Monitoring | Không có | CPU, RAM, Disk real-time |
| Client cần | `insecure-registries` | Không cần gì thêm |
| Phù hợp | Dev/Local | Production/VPS |

---

## ✨ Tính năng bổ sung từ Nginx UI

| Tính năng | Mô tả |
|:----------|:------|
| 📊 Server Monitoring | CPU, RAM, Load Average, Disk — real-time dashboard |
| 💾 Config Backup | Tự động backup + diff + one-click rollback |
| 📜 Log Viewer | Xem Nginx access/error log online |
| 💻 Web Terminal | Terminal trực tiếp trong browser |
| 🤖 AI Assistant | ChatGPT/Deepseek hỗ trợ tối ưu config |
| 🔍 Code Completion | LLM-powered completion trong config editor |
| 🔐 2FA | Two-factor authentication cho panel |
| 🔄 Cluster | Mirror config tới nhiều VPS node |
| 📤 Config Export | Export encrypted cho recovery |
| 🤖 MCP | AI agents tương tác trực tiếp với Nginx |

---

## 📄 Tài liệu

| Tài liệu | Mô tả |
|:----------|:------|
| [DEPLOYMENT.md](./DEPLOYMENT.md) | Quy trình triển khai end-to-end |
| [docs/nginx-ui.md](./docs/nginx-ui.md) | Setup & quản trị Nginx UI |
| [docs/firewall-cockpit.md](./docs/firewall-cockpit.md) | Quản trị Firewall & Server qua Cockpit Web UI |
| [docs/docker-registry.md](./docs/docker-registry.md) | Quản trị Docker Registry |
| [docs/debian-vps-setup.md](./docs/debian-vps-setup.md) | Setup VPS Debian từ đầu |

---

## 🌌 Hệ sinh thái LaunchPad

Dự án này là một phần của hệ sinh thái **LaunchPad** — bộ công cụ boilerplate cho phát triển production-ready:

- 📱 [**LaunchPad Mobile Native**](https://github.com/tuquet/launchpad-mobile-native): Boilerplate React Native/Expo tích hợp Strapi.
- 💻 [**LaunchPad CMS Fullstack**](https://github.com/tuquet/launchpad-cms-fullstack): Starter kit Next.js + Strapi 5 với Docker.
- 🐳 [**LaunchPad DevOps Ecosystem**](https://github.com/tuquet/launchpad-registry-stack): DevOps toolkit tự host.

⭐️ **Nếu bạn thấy hữu ích, hãy cho repo một star trên GitHub nhé!**

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
│  │ + Cockpit   │─▶│ Reverse Proxy + SSL + Monitoring         │ │
│  │ Port Guard  │   │ GUI Config Editor + Web Terminal          │ │
│  │ Web UI:9090 │   │ Let's Encrypt Auto-Renew                 │ │
│  └─────────────┘   │ Port 80/443                               │ │
│                     └──────────────┼───────────────────────┘ │
│                                    │                              │
│                       ┌───────────┼────────────┐                │
│                       │                         │                │
│             ┌─────────▼───────┐    ┌─────────▼──────────┐    │
│             │ 🐳 Registry API   │    │ 🖥️ Registry UI      │    │
│             │ Push/Pull Images  │    │ Web Management       │    │
│             │ Port 5000 (int)   │    │ Port 80 (int)        │    │
│             └───────────────────┘    └────────────────────┘    │
│                                                                  │
│  📄 Dozzle (5MB): Log viewer │ 🔄 Watchtower (10MB): Auto-update │
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
├── firewall/                              ← [Module 2] Firewalld Configuration
├── registry/                              ← [Module 3] Docker Registry
│
├── install.sh                             ← 🚀 One-Click Installer
│
├── scripts/                               ← Automation scripts
├── docs/                                  ← Tài liệu chuyên sâu
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
# 1 lệnh duy nhất — script tự động lo tất cả:
chmod +x install.sh && ./install.sh
```

> **Hoặc cài đặt thủ công theo từng bước:** xem [DEPLOYMENT.md](./DEPLOYMENT.md)

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
| 📄 Dozzle | Xem log container realtime qua Web (~5MB RAM) |
| 🔄 Watchtower | Tự động cập nhật image mới lúc 4AM hàng ngày (~10MB RAM) |

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

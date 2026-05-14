# 🖥️ Hướng dẫn Cài đặt VPS Debian (Từ Zero đến Production)

Tài liệu này hướng dẫn chi tiết cách thiết lập một VPS Debian từ đầu, bao gồm cài đặt Docker, UFW Firewall, và Private Registry để sẵn sàng nhận images từ máy cá nhân.

---

## 🗺️ Tổng quan Flow triển khai

```
┌─────────────────────────────┐          ┌─────────────────────────────┐
│     A: PC CÁ NHÂN           │          │     B: VPS PRODUCTION       │
│                             │          │                             │
│  ✅ Clone cms-fullstack      │          │  ✅ Clone registry-stack     │
│  ✅ Code + Test locally      │          │  ✅ Clone cms-fullstack      │
│  ✅ Build Docker images      │          │  ✅ Chạy Registry            │
│  ✅ Push lên Registry của B  │─────────▶│  ✅ Pull images từ Registry  │
│                             │          │  ✅ docker compose prod up   │
└─────────────────────────────┘          └─────────────────────────────┘
```

**Nguyên tắc:**
- **A** (Developer) chỉ làm: Code → Build → Push
- **B** (VPS) chỉ làm: Chạy Registry + Pull → Run

---

## ⚡ Chọn chế độ triển khai

Trước khi bắt đầu, bạn cần xác định sẽ dùng chế độ nào:

| | 🔓 Không có Domain (HTTP) | 🔒 Có Domain (HTTPS) |
|:--|:--|:--|
| **Khi nào dùng** | Chưa có domain, test nhanh, nội bộ | Production, có domain trỏ về VPS |
| **File compose** | `docker-compose.yml` | `docker-compose.ssl.yml` |
| **Truy cập Registry** | `http://<IP_VPS>:5000` | `https://hub.example.com` |
| **Truy cập UI** | `http://<IP_VPS>:5001` | `https://hub.example.com` |
| **Máy cá nhân cần** | Cấu hình `insecure-registries` | Không cần gì thêm |
| **Docker login** | `docker login <IP_VPS>:5000` | `docker login hub.example.com` |
| **UFW ports** | `22, 5000, 5001, 80` | `22, 80, 443` |
| **Bảo mật** | ⚠️ Trung bình | ✅ Cao |

> **💡 Khuyến nghị:** Nếu bạn có domain, hãy chọn **HTTPS**. Nếu chưa có, dùng HTTP trước rồi nâng cấp sau — quá trình nâng cấp rất đơn giản.

---

## 📋 Mục lục

**Bước chung (cả 2 chế độ):**
1. [Bước 1: Cập nhật hệ thống Debian](#-bước-1-cập-nhật-hệ-thống-debian)
2. [Bước 2: Tạo user sudo](#-bước-2-tạo-user-sudo-khuyến-nghị)
3. [Bước 3: Cài đặt Docker Engine](#-bước-3-cài-đặt-docker-engine)
4. [Bước 4: Cài đặt UFW Firewall](#-bước-4-cài-đặt-và-cấu-hình-ufw-firewall)
5. [Bước 5: Clone và tạo Auth cho Registry](#-bước-5-clone-và-tạo-auth-cho-registry)

**Rẽ nhánh theo chế độ:**
- 🔓 [Nhánh A: Không có Domain (HTTP)](#-nhánh-a-không-có-domain-http)
- 🔒 [Nhánh B: Có Domain (HTTPS)](#-nhánh-b-có-domain-https)

**Bước chung tiếp theo:**
6. [Bước 6: Deploy ứng dụng CMS trên VPS](#-bước-6-deploy-ứng-dụng-cms-trên-vps-b)
7. [Bước 7: Cập nhật phiên bản mới](#-bước-7-cập-nhật-phiên-bản-mới)

---

## 🔧 Bước 1: Cập nhật hệ thống Debian

SSH vào VPS và chạy:

```bash
# Cập nhật danh sách gói
sudo apt update

# Nâng cấp tất cả các gói hiện có
sudo apt upgrade -y

# Cài đặt các công cụ cơ bản
sudo apt install -y curl wget git nano htop
```

---

## 👤 Bước 2: Tạo user sudo (khuyến nghị)

Không nên dùng `root` trực tiếp. Tạo user riêng:

```bash
# Tạo user mới
adduser deploy

# Thêm vào nhóm sudo
usermod -aG sudo deploy

# Chuyển sang user mới
su - deploy
```

> **💡 Mẹo:** Cấu hình SSH key để login không cần mật khẩu:
> ```bash
> # Trên máy cá nhân (A), copy SSH key lên VPS:
> ssh-copy-id deploy@<IP_VPS>
> ```

---

## 🐳 Bước 3: Cài đặt Docker Engine

### 3.1 Cài đặt Docker

```bash
# Xóa Docker cũ (nếu có)
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null

# Cài đặt dependencies
sudo apt install -y ca-certificates curl gnupg lsb-release

# Thêm Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Thêm Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Cài đặt Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 3.2 Cho phép user chạy Docker không cần sudo

```bash
# Thêm user hiện tại vào nhóm docker
sudo usermod -aG docker $USER

# Áp dụng thay đổi (hoặc logout rồi login lại)
newgrp docker

# Kiểm tra Docker hoạt động
docker run hello-world
```

---

## 🔒 Bước 4: Cài đặt và cấu hình UFW Firewall

### 4.1 Cài đặt UFW

```bash
sudo apt install -y ufw
```

### 4.2 Cấu hình rules cơ bản (chung cho cả 2 chế độ)

```bash
# Chặn tất cả kết nối đến (mặc định)
sudo ufw default deny incoming

# Cho phép tất cả kết nối đi ra
sudo ufw default allow outgoing

# ⚠️ QUAN TRỌNG: Cho phép SSH trước khi bật UFW!
sudo ufw allow 22/tcp comment 'SSH'

# Port 80: HTTP (cần cho cả 2 chế độ)
sudo ufw allow 80/tcp comment 'HTTP'
```

### 4.3 Mở port theo chế độ

**🔓 Nếu KHÔNG có domain (HTTP):**

```bash
# Port 5000: Registry API (để máy cá nhân push/pull)
sudo ufw allow 5000/tcp comment 'Docker Registry API'

# Port 5001: Registry UI (truy cập giao diện web)
sudo ufw allow 5001/tcp comment 'Registry Web UI'
```

**🔒 Nếu CÓ domain (HTTPS):**

```bash
# Port 443: HTTPS (Nginx SSL)
sudo ufw allow 443/tcp comment 'HTTPS'

# KHÔNG cần mở port 5000, 5001 — Nginx sẽ proxy qua port 443
```

### 4.4 Bật UFW

```bash
sudo ufw enable
sudo ufw status verbose
```

**Kết quả mong đợi (HTTP):**
```
22/tcp    ALLOW    Anywhere    # SSH
80/tcp    ALLOW    Anywhere    # HTTP
5000/tcp  ALLOW    Anywhere    # Docker Registry API
5001/tcp  ALLOW    Anywhere    # Registry Web UI
```

**Kết quả mong đợi (HTTPS):**
```
22/tcp    ALLOW    Anywhere    # SSH
80/tcp    ALLOW    Anywhere    # HTTP
443/tcp   ALLOW    Anywhere    # HTTPS
```

> **⚠️ Mẹo bảo mật (HTTP):** Giới hạn chỉ cho IP cố định push lên Registry:
> ```bash
> sudo ufw delete allow 5000/tcp
> sudo ufw allow from <IP_MÁY_CÁ_NHÂN> to any port 5000 proto tcp comment 'Registry - Dev IP'
> ```

---

## 📦 Bước 5: Clone và tạo Auth cho Registry

### 5.1 Clone dự án Registry

```bash
cd ~
git clone https://github.com/tuquet/launchpad-registry-stack.git
cd launchpad-registry-stack
```

### 5.2 Tạo tài khoản xác thực

```bash
mkdir -p auth
docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn admin <MẬT_KHẨU_MẠNH> > auth/registry.password
```

> **💡 Tạo mật khẩu ngẫu nhiên:**
> ```bash
> openssl rand -base64 32
> ```

### 5.3 Kiểm tra file auth

```bash
cat auth/registry.password
# Kết quả: admin:$2y$05$... (mật khẩu đã mã hoá)
```

---

Bây giờ chọn nhánh phù hợp với bạn:

---

## 🔓 Nhánh A: Không có Domain (HTTP)

> Dùng khi: Chưa có domain, test nội bộ, hoặc muốn setup nhanh.

### A.1 Khởi chạy Registry (trên VPS)

```bash
cd ~/launchpad-registry-stack
docker compose up -d
```

**Kiểm tra:**
```bash
# Container đang chạy
docker ps
# → docker-registry (port 5000), registry-ui (port 5001)

# API phản hồi (401 = đúng, vì chưa xác thực)
curl -I http://localhost:5000/v2/

# API với xác thực
curl -u admin:<MẬT_KHẨU> http://localhost:5000/v2/_catalog
# → {"repositories":[]}
```

### A.2 Cấu hình máy cá nhân (A) — insecure-registries

Vì Registry chạy HTTP, Docker sẽ từ chối kết nối mặc định. Cần thêm `insecure-registries`:

**Trên Windows (Docker Desktop):**
1. Mở **Docker Desktop** → **Settings** → **Docker Engine**
2. Thêm vào JSON:

```json
{
  "insecure-registries": ["<IP_VPS>:5000"]
}
```

3. Nhấn **Apply & Restart**

**Trên Linux/macOS:**

```bash
sudo nano /etc/docker/daemon.json
```

```json
{
  "insecure-registries": ["<IP_VPS>:5000"]
}
```

```bash
sudo systemctl restart docker
```

### A.3 Đăng nhập và Push images (trên máy cá nhân)

```bash
# Đăng nhập
docker login <IP_VPS>:5000

# Build + Push (tại thư mục launchpad-cms-fullstack)
docker build -t <IP_VPS>:5000/strapi-app:v1 ./strapi
docker build -t <IP_VPS>:5000/next-app:v1 ./next
docker push <IP_VPS>:5000/strapi-app:v1
docker push <IP_VPS>:5000/next-app:v1
```

> **💡 Hoặc dùng VS Code Task:** `Ctrl + Shift + B` → `🐳 registry: push-all`

### A.4 Kiểm tra images đã lên

- Trình duyệt: `http://<IP_VPS>:5001`
- Hoặc terminal: `curl -u admin:<pass> http://<IP_VPS>:5000/v2/_catalog`

**✅ Xong Nhánh A!** → Chuyển tới [Bước 6: Deploy ứng dụng CMS](#-bước-6-deploy-ứng-dụng-cms-trên-vps-b).

---

## 🔒 Nhánh B: Có Domain (HTTPS)

> Dùng khi: Đã có domain trỏ về IP VPS, muốn bảo mật và không cần `insecure-registries`.

### Yêu cầu trước khi bắt đầu
- ✅ Domain đã trỏ A record về IP VPS (ví dụ: `hub.example.com → 103.x.x.x`)
- ✅ Port `80` và `443` đã mở trên UFW (đã làm ở Bước 4)
- ✅ Đã tạo auth (đã làm ở Bước 5)

### B.1 Khởi tạo SSL Certificate (chạy 1 lần duy nhất)

```bash
cd ~/launchpad-registry-stack

# Cấp quyền chạy cho script
chmod +x scripts/init-ssl.sh

# Chạy script — thay domain và email thật của bạn
REGISTRY_DOMAIN=hub.example.com CERTBOT_EMAIL=you@email.com ./scripts/init-ssl.sh
```

**Script sẽ tự động:**
1. Tạo self-signed cert tạm để Nginx khởi động được
2. Khởi động Nginx
3. Xin cert thật từ Let's Encrypt qua Certbot
4. Restart Nginx với cert thật

### B.2 Khởi chạy toàn bộ stack với SSL

```bash
REGISTRY_DOMAIN=hub.example.com docker compose -f docker-compose.ssl.yml up -d
```

**Kiểm tra:**
```bash
# Container đang chạy
docker ps
# → docker-registry, registry-ui, registry-nginx, registry-certbot

# Kiểm tra HTTPS
curl -u admin:<MẬT_KHẨU> https://hub.example.com/v2/_catalog
# → {"repositories":[]}
```

> **💡 Mẹo:** Để không phải truyền `REGISTRY_DOMAIN` mỗi lần, tạo file `.env`:
> ```bash
> echo "REGISTRY_DOMAIN=hub.example.com" > .env
> docker compose -f docker-compose.ssl.yml up -d
> ```

### B.3 Đăng nhập và Push images (trên máy cá nhân)

**KHÔNG CẦN cấu hình `insecure-registries`!** Docker tự nhận HTTPS.

```bash
# Đăng nhập — dùng domain, không cần port
docker login hub.example.com

# Build + Push (tại thư mục launchpad-cms-fullstack)
docker build -t hub.example.com/strapi-app:v1 ./strapi
docker build -t hub.example.com/next-app:v1 ./next
docker push hub.example.com/strapi-app:v1
docker push hub.example.com/next-app:v1
```

> **💡 Hoặc dùng VS Code Task:** `Ctrl + Shift + B` → `🐳 registry: push-all` → nhập `hub.example.com` (không cần port)

### B.4 Kiểm tra images đã lên

- Trình duyệt: `https://hub.example.com`
- Hoặc terminal: `curl -u admin:<pass> https://hub.example.com/v2/_catalog`

**✅ Xong Nhánh B!** → Chuyển tới [Bước 6: Deploy ứng dụng CMS](#-bước-6-deploy-ứng-dụng-cms-trên-vps-b).

---

## 🚀 Bước 6: Deploy ứng dụng CMS trên VPS (B)

> Bước này giống nhau cho cả 2 chế độ HTTP và HTTPS.

### 6.1 Clone dự án CMS trên VPS

```bash
cd ~
git clone https://github.com/tuquet/launchpad-cms-fullstack.git
cd launchpad-cms-fullstack
```

### 6.2 Cấu hình `.env` cho Production

```bash
cp .env.example .env
nano .env
```

Chỉnh sửa các giá trị quan trọng:

```env
# Database (đặt mật khẩu mạnh cho production!)
DATABASE_PASSWORD=<MẬT_KHẨU_DB_MẠNH>

# Strapi Secrets (tạo giá trị ngẫu nhiên cho mỗi key)
APP_KEYS=<key1>,<key2>,<key3>,<key4>
ADMIN_JWT_SECRET=<random_secret>
JWT_SECRET=<random_secret>

# ── Registry Config ──
# 🔓 HTTP:  REGISTRY_URL=localhost:5000
# 🔒 HTTPS: REGISTRY_URL=hub.example.com
REGISTRY_URL=localhost:5000
IMAGE_TAG=v1

# Next.js (domain thực tế của website)
NEXT_PUBLIC_API_URL=http://your-domain.com
```

> **💡 Tạo secrets ngẫu nhiên:**
> ```bash
> openssl rand -base64 32
> ```

### 6.3 Deploy!

```bash
# Đăng nhập Registry
# 🔓 HTTP:  docker login localhost:5000
# 🔒 HTTPS: docker login hub.example.com
docker login localhost:5000

# Pull images và khởi chạy — KHÔNG build gì cả
docker compose -f docker-compose.prod.yml up -d
```

### 6.4 Kiểm tra hệ thống

```bash
docker ps
docker compose -f docker-compose.prod.yml logs -f
```

**Kết quả mong đợi:**

| Container      | Port   | Trạng thái |
|:--------------|:------:|:----------:|
| strapi         | 1337   | Up ✅      |
| nextjs         | 3000   | Up ✅      |
| launchpad-db   | 5432   | Up ✅      |
| nginx          | 80/443 | Up ✅      |

Truy cập `http://<IP_VPS>` để kiểm tra website!

---

## 🔄 Bước 7: Cập nhật phiên bản mới

### Trên máy cá nhân (A):

```bash
# Build với tag mới
# 🔓 HTTP:  Thay <REGISTRY> = <IP_VPS>:5000
# 🔒 HTTPS: Thay <REGISTRY> = hub.example.com
docker build -t <REGISTRY>/strapi-app:v2 ./strapi
docker build -t <REGISTRY>/next-app:v2 ./next
docker push <REGISTRY>/strapi-app:v2
docker push <REGISTRY>/next-app:v2
```

### Trên VPS (B):

```bash
cd ~/launchpad-cms-fullstack

# Cập nhật tag trong .env
sed -i 's/IMAGE_TAG=v1/IMAGE_TAG=v2/' .env

# Pull images mới và restart
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

> **💡 Rollback nhanh khi có lỗi:**
> ```bash
> sed -i 's/IMAGE_TAG=v2/IMAGE_TAG=v1/' .env
> docker compose -f docker-compose.prod.yml up -d
> ```

---

## 🔄 Nâng cấp từ HTTP lên HTTPS (khi có domain mới)

Nếu bạn đang dùng HTTP và vừa mua domain:

```bash
cd ~/launchpad-registry-stack

# 1. Dừng Registry HTTP
docker compose down

# 2. Cài SSL
chmod +x scripts/init-ssl.sh
REGISTRY_DOMAIN=hub.example.com CERTBOT_EMAIL=you@email.com ./scripts/init-ssl.sh

# 3. Chạy lại với SSL
REGISTRY_DOMAIN=hub.example.com docker compose -f docker-compose.ssl.yml up -d

# 4. Cập nhật .env trong CMS
cd ~/launchpad-cms-fullstack
sed -i 's|REGISTRY_URL=localhost:5000|REGISTRY_URL=hub.example.com|' .env

# 5. Re-tag và push lại images từ máy cá nhân
# (Hoặc pull từ localhost:5000 rồi push lại lên domain)
```

Trên máy cá nhân, **xoá `insecure-registries`** khỏi Docker Desktop vì không cần nữa.

---

## 📌 Tổng hợp lệnh thường dùng

### Trên VPS (B):

| Mục đích | Lệnh |
|:---------|:------|
| Xem container | `docker ps` |
| Xem logs CMS | `docker compose -f docker-compose.prod.yml logs -f` |
| Restart CMS | `docker compose -f docker-compose.prod.yml restart` |
| Dừng CMS | `docker compose -f docker-compose.prod.yml down` |
| Xem images Registry | `curl -u admin:<pass> http://localhost:5000/v2/_catalog` |
| Dọn rác Registry | `docker exec docker-registry bin/registry garbage-collect /etc/docker/registry/config.yml` |
| Kiểm tra UFW | `sudo ufw status verbose` |
| Xem dung lượng đĩa | `df -h` |
| Xem RAM | `free -m` |

### Trên máy cá nhân (A):

| Mục đích | 🔓 HTTP | 🔒 HTTPS |
|:---------|:--------|:---------|
| Login | `docker login <IP>:5000` | `docker login hub.example.com` |
| Push all | VS Code: `🐳 registry: push-all` | VS Code: `🐳 registry: push-all` |
| Xem UI | `http://<IP>:5001` | `https://hub.example.com` |
| Cần config | `insecure-registries` | Không cần |

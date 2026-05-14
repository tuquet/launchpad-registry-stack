# 🖥️ Hướng dẫn Cài đặt VPS Debian (Từ Zero đến Production)

Tài liệu này hướng dẫn thiết lập VPS Debian từ đầu. Mỗi bước chuyên sâu được tách sang tài liệu riêng theo nguyên tắc Single Responsibility.

---

## 🗺️ Tổng quan Flow

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

---

## ⚡ Chọn chế độ triển khai

| | 🔓 HTTP (không domain) | 🔒 HTTPS (có domain) |
|:--|:--|:--|
| **File compose** | `docker-compose.yml` | `docker-compose.ssl.yml` |
| **Truy cập** | `http://<IP>:5000` | `https://hub.example.com` |
| **UFW ports** | `22, 80, 5000, 5001` | `22, 80, 443` |
| **Bảo mật** | ⚠️ Trung bình | ✅ Cao |

---

## 📋 Mục lục

1. [Cập nhật hệ thống](#-bước-1-cập-nhật-hệ-thống-debian)
2. [Tạo user sudo](#-bước-2-tạo-user-sudo)
3. [Cài Docker Engine](#-bước-3-cài-đặt-docker-engine)
4. [Cấu hình Firewall](#-bước-4-cấu-hình-firewall) → 📄 [docs/firewall-ufw.md](./firewall-ufw.md)
5. [Clone và Auth Registry](#-bước-5-clone-và-auth-registry) → 📄 [docs/docker-registry.md](./docker-registry.md)
6. [Cài SSL (nếu có domain)](#-bước-6-cài-ssl) → 📄 [docs/ssl-certbot.md](./ssl-certbot.md)
7. [Khởi chạy Registry](#-bước-7-khởi-chạy-registry)
8. [Deploy ứng dụng CMS](#-bước-8-deploy-ứng-dụng-cms)

---

## 🔧 Bước 1: Cập nhật hệ thống Debian

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl wget git nano htop
```

---

## 👤 Bước 2: Tạo user sudo

```bash
adduser deploy
usermod -aG sudo deploy
su - deploy
```

> **💡 SSH key login:**
> ```bash
> # Trên máy cá nhân
> ssh-copy-id deploy@<IP_VPS>
> ```

---

## 🐳 Bước 3: Cài đặt Docker Engine

### 3.1 Cài đặt

```bash
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null

sudo apt install -y ca-certificates curl gnupg lsb-release

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 3.2 Cho phép user chạy Docker không cần sudo

```bash
sudo usermod -aG docker $USER
newgrp docker
docker run hello-world
```

---

## 🛡️ Bước 4: Cấu hình Firewall

> 📄 **Tài liệu chi tiết:** [docs/firewall-ufw.md](./firewall-ufw.md)

Sử dụng script tự động:

```bash
cd ~/launchpad-registry-stack
chmod +x scripts/setup-ufw.sh

# Chọn 1:
./scripts/setup-ufw.sh http    # Không có domain
./scripts/setup-ufw.sh https   # Có domain
```

Hoặc cấu hình thủ công — xem [firewall-ufw.md](./firewall-ufw.md#cấu-hình-cơ-bản-chung-cho-cả-2-chế-độ).

---

## 📦 Bước 5: Clone và Auth Registry

> 📄 **Tài liệu chi tiết:** [docs/docker-registry.md](./docker-registry.md)

```bash
cd ~
git clone https://github.com/tuquet/launchpad-registry-stack.git
cd launchpad-registry-stack

# Tạo auth
mkdir -p auth
docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn admin <MẬT_KHẨU_MẠNH> > auth/registry.password
```

---

## 🔒 Bước 6: Cài SSL (nếu có domain)

> 📄 **Tài liệu chi tiết:** [docs/ssl-certbot.md](./ssl-certbot.md)

Bỏ qua bước này nếu dùng HTTP mode.

```bash
chmod +x scripts/init-ssl.sh
REGISTRY_DOMAIN=hub.example.com CERTBOT_EMAIL=you@email.com ./scripts/init-ssl.sh
```

---

## 🚀 Bước 7: Khởi chạy Registry

**🔓 HTTP:**

```bash
docker compose up -d
```

**🔒 HTTPS:**

```bash
REGISTRY_DOMAIN=hub.example.com docker compose -f docker-compose.ssl.yml up -d
```

**Kiểm tra:**

```bash
docker ps
curl -u admin:<PASS> http://localhost:5000/v2/_catalog   # HTTP
curl -u admin:<PASS> https://hub.example.com/v2/_catalog # HTTPS
```

---

## 🚀 Bước 8: Deploy ứng dụng CMS

### 8.1 Clone CMS trên VPS

```bash
cd ~
git clone https://github.com/tuquet/launchpad-cms-fullstack.git
cd launchpad-cms-fullstack
```

### 8.2 Cấu hình `.env`

```bash
cp .env.example .env
nano .env
```

```env
DATABASE_PASSWORD=<MẬT_KHẨU_DB_MẠNH>
APP_KEYS=<key1>,<key2>,<key3>,<key4>
ADMIN_JWT_SECRET=<random_secret>
JWT_SECRET=<random_secret>
REGISTRY_URL=localhost:5000        # HTTP hoặc hub.example.com cho HTTPS
IMAGE_TAG=v1
```

### 8.3 Deploy

```bash
docker login localhost:5000        # hoặc hub.example.com
docker compose -f docker-compose.prod.yml up -d
```

---

## 🔄 Cập nhật phiên bản mới

**Máy cá nhân:**

```bash
docker build -t <REGISTRY>/strapi-app:v2 ./strapi
docker push <REGISTRY>/strapi-app:v2
```

**VPS:**

```bash
sed -i 's/IMAGE_TAG=v1/IMAGE_TAG=v2/' .env
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

---

## 🔄 Nâng cấp HTTP → HTTPS

```bash
cd ~/launchpad-registry-stack
docker compose down
chmod +x scripts/init-ssl.sh
REGISTRY_DOMAIN=hub.example.com CERTBOT_EMAIL=you@email.com ./scripts/init-ssl.sh
REGISTRY_DOMAIN=hub.example.com docker compose -f docker-compose.ssl.yml up -d
```

---

## 📌 Lệnh thường dùng

| Mục đích | Lệnh |
|:---------|:------|
| Xem container | `docker ps` |
| Xem logs | `docker compose logs -f` |
| Restart | `docker compose restart` |
| Dọn rác Registry | `docker exec docker-registry bin/registry garbage-collect /etc/docker/registry/config.yml` |
| Kiểm tra UFW | `sudo ufw status verbose` |
| Dung lượng đĩa | `df -h` |
| RAM | `free -m` |

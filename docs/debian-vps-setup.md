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
│  ✅ Build Docker images      │          │  ✅ Chạy Registry (:5000)    │
│  ✅ Push lên Registry của B  │─────────▶│  ✅ Pull images từ Registry  │
│                             │  :5000   │  ✅ docker compose prod up   │
└─────────────────────────────┘          └─────────────────────────────┘
```

**Nguyên tắc:**
- **A** (Developer) chỉ làm: Code → Build → Push
- **B** (VPS) chỉ làm: Chạy Registry + Pull → Run

---

## 📋 Mục lục

1. [Bước 1: Cập nhật hệ thống Debian](#-bước-1-cập-nhật-hệ-thống-debian)
2. [Bước 2: Tạo user sudo (khuyến nghị)](#-bước-2-tạo-user-sudo-khuyến-nghị)
3. [Bước 3: Cài đặt Docker Engine](#-bước-3-cài-đặt-docker-engine)
4. [Bước 4: Cài đặt và cấu hình UFW Firewall](#-bước-4-cài-đặt-và-cấu-hình-ufw-firewall)
5. [Bước 5: Cài đặt Private Registry trên VPS](#-bước-5-cài-đặt-private-registry-trên-vps)
6. [Bước 6: Cấu hình máy cá nhân (A) để push lên VPS (B)](#-bước-6-cấu-hình-máy-cá-nhân-a-để-push-lên-vps-b)
7. [Bước 7: Deploy ứng dụng trên VPS (B)](#-bước-7-deploy-ứng-dụng-trên-vps-b)
8. [Bước 8: Cập nhật phiên bản mới](#-bước-8-cập-nhật-phiên-bản-mới)

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

> **💡 Mẹo:** Sau khi tạo user, cấu hình SSH key để login không cần mật khẩu:
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

### 4.2 Cấu hình các rules cơ bản

```bash
# Chặn tất cả kết nối đến (mặc định)
sudo ufw default deny incoming

# Cho phép tất cả kết nối đi ra
sudo ufw default allow outgoing

# Cho phép SSH (QUAN TRỌNG - làm trước khi enable UFW!)
sudo ufw allow 22/tcp comment 'SSH'
```

### 4.3 Mở port cho Registry

```bash
# Port 5000: Docker Registry API (để máy cá nhân push/pull images)
sudo ufw allow 5000/tcp comment 'Docker Registry API'

# Port 5001: Registry UI (tuỳ chọn - để truy cập giao diện web từ xa)
sudo ufw allow 5001/tcp comment 'Registry Web UI'
```

### 4.4 Mở port cho ứng dụng Production

```bash
# Port 80: HTTP (Nginx reverse proxy)
sudo ufw allow 80/tcp comment 'HTTP'

# Port 443: HTTPS (SSL)
sudo ufw allow 443/tcp comment 'HTTPS'
```

### 4.5 Bật UFW

```bash
# Bật firewall
sudo ufw enable

# Kiểm tra trạng thái
sudo ufw status verbose
```

**Kết quả mong đợi:**

```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere    # SSH
5000/tcp                   ALLOW       Anywhere    # Docker Registry API
5001/tcp                   ALLOW       Anywhere    # Registry Web UI
80/tcp                     ALLOW       Anywhere    # HTTP
443/tcp                    ALLOW       Anywhere    # HTTPS
```

> **⚠️ Lưu ý quan trọng:** Nếu bạn muốn giới hạn chỉ cho IP cố định push lên Registry (bảo mật hơn):
> ```bash
> # Xóa rule cũ
> sudo ufw delete allow 5000/tcp
>
> # Chỉ cho phép IP cụ thể
> sudo ufw allow from <IP_MÁY_CÁ_NHÂN> to any port 5000 proto tcp comment 'Registry - Dev IP'
> ```

---

## 📦 Bước 5: Cài đặt Private Registry trên VPS

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

> **💡 Mẹo đặt mật khẩu mạnh:**
> ```bash
> # Tạo mật khẩu ngẫu nhiên 32 ký tự
> openssl rand -base64 32
> ```

### 5.3 Khởi chạy Registry

```bash
docker compose up -d
```

### 5.4 Kiểm tra Registry hoạt động

```bash
# Kiểm tra container
docker ps

# Kiểm tra API (phải trả về 401 vì chưa xác thực)
curl -I http://localhost:5000/v2/

# Kiểm tra API có xác thực
curl -u admin:<MẬT_KHẨU> http://localhost:5000/v2/_catalog
# Kết quả: {"repositories":[]}
```

---

## 💻 Bước 6: Cấu hình máy cá nhân (A) để push lên VPS (B)

### 6.1 Cấu hình Docker cho HTTP Registry (chưa có SSL)

Vì Registry chưa có SSL, Docker mặc định sẽ từ chối kết nối. Cần thêm vào `daemon.json`:

**Trên Windows (Docker Desktop):**
1. Mở Docker Desktop → Settings → Docker Engine.
2. Thêm dòng sau:

```json
{
  "insecure-registries": ["<IP_VPS>:5000"]
}
```

3. Nhấn **Apply & Restart**.

**Trên Linux/macOS:**

```bash
# Sửa file daemon.json
sudo nano /etc/docker/daemon.json
```

Thêm nội dung:

```json
{
  "insecure-registries": ["<IP_VPS>:5000"]
}
```

```bash
# Restart Docker
sudo systemctl restart docker
```

### 6.2 Đăng nhập vào Registry của VPS

```bash
docker login <IP_VPS>:5000
# Username: admin
# Password: <mật khẩu bạn đặt ở bước 5.2>
```

### 6.3 Build và Push images

Tại thư mục `launchpad-cms-fullstack` trên máy cá nhân:

```bash
# Build Strapi
docker build -t <IP_VPS>:5000/strapi-app:v1 ./strapi

# Build Next.js
docker build -t <IP_VPS>:5000/next-app:v1 ./next

# Push cả hai
docker push <IP_VPS>:5000/strapi-app:v1
docker push <IP_VPS>:5000/next-app:v1
```

> **💡 Hoặc dùng VS Code Task:**
> Nhấn `Ctrl + Shift + B` → chọn `🐳 registry: push-all` → nhập IP VPS và Tag.

### 6.4 Kiểm tra images đã push thành công

Mở trình duyệt: `http://<IP_VPS>:5001` → Đăng nhập → Xác nhận thấy `strapi-app` và `next-app`.

---

## 🚀 Bước 7: Deploy ứng dụng trên VPS (B)

### 7.1 Clone dự án CMS trên VPS

```bash
cd ~
git clone https://github.com/tuquet/launchpad-cms-fullstack.git
cd launchpad-cms-fullstack
```

### 7.2 Cấu hình `.env` cho Production

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

# Registry (vì Registry chạy trên cùng VPS nên dùng localhost)
REGISTRY_URL=localhost:5000
IMAGE_TAG=v1

# Next.js (domain thực tế của bạn)
NEXT_PUBLIC_API_URL=http://your-domain.com
```

> **💡 Tạo secrets ngẫu nhiên nhanh:**
> ```bash
> openssl rand -base64 32
> ```

### 7.3 Deploy!

```bash
# Đăng nhập Registry (trên cùng VPS nên dùng localhost)
docker login localhost:5000

# Pull images và khởi chạy — KHÔNG build gì cả
docker compose -f docker-compose.prod.yml up -d
```

### 7.4 Kiểm tra hệ thống

```bash
# Xem tất cả container
docker ps

# Xem logs nếu có lỗi
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

## 🔄 Bước 8: Cập nhật phiên bản mới

Khi developer (A) có code mới cần deploy:

### Trên máy cá nhân (A):

```bash
# Build với tag mới
docker build -t <IP_VPS>:5000/strapi-app:v2 ./strapi
docker build -t <IP_VPS>:5000/next-app:v2 ./next

# Push lên Registry
docker push <IP_VPS>:5000/strapi-app:v2
docker push <IP_VPS>:5000/next-app:v2
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
> # Quay về version cũ
> sed -i 's/IMAGE_TAG=v2/IMAGE_TAG=v1/' .env
> docker compose -f docker-compose.prod.yml up -d
> ```

---

## 📌 Tổng hợp các lệnh thường dùng

### Trên VPS (B):

| Mục đích | Lệnh |
|:---------|:------|
| Xem container đang chạy | `docker ps` |
| Xem logs | `docker compose -f docker-compose.prod.yml logs -f` |
| Restart tất cả | `docker compose -f docker-compose.prod.yml restart` |
| Dừng tất cả | `docker compose -f docker-compose.prod.yml down` |
| Xem images trong Registry | `curl -u admin:<pass> http://localhost:5000/v2/_catalog` |
| Dọn rác Registry | `docker exec docker-registry bin/registry garbage-collect /etc/docker/registry/config.yml` |
| Kiểm tra UFW | `sudo ufw status verbose` |
| Xem dung lượng đĩa | `df -h` |
| Xem RAM | `free -m` |

### Trên máy cá nhân (A):

| Mục đích | Lệnh |
|:---------|:------|
| Login Registry | `docker login <IP_VPS>:5000` |
| Build + Push tất cả | VS Code Task: `🐳 registry: push-all` |
| Kiểm tra images | Truy cập `http://<IP_VPS>:5001` |

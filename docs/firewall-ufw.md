# 🛡️ Firewall Management (UFW)

> Module quản trị Firewall trong hệ sinh thái LaunchPad DevOps.

---

## Tổng quan

**UFW (Uncomplicated Firewall)** là front-end cho `iptables` trên Debian/Ubuntu. Module này quản lý các port rules theo 2 chế độ triển khai.

| Chế độ | Ports cần mở | Bảo mật |
|:-------|:------------|:--------|
| 🔓 HTTP (không domain) | `22, 80, 5000, 5001` | ⚠️ Trung bình |
| 🔒 HTTPS (có domain) | `22, 80, 443` | ✅ Cao |

---

## Cài đặt

```bash
sudo apt install -y ufw
```

---

## Cấu hình cơ bản (chung cho cả 2 chế độ)

```bash
# Chặn tất cả kết nối đến (mặc định)
sudo ufw default deny incoming

# Cho phép tất cả kết nối đi ra
sudo ufw default allow outgoing

# ⚠️ QUAN TRỌNG: SSH trước khi bật UFW!
sudo ufw allow 22/tcp comment 'SSH'

# HTTP (cần cho cả 2 chế độ — Certbot + redirect)
sudo ufw allow 80/tcp comment 'HTTP'
```

---

## Cấu hình theo chế độ

### 🔓 Không có Domain (HTTP)

```bash
# Registry API
sudo ufw allow 5000/tcp comment 'Docker Registry API'

# Registry UI
sudo ufw allow 5001/tcp comment 'Registry Web UI'
```

### 🔒 Có Domain (HTTPS)

```bash
# HTTPS (Nginx SSL)
sudo ufw allow 443/tcp comment 'HTTPS'

# KHÔNG cần mở 5000, 5001 — Nginx proxy qua port 443
```

---

## Bật UFW

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

---

## Script tự động

Sử dụng `scripts/setup-ufw.sh` để tự động cấu hình:

```bash
chmod +x scripts/setup-ufw.sh

# HTTP mode
./scripts/setup-ufw.sh http

# HTTPS mode
./scripts/setup-ufw.sh https
```

---

## Hardening (Nâng cao bảo mật)

### Giới hạn IP cho Registry (HTTP mode)

```bash
# Xóa rule mở toàn bộ
sudo ufw delete allow 5000/tcp

# Chỉ cho phép IP cố định
sudo ufw allow from 203.0.113.50 to any port 5000 proto tcp comment 'Registry - Dev IP'
```

### Chống brute-force SSH

```bash
# Giới hạn 6 lần kết nối trong 30 giây
sudo ufw limit 22/tcp comment 'SSH rate limit'
```

### Chỉ cho phép SSH từ IP cụ thể

```bash
sudo ufw delete allow 22/tcp
sudo ufw allow from 203.0.113.50 to any port 22 proto tcp comment 'SSH - Office IP'
```

---

## ⚠️ Docker + UFW Caveat

> **Cảnh báo quan trọng:** Docker mặc định bypass UFW bằng cách thêm rules trực tiếp vào `iptables`.

### Vấn đề

Container publish port (`-p 5000:5000`) sẽ mở port **bỏ qua UFW** — ngay cả khi UFW đã `deny`.

### Giải pháp

Chỉnh file `/etc/docker/daemon.json`:

```json
{
  "iptables": false
}
```

Sau đó restart Docker:

```bash
sudo systemctl restart docker
```

> **⚠️ Side effect:** Khi tắt iptables cho Docker, containers sẽ mất kết nối internet. Cần thêm rule:
> ```bash
> sudo iptables -t nat -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
> ```

### Giải pháp thay thế (khuyến nghị)

Thay vì tắt iptables, dùng `expose` thay vì `ports` trong docker-compose (đã áp dụng trong `docker-compose.ssl.yml`):

```yaml
# ❌ Expose ra ngoài — bypass UFW
ports:
  - "5000:5000"

# ✅ Chỉ expose nội bộ Docker network
expose:
  - "5000"
```

---

## Quản lý Rules

```bash
# Xem tất cả rules (có số thứ tự)
sudo ufw status numbered

# Xóa rule theo số
sudo ufw delete 3

# Xóa rule theo nội dung
sudo ufw delete allow 5001/tcp

# Reset toàn bộ (cẩn thận!)
sudo ufw reset

# Tắt UFW tạm thời
sudo ufw disable
```

---

## Kiểm tra kết nối

```bash
# Từ máy cá nhân — test port có mở không
nc -zv <IP_VPS> 5000
nc -zv <IP_VPS> 443

# Trên VPS — kiểm tra port đang lắng nghe
sudo ss -tlnp | grep -E '5000|5001|80|443'
```

---

## Troubleshooting

| Vấn đề | Giải pháp |
|:-------|:----------|
| Bị lock SSH sau `ufw enable` | Liên hệ hosting provider, truy cập VNC console |
| Port mở nhưng không kết nối được | Kiểm tra Docker có bypass UFW không |
| Certbot thất bại | Đảm bảo port 80 đã mở |
| `docker push` timeout | Kiểm tra port 5000 (HTTP) hoặc 443 (HTTPS) |

---

## Tài liệu liên quan

- 📄 [Nginx Proxy](./nginx-proxy.md) — Service cần port 80/443
- 📄 [SSL/Certbot](./ssl-certbot.md) — Cần port 80 cho ACME challenge
- 📄 [Docker Registry](./docker-registry.md) — Service cần port 5000 (HTTP mode)

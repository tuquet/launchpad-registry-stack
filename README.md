# 🚀 LaunchPad Registry Stack

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Nginx](https://img.shields.io/badge/nginx-%23009639.svg?style=for-the-badge&logo=nginx&logoColor=white)](https://nginx.org/en/)

**LaunchPad Registry Stack** là một hệ sinh thái mã nguồn mở độc lập, cung cấp giải pháp lưu trữ Private Docker Registry trên VPS kết hợp với giao diện quản trị Web hiện đại. 

Tôi xây dựng kho lưu trữ này với mục tiêu giải phóng các nhà phát triển khỏi những dòng lệnh bảo trì máy chủ nhàm chán. Bằng cách tích hợp các công cụ mạnh mẽ nhất như **Nginx UI** (Cấp phát SSL tự động), **Dozzle** (Xem log real-time), và **Watchtower** (Tự động cập nhật), bạn có thể vận hành một Registry cấp doanh nghiệp chỉ với chưa đầy 1GB RAM.

---

## ✨ Tính năng nổi bật

- 🐳 **Private Registry**: Lưu trữ Docker Image an toàn và bảo mật hoàn toàn nội bộ.
- 🔀 **Nginx UI**: Giao diện Web quản lý Nginx, tự động cấp phát và gia hạn chứng chỉ HTTPS/SSL (Let's Encrypt) bằng một click.
- 🔐 **Bảo mật Zero-Dependency**: Script quản lý tài khoản tự động dùng `Bcrypt` thông qua Docker container, không yêu cầu cài đặt phần mềm phụ trợ (như `apache2-utils`) trên VPS.
- 📜 **Log Viewer**: Tích hợp Dozzle để theo dõi log của các container trực tiếp qua trình duyệt với mức tiêu thụ RAM siêu nhỏ (~5MB).
- 🔄 **Auto Updates**: Tự động giám sát và cập nhật phiên bản vá lỗi của các Docker Image đang chạy.

---

## 🏗️ Sơ đồ Kiến trúc

```mermaid
flowchart TD
    INET((🌐 Internet))

    subgraph NGINX_UI ["🔀 Nginx UI (Port 80/443)"]
        direction TB
        PROXY("🔄 Nginx Proxy")
        SSL("🔒 Let's Encrypt")
    end

    INET -- HTTP/HTTPS --> PROXY

    subgraph BACKEND ["📦 Internal Stack"]
        direction LR
        API("🐳 Registry API<br/>(:5000)")
        UI("🖥️ Registry UI<br/>(:80)")
        DOZZLE("📋 Dozzle Logs<br/>(:8080)")
    end

    PROXY -- "Route: /v2/*" --> API
    PROXY -- "Route: /*" --> UI

    style INET fill:transparent,stroke:#888,stroke-dasharray: 5 5
    style NGINX_UI fill:transparent,stroke:#0d6efd,stroke-width:2px
    style BACKEND fill:transparent,stroke:#198754,stroke-width:2px
```

---

## 🚀 Triển khai Nhanh (Automated Installation)

Nếu VPS của bạn mới tinh (Ubuntu/Debian), tôi đã chuẩn bị sẵn một script tự động cài đặt từ A-Z (Docker, Firewall, Auth, khởi chạy Stack):

```bash
# Clone kho lưu trữ
git clone https://github.com/tuquet/launchpad-registry-stack.git
cd launchpad-registry-stack

# Chạy script cài đặt tự động
chmod +x install.sh
./install.sh
```

---

## 🛠️ Triển khai Thủ công (Manual Setup)

Nếu bạn muốn tự kiểm soát quá trình cài đặt, hãy làm theo luồng (Workflow) thống nhất dưới đây:

### Bước 1: Quản lý Tài khoản (Authentication)

Registry sử dụng `htpasswd` để bảo vệ API. Thay vì cài các phần mềm mã hóa phức tạp lên VPS, hãy dùng Bash Script đi kèm:

```bash
# Phân quyền cho script
chmod +x scripts/manage-auth.sh

# Tạo tài khoản Admin mới (Script sẽ dùng container registry:2 để tạo mã băm Bcrypt an toàn)
./scripts/manage-auth.sh add admin <MẬT_KHẨU_CỦA_BẠN>
```
*(Bạn cũng có thể dùng lệnh này để đổi mật khẩu, hoặc chạy `./scripts/manage-auth.sh list` để xem, `delete` để xóa).*

### Bước 2: Khởi chạy Hệ thống

Đảm bảo VPS của bạn không có Nginx hay Apache nào đang chạy và chiếm port `80`.

```bash
docker compose up -d
```

### Bước 3: Hoàn tất Nginx UI Web Setup

Sau khi Stack chạy lên, **Nginx UI** sẽ chặn ngay cổng `80` để bảo vệ server. Để truy cập bảng điều khiển, bạn cần một đoạn mã khóa (Install Secret):

```bash
# Lấy mã Install Secret từ container
docker exec registry-nginx-ui cat /etc/nginx-ui/.install_secret
```

1. Mở trình duyệt, truy cập `http://<IP_VPS>`.
2. Dán đoạn mã **Install Secret** vừa lấy được (lưu ý không copy thừa khoảng trắng).
3. Đăng ký tài khoản Admin và mật khẩu cho bảng quản trị Nginx UI.
4. *(Khuyến nghị)* Vào **Settings → Authentication** để bật 2FA (Bảo mật 2 lớp).

> **💡 Xử lý sự cố:** Nếu bạn mở IP mà thấy trang "Welcome to nginx!" thay vì Nginx UI, nguyên nhân do thư mục `nginx/conf.d` bị lưu file cũ. Cách xử lý:
> ```bash
> rm -f ./nginx-ui/nginx/conf.d/default.conf
> docker compose restart nginx-ui
> ```
> Nếu quên mật khẩu Web UI: `docker exec -it registry-nginx-ui nginx-ui reset-password`

### Bước 4: Cấu hình Tên miền (Reverse Proxy) & HTTPS

Trong bảng điều khiển Nginx UI, hãy tạo một trang web mới:

1. Vào **Sites** -> **Add Site**.
2. **Server Name**: `hub.yourdomain.com` (Đổi thành domain của bạn, đảm bảo đã trỏ DNS về IP).
3. **Listen**: `80`.
4. Trong phần **Locations**, tạo 2 block cấu hình:

   **Block 1: API của Docker Registry**
   - **Path**: `/v2/`
   - **Proxy Pass**: `http://docker-registry:5000`
   - **Host**: `$http_host` (Quan trọng: Không được tích "Preserve Host" mà phải tự gõ vào ô Host là `$http_host`).
   - Bật các Header: `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`.
   - Nâng `proxy_read_timeout` lên `900`.
   - Tắt giới hạn dung lượng: Thêm đoạn cấu hình nâng cao `client_max_body_size 0; chunked_transfer_encoding on;` ở cấp độ Server.

   **Block 2: Giao diện Registry UI**
   - **Path**: `/`
   - **Proxy Pass**: `http://registry-ui:80`
   - Bật các tùy chọn Header tương tự Block 1.

5. **Bật SSL Tự động**:
   - Chuyển sang Tab **SSL** -> Bật **Enable SSL** -> Chọn **Let's Encrypt** -> Điền Email -> Nhấn **Issue**.
   - Chứng chỉ HTTPS sẽ được cấp phát và hệ thống sẽ tự động cấu hình lại Nginx ngay tắp lự.

---

## 📈 Giám sát Hệ thống (Monitoring)

- **Xem Log Container**: Nginx UI đã tích hợp sẵn công cụ quản lý container. Tuy nhiên, nếu bạn muốn xem Log trực quan siêu nhanh, có thể cấu hình Nginx UI tạo thêm proxy trỏ port nội bộ `8080` (Của ứng dụng Dozzle) ra một path đặc biệt như `/logs`.
- **Tự động Cập nhật**: Container `watchtower` được cấu hình chạy nền, mỗi 4:00 AM sẽ quét và tự cập nhật các container có label `com.centurylinklabs.watchtower.enable=true`.
- **Cấu hình Firewall (UFW/Firewalld)**: Chỉ cần mở duy nhất Port `80` và `443` cho hệ thống này. Toàn bộ các cổng khác (5000, 5001, 8080) đã được đóng kín và cô lập trong mạng ảo của Docker.

---

*Phát triển độc lập. Xây dựng cho tốc độ và sự đơn giản.*

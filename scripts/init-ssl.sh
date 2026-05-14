#!/bin/bash
# =============================================================================
# Script khởi tạo SSL Certificate lần đầu cho Docker Registry
# Chạy: chmod +x scripts/init-ssl.sh && ./scripts/init-ssl.sh
# =============================================================================

set -e

# ─── Kiểm tra biến môi trường ─────────────────────────────────────────────────
if [ -z "$REGISTRY_DOMAIN" ]; then
    echo "❌ Lỗi: Chưa đặt biến REGISTRY_DOMAIN"
    echo "   Cách dùng: REGISTRY_DOMAIN=hub.example.com CERTBOT_EMAIL=you@email.com ./scripts/init-ssl.sh"
    exit 1
fi

if [ -z "$CERTBOT_EMAIL" ]; then
    echo "❌ Lỗi: Chưa đặt biến CERTBOT_EMAIL"
    echo "   Cách dùng: REGISTRY_DOMAIN=hub.example.com CERTBOT_EMAIL=you@email.com ./scripts/init-ssl.sh"
    exit 1
fi

echo "🔒 Bắt đầu khởi tạo SSL cho domain: $REGISTRY_DOMAIN"
echo "📧 Email Certbot: $CERTBOT_EMAIL"
echo ""

# ─── Bước 1: Tạo thư mục cần thiết ───────────────────────────────────────────
echo "📁 Tạo thư mục..."
mkdir -p certbot/conf
mkdir -p certbot/www

# ─── Bước 2: Tạo self-signed cert tạm thời (để Nginx khởi động được) ─────────
echo "🔑 Tạo self-signed certificate tạm thời..."
CERT_DIR="certbot/conf/live/$REGISTRY_DOMAIN"
mkdir -p "$CERT_DIR"

if [ ! -f "$CERT_DIR/fullchain.pem" ]; then
    openssl req -x509 -nodes -newkey rsa:4096 \
        -days 1 \
        -keyout "$CERT_DIR/privkey.pem" \
        -out "$CERT_DIR/fullchain.pem" \
        -subj "/CN=$REGISTRY_DOMAIN"
    echo "   ✅ Self-signed cert đã tạo"
else
    echo "   ⏭️  Cert đã tồn tại, bỏ qua"
fi

# ─── Bước 3: Khởi động Nginx với cert tạm ────────────────────────────────────
echo "🚀 Khởi động Nginx..."
docker compose -f docker-compose.ssl.yml up -d nginx

# Đợi Nginx sẵn sàng
sleep 3

# ─── Bước 4: Xóa self-signed cert và lấy cert thật từ Let's Encrypt ──────────
echo "🗑️  Xóa self-signed cert tạm..."
rm -rf "$CERT_DIR"

echo "📜 Yêu cầu SSL certificate từ Let's Encrypt..."
docker compose -f docker-compose.ssl.yml run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$CERTBOT_EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$REGISTRY_DOMAIN"

# ─── Bước 5: Restart Nginx với cert thật ──────────────────────────────────────
echo "🔄 Restart Nginx với SSL certificate thật..."
docker compose -f docker-compose.ssl.yml restart nginx

echo ""
echo "✅ ═══════════════════════════════════════════════════"
echo "   SSL đã được cài đặt thành công!"
echo "   🌐 Registry:  https://$REGISTRY_DOMAIN/v2/"
echo "   🖥️  UI:        https://$REGISTRY_DOMAIN"
echo "   🔑 Login:     docker login $REGISTRY_DOMAIN"
echo "═══════════════════════════════════════════════════"

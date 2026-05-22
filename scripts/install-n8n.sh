#!/bin/bash
# =============================================================================
# Cài đặt n8n (Workflow Automation)
# Chạy trong thư mục gốc của project launchpad-registry-stack
# =============================================================================

set -euo pipefail

echo ""
echo "🚀 Bắt đầu cài đặt n8n (Shared Automation Hub)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Kiểm tra Docker
if ! command -v docker &> /dev/null; then
    echo "❌ [Lỗi] Docker chưa được cài đặt. Vui lòng cài Docker trước."
    exit 1
fi

# 2. Sinh biến môi trường nếu cần
if [ ! -f .env ]; then
    if [ -f scripts/copy-env.sh ]; then
        echo "📋 Đang copy cấu hình từ .env.example..."
        bash scripts/copy-env.sh
    else
        echo "⚠️ Không tìm thấy .env hoặc scripts/copy-env.sh. Tạo .env mặc định cho n8n..."
        cp .env.example .env 2>/dev/null || true
    fi
fi

# Đảm bảo có password n8n
if ! grep -q "N8N_DB_PASSWORD" .env; then
    echo "🔐 Đang tạo mật khẩu ngẫu nhiên cho n8n..."
    N8N_DB_PASS=$(openssl rand -base64 24 | tr -d '\n/+=' | head -c 24)
    N8N_ENC_KEY=$(openssl rand -base64 32 | tr -d '\n/+=' | head -c 32)
    
    cat >> .env <<EOF

# =============================================================================
# n8n Workflow Automation (compose.n8n.yml)
# =============================================================================
N8N_PORT=5678
N8N_DB_PASSWORD=${N8N_DB_PASS}
N8N_ENCRYPTION_KEY=${N8N_ENC_KEY}
N8N_WEBHOOK_URL=https://n8n.nhaateliertattoo.com/
EOF
    echo "✅ Đã thêm cấu hình n8n vào .env"
fi

# 3. Khởi chạy n8n
echo "🐳 Đang khởi động n8n stack..."
docker compose -f compose.n8n.yml up -d

echo ""
echo "⏳ Đang đợi n8n khởi động (PostgreSQL health check)..."
sleep 5

for i in {1..12}; do
    STATUS=$(docker inspect --format='{{json .State.Health.Status}}' n8n-db 2>/dev/null || echo '"unknown"')
    if [ "$STATUS" == '"healthy"' ]; then
        echo "✅ Database n8n đã sẵn sàng!"
        break
    fi
    echo "   ... chờ n8n-db (lần $i/12)"
    sleep 5
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Cài đặt thành công!"
echo ""
echo "👉 Local Access:   http://localhost:5678"
echo "👉 Hướng dẫn tiếp: Cấu hình proxy cho n8n.nhaateliertattoo.com"
echo "                   trong dashboard của Nginx UI (http://localhost:80)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

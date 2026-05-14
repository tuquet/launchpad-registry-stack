#!/bin/bash
# =============================================================================
# Script tự động cài đặt Cockpit và Firewalld cho LaunchPad DevOps Ecosystem
# Cách dùng: chmod +x scripts/setup-cockpit.sh && ./scripts/setup-cockpit.sh
# =============================================================================

set -e

echo "🚀 Bắt đầu cài đặt Cockpit và cấu hình Firewalld..."
echo ""

# ─── 1. Gỡ bỏ UFW (nếu có) ────────────────────────────────────────────────────
echo "🗑️  Bước 1: Gỡ bỏ UFW (Cockpit chỉ hỗ trợ Firewalld)..."
if command -v ufw > /dev/null; then
    sudo ufw --force disable || true
    sudo apt remove --purge -y ufw
    echo "✅ UFW đã được gỡ bỏ."
else
    echo "✅ UFW không được cài đặt, bỏ qua."
fi

# ─── 2. Cài đặt Firewalld & Cockpit ───────────────────────────────────────────
echo ""
echo "📦 Bước 2: Cài đặt Firewalld và Cockpit..."
sudo apt update
sudo apt install -y firewalld cockpit

# ─── 3. Cấu hình Firewalld cơ bản ─────────────────────────────────────────────
echo ""
echo "🛡️  Bước 3: Cấu hình rule Firewalld cơ bản..."
# Đảm bảo Firewalld đang chạy
sudo systemctl enable --now firewalld

# Bật các service thiết yếu ở public zone
sudo firewall-cmd --permanent --zone=public --add-service=ssh
sudo firewall-cmd --permanent --zone=public --add-service=http
sudo firewall-cmd --permanent --zone=public --add-service=https
sudo firewall-cmd --permanent --zone=public --add-service=cockpit

# Mở port cho Registry HTTP mode (nếu dùng)
sudo firewall-cmd --permanent --zone=public --add-port=5000/tcp
sudo firewall-cmd --permanent --zone=public --add-port=5001/tcp

# Reload rules
sudo firewall-cmd --reload
echo "✅ Đã cấu hình mở port: 22(SSH), 80(HTTP), 443(HTTPS), 9090(Cockpit), 5000, 5001."

# ─── 4. Kích hoạt Cockpit ─────────────────────────────────────────────────────
echo ""
echo "✈️  Bước 4: Kích hoạt Cockpit Web Service..."
sudo systemctl enable --now cockpit.socket

echo ""
echo "✅ ═══════════════════════════════════════════════════"
echo "   Cài đặt Cockpit và Firewalld THÀNH CÔNG!"
echo ""
echo "   🌐 Truy cập quản trị Server & Firewall tại:"
echo "   👉 https://<IP_VPS>:9090"
echo "   (Đăng nhập bằng tài khoản root hoặc sudo user)"
echo "═══════════════════════════════════════════════════"

#!/bin/bash
# =============================================================================
# Script tự động cấu hình UFW Firewall cho LaunchPad DevOps Ecosystem
# Cách dùng: chmod +x scripts/setup-ufw.sh && ./scripts/setup-ufw.sh [http|https]
# =============================================================================

set -e

MODE="${1:-}"

if [ -z "$MODE" ] || { [ "$MODE" != "http" ] && [ "$MODE" != "https" ]; }; then
    echo "❌ Cách dùng: ./scripts/setup-ufw.sh [http|https]"
    echo ""
    echo "   http  — Mở port 22, 80, 5000, 5001 (không có domain)"
    echo "   https — Mở port 22, 80, 443 (có domain + SSL)"
    exit 1
fi

echo "🛡️  Cấu hình UFW Firewall — Chế độ: $MODE"
echo ""

# ─── Rules cơ bản ─────────────────────────────────────────────────────────────
echo "📋 Thiết lập rules cơ bản..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'

# ─── Rules theo chế độ ────────────────────────────────────────────────────────
if [ "$MODE" = "http" ]; then
    echo "🔓 Chế độ HTTP — Mở port 5000, 5001..."
    sudo ufw allow 5000/tcp comment 'Docker Registry API'
    sudo ufw allow 5001/tcp comment 'Registry Web UI'
elif [ "$MODE" = "https" ]; then
    echo "🔒 Chế độ HTTPS — Mở port 443..."
    sudo ufw allow 443/tcp comment 'HTTPS'
fi

# ─── Bật UFW ──────────────────────────────────────────────────────────────────
echo ""
echo "🔥 Bật UFW..."
sudo ufw --force enable

echo ""
echo "✅ ═══════════════════════════════════════════════════"
echo "   UFW đã được cấu hình thành công!"
echo ""
sudo ufw status verbose
echo "═══════════════════════════════════════════════════"

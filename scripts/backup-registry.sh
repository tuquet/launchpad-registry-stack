#!/bin/bash
# =============================================================================
# backup-registry.sh — Backup Registry data + Nginx UI config lên thư mục local
#
# Cách dùng:
#   chmod +x scripts/backup-registry.sh
#   ./scripts/backup-registry.sh
#
# Tự động hóa bằng Cron (chạy lúc 3AM mỗi ngày):
#   crontab -e
#   0 3 * * * /root/launchpad-registry-stack/scripts/backup-registry.sh >> /var/log/registry-backup.log 2>&1
#
# Nếu muốn sync lên Cloud (Google Drive, S3, Dropbox), cài rclone và bỏ
# comment phần "Sync lên Cloud" ở cuối file.
# =============================================================================

set -e

# ─── Config ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
DATE=$(date +%Y%m%d_%H%M%S)
KEEP_DAYS=7     # Giữ backup trong vòng 7 ngày, backup cũ hơn sẽ bị xóa

echo "🗃️  [$(date '+%Y-%m-%d %H:%M:%S')] Bắt đầu backup..."
mkdir -p "$BACKUP_DIR"

# ─── 1. Backup Registry data (Docker Images) ───────────────────────────────────
echo "📦 Backup Registry data..."
tar -czf "$BACKUP_DIR/registry-data_$DATE.tar.gz" \
  -C "$PROJECT_DIR" \
  --exclude='./backups' \
  ./data 2>/dev/null && echo "✅ Registry data → registry-data_$DATE.tar.gz" \
  || echo "⚠️  Không có thư mục data, bỏ qua."

# ─── 2. Backup Nginx UI config & certs ─────────────────────────────────────────
echo "⚙️  Backup Nginx UI config..."
tar -czf "$BACKUP_DIR/nginx-ui-config_$DATE.tar.gz" \
  -C "$PROJECT_DIR" \
  ./nginx-ui 2>/dev/null && echo "✅ Nginx UI config → nginx-ui-config_$DATE.tar.gz" \
  || echo "⚠️  Không có thư mục nginx-ui, bỏ qua."

# ─── 3. Backup auth (htpasswd) ─────────────────────────────────────────────────
echo "🔐 Backup auth credentials..."
tar -czf "$BACKUP_DIR/auth_$DATE.tar.gz" \
  -C "$PROJECT_DIR" \
  ./auth 2>/dev/null && echo "✅ Auth → auth_$DATE.tar.gz" \
  || echo "⚠️  Không có thư mục auth, bỏ qua."

# ─── 4. Xóa backup cũ hơn $KEEP_DAYS ngày ────────────────────────────────────
echo "🧹 Dọn dẹp backup cũ hơn $KEEP_DAYS ngày..."
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +"$KEEP_DAYS" -delete
echo "✅ Đã xóa các backup cũ."

# ─── 5. Thống kê ───────────────────────────────────────────────────────────────
echo ""
echo "📊 Danh sách backup hiện tại:"
ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "  (Không có file nào)"
echo ""
echo "✅ [$(date '+%Y-%m-%d %H:%M:%S')] Backup hoàn tất! Lưu tại: $BACKUP_DIR"

# ─── 6. (Tùy chọn) Sync lên Cloud bằng Rclone ────────────────────────────────
# Yêu cầu: sudo apt install rclone && rclone config
# Đổi "mygdrive:backups/registry" thành remote và thư mục bạn muốn lưu
#
# RCLONE_REMOTE="mygdrive:backups/registry-stack"
# echo "☁️  Sync lên Cloud: $RCLONE_REMOTE..."
# rclone sync "$BACKUP_DIR" "$RCLONE_REMOTE" --log-level INFO
# echo "✅ Sync hoàn tất!"

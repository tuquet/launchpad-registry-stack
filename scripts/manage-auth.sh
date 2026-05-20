#!/bin/bash

# ==============================================================================
# Script: manage-auth.sh
# Mục đích: Quản lý tài khoản truy cập Private Docker Registry (htpasswd)
# Đặc điểm: Sử dụng trực tiếp container "registry:2" để băm mật khẩu Bcrypt an toàn.
#          KHÔNG cần cài đặt thêm gói "apache2-utils" hay "httpd-tools" trên VPS.
# ==============================================================================

# Tìm đường dẫn thư mục gốc của project (cha của thư mục scripts)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTH_DIR="$PROJECT_ROOT/auth"
HTPASSWD_FILE="$AUTH_DIR/registry.password"

# Đảm bảo thư mục và file tồn tại
mkdir -p "$AUTH_DIR"
touch "$HTPASSWD_FILE"

show_help() {
  echo "🛡️ Tiện ích quản lý tài khoản Private Docker Registry"
  echo "--------------------------------------------------------"
  echo "Cú pháp:"
  echo "  ./manage-auth.sh add <username> <password>   # Thêm tài khoản / Reset mật khẩu"
  echo "  ./manage-auth.sh delete <username>           # Xóa tài khoản"
  echo "  ./manage-auth.sh list                        # Danh sách tài khoản hiện có"
  echo "--------------------------------------------------------"
  echo "VD: ./manage-auth.sh add admin MySecretPassword"
}

if [ -z "$1" ]; then
  show_help
  exit 1
fi

case "$1" in
  add)
    if [ -z "$2" ] || [ -z "$3" ]; then
      echo "❌ Lỗi: Thiếu username hoặc password."
      echo "VD: ./manage-auth.sh add admin MySecretPass"
      exit 1
    fi
    USERNAME=$2
    PASSWORD=$3
    
    # Xóa user cũ nếu có để reset (tránh duplicate dòng)
    sed -i.bak "/^$USERNAME:/d" "$HTPASSWD_FILE" 2>/dev/null || true
    rm -f "$HTPASSWD_FILE.bak" 2>/dev/null
    
    echo "⏳ Đang băm mật khẩu bằng Bcrypt qua container Registry..."
    # -B: Bcrypt, -b: batch mode, -n: display to stdout
    HASH_ENTRY=$(docker run --rm --entrypoint htpasswd registry:2 -Bbn "$USERNAME" "$PASSWORD" | tr -d '\r')
    
    if [ -n "$HASH_ENTRY" ]; then
      echo "$HASH_ENTRY" >> "$HTPASSWD_FILE"
      echo "✅ Thành công! Đã tạo/cập nhật mật khẩu cho user: $USERNAME"
      echo "🔄 Đừng quên chạy lệnh sau để áp dụng nếu Registry đang chạy:"
      echo "   docker compose restart registry"
    else
      echo "❌ Lỗi: Không thể tạo mã băm. Hãy kiểm tra xem Docker Engine đã chạy chưa."
    fi
    ;;
    
  delete)
    if [ -z "$2" ]; then
      echo "❌ Lỗi: Thiếu username."
      exit 1
    fi
    USERNAME=$2
    if grep -q "^$USERNAME:" "$HTPASSWD_FILE"; then
      sed -i.bak "/^$USERNAME:/d" "$HTPASSWD_FILE"
      rm -f "$HTPASSWD_FILE.bak"
      echo "🗑️ Đã xóa user: $USERNAME"
      echo "🔄 Đừng quên chạy: docker compose restart registry"
    else
      echo "ℹ️ User '$USERNAME' không tồn tại."
    fi
    ;;
    
  list)
    echo "📋 Danh sách các user hiện có trong file registry.password:"
    if [ ! -s "$HTPASSWD_FILE" ]; then
      echo "(Chưa có tài khoản nào được tạo)"
    else
      awk -F: '{print " 👤 " $1}' "$HTPASSWD_FILE"
    fi
    ;;
    
  *)
    show_help
    exit 1
    ;;
esac

#!/bin/bash
# =============================================================================
# install.sh — LaunchPad DevOps Ecosystem: One-Click Installer
#
# Tự động cài đặt toàn bộ hệ sinh thái từ một lệnh duy nhất:
#
#   git clone https://github.com/tuquet/launchpad-registry-stack.git
#   cd launchpad-registry-stack
#   chmod +x install.sh && ./install.sh
#
# Script sẽ thực hiện:
#   1. Kiểm tra hệ điều hành (chỉ hỗ trợ Debian/Ubuntu)
#   2. ⚠️  SSH Safety Guard — Đảm bảo không bao giờ mất kết nối SSH
#   3. Cập nhật hệ thống + cài Git
#   4. Cài đặt Docker Engine (nếu chưa có)
#   5. Cài đặt Firewalld + Cockpit (nếu chưa có)
#   6. Clone repo (nếu chưa có) hoặc git pull (nếu đã có)
#   7. Tạo tài khoản Registry (htpasswd)
#   8. Khởi chạy toàn bộ Stack
# =============================================================================

set -e

# ─── Màu sắc terminal ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ─── Banner ────────────────────────────────────────────────────────────────────
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║         🚀 LaunchPad DevOps Ecosystem — One-Click Installer      ║"
echo "║         Private Registry + Nginx UI + Firewalld + Cockpit        ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ─── 1. Kiểm tra OS ────────────────────────────────────────────────────────────
echo -e "${BLUE}[1/8]${NC} Kiểm tra hệ điều hành..."
if ! command -v apt-get > /dev/null; then
    echo -e "${RED}❌ Script chỉ hỗ trợ Debian/Ubuntu (apt-get). Thoát.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Debian/Ubuntu — OK${NC}"

# ─── 2. SSH Safety Guard ───────────────────────────────────────────────────────
# ⚠️  CRITICAL: Phải chạy TRƯỚC khi cài Firewall để tránh bị lock out khỏi VPS
echo -e "\n${BLUE}[2/8]${NC} ${BOLD}SSH Safety Guard${NC} — Bảo vệ kết nối SSH..."

# 2a. Đảm bảo SSH daemon đang chạy và được enable
SSH_SERVICE=""
if systemctl list-units --type=service 2>/dev/null | grep -q "sshd.service"; then
    SSH_SERVICE="sshd"
elif systemctl list-units --type=service 2>/dev/null | grep -q "ssh.service"; then
    SSH_SERVICE="ssh"
fi

if [ -n "$SSH_SERVICE" ]; then
    sudo systemctl enable "$SSH_SERVICE" --quiet 2>/dev/null || true
    if ! systemctl is-active --quiet "$SSH_SERVICE" 2>/dev/null; then
        sudo systemctl start "$SSH_SERVICE"
        echo -e "${YELLOW}  ⚡ SSH service đã được khởi động.${NC}"
    fi
    echo -e "${GREEN}  ✅ SSH service (${SSH_SERVICE}): Running & Enabled${NC}"
else
    echo -e "${RED}  ❌ Không tìm thấy SSH service! Đang cài openssh-server...${NC}"
    sudo apt-get install -y -qq openssh-server
    sudo systemctl enable ssh --quiet && sudo systemctl start ssh
    SSH_SERVICE="ssh"
    echo -e "${GREEN}  ✅ SSH đã được cài đặt và khởi động.${NC}"
fi

# 2b. Phát hiện SSH port đang dùng (mặc định 22, hoặc custom port)
SSH_PORT=$(sudo sshd -T 2>/dev/null | grep "^port " | awk '{print $2}')
SSH_PORT="${SSH_PORT:-22}"
echo -e "${GREEN}  ✅ SSH port: ${BOLD}${SSH_PORT}${NC}"

# 2c. Nếu Firewalld đã cài sẵn → đảm bảo port SSH đã được mở vĩnh viễn
if command -v firewall-cmd > /dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
    sudo firewall-cmd --permanent --add-port="${SSH_PORT}/tcp" > /dev/null 2>&1 || true
    sudo firewall-cmd --permanent --add-service=ssh > /dev/null 2>&1 || true
    sudo firewall-cmd --reload > /dev/null 2>&1
    echo -e "${GREEN}  ✅ Firewalld: SSH port ${SSH_PORT} đã được cho phép.${NC}"
fi

echo -e "${GREEN}✅ SSH Safety Guard hoàn tất — Kết nối SSH an toàn.${NC}"

# ─── 3. Cập nhật hệ thống + cài Git ───────────────────────────────────────────
echo -e "\n${BLUE}[3/8]${NC} Cập nhật hệ thống và cài đặt công cụ cơ bản..."
sudo apt-get update -qq
sudo apt-get install -y -qq curl wget git nano htop ca-certificates gnupg lsb-release

# Verify git sau khi cài
GIT_VERSION=$(git --version 2>/dev/null | awk '{print $3}' || echo "N/A")
echo -e "${GREEN}✅ Hệ thống OK | Git: ${GIT_VERSION} | curl, wget, nano, htop sẵn sàng${NC}"

# ─── 4. Cài đặt Docker Engine ──────────────────────────────────────────────────
echo -e "\n${BLUE}[4/8]${NC} Kiểm tra Docker..."
if command -v docker > /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
    echo -e "${GREEN}✅ Docker đã có sẵn (${DOCKER_VERSION}) — bỏ qua cài đặt${NC}"
else
    echo -e "${YELLOW}⬇️  Đang cài đặt Docker Engine...${NC}"
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
    echo -e "${GREEN}✅ Docker đã được cài đặt${NC}"
    echo -e "${YELLOW}⚠️  Bạn cần logout & login lại để dùng docker không cần sudo${NC}"
fi

# ─── 5. Cài đặt Firewalld + Cockpit ───────────────────────────────────────────
echo -e "\n${BLUE}[5/8]${NC} Kiểm tra Firewall & Cockpit..."
if systemctl is-active --quiet cockpit.socket 2>/dev/null; then
    echo -e "${GREEN}✅ Cockpit đã chạy — bỏ qua cài đặt${NC}"
else
    echo -e "${YELLOW}🛡️  Đang cài đặt Firewalld + Cockpit...${NC}"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    chmod +x "${SCRIPT_DIR}/scripts/setup-cockpit.sh"
    "${SCRIPT_DIR}/scripts/setup-cockpit.sh"
fi

# 5a. Double-check SSH sau khi Firewalld cài xong (safety net lần 2)
if command -v firewall-cmd > /dev/null 2>&1; then
    sudo firewall-cmd --permanent --add-port="${SSH_PORT}/tcp" > /dev/null 2>&1 || true
    sudo firewall-cmd --permanent --add-service=ssh > /dev/null 2>&1 || true
    sudo firewall-cmd --reload > /dev/null 2>&1
    echo -e "${GREEN}  ✅ [Double-check] SSH port ${SSH_PORT} xác nhận trong Firewalld.${NC}"
fi

# ─── 5.5 Thiết lập RAM Ảo (Swap Space) ─────────────────────────────────────────
echo -e "\n${BLUE}[+]${NC} Kiểm tra RAM Ảo (Tối ưu cho máy 1-2GB RAM)..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "${SCRIPT_DIR}/scripts/setup-swap.sh"
"${SCRIPT_DIR}/scripts/setup-swap.sh"

# ─── 6. Git — Clone hoặc cập nhật repo ────────────────────────────────────────
REPO_URL="https://github.com/tuquet/launchpad-registry-stack.git"
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "\n${BLUE}[6/8]${NC} Kiểm tra repository..."
if [ -f "${INSTALL_DIR}/docker-compose.yml" ]; then
    if [ -d "${INSTALL_DIR}/.git" ]; then
        echo -e "${YELLOW}  🔄 Đang cập nhật repo (git pull)...${NC}"
        git -C "${INSTALL_DIR}" pull --quiet
        echo -e "${GREEN}✅ Repo đã được cập nhật lên phiên bản mới nhất.${NC}"
    else
        echo -e "${GREEN}✅ Đang chạy từ thư mục repo — bỏ qua git pull.${NC}"
    fi
else
    echo -e "${YELLOW}  ⬇️  Clone repository từ GitHub...${NC}"
    git clone "$REPO_URL" "${INSTALL_DIR}"
    echo -e "${GREEN}✅ Clone hoàn tất.${NC}"
fi

# ─── 7. Tạo Auth Registry (htpasswd) ──────────────────────────────────────────
echo -e "\n${BLUE}[7/8]${NC} Tạo tài khoản Registry..."
mkdir -p "${INSTALL_DIR}/auth"

SKIP_AUTH=""
if [ -f "${INSTALL_DIR}/auth/registry.password" ]; then
    echo -e "${YELLOW}⚠️  File auth/registry.password đã tồn tại.${NC}"
    read -rp "  Ghi đè và tạo tài khoản mới? (y/N): " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✅ Giữ nguyên tài khoản cũ${NC}"
        SKIP_AUTH=true
    fi
fi

if [ -z "$SKIP_AUTH" ]; then
    read -rp "  Nhập tên đăng nhập Registry [admin]: " REG_USER
    REG_USER="${REG_USER:-admin}"

    while true; do
        read -rsp "  Nhập mật khẩu Registry: " REG_PASS
        echo ""
        read -rsp "  Xác nhận mật khẩu: " REG_PASS2
        echo ""
        if [ "$REG_PASS" = "$REG_PASS2" ]; then
            break
        fi
        echo -e "${RED}  ❌ Mật khẩu không khớp, thử lại.${NC}"
    done

    chmod +x "${INSTALL_DIR}/scripts/manage-auth.sh"
    "${INSTALL_DIR}/scripts/manage-auth.sh" add "$REG_USER" "$REG_PASS"
    echo -e "${GREEN}✅ Tài khoản Registry: ${REG_USER}${NC}"
fi

# ─── 8. Khởi chạy Stack ────────────────────────────────────────────────────────
echo -e "\n${BLUE}[8/8]${NC} Khởi chạy LaunchPad Stack..."

SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "<IP_VPS>")

echo -e "${YELLOW}⬆️  Đang khởi động các dịch vụ (Nginx UI, Registry, Dozzle, Watchtower)...${NC}"
cd "${INSTALL_DIR}" && sudo docker compose up -d
sleep 3

NGINX_UI_SECRET=$(docker exec registry-nginx-ui cat /etc/nginx-ui/.install_secret 2>/dev/null || echo "(lấy sau: docker exec registry-nginx-ui cat /etc/nginx-ui/.install_secret)")

echo ""
echo -e "${GREEN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    ✅ KHỞI CHẠY THÀNH CÔNG!                     ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
printf "║  🔀 Nginx UI:  http://%-44s║\n" "${SERVER_IP}:80"
printf "║  🛡️  Cockpit:   https://%-43s║\n" "${SERVER_IP}:9090"
echo "║  📄 Dozzle:    Xem log qua Nginx UI (proxy nội bộ)             ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
printf "║  🔑 Secret: %-52s║\n" "${NGINX_UI_SECRET}"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}Bước tiếp theo:${NC}"
echo "  1. Mở http://${SERVER_IP}:80 → nhập Secret ở trên → tạo admin account"
echo "  2. Cấu hình Reverse Proxy + SSL: xem README.md"
echo "  3. Quản lý Server & Firewall: https://${SERVER_IP}:9090"

echo -e "\n${CYAN}📄 Tài liệu chi tiết: ${INSTALL_DIR}/README.md${NC}"

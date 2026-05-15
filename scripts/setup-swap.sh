#!/bin/bash
# =============================================================================
# LaunchPad Registry Stack - Khởi tạo RAM Ảo (Swap Space) chống sập VPS
# =============================================================================

# Màu sắc hiển thị
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🚀 Kiểm tra và thiết lập RAM Ảo (Swap Space)...${NC}"

# Kiểm tra xem hệ thống đã có Swap chưa
SWAP_SIZE=$(free -m | awk '/^Swap:/ {print $2}')

if [ "$SWAP_SIZE" -gt 0 ]; then
    echo -e "${GREEN}✅ Hệ thống đã có sẵn RAM ảo (Swap) với dung lượng ${SWAP_SIZE}MB. Bỏ qua bước này.${NC}"
    exit 0
fi

echo -e "${YELLOW}⚠️ Cảnh báo: Không phát hiện thấy Swap. Hệ thống có nguy cơ bị sập (OOM) khi tải nặng.${NC}"
read -rp "Bạn có muốn tạo tự động 2GB RAM Ảo (Swap) ngay bây giờ không? (y/n) [Mặc định: y]: " CREATE_SWAP
CREATE_SWAP="${CREATE_SWAP:-y}"

if [[ "$CREATE_SWAP" =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}[1/4] Đang khởi tạo file /swapfile dung lượng 2GB...${NC}"
    sudo fallocate -l 2G /swapfile
    
    echo -e "${YELLOW}[2/4] Thiết lập phân quyền bảo mật...${NC}"
    sudo chmod 600 /swapfile
    
    echo -e "${YELLOW}[3/4] Định dạng Swap...${NC}"
    sudo mkswap /swapfile
    
    echo -e "${YELLOW}[4/4] Kích hoạt Swap và lưu vĩnh viễn...${NC}"
    sudo swapon /swapfile
    
    # Backup fstab trước khi ghi
    sudo cp /etc/fstab /etc/fstab.bak
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
    
    echo -e "\n${GREEN}🎉 Hoàn tất! Hệ thống của bạn đã được gia cố thêm 2GB RAM Ảo an toàn!${NC}"
    free -h
else
    echo -e "${RED}❌ Đã hủy bỏ việc tạo Swap. Hãy cẩn thận khi chạy nhiều container!${NC}"
fi

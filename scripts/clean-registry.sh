#!/bin/bash
# =============================================================================
# LaunchPad Registry Stack - Registry Garbage Collection (Dọn dẹp ổ đĩa)
# =============================================================================

# Màu sắc hiển thị
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🚀 Bắt đầu quá trình dọn dẹp Docker Registry (Garbage Collection)...${NC}"

# Kiểm tra xem container registry có đang chạy không
if ! docker ps | grep -q "docker-registry"; then
    echo -e "${RED}❌ Lỗi: Container 'docker-registry' không hoạt động.${NC}"
    echo "Hãy chắc chắn rằng bạn đã khởi chạy stack bằng lệnh: docker compose up -d"
    exit 1
fi

echo -e "\n${YELLOW}1. Khởi chạy quá trình thu gom rác ngầm định (Dry Run để kiểm tra)...${NC}"
# Chạy dry-run trước để an toàn (không xoá gì cả, chỉ hiện danh sách)
docker exec docker-registry bin/registry garbage-collect --dry-run /etc/docker/registry/config.yml

echo -e "\n${YELLOW}2. Chạy quá trình xóa thực tế (Xóa các block dữ liệu không còn được tag)...${NC}"
docker exec docker-registry bin/registry garbage-collect /etc/docker/registry/config.yml

echo -e "\n${GREEN}✅ Dọn dẹp hoàn tất!${NC}"
echo -e "${YELLOW}💡 Mẹo:${NC} Để giải phóng hoàn toàn dung lượng ổ cứng bị chiếm bởi các file log hoặc Docker Image cũ của máy chủ (không thuộc Registry), bạn có thể chạy thêm lệnh: ${GREEN}docker system prune -a --volumes -f${NC}"

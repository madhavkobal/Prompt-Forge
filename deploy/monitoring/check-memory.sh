#!/bin/bash
################################################################################
# PromptForge Memory Usage Check Script
################################################################################

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo "=========================================="
echo "  Memory Usage"
echo "=========================================="
echo ""

# System memory
free -h

echo ""
echo "Container Memory Usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}" | grep promptforge

# Check for high memory usage
MEM_PCT=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
echo ""
if [ $MEM_PCT -ge 90 ]; then
    echo -e "${RED}⚠ CRITICAL: Memory usage is at ${MEM_PCT}%${NC}"
elif [ $MEM_PCT -ge 80 ]; then
    echo -e "${YELLOW}⚠ WARNING: Memory usage is at ${MEM_PCT}%${NC}"
else
    echo -e "${GREEN}✓ Memory usage is OK (${MEM_PCT}%)${NC}"
fi

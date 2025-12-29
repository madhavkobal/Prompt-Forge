#!/bin/bash
################################################################################
# PromptForge Disk Space Check Script
################################################################################

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo "=========================================="
echo "  Disk Space Usage"
echo "=========================================="
echo ""

# Check main filesystem
df -h / | tail -1 | awk '{
    use = int($5)
    if (use >= 90) 
        printf "\033[0;31m✗ CRITICAL:\033[0m Root filesystem at %s (%s used of %s)\n", $5, $3, $2
    else if (use >= 80)
        printf "\033[1;33m⚠ WARNING:\033[0m Root filesystem at %s (%s used of %s)\n", $5, $3, $2
    else
        printf "\033[0;32m✓ OK:\033[0m Root filesystem at %s (%s used of %s)\n", $5, $3, $2
}'

# Check backup directory
echo ""
if [ -d "/var/backups/promptforge" ]; then
    BACKUP_SIZE=$(du -sh /var/backups/promptforge 2>/dev/null | cut -f1)
    echo "Backup directory size: $BACKUP_SIZE"
fi

# Check Docker space
echo ""
echo "Docker Disk Usage:"
docker system df

# Warn if low space
echo ""
ROOT_USE=$(df / | tail -1 | awk '{print int($5)}')
if [ $ROOT_USE -ge 90 ]; then
    echo -e "${RED}⚠ CRITICAL: Disk space is critically low!${NC}"
    echo "Run: sudo ./deploy/maintenance/docker-cleanup.sh"
    exit 1
elif [ $ROOT_USE -ge 80 ]; then
    echo -e "${YELLOW}⚠ WARNING: Disk space is running low${NC}"
    echo "Consider: sudo ./deploy/maintenance/cleanup-logs.sh"
fi

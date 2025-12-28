#!/bin/bash

################################################################################
# PromptForge Database Backup Script
################################################################################
#
# Automated database backup script with rotation and compression.
# Should be run via cron for regular backups.
#
# Usage:
#   ./backup.sh [OPTIONS]
#
# Options:
#   --keep-days N     Number of days to keep backups (default: 7)
#   --backup-dir DIR  Backup directory (default: ./backups)
#   --compress        Compress backups with gzip (default: true)
#   --help            Show this help message
#
# Cron Example (daily at 2 AM):
#   0 2 * * * /path/to/backup.sh >> /var/log/promptforge-backup.log 2>&1
#
################################################################################

set -e

# Default configuration
KEEP_DAYS=7
BACKUP_DIR="./backups"
COMPRESS=true
COMPOSE_FILE="docker-compose.prod.yml"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --keep-days)
            KEEP_DAYS="$2"
            shift 2
            ;;
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --no-compress)
            COMPRESS=false
            shift
            ;;
        --help)
            grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Generate backup filename
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/promptforge-$TIMESTAMP.sql"

echo "Starting database backup..."

# Check if database container is running
if ! docker-compose -f "$COMPOSE_FILE" ps postgres | grep -q "Up"; then
    echo -e "${RED}Error: Database container is not running${NC}"
    exit 1
fi

# Perform backup
docker-compose -f "$COMPOSE_FILE" exec -T postgres \
    pg_dump -U promptforge -d promptforge \
    --clean \
    --if-exists \
    --no-owner \
    --no-acl > "$BACKUP_FILE"

if [[ ! -s "$BACKUP_FILE" ]]; then
    echo -e "${RED}Error: Backup file is empty${NC}"
    rm -f "$BACKUP_FILE"
    exit 1
fi

# Compress backup
if [[ "$COMPRESS" == "true" ]]; then
    gzip "$BACKUP_FILE"
    BACKUP_FILE="${BACKUP_FILE}.gz"
fi

# Get backup size
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

echo -e "${GREEN}Backup completed successfully${NC}"
echo "File: $BACKUP_FILE"
echo "Size: $BACKUP_SIZE"

# Cleanup old backups
echo "Cleaning up backups older than $KEEP_DAYS days..."
find "$BACKUP_DIR" -name "promptforge-*.sql.gz" -mtime +$KEEP_DAYS -delete
find "$BACKUP_DIR" -name "promptforge-*.sql" -mtime +$KEEP_DAYS -delete

REMAINING=$(find "$BACKUP_DIR" -name "promptforge-*.sql*" | wc -l)
echo "Remaining backups: $REMAINING"

echo "Backup process completed"

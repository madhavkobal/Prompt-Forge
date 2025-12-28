#!/bin/bash

################################################################################
# PromptForge Database Restore Script
################################################################################
#
# Restore database from backup file.
#
# Usage:
#   ./restore.sh <backup-file>
#
# Example:
#   ./restore.sh backups/promptforge-20241228-020000.sql.gz
#
# WARNING: This will overwrite all existing data!
#
################################################################################

set -e

COMPOSE_FILE="docker-compose.prod.yml"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check arguments
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <backup-file>"
    echo "Example: $0 backups/promptforge-20241228-020000.sql.gz"
    exit 1
fi

BACKUP_FILE="$1"

# Validate backup file exists
if [[ ! -f "$BACKUP_FILE" ]]; then
    echo -e "${RED}Error: Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}WARNING: This will overwrite all existing data!${NC}"
echo "Backup file: $BACKUP_FILE"
read -p "Are you sure you want to continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Restore cancelled"
    exit 0
fi

# Check if database container is running
if ! docker-compose -f "$COMPOSE_FILE" ps postgres | grep -q "Up"; then
    echo -e "${RED}Error: Database container is not running${NC}"
    echo "Start it with: docker-compose -f $COMPOSE_FILE up -d postgres"
    exit 1
fi

echo "Starting database restore..."

# Decompress if needed
if [[ "$BACKUP_FILE" == *.gz ]]; then
    echo "Decompressing backup..."
    TEMP_FILE=$(mktemp)
    gunzip -c "$BACKUP_FILE" > "$TEMP_FILE"
    RESTORE_FILE="$TEMP_FILE"
else
    RESTORE_FILE="$BACKUP_FILE"
fi

# Restore database
docker-compose -f "$COMPOSE_FILE" exec -T postgres \
    psql -U promptforge -d promptforge < "$RESTORE_FILE"

# Cleanup temp file
if [[ -n "${TEMP_FILE:-}" ]]; then
    rm -f "$TEMP_FILE"
fi

echo -e "${GREEN}Database restored successfully${NC}"
echo "Restarting backend to apply changes..."

docker-compose -f "$COMPOSE_FILE" restart backend

echo -e "${GREEN}Restore completed${NC}"

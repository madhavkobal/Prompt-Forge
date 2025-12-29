#!/bin/bash
################################################################################
# PromptForge Backup Cleanup Script
################################################################################

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

RETENTION_DAYS="${1:-30}"

log "Cleaning up backups older than $RETENTION_DAYS days..."

# Clean full backups
if [ -d "/var/backups/promptforge/full" ]; then
    BEFORE=$(find /var/backups/promptforge/full -maxdepth 1 -type d -name "20*" | wc -l)
    find /var/backups/promptforge/full -maxdepth 1 -type d -name "20*" -mtime +$RETENTION_DAYS -exec rm -rf {} \;
    AFTER=$(find /var/backups/promptforge/full -maxdepth 1 -type d -name "20*" | wc -l)
    log "Full backups: $BEFORE -> $AFTER"
fi

# Clean database backups
if [ -d "/var/backups/promptforge/database" ]; then
    BEFORE=$(find /var/backups/promptforge/database -maxdepth 1 -type d -name "20*" | wc -l)
    find /var/backups/promptforge/database -maxdepth 1 -type d -name "20*" -mtime +$RETENTION_DAYS -exec rm -rf {} \;
    AFTER=$(find /var/backups/promptforge/database -maxdepth 1 -type d -name "20*" | wc -l)
    log "Database backups: $BEFORE -> $AFTER"
fi

# Clean WAL archives (keep 7 days)
if [ -d "/var/backups/promptforge/wal_archive" ]; then
    find /var/backups/promptforge/wal_archive -type f -mtime +7 -delete
    log "WAL archives cleaned"
fi

success "Backup cleanup completed"

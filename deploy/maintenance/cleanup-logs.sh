#!/bin/bash
################################################################################
# PromptForge Log Cleanup Script
################################################################################

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

DAYS="${1:-30}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

log "Cleaning up logs older than $DAYS days..."

# Clean application logs
if [ -d "$PROJECT_ROOT/logs" ]; then
    BEFORE=$(du -sh "$PROJECT_ROOT/logs" | cut -f1)
    find "$PROJECT_ROOT/logs" -name "*.log" -mtime +$DAYS -delete
    AFTER=$(du -sh "$PROJECT_ROOT/logs" | cut -f1)
    success "Application logs: $BEFORE -> $AFTER"
fi

# Clean system logs
if [ -d "/var/log/promptforge" ]; then
    find /var/log/promptforge -name "*.log" -mtime +$DAYS -delete
    success "System logs cleaned"
fi

# Truncate large log files
find "$PROJECT_ROOT/logs" -name "*.log" -size +100M -exec truncate -s 10M {} \;

# Compress old logs
find "$PROJECT_ROOT/logs" -name "*.log" -mtime +7 ! -name "*.gz" -exec gzip {} \;

success "Log cleanup completed"

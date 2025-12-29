#!/bin/bash

################################################################################
# PromptForge Backup Cron Setup Script
################################################################################
#
# This script installs cron jobs for automated backups.
#
# Usage:
#   sudo ./setup-cron.sh [--install|--uninstall|--status]
#
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Cron file paths
CRON_SOURCE="$SCRIPT_DIR/promptforge-backup.cron"
CRON_DEST="/etc/cron.d/promptforge-backup"

# Log directory
LOG_DIR="/var/log/promptforge"

################################################################################
# Helper Functions
################################################################################

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

################################################################################
# Check Root
################################################################################

if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root"
    echo "Please run: sudo $0"
    exit 1
fi

################################################################################
# Install Cron Jobs
################################################################################

install_cron() {
    echo ""
    echo "=========================================="
    echo "  Installing Backup Cron Jobs"
    echo "=========================================="
    echo ""

    # Check if cron source file exists
    if [ ! -f "$CRON_SOURCE" ]; then
        error "Cron source file not found: $CRON_SOURCE"
        exit 1
    fi

    # Create log directory
    log "Creating log directory..."
    mkdir -p "$LOG_DIR"
    chmod 755 "$LOG_DIR"
    success "Log directory created: $LOG_DIR"

    # Update paths in cron file
    log "Configuring cron jobs..."

    # Create temporary file with updated paths
    TEMP_CRON=$(mktemp)
    sed "s|PROMPTFORGE_DIR=/opt/promptforge|PROMPTFORGE_DIR=$PROJECT_ROOT|g" "$CRON_SOURCE" > "$TEMP_CRON"

    # Install cron file
    log "Installing cron file..."
    cp "$TEMP_CRON" "$CRON_DEST"
    chmod 644 "$CRON_DEST"
    rm "$TEMP_CRON"

    success "Cron file installed: $CRON_DEST"

    # Restart cron service
    log "Restarting cron service..."

    if command -v systemctl &> /dev/null; then
        systemctl restart cron 2>/dev/null || systemctl restart crond 2>/dev/null || true
    else
        service cron restart 2>/dev/null || service crond restart 2>/dev/null || true
    fi

    success "Cron service restarted"

    # Display installed jobs
    echo ""
    log "Installed cron jobs:"
    echo ""
    grep -v "^#\|^$\|^SHELL\|^PATH\|^MAILTO\|^PROMPTFORGE_DIR" "$CRON_DEST" || true

    echo ""
    success "Backup cron jobs installed successfully!"
    echo ""
    log "Backup schedule:"
    echo "  • Daily database backup:     1:00 AM"
    echo "  • Weekly full backup:        2:00 AM Sunday"
    echo "  • Daily verification:        3:00 AM"
    echo "  • Weekly full verification:  4:00 AM Monday"
    echo "  • Monthly test restore:      4:00 AM first Sunday"
    echo "  • Disk space check:          Every 6 hours"
    echo "  • Database health check:     Every hour"
    echo ""
    log "Logs will be written to: $LOG_DIR"
    echo ""
}

################################################################################
# Uninstall Cron Jobs
################################################################################

uninstall_cron() {
    echo ""
    echo "=========================================="
    echo "  Uninstalling Backup Cron Jobs"
    echo "=========================================="
    echo ""

    if [ ! -f "$CRON_DEST" ]; then
        warning "Cron file not found: $CRON_DEST"
        log "Nothing to uninstall"
        return 0
    fi

    log "Removing cron file..."
    rm -f "$CRON_DEST"
    success "Cron file removed"

    # Restart cron service
    log "Restarting cron service..."

    if command -v systemctl &> /dev/null; then
        systemctl restart cron 2>/dev/null || systemctl restart crond 2>/dev/null || true
    else
        service cron restart 2>/dev/null || service crond restart 2>/dev/null || true
    fi

    success "Cron service restarted"

    echo ""
    success "Backup cron jobs uninstalled successfully!"
    echo ""
}

################################################################################
# Show Status
################################################################################

show_status() {
    echo ""
    echo "=========================================="
    echo "  Backup Cron Jobs Status"
    echo "=========================================="
    echo ""

    if [ -f "$CRON_DEST" ]; then
        success "Cron jobs are installed: $CRON_DEST"
        echo ""
        log "Installed jobs:"
        echo ""
        grep -v "^#\|^$\|^SHELL\|^PATH\|^MAILTO\|^PROMPTFORGE_DIR" "$CRON_DEST" || true
        echo ""

        # Check recent backup logs
        log "Recent backup activity:"
        echo ""

        if [ -f "$LOG_DIR/backup-db.log" ]; then
            echo "Last database backup:"
            tail -5 "$LOG_DIR/backup-db.log" | sed 's/^/  /'
            echo ""
        fi

        if [ -f "$LOG_DIR/backup-full.log" ]; then
            echo "Last full backup:"
            tail -5 "$LOG_DIR/backup-full.log" | sed 's/^/  /'
            echo ""
        fi

        # Check disk space
        log "Backup disk space:"
        df -h /var/backups/promptforge 2>/dev/null | tail -1 || log "Backup directory not found"
        echo ""

        # Count backups
        if [ -d "/var/backups/promptforge" ]; then
            DB_BACKUPS=$(find /var/backups/promptforge/database -maxdepth 1 -type d -name "20*" 2>/dev/null | wc -l)
            FULL_BACKUPS=$(find /var/backups/promptforge/full -maxdepth 1 -type d -name "20*" 2>/dev/null | wc -l)

            log "Backup count:"
            echo "  Database backups: $DB_BACKUPS"
            echo "  Full backups: $FULL_BACKUPS"
            echo ""
        fi

    else
        warning "Cron jobs are NOT installed"
        log "Run with --install to install cron jobs"
        echo ""
    fi
}

################################################################################
# Test Cron Jobs
################################################################################

test_cron() {
    echo ""
    echo "=========================================="
    echo "  Testing Backup Scripts"
    echo "=========================================="
    echo ""

    # Test database backup (dry run)
    log "Testing database backup script..."
    if [ -x "$PROJECT_ROOT/backup/scripts/backup-db.sh" ]; then
        success "✓ backup-db.sh is executable"
    else
        error "✗ backup-db.sh is not executable or not found"
    fi

    # Test full backup (dry run)
    log "Testing full backup script..."
    if [ -x "$PROJECT_ROOT/backup/scripts/backup-full.sh" ]; then
        success "✓ backup-full.sh is executable"
    else
        error "✗ backup-full.sh is not executable or not found"
    fi

    # Test verification script
    log "Testing verification script..."
    if [ -x "$PROJECT_ROOT/backup/scripts/backup-verify.sh" ]; then
        success "✓ backup-verify.sh is executable"
    else
        error "✗ backup-verify.sh is not executable or not found"
    fi

    # Check log directory
    log "Checking log directory..."
    if [ -d "$LOG_DIR" ] && [ -w "$LOG_DIR" ]; then
        success "✓ Log directory is writable: $LOG_DIR"
    else
        warning "✗ Log directory is not writable: $LOG_DIR"
    fi

    # Check backup directory
    log "Checking backup directory..."
    if [ -d "/var/backups/promptforge" ] && [ -w "/var/backups/promptforge" ]; then
        success "✓ Backup directory is writable: /var/backups/promptforge"
    else
        warning "✗ Backup directory is not writable (will be created on first backup)"
    fi

    echo ""
    success "Test completed"
    echo ""
}

################################################################################
# Main Menu
################################################################################

case "${1:-}" in
    --install)
        install_cron
        ;;

    --uninstall)
        uninstall_cron
        ;;

    --status)
        show_status
        ;;

    --test)
        test_cron
        ;;

    *)
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║                                                            ║"
        echo "║        PromptForge Backup Cron Setup                       ║"
        echo "║                                                            ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Usage: sudo $0 [OPTION]"
        echo ""
        echo "Options:"
        echo "  --install      Install backup cron jobs"
        echo "  --uninstall    Uninstall backup cron jobs"
        echo "  --status       Show status of backup cron jobs"
        echo "  --test         Test backup scripts"
        echo ""
        echo "Backup Schedule:"
        echo "  Daily database backup:     1:00 AM"
        echo "  Weekly full backup:        2:00 AM Sunday"
        echo "  Daily verification:        3:00 AM"
        echo "  Weekly full verification:  4:00 AM Monday"
        echo "  Monthly test restore:      4:00 AM first Sunday"
        echo ""
        exit 1
        ;;
esac

exit 0

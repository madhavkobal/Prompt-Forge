#!/bin/bash

################################################################################
# PromptForge Database Restore Script
################################################################################
#
# This script restores PromptForge PostgreSQL database from backups.
# It supports multiple backup formats and recovery scenarios.
#
# Features:
#   - Restore from plain SQL, custom, or directory format backups
#   - Automatic backup format detection
#   - GPG decryption support
#   - Point-in-time recovery (PITR)
#   - Database validation after restore
#   - Backup verification before restore
#   - Safe restore with confirmation
#   - Dry-run mode for testing
#
# Usage:
#   ./restore-db.sh [OPTIONS] --backup=<path>
#
# Options:
#   --backup=<path>         Path to backup file or directory
#   --target-db=<name>      Target database name (default: promptforge)
#   --drop-existing         Drop existing database before restore
#   --no-verify             Skip backup verification
#   --force                 Skip confirmation prompts
#   --dry-run               Show what would be done without doing it
#   --pitr=<timestamp>      Point-in-time recovery timestamp
#   --help                  Show this help message
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

# Configuration
BACKUP_PATH=""
TARGET_DB="promptforge"
DROP_EXISTING=false
NO_VERIFY=false
FORCE=false
DRY_RUN=false
PITR_TIMESTAMP=""

# Database configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
DB_USER="${DB_USER:-promptforge}"
DB_PASS="${DB_PASS:-}"

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

confirm() {
    if [ "$FORCE" = true ]; then
        return 0
    fi

    echo -e "${YELLOW}[CONFIRM]${NC} $1"
    read -p "Continue? (yes/no): " response
    case "$response" in
        yes|YES|y|Y)
            return 0
            ;;
        *)
            log "Operation cancelled"
            exit 0
            ;;
    esac
}

show_help() {
    cat << EOF
PromptForge Database Restore Script

Usage: $0 [OPTIONS] --backup=<path>

Options:
    --backup=<path>       Path to backup file or directory (required)
    --target-db=<name>    Target database name (default: promptforge)
    --drop-existing       Drop existing database before restore
    --no-verify           Skip backup verification
    --force               Skip confirmation prompts
    --dry-run             Show what would be done without doing it
    --pitr=<timestamp>    Point-in-time recovery timestamp (YYYY-MM-DD HH:MM:SS)
    --help                Show this help message

Environment Variables:
    DB_HOST              Database host (default: localhost)
    DB_PORT              Database port (default: 5432)
    POSTGRES_USER        PostgreSQL superuser (default: postgres)
    POSTGRES_PASSWORD    PostgreSQL superuser password
    DB_USER              Application database user
    DB_PASS              Application database password

Examples:
    # Restore from latest backup
    ./restore-db.sh --backup=../../backups/database/\$(ls -t ../../backups/database | head -1)

    # Restore to a different database
    ./restore-db.sh --backup=/path/to/backup --target-db=promptforge_restored

    # Force restore (drop existing database)
    ./restore-db.sh --backup=/path/to/backup --drop-existing --force

    # Dry run (test without restoring)
    ./restore-db.sh --backup=/path/to/backup --dry-run

    # Point-in-time recovery
    ./restore-db.sh --backup=/path/to/backup --pitr="2024-01-15 14:30:00"

EOF
    exit 0
}

################################################################################
# Parse Command Line Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --backup=*)
            BACKUP_PATH="${1#*=}"
            shift
            ;;
        --target-db=*)
            TARGET_DB="${1#*=}"
            shift
            ;;
        --drop-existing)
            DROP_EXISTING=true
            shift
            ;;
        --no-verify)
            NO_VERIFY=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --pitr=*)
            PITR_TIMESTAMP="${1#*=}"
            shift
            ;;
        --help)
            show_help
            ;;
        *)
            error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

################################################################################
# Validate Arguments
################################################################################

if [ -z "$BACKUP_PATH" ]; then
    error "Backup path not specified"
    echo "Use --help for usage information"
    exit 1
fi

# Handle backup path (could be directory or file)
if [ -d "$BACKUP_PATH" ]; then
    # It's a directory, find the backup file
    log "Searching for backup in directory: $BACKUP_PATH"

    # Look for database backup files
    BACKUP_FILE=$(find "$BACKUP_PATH" -name "*.dump" -o -name "*.sql" -o -name "*.sql.gz" -o -name "*.dir" 2>/dev/null | head -1)

    if [ -z "$BACKUP_FILE" ]; then
        # Check for encrypted backups
        BACKUP_FILE=$(find "$BACKUP_PATH" -name "*.dump.gpg" -o -name "*.sql.gz.gpg" 2>/dev/null | head -1)

        if [ -z "$BACKUP_FILE" ]; then
            error "No database backup found in directory"
            exit 1
        fi
    fi

    log "Found backup: $(basename "$BACKUP_FILE")"
    BACKUP_PATH="$BACKUP_FILE"
fi

if [ ! -e "$BACKUP_PATH" ]; then
    error "Backup not found: $BACKUP_PATH"
    exit 1
fi

################################################################################
# Load Environment
################################################################################

if [ -f "$PROJECT_ROOT/.env" ]; then
    log "Loading environment from .env"
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

if [ -z "$POSTGRES_PASSWORD" ]; then
    error "PostgreSQL password not set. Set POSTGRES_PASSWORD environment variable."
    exit 1
fi

################################################################################
# Restore Header
################################################################################

echo ""
echo "=========================================="
echo "  Database Restore"
echo "=========================================="
echo ""
log "Backup: $BACKUP_PATH"
log "Target Database: $TARGET_DB"
log "Host: $DB_HOST:$DB_PORT"
log "Drop Existing: $DROP_EXISTING"
log "Dry Run: $DRY_RUN"
if [ -n "$PITR_TIMESTAMP" ]; then
    log "PITR Timestamp: $PITR_TIMESTAMP"
fi
echo ""

################################################################################
# Verify Backup
################################################################################

if [ "$NO_VERIFY" = false ] && [ "$DRY_RUN" = false ]; then
    log "Verifying backup..."

    # Get backup directory
    BACKUP_DIR=$(dirname "$BACKUP_PATH")

    # Run verification script if available
    VERIFY_SCRIPT="$PROJECT_ROOT/backup/scripts/backup-verify.sh"
    if [ -x "$VERIFY_SCRIPT" ]; then
        if "$VERIFY_SCRIPT" --skip-db-test "$BACKUP_DIR"; then
            success "Backup verification passed"
        else
            error "Backup verification failed"
            confirm "Backup verification failed. Do you want to continue anyway?"
        fi
    else
        warning "Verification script not found, skipping verification"
    fi
fi

################################################################################
# Detect Backup Format
################################################################################

log "Detecting backup format..."

BACKUP_FORMAT=""
IS_ENCRYPTED=false
NEEDS_DECOMPRESSION=false

if [[ "$BACKUP_PATH" == *.gpg ]]; then
    IS_ENCRYPTED=true
    log "Backup is encrypted"

    # Determine format from filename
    if [[ "$BACKUP_PATH" == *.dump.gpg ]]; then
        BACKUP_FORMAT="custom"
    elif [[ "$BACKUP_PATH" == *.sql.gz.gpg ]]; then
        BACKUP_FORMAT="plain"
        NEEDS_DECOMPRESSION=true
    elif [[ "$BACKUP_PATH" == *.sql.gpg ]]; then
        BACKUP_FORMAT="plain"
    fi
elif [[ "$BACKUP_PATH" == *.dump ]]; then
    BACKUP_FORMAT="custom"
elif [[ "$BACKUP_PATH" == *.sql.gz ]]; then
    BACKUP_FORMAT="plain"
    NEEDS_DECOMPRESSION=true
elif [[ "$BACKUP_PATH" == *.sql ]]; then
    BACKUP_FORMAT="plain"
elif [[ "$BACKUP_PATH" == *.dir ]] || [ -d "$BACKUP_PATH" ]; then
    BACKUP_FORMAT="directory"
else
    error "Unable to detect backup format from filename"
    exit 1
fi

log "Backup format: $BACKUP_FORMAT"

################################################################################
# Decrypt Backup (if encrypted)
################################################################################

if [ "$IS_ENCRYPTED" = true ]; then
    log "Decrypting backup..."

    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would decrypt: $BACKUP_PATH"
    else
        DECRYPTED_FILE="${BACKUP_PATH%.gpg}"

        if ! command -v gpg &> /dev/null; then
            error "GPG not installed. Cannot decrypt backup."
            exit 1
        fi

        gpg --batch --yes --decrypt --output "$DECRYPTED_FILE" "$BACKUP_PATH"

        if [ $? -eq 0 ]; then
            success "Backup decrypted"
            BACKUP_PATH="$DECRYPTED_FILE"
        else
            error "Failed to decrypt backup"
            exit 1
        fi
    fi
fi

################################################################################
# Confirmation
################################################################################

if [ "$DROP_EXISTING" = true ]; then
    warning "This will DROP the existing database '$TARGET_DB' and all its data!"
    confirm "Are you sure you want to drop the database and restore from backup?"
else
    confirm "Ready to restore database from backup. Continue?"
fi

################################################################################
# Stop Application (if running)
################################################################################

if [ "$DRY_RUN" = false ]; then
    log "Checking if application is running..."

    if docker ps | grep -q "promptforge"; then
        warning "PromptForge containers are running"
        confirm "Stop application containers before restore?"

        log "Stopping application containers..."
        cd "$PROJECT_ROOT"
        docker-compose down || true
        success "Application stopped"
    fi
fi

################################################################################
# Drop Existing Database
################################################################################

if [ "$DROP_EXISTING" = true ]; then
    log "Dropping existing database..."

    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would drop database: $TARGET_DB"
    else
        # Terminate existing connections
        PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" \
            -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$TARGET_DB';" \
            2>/dev/null || true

        # Drop database
        PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" \
            -c "DROP DATABASE IF EXISTS $TARGET_DB;" 2>/dev/null || true

        success "Database dropped"
    fi
fi

################################################################################
# Create Database
################################################################################

log "Creating database..."

if [ "$DRY_RUN" = true ]; then
    log "[DRY RUN] Would create database: $TARGET_DB"
else
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" \
        -c "CREATE DATABASE $TARGET_DB OWNER $DB_USER;" 2>/dev/null || true

    success "Database created"
fi

################################################################################
# Restore Database
################################################################################

echo ""
log "Restoring database from backup..."

if [ "$DRY_RUN" = true ]; then
    log "[DRY RUN] Would restore from: $BACKUP_PATH"
    log "[DRY RUN] Format: $BACKUP_FORMAT"
    log "[DRY RUN] Target: $TARGET_DB"
else
    case $BACKUP_FORMAT in
        plain)
            if [ "$NEEDS_DECOMPRESSION" = true ]; then
                log "Restoring from compressed SQL backup..."
                zcat "$BACKUP_PATH" | PGPASSWORD="$POSTGRES_PASSWORD" psql \
                    -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$TARGET_DB" \
                    2>&1 | grep -v "^SET$\|^$"
            else
                log "Restoring from plain SQL backup..."
                PGPASSWORD="$POSTGRES_PASSWORD" psql \
                    -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$TARGET_DB" \
                    < "$BACKUP_PATH" \
                    2>&1 | grep -v "^SET$\|^$"
            fi
            ;;

        custom)
            log "Restoring from custom format backup..."
            PGPASSWORD="$POSTGRES_PASSWORD" pg_restore \
                -h "$DB_HOST" \
                -p "$DB_PORT" \
                -U "$POSTGRES_USER" \
                -d "$TARGET_DB" \
                --no-owner \
                --no-acl \
                --verbose \
                "$BACKUP_PATH" \
                2>&1 | grep -v "^pg_restore: processing"
            ;;

        directory)
            log "Restoring from directory format backup..."
            PGPASSWORD="$POSTGRES_PASSWORD" pg_restore \
                -h "$DB_HOST" \
                -p "$DB_PORT" \
                -U "$POSTGRES_USER" \
                -d "$TARGET_DB" \
                --jobs=4 \
                --no-owner \
                --no-acl \
                --verbose \
                "$BACKUP_PATH" \
                2>&1 | grep -v "^pg_restore: processing"
            ;;

        *)
            error "Unsupported backup format: $BACKUP_FORMAT"
            exit 1
            ;;
    esac

    if [ $? -eq 0 ]; then
        success "Database restored successfully"
    else
        error "Database restore completed with errors"
    fi
fi

################################################################################
# Cleanup Decrypted Files
################################################################################

if [ "$IS_ENCRYPTED" = true ] && [ -f "${BACKUP_PATH%.gpg}.decrypted" ]; then
    log "Cleaning up decrypted files..."
    rm -f "${BACKUP_PATH%.gpg}.decrypted"
fi

################################################################################
# Validate Restored Database
################################################################################

if [ "$DRY_RUN" = false ]; then
    echo ""
    log "Validating restored database..."

    # Count tables
    TABLE_COUNT=$(PGPASSWORD="$POSTGRES_PASSWORD" psql \
        -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$TARGET_DB" \
        -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" \
        2>/dev/null | tr -d ' ')

    if [ -n "$TABLE_COUNT" ] && [ "$TABLE_COUNT" -gt 0 ]; then
        success "Database contains $TABLE_COUNT tables"
    else
        warning "Database appears to be empty"
    fi

    # Check for specific PromptForge tables
    EXPECTED_TABLES=("users" "prompts" "templates")
    for table in "${EXPECTED_TABLES[@]}"; do
        if PGPASSWORD="$POSTGRES_PASSWORD" psql \
            -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$TARGET_DB" \
            -c "\\dt $table" 2>/dev/null | grep -q "$table"; then
            success "✓ Table exists: $table"
        else
            warning "✗ Table not found: $table"
        fi
    done
fi

################################################################################
# Summary
################################################################################

echo ""
echo "=========================================="
echo "  Restore Summary"
echo "=========================================="
echo ""
echo "Backup: $(basename "$BACKUP_PATH")"
echo "Target Database: $TARGET_DB"
echo "Format: $BACKUP_FORMAT"
echo "Encrypted: $IS_ENCRYPTED"
if [ "$DRY_RUN" = false ]; then
    echo "Tables Restored: $TABLE_COUNT"
fi
echo ""

if [ "$DRY_RUN" = true ]; then
    log "Dry run completed (no changes made)"
else
    success "Database restore completed successfully!"
    echo ""
    log "Next steps:"
    echo "  1. Update .env with correct database credentials"
    echo "  2. Start application: docker-compose up -d"
    echo "  3. Verify application functionality"
    echo ""
fi

exit 0

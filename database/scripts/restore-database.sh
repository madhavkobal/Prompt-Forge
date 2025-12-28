#!/bin/bash

################################################################################
# PromptForge Database Restore Script
################################################################################
#
# This script restores a PostgreSQL database from a backup created by
# backup-database.sh. It includes safety checks and verification.
#
# Usage:
#   ./restore-database.sh <backup_file> [--force] [--verify]
#
# Options:
#   --force    Skip confirmation prompt
#   --verify   Verify backup before restoring
#   --help     Show this help message
#
# Example:
#   ./restore-database.sh /var/backups/promptforge/database/promptforge_prod_full_20240101_120000.sql.gz
#
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
FORCE=false
VERIFY=false
BACKUP_FILE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

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
# Parse Arguments
################################################################################

if [[ $# -eq 0 ]]; then
    error "No backup file specified"
    echo "Usage: $0 <backup_file> [--force] [--verify]"
    exit 1
fi

BACKUP_FILE="$1"
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --verify)
            VERIFY=true
            shift
            ;;
        --help)
            grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^# \?//'
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

################################################################################
# Load Environment
################################################################################

load_environment() {
    log "Loading environment configuration..."

    # Try to load from .env files
    if [[ -f "$PROJECT_ROOT/.env.production" ]]; then
        source "$PROJECT_ROOT/.env.production"
    elif [[ -f "$PROJECT_ROOT/.env" ]]; then
        source "$PROJECT_ROOT/.env"
    fi

    # Check if DATABASE_URL is set
    if [[ -z "${DATABASE_URL:-}" ]]; then
        error "DATABASE_URL not set"
        echo "Set it in .env or .env.production, or export it"
        exit 1
    fi

    # Extract database connection details
    DB_USER=$(echo "$DATABASE_URL" | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
    DB_PASS=$(echo "$DATABASE_URL" | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
    DB_HOST=$(echo "$DATABASE_URL" | sed -n 's/.*@\([^:]*\):.*/\1/p')
    DB_PORT=$(echo "$DATABASE_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
    DB_NAME=$(echo "$DATABASE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')

    success "Environment loaded"
}

################################################################################
# Validate Backup File
################################################################################

validate_backup() {
    log "Validating backup file..."

    # Check if backup file exists
    if [[ ! -f "$BACKUP_FILE" ]]; then
        error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi

    # Check file extension
    if [[ ! "$BACKUP_FILE" =~ \.(sql|sql\.gz|dump|dump\.gz)$ ]]; then
        warning "Backup file may not be a valid PostgreSQL backup"
    fi

    # Get file size
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "Backup file size: $BACKUP_SIZE"

    # Verify checksum if available
    if [[ -f "${BACKUP_FILE}.sha256" ]]; then
        log "Verifying checksum..."
        if sha256sum -c "${BACKUP_FILE}.sha256" &> /dev/null; then
            success "Checksum verified"
        else
            error "Checksum verification failed"
            exit 1
        fi
    else
        warning "No checksum file found, skipping verification"
    fi

    # Test file integrity if gzipped
    if [[ "$BACKUP_FILE" =~ \.gz$ ]]; then
        if [[ "$VERIFY" == "true" ]]; then
            log "Testing backup file integrity..."
            if gzip -t "$BACKUP_FILE" 2>/dev/null; then
                success "Backup file integrity verified"
            else
                error "Backup file is corrupted"
                exit 1
            fi
        fi
    fi

    # Show metadata if available
    if [[ -f "${BACKUP_FILE}.meta" ]]; then
        log "Backup metadata:"
        cat "${BACKUP_FILE}.meta" | sed 's/^/  /'
    fi

    success "Backup file validated"
}

################################################################################
# Safety Confirmation
################################################################################

confirm_restore() {
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi

    echo ""
    warning "=========================================="
    warning "  WARNING: DATABASE RESTORE"
    warning "=========================================="
    echo ""
    warning "This will REPLACE the current database:"
    echo "  Database: $DB_NAME"
    echo "  Host: $DB_HOST:$DB_PORT"
    echo ""
    warning "ALL CURRENT DATA WILL BE LOST!"
    echo ""
    echo "Backup file: $BACKUP_FILE"
    echo "Backup size: $BACKUP_SIZE"
    echo ""

    read -p "Are you absolutely sure you want to proceed? (type 'yes' to confirm): " CONFIRM

    if [[ "$CONFIRM" != "yes" ]]; then
        warning "Restore cancelled"
        exit 0
    fi

    read -p "Type the database name '$DB_NAME' to confirm: " DB_CONFIRM

    if [[ "$DB_CONFIRM" != "$DB_NAME" ]]; then
        error "Database name does not match. Restore cancelled."
        exit 1
    fi

    success "Confirmation received"
}

################################################################################
# Create Pre-Restore Backup
################################################################################

create_pre_restore_backup() {
    log "Creating pre-restore backup of current database..."

    PRE_RESTORE_BACKUP="/tmp/${DB_NAME}_pre_restore_$(date +%Y%m%d_%H%M%S).sql.gz"

    # Check if database exists
    if PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then

        log "Backing up current database to: $PRE_RESTORE_BACKUP"

        PGPASSWORD="$DB_PASS" pg_dump \
            -h "$DB_HOST" \
            -p "$DB_PORT" \
            -U "$DB_USER" \
            -d "$DB_NAME" \
            --format=plain \
            --no-owner \
            --no-acl \
            | gzip > "$PRE_RESTORE_BACKUP" 2>/dev/null

        success "Pre-restore backup created: $PRE_RESTORE_BACKUP"
        log "Keep this file in case you need to rollback"
    else
        log "Database does not exist, skipping pre-restore backup"
    fi
}

################################################################################
# Terminate Active Connections
################################################################################

terminate_connections() {
    log "Terminating active database connections..."

    # Terminate all connections to the database (except ours)
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres <<EOF
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '$DB_NAME'
  AND pid <> pg_backend_pid();
EOF

    success "Active connections terminated"
}

################################################################################
# Drop and Recreate Database
################################################################################

recreate_database() {
    log "Dropping existing database..."

    # Drop database
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
        -c "DROP DATABASE IF EXISTS $DB_NAME;" &> /dev/null

    success "Database dropped"

    log "Creating fresh database..."

    # Create database
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
        -c "CREATE DATABASE $DB_NAME;" &> /dev/null

    success "Database created"
}

################################################################################
# Restore Database
################################################################################

restore_database() {
    log "Restoring database from backup..."

    # Determine if file is compressed
    if [[ "$BACKUP_FILE" =~ \.gz$ ]]; then
        log "Decompressing and restoring..."
        gunzip -c "$BACKUP_FILE" | PGPASSWORD="$DB_PASS" psql \
            -h "$DB_HOST" \
            -p "$DB_PORT" \
            -U "$DB_USER" \
            -d "$DB_NAME" \
            2>&1 | tee /tmp/restore.log | grep -v "^INSERT" | grep -v "^COPY"
    else
        log "Restoring..."
        PGPASSWORD="$DB_PASS" psql \
            -h "$DB_HOST" \
            -p "$DB_PORT" \
            -U "$DB_USER" \
            -d "$DB_NAME" \
            -f "$BACKUP_FILE" \
            2>&1 | tee /tmp/restore.log | grep -v "^INSERT" | grep -v "^COPY"
    fi

    # Check for errors in restore log
    if grep -qi "error" /tmp/restore.log; then
        warning "Some errors occurred during restore. Check /tmp/restore.log"
    else
        success "Database restored successfully"
    fi
}

################################################################################
# Verify Restore
################################################################################

verify_restore() {
    log "Verifying database restore..."

    # Check if database exists
    if ! PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        error "Database not found after restore"
        return 1
    fi

    # Get table count
    TABLE_COUNT=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)

    log "Tables restored: $TABLE_COUNT"

    # Get database size
    DB_SIZE=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$DB_NAME" -t -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" | xargs)

    log "Database size: $DB_SIZE"

    # Run a simple query to ensure database is functional
    if PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$DB_NAME" -c "SELECT 1;" &> /dev/null; then
        success "Database is functional"
    else
        error "Database queries failing"
        return 1
    fi

    success "Restore verification complete"
}

################################################################################
# Analyze Database
################################################################################

analyze_database() {
    log "Analyzing database for query optimization..."

    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$DB_NAME" -c "ANALYZE;" &> /dev/null

    success "Database analyzed"
}

################################################################################
# Display Summary
################################################################################

show_summary() {
    echo ""
    success "=========================================="
    success "  Database Restore Complete!"
    success "=========================================="
    echo ""
    log "Restore Details:"
    echo "  Database: $DB_NAME"
    echo "  Host: $DB_HOST:$DB_PORT"
    echo "  Tables: $TABLE_COUNT"
    echo "  Size: $DB_SIZE"
    echo ""
    log "Backup Details:"
    echo "  File: $BACKUP_FILE"
    echo "  Size: $BACKUP_SIZE"
    echo ""

    if [[ -f "$PRE_RESTORE_BACKUP" ]]; then
        log "Pre-restore backup saved to:"
        echo "  $PRE_RESTORE_BACKUP"
        echo ""
        log "To rollback this restore:"
        echo "  ./restore-database.sh $PRE_RESTORE_BACKUP --force"
        echo ""
    fi

    log "Next steps:"
    echo "  1. Verify application functionality"
    echo "  2. Run database migrations if needed: cd backend && ./migrate.sh upgrade"
    echo "  3. Restart application services"
    echo "  4. Monitor application logs"
    echo ""
}

################################################################################
# Main Script
################################################################################

echo "=========================================="
echo "  PromptForge Database Restore"
echo "=========================================="
echo ""

load_environment
validate_backup
confirm_restore
create_pre_restore_backup
terminate_connections
recreate_database
restore_database
verify_restore
analyze_database
show_summary

exit 0

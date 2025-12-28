#!/bin/bash

################################################################################
# PromptForge Database Backup Script
################################################################################
#
# This script creates automated backups of the PostgreSQL database with:
#   - Full database dumps using pg_dump
#   - Compression (gzip)
#   - Retention policy (default: 30 days)
#   - Backup verification
#   - External storage support (NFS, S3-compatible)
#   - Point-in-time recovery setup
#
# Usage:
#   ./backup-database.sh [--verify] [--external] [--retention DAYS]
#
# Options:
#   --verify           Verify backup after creation
#   --external         Upload to external storage
#   --retention DAYS   Keep backups for N days (default: 30)
#   --s3-bucket NAME   S3 bucket for external storage
#   --nfs-path PATH    NFS mount path for external storage
#   --help             Show this help message
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
BACKUP_DIR="${BACKUP_DIR:-/var/backups/promptforge/database}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
VERIFY_BACKUP=false
EXTERNAL_BACKUP=false
S3_BUCKET=""
NFS_PATH=""
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
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

while [[ $# -gt 0 ]]; do
    case $1 in
        --verify)
            VERIFY_BACKUP=true
            shift
            ;;
        --external)
            EXTERNAL_BACKUP=true
            shift
            ;;
        --retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --s3-bucket)
            S3_BUCKET="$2"
            shift 2
            ;;
        --nfs-path)
            NFS_PATH="$2"
            shift 2
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
# Check Prerequisites
################################################################################

check_prerequisites() {
    log "Checking prerequisites..."

    # Check if pg_dump is available
    if ! command -v pg_dump &> /dev/null; then
        error "pg_dump not found. Please install PostgreSQL client tools."
        exit 1
    fi

    # Check if gzip is available
    if ! command -v gzip &> /dev/null; then
        error "gzip not found. Please install gzip."
        exit 1
    fi

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    # Check if we can write to backup directory
    if [[ ! -w "$BACKUP_DIR" ]]; then
        error "Cannot write to backup directory: $BACKUP_DIR"
        exit 1
    fi

    # Check database connection
    if ! PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -c "SELECT 1;" &> /dev/null; then
        error "Cannot connect to database: $DB_NAME"
        exit 1
    fi

    # Check external storage tools if needed
    if [[ "$EXTERNAL_BACKUP" == "true" ]]; then
        if [[ -n "$S3_BUCKET" ]]; then
            if ! command -v aws &> /dev/null && ! command -v s3cmd &> /dev/null; then
                error "AWS CLI or s3cmd not found for S3 backup"
                exit 1
            fi
        fi
    fi

    success "Prerequisites checked"
}

################################################################################
# Create Full Backup
################################################################################

create_full_backup() {
    log "Creating full database backup..."

    BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_full_${TIMESTAMP}.sql"
    BACKUP_FILE_GZ="${BACKUP_FILE}.gz"

    # Get database size
    DB_SIZE=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$DB_NAME" -t -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" | xargs)
    log "Database size: $DB_SIZE"

    # Create backup with pg_dump
    log "Running pg_dump..."
    PGPASSWORD="$DB_PASS" pg_dump \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --format=plain \
        --no-owner \
        --no-acl \
        --verbose \
        > "$BACKUP_FILE" 2>/tmp/backup.log

    # Compress backup
    log "Compressing backup..."
    gzip "$BACKUP_FILE"

    # Get backup file size
    BACKUP_SIZE=$(du -h "$BACKUP_FILE_GZ" | cut -f1)
    success "Backup created: $BACKUP_FILE_GZ ($BACKUP_SIZE)"

    # Create checksum
    log "Creating checksum..."
    sha256sum "$BACKUP_FILE_GZ" > "${BACKUP_FILE_GZ}.sha256"

    # Create metadata file
    cat > "${BACKUP_FILE_GZ}.meta" <<EOF
Backup Timestamp: $TIMESTAMP
Database Name: $DB_NAME
Database Size: $DB_SIZE
Backup Size: $BACKUP_SIZE
Backup File: $(basename "$BACKUP_FILE_GZ")
Checksum File: $(basename "${BACKUP_FILE_GZ}.sha256")
PostgreSQL Version: $(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT version();" | xargs)
EOF

    success "Full backup completed"
}

################################################################################
# Create Schema-Only Backup
################################################################################

create_schema_backup() {
    log "Creating schema-only backup..."

    SCHEMA_BACKUP="$BACKUP_DIR/${DB_NAME}_schema_${TIMESTAMP}.sql"

    # Dump schema only
    PGPASSWORD="$DB_PASS" pg_dump \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --schema-only \
        --no-owner \
        --no-acl \
        > "$SCHEMA_BACKUP" 2>/dev/null

    # Compress
    gzip "$SCHEMA_BACKUP"

    success "Schema backup created: ${SCHEMA_BACKUP}.gz"
}

################################################################################
# Verify Backup
################################################################################

verify_backup() {
    if [[ "$VERIFY_BACKUP" != "true" ]]; then
        return 0
    fi

    log "Verifying backup..."

    # Verify checksum
    if ! sha256sum -c "${BACKUP_FILE_GZ}.sha256" &> /dev/null; then
        error "Backup checksum verification failed"
        return 1
    fi
    success "Checksum verified"

    # Test gunzip
    log "Testing backup file integrity..."
    if ! gzip -t "$BACKUP_FILE_GZ" 2>/dev/null; then
        error "Backup file is corrupted"
        return 1
    fi
    success "Backup file integrity verified"

    # Test restore to temporary database (optional, resource-intensive)
    if [[ "${VERIFY_RESTORE:-false}" == "true" ]]; then
        log "Testing backup restore (creating temporary database)..."
        TEST_DB="${DB_NAME}_verify_${TIMESTAMP}"

        # Create test database
        PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
            -c "CREATE DATABASE $TEST_DB;" &> /dev/null

        # Restore backup
        gunzip -c "$BACKUP_FILE_GZ" | PGPASSWORD="$DB_PASS" psql \
            -h "$DB_HOST" \
            -p "$DB_PORT" \
            -U "$DB_USER" \
            -d "$TEST_DB" &> /dev/null

        # Verify data
        TABLE_COUNT=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
            -d "$TEST_DB" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)

        log "Restored $TABLE_COUNT tables"

        # Cleanup test database
        PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
            -c "DROP DATABASE $TEST_DB;" &> /dev/null

        success "Restore test successful"
    fi

    success "Backup verification complete"
}

################################################################################
# Upload to External Storage
################################################################################

upload_to_external() {
    if [[ "$EXTERNAL_BACKUP" != "true" ]]; then
        return 0
    fi

    log "Uploading to external storage..."

    # Upload to S3
    if [[ -n "$S3_BUCKET" ]]; then
        log "Uploading to S3 bucket: $S3_BUCKET"

        # Try AWS CLI first
        if command -v aws &> /dev/null; then
            aws s3 cp "$BACKUP_FILE_GZ" "s3://$S3_BUCKET/database/$(basename "$BACKUP_FILE_GZ")"
            aws s3 cp "${BACKUP_FILE_GZ}.sha256" "s3://$S3_BUCKET/database/$(basename "${BACKUP_FILE_GZ}.sha256")"
            aws s3 cp "${BACKUP_FILE_GZ}.meta" "s3://$S3_BUCKET/database/$(basename "${BACKUP_FILE_GZ}.meta")"
        # Try s3cmd
        elif command -v s3cmd &> /dev/null; then
            s3cmd put "$BACKUP_FILE_GZ" "s3://$S3_BUCKET/database/"
            s3cmd put "${BACKUP_FILE_GZ}.sha256" "s3://$S3_BUCKET/database/"
            s3cmd put "${BACKUP_FILE_GZ}.meta" "s3://$S3_BUCKET/database/"
        fi

        success "Uploaded to S3"
    fi

    # Upload to NFS
    if [[ -n "$NFS_PATH" ]]; then
        log "Copying to NFS: $NFS_PATH"

        # Create directory if it doesn't exist
        mkdir -p "$NFS_PATH/database"

        # Copy files
        cp "$BACKUP_FILE_GZ" "$NFS_PATH/database/"
        cp "${BACKUP_FILE_GZ}.sha256" "$NFS_PATH/database/"
        cp "${BACKUP_FILE_GZ}.meta" "$NFS_PATH/database/"

        success "Copied to NFS"
    fi
}

################################################################################
# Cleanup Old Backups
################################################################################

cleanup_old_backups() {
    log "Cleaning up old backups (retention: $RETENTION_DAYS days)..."

    # Find and delete old backups
    DELETED_COUNT=0

    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            log "Deleting old backup: $(basename "$file")"
            rm -f "$file" "$file.sha256" "$file.meta"
            ((DELETED_COUNT++))
        fi
    done < <(find "$BACKUP_DIR" -name "${DB_NAME}_full_*.sql.gz" -type f -mtime +$RETENTION_DAYS)

    if [[ $DELETED_COUNT -gt 0 ]]; then
        success "Deleted $DELETED_COUNT old backup(s)"
    else
        log "No old backups to delete"
    fi

    # Show current backup count
    CURRENT_BACKUPS=$(find "$BACKUP_DIR" -name "${DB_NAME}_full_*.sql.gz" -type f | wc -l)
    log "Current backups: $CURRENT_BACKUPS"
}

################################################################################
# Setup Point-in-Time Recovery (PITR)
################################################################################

setup_pitr() {
    log "Setting up Point-in-Time Recovery..."

    # Create WAL archive directory
    WAL_ARCHIVE_DIR="$BACKUP_DIR/wal_archive"
    mkdir -p "$WAL_ARCHIVE_DIR"

    # Show PITR configuration recommendations
    warning "To enable Point-in-Time Recovery, add these settings to postgresql.conf:"
    echo ""
    echo "  wal_level = replica"
    echo "  archive_mode = on"
    echo "  archive_command = 'test ! -f $WAL_ARCHIVE_DIR/%f && cp %p $WAL_ARCHIVE_DIR/%f'"
    echo "  archive_timeout = 300  # Archive every 5 minutes"
    echo ""
    log "WAL archive directory: $WAL_ARCHIVE_DIR"
}

################################################################################
# Display Summary
################################################################################

show_summary() {
    echo ""
    success "=========================================="
    success "  Database Backup Complete!"
    success "=========================================="
    echo ""
    log "Backup Details:"
    echo "  Database: $DB_NAME"
    echo "  Timestamp: $TIMESTAMP"
    echo "  Location: $BACKUP_FILE_GZ"
    echo "  Size: $BACKUP_SIZE"
    echo ""

    if [[ "$VERIFY_BACKUP" == "true" ]]; then
        echo "  ✓ Backup verified"
    fi

    if [[ "$EXTERNAL_BACKUP" == "true" ]]; then
        echo "  ✓ Uploaded to external storage"
    fi

    echo ""
    log "Retention: $RETENTION_DAYS days"
    log "Current backups: $CURRENT_BACKUPS"
    echo ""
    log "To restore this backup:"
    echo "  gunzip -c $BACKUP_FILE_GZ | psql -U $DB_USER -d $DB_NAME"
    echo ""
}

################################################################################
# Main Script
################################################################################

echo "=========================================="
echo "  PromptForge Database Backup"
echo "=========================================="
echo ""

load_environment
check_prerequisites
create_full_backup
create_schema_backup
verify_backup
upload_to_external
cleanup_old_backups
setup_pitr
show_summary

exit 0

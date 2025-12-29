#!/bin/bash

################################################################################
# PromptForge Database Backup Script
################################################################################
#
# This script performs database-only backups for PromptForge PostgreSQL
# database. It's faster than full system backup and suitable for daily
# automated backups.
#
# Features:
#   - PostgreSQL database backup using pg_dump
#   - Multiple backup formats (plain SQL, custom, directory)
#   - Compression with configurable levels
#   - SHA256 checksums for integrity verification
#   - Optional GPG encryption
#   - Off-site backup via rsync
#   - Automated retention policy
#   - Detailed logging and manifest
#
# Usage:
#   ./backup-db.sh [OPTIONS]
#
# Options:
#   --format=<plain|custom|directory>  Backup format (default: custom)
#   --encrypt                          Encrypt backup with GPG
#   --offsite                          Copy to remote server
#   --compress=<0-9>                   Compression level (default: 6)
#   --retention=<days>                 Retention period (default: 30)
#   --help                             Show this help message
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

# Default configuration
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_ROOT/backups/database}"
BACKUP_FORMAT="${BACKUP_FORMAT:-custom}"
COMPRESS_LEVEL="${COMPRESS_LEVEL:-6}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
ENCRYPT="${ENCRYPT:-false}"
OFFSITE="${OFFSITE:-false}"

# Remote backup configuration
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_PATH="${REMOTE_PATH:-/backups/promptforge/database}"

# GPG configuration
GPG_RECIPIENT="${GPG_RECIPIENT:-admin@promptforge.io}"

# Database configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-promptforge}"
DB_USER="${DB_USER:-promptforge}"
DB_PASS="${DB_PASS:-}"

# Timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE=$(date +%Y-%m-%d)

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

show_help() {
    cat << EOF
PromptForge Database Backup Script

Usage: $0 [OPTIONS]

Options:
    --format=<plain|custom|directory>  Backup format (default: custom)
    --encrypt                          Encrypt backup with GPG
    --offsite                          Copy to remote server
    --compress=<0-9>                   Compression level (default: 6)
    --retention=<days>                 Retention period (default: 30)
    --help                             Show this help message

Backup Formats:
    plain      - Plain SQL text file (human-readable, large)
    custom     - PostgreSQL custom format (compressed, fast restore)
    directory  - Directory format (parallel restore, flexible)

Environment Variables:
    BACKUP_DIR              Backup directory (default: ./backups/database)
    DB_HOST                 Database host (default: localhost)
    DB_PORT                 Database port (default: 5432)
    DB_NAME                 Database name (default: promptforge)
    DB_USER                 Database user (default: promptforge)
    DB_PASS                 Database password
    GPG_RECIPIENT           GPG recipient for encryption
    REMOTE_USER             Remote backup user
    REMOTE_HOST             Remote backup host
    REMOTE_PATH             Remote backup path

Examples:
    # Basic database backup
    ./backup-db.sh

    # Encrypted backup with custom format
    ./backup-db.sh --format=custom --encrypt

    # Backup with off-site copy
    ./backup-db.sh --encrypt --offsite

    # Plain SQL backup with 30-day retention
    ./backup-db.sh --format=plain --retention=30

EOF
    exit 0
}

################################################################################
# Parse Command Line Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --format=*)
            BACKUP_FORMAT="${1#*=}"
            shift
            ;;
        --encrypt)
            ENCRYPT=true
            shift
            ;;
        --offsite)
            OFFSITE=true
            shift
            ;;
        --compress=*)
            COMPRESS_LEVEL="${1#*=}"
            shift
            ;;
        --retention=*)
            RETENTION_DAYS="${1#*=}"
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
# Load Configuration
################################################################################

# Load from config file if exists
CONFIG_FILE="$PROJECT_ROOT/backup/config/backup.conf"
if [ -f "$CONFIG_FILE" ]; then
    log "Loading configuration from $CONFIG_FILE"
    source "$CONFIG_FILE"
fi

# Load from .env file if exists
if [ -f "$PROJECT_ROOT/.env" ]; then
    log "Loading environment from .env"
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

################################################################################
# Validate Configuration
################################################################################

if [ -z "$DB_PASS" ]; then
    error "Database password not set. Set DB_PASS environment variable."
    exit 1
fi

if [ "$OFFSITE" = true ]; then
    if [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_HOST" ]; then
        error "Remote backup credentials not set. Set REMOTE_USER and REMOTE_HOST."
        exit 1
    fi
fi

if [ "$ENCRYPT" = true ]; then
    if ! command -v gpg &> /dev/null; then
        error "GPG not installed. Install gpg or disable encryption."
        exit 1
    fi
fi

################################################################################
# Create Backup Directory
################################################################################

mkdir -p "$BACKUP_DIR"

BACKUP_SUBDIR="$BACKUP_DIR/$DATE"
mkdir -p "$BACKUP_SUBDIR"

log "Backup directory: $BACKUP_SUBDIR"

################################################################################
# Backup Database
################################################################################

echo ""
echo "=========================================="
echo "  Database Backup"
echo "=========================================="
echo ""
log "Starting database backup..."
log "Database: $DB_NAME"
log "Format: $BACKUP_FORMAT"
log "Timestamp: $TIMESTAMP"
echo ""

# Determine backup file extension
case $BACKUP_FORMAT in
    plain)
        BACKUP_EXT="sql"
        FORMAT_ARG="--format=plain"
        ;;
    custom)
        BACKUP_EXT="dump"
        FORMAT_ARG="--format=custom"
        ;;
    directory)
        BACKUP_EXT="dir"
        FORMAT_ARG="--format=directory"
        ;;
    *)
        error "Invalid backup format: $BACKUP_FORMAT"
        exit 1
        ;;
esac

BACKUP_FILE="$BACKUP_SUBDIR/${DB_NAME}_${TIMESTAMP}.${BACKUP_EXT}"

# Perform backup
log "Creating database backup..."

if [ "$BACKUP_FORMAT" = "directory" ]; then
    # Directory format
    PGPASSWORD="$DB_PASS" pg_dump \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        $FORMAT_ARG \
        --jobs=4 \
        --compress=$COMPRESS_LEVEL \
        --no-owner \
        --no-acl \
        --verbose \
        --file="$BACKUP_FILE" \
        2>&1 | grep -v "^pg_dump: reading"
else
    # Plain or custom format
    PGPASSWORD="$DB_PASS" pg_dump \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        $FORMAT_ARG \
        --compress=$COMPRESS_LEVEL \
        --no-owner \
        --no-acl \
        --verbose \
        --file="$BACKUP_FILE" \
        2>&1 | grep -v "^pg_dump: reading"
fi

success "Database backup created: $(basename "$BACKUP_FILE")"

# Get backup size
BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
log "Backup size: $BACKUP_SIZE"

################################################################################
# Create Checksum
################################################################################

log "Creating checksum..."

if [ "$BACKUP_FORMAT" = "directory" ]; then
    # Create checksums for all files in directory
    find "$BACKUP_FILE" -type f -exec sha256sum {} \; > "${BACKUP_FILE}.sha256"
else
    # Single file checksum
    sha256sum "$BACKUP_FILE" > "${BACKUP_FILE}.sha256"
fi

success "Checksum created"

################################################################################
# Compress (if plain format)
################################################################################

if [ "$BACKUP_FORMAT" = "plain" ]; then
    log "Compressing backup..."

    gzip -$COMPRESS_LEVEL "$BACKUP_FILE"
    BACKUP_FILE="${BACKUP_FILE}.gz"

    # Update checksum
    sha256sum "$BACKUP_FILE" > "${BACKUP_FILE}.sha256"

    COMPRESSED_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    success "Backup compressed: $COMPRESSED_SIZE"
fi

################################################################################
# Encrypt Backup
################################################################################

if [ "$ENCRYPT" = true ]; then
    log "Encrypting backup..."

    if [ "$BACKUP_FORMAT" = "directory" ]; then
        # Tar and encrypt directory
        tar czf - -C "$(dirname "$BACKUP_FILE")" "$(basename "$BACKUP_FILE")" | \
            gpg --batch --yes --recipient "$GPG_RECIPIENT" --encrypt \
            --output "${BACKUP_FILE}.tar.gz.gpg"

        ENCRYPTED_FILE="${BACKUP_FILE}.tar.gz.gpg"
    else
        # Encrypt file directly
        gpg --batch --yes --recipient "$GPG_RECIPIENT" --encrypt \
            --output "${BACKUP_FILE}.gpg" "$BACKUP_FILE"

        ENCRYPTED_FILE="${BACKUP_FILE}.gpg"
    fi

    # Create checksum of encrypted file
    sha256sum "$ENCRYPTED_FILE" > "${ENCRYPTED_FILE}.sha256"

    success "Backup encrypted: $(basename "$ENCRYPTED_FILE")"

    # Remove unencrypted backup for security
    if [ "$BACKUP_FORMAT" = "directory" ]; then
        rm -rf "$BACKUP_FILE"
    else
        rm -f "$BACKUP_FILE"
    fi

    FINAL_BACKUP="$ENCRYPTED_FILE"
else
    FINAL_BACKUP="$BACKUP_FILE"
fi

################################################################################
# Create Backup Metadata
################################################################################

log "Creating backup metadata..."

METADATA_FILE="$BACKUP_SUBDIR/backup_${TIMESTAMP}.metadata"

cat > "$METADATA_FILE" << EOF
# PromptForge Database Backup Metadata
# Generated: $(date)

[backup]
timestamp=$TIMESTAMP
date=$DATE
format=$BACKUP_FORMAT
encrypted=$ENCRYPT
compression_level=$COMPRESS_LEVEL

[database]
host=$DB_HOST
port=$DB_PORT
name=$DB_NAME
user=$DB_USER

[files]
backup_file=$(basename "$FINAL_BACKUP")
checksum_file=$(basename "${FINAL_BACKUP}.sha256")
size=$BACKUP_SIZE

[verification]
checksum=$(cat "${FINAL_BACKUP}.sha256" | cut -d' ' -f1)
created=$(date -r "$FINAL_BACKUP" '+%Y-%m-%d %H:%M:%S')
EOF

success "Metadata created"

################################################################################
# Create Backup Manifest
################################################################################

log "Creating backup manifest..."

MANIFEST_FILE="$BACKUP_SUBDIR/MANIFEST_${TIMESTAMP}.txt"

cat > "$MANIFEST_FILE" << EOF
================================================================================
PromptForge Database Backup Manifest
================================================================================

Backup Information:
  Date: $DATE
  Timestamp: $TIMESTAMP
  Format: $BACKUP_FORMAT
  Encrypted: $ENCRYPT
  Compression Level: $COMPRESS_LEVEL

Database Information:
  Host: $DB_HOST
  Port: $DB_PORT
  Database: $DB_NAME
  User: $DB_USER

Backup Files:
  Main Backup: $(basename "$FINAL_BACKUP") ($BACKUP_SIZE)
  Checksum: $(basename "${FINAL_BACKUP}.sha256")
  Metadata: $(basename "$METADATA_FILE")

Checksum Verification:
EOF

cat "${FINAL_BACKUP}.sha256" >> "$MANIFEST_FILE"

cat >> "$MANIFEST_FILE" << EOF

================================================================================
Restore Instructions:
================================================================================

To restore this backup:

EOF

if [ "$ENCRYPT" = true ]; then
    cat >> "$MANIFEST_FILE" << EOF
1. Decrypt the backup:
   gpg --decrypt $(basename "$FINAL_BACKUP") > ${DB_NAME}_${TIMESTAMP}.${BACKUP_EXT}

EOF
fi

case $BACKUP_FORMAT in
    plain)
        cat >> "$MANIFEST_FILE" << EOF
2. Restore the database:
   psql -h \$DB_HOST -p \$DB_PORT -U \$DB_USER -d \$DB_NAME < ${DB_NAME}_${TIMESTAMP}.sql

EOF
        ;;
    custom)
        cat >> "$MANIFEST_FILE" << EOF
2. Restore the database:
   pg_restore -h \$DB_HOST -p \$DB_PORT -U \$DB_USER -d \$DB_NAME ${DB_NAME}_${TIMESTAMP}.dump

EOF
        ;;
    directory)
        cat >> "$MANIFEST_FILE" << EOF
2. Restore the database:
   pg_restore -h \$DB_HOST -p \$DB_PORT -U \$DB_USER -d \$DB_NAME --jobs=4 ${DB_NAME}_${TIMESTAMP}.dir

EOF
        ;;
esac

cat >> "$MANIFEST_FILE" << EOF
Or use the restore script:
   ./backup/scripts/restore-db.sh --backup=$BACKUP_SUBDIR

================================================================================
EOF

success "Manifest created"

################################################################################
# Off-site Backup
################################################################################

if [ "$OFFSITE" = true ]; then
    echo ""
    log "Copying backup to remote server..."
    log "Remote: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"

    # Create remote directory
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_PATH}/$DATE"

    # Copy backup files
    rsync -avz --progress \
        "$BACKUP_SUBDIR/" \
        "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/$DATE/"

    if [ $? -eq 0 ]; then
        success "Backup copied to remote server"
    else
        error "Failed to copy backup to remote server"
    fi
fi

################################################################################
# Cleanup Old Backups
################################################################################

echo ""
log "Cleaning up old backups (retention: $RETENTION_DAYS days)..."

find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" -mtime +$RETENTION_DAYS -exec rm -rf {} \;

REMAINING_BACKUPS=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" | wc -l)
success "Cleanup complete ($REMAINING_BACKUPS backups remaining)"

################################################################################
# Summary
################################################################################

echo ""
echo "=========================================="
echo "  Backup Summary"
echo "=========================================="
echo ""
echo "Database: $DB_NAME"
echo "Backup Format: $BACKUP_FORMAT"
echo "Backup Size: $BACKUP_SIZE"
echo "Encrypted: $ENCRYPT"
echo "Off-site Copy: $OFFSITE"
echo "Location: $BACKUP_SUBDIR"
echo ""
success "Database backup completed successfully!"
echo ""
log "Backup files:"
ls -lh "$BACKUP_SUBDIR" | grep -v "^total" | awk '{print "  " $9 " (" $5 ")"}'
echo ""

exit 0

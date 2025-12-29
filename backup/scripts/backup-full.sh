#!/bin/bash

################################################################################
# PromptForge Full System Backup Script
################################################################################
#
# This script performs a comprehensive backup of the entire PromptForge system:
#   - PostgreSQL database (pg_dump)
#   - Docker volumes (all persistent data)
#   - Application configuration files
#   - SSL certificates
#   - Environment files
#   - Monitoring data (optional)
#   - Backup encryption (GPG)
#   - Off-site backup copy (rsync)
#
# Usage:
#   ./backup-full.sh [--encrypt] [--offsite] [--skip-volumes]
#
# Options:
#   --encrypt       Encrypt backup with GPG
#   --offsite       Copy to remote server
#   --skip-volumes  Skip Docker volumes backup
#   --no-db         Skip database backup
#   --help          Show this help message
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-/var/backups/promptforge}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/full-backup-$TIMESTAMP"
LOG_FILE="$BACKUP_BASE_DIR/logs/backup-full-$TIMESTAMP.log"

# Options
ENCRYPT_BACKUP=false
OFFSITE_BACKUP=false
SKIP_VOLUMES=false
SKIP_DATABASE=false

# Backup settings (can be overridden by config file)
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}
COMPRESSION_LEVEL=${BACKUP_COMPRESSION_LEVEL:-6}
GPG_RECIPIENT=${BACKUP_GPG_RECIPIENT:-backup@promptforge.io}
REMOTE_HOST=${BACKUP_REMOTE_HOST:-}
REMOTE_USER=${BACKUP_REMOTE_USER:-backup}
REMOTE_PATH=${BACKUP_REMOTE_PATH:-/backups/promptforge}

################################################################################
# Helper Functions
################################################################################

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠${NC} $1" | tee -a "$LOG_FILE"
}

################################################################################
# Parse Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --encrypt)
            ENCRYPT_BACKUP=true
            shift
            ;;
        --offsite)
            OFFSITE_BACKUP=true
            shift
            ;;
        --skip-volumes)
            SKIP_VOLUMES=true
            shift
            ;;
        --no-db)
            SKIP_DATABASE=true
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
# Load Configuration
################################################################################

load_config() {
    # Load from config file if exists
    if [[ -f "$SCRIPT_DIR/../config/backup.conf" ]]; then
        source "$SCRIPT_DIR/../config/backup.conf"
        log "Loaded configuration from backup.conf"
    fi

    # Load environment variables
    if [[ -f "$PROJECT_ROOT/.env.production" ]]; then
        source "$PROJECT_ROOT/.env.production"
    elif [[ -f "$PROJECT_ROOT/.env" ]]; then
        source "$PROJECT_ROOT/.env"
    fi
}

################################################################################
# Prerequisites Check
################################################################################

check_prerequisites() {
    log "Checking prerequisites..."

    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        error "This script requires root privileges or passwordless sudo"
        exit 1
    fi

    # Check required commands
    local required_commands=("docker" "pg_dump" "tar" "gzip")

    if [[ "$ENCRYPT_BACKUP" == "true" ]]; then
        required_commands+=("gpg")
    fi

    if [[ "$OFFSITE_BACKUP" == "true" ]]; then
        required_commands+=("rsync" "ssh")
    fi

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Required command not found: $cmd"
            exit 1
        fi
    done

    # Create backup directories
    mkdir -p "$BACKUP_DIR"/{database,volumes,config,logs,app-data}
    mkdir -p "$BACKUP_BASE_DIR/logs"

    success "Prerequisites checked"
}

################################################################################
# Backup Database
################################################################################

backup_database() {
    if [[ "$SKIP_DATABASE" == "true" ]]; then
        warning "Skipping database backup"
        return 0
    fi

    log "Backing up PostgreSQL database..."

    local db_backup_file="$BACKUP_DIR/database/promptforge_db_$TIMESTAMP.sql"

    # Get database connection details
    local db_host=$(echo "$DATABASE_URL" | sed -n 's/.*@\([^:]*\):.*/\1/p')
    local db_port=$(echo "$DATABASE_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
    local db_name=$(echo "$DATABASE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')
    local db_user=$(echo "$DATABASE_URL" | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
    local db_pass=$(echo "$DATABASE_URL" | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')

    # Perform backup
    PGPASSWORD="$db_pass" pg_dump \
        -h "$db_host" \
        -p "$db_port" \
        -U "$db_user" \
        -d "$db_name" \
        --format=plain \
        --no-owner \
        --no-acl \
        --verbose \
        > "$db_backup_file" 2>> "$LOG_FILE"

    # Compress
    log "Compressing database backup..."
    gzip -$COMPRESSION_LEVEL "$db_backup_file"

    # Create checksum
    sha256sum "${db_backup_file}.gz" > "${db_backup_file}.gz.sha256"

    local db_size=$(du -h "${db_backup_file}.gz" | cut -f1)
    success "Database backup completed: $db_size"
}

################################################################################
# Backup Docker Volumes
################################################################################

backup_volumes() {
    if [[ "$SKIP_VOLUMES" == "true" ]]; then
        warning "Skipping Docker volumes backup"
        return 0
    fi

    log "Backing up Docker volumes..."

    # Get list of volumes
    local volumes=$(docker volume ls --format '{{.Name}}' | grep promptforge || true)

    if [[ -z "$volumes" ]]; then
        warning "No PromptForge volumes found"
        return 0
    fi

    local volume_count=0
    while IFS= read -r volume; do
        log "Backing up volume: $volume"

        # Create temporary container to access volume
        docker run --rm \
            -v "$volume:/volume" \
            -v "$BACKUP_DIR/volumes:/backup" \
            alpine \
            tar czf "/backup/${volume}_$TIMESTAMP.tar.gz" -C /volume . \
            2>> "$LOG_FILE"

        # Create checksum
        sha256sum "$BACKUP_DIR/volumes/${volume}_$TIMESTAMP.tar.gz" \
            > "$BACKUP_DIR/volumes/${volume}_$TIMESTAMP.tar.gz.sha256"

        ((volume_count++))
    done <<< "$volumes"

    success "Backed up $volume_count Docker volumes"
}

################################################################################
# Backup Configuration Files
################################################################################

backup_config() {
    log "Backing up configuration files..."

    local config_files=(
        ".env"
        ".env.production"
        "docker-compose.yml"
        "docker-compose.prod.yml"
        "docker-compose.ha.yml"
        "docker-compose.monitoring.yml"
        "nginx/nginx.conf"
        "nginx/conf.d"
        "ha/nginx"
        "ha/postgresql"
        "ha/redis"
        "monitoring/prometheus"
        "monitoring/grafana"
        "monitoring/loki"
        "monitoring/alertmanager"
        "database/config"
    )

    for item in "${config_files[@]}"; do
        local source_path="$PROJECT_ROOT/$item"
        if [[ -e "$source_path" ]]; then
            log "Backing up: $item"

            # Create parent directory structure
            local dest_path="$BACKUP_DIR/config/$item"
            mkdir -p "$(dirname "$dest_path")"

            # Copy file or directory
            if [[ -d "$source_path" ]]; then
                cp -r "$source_path" "$dest_path"
            else
                cp "$source_path" "$dest_path"
            fi
        fi
    done

    # Create tarball of all config
    log "Creating configuration archive..."
    tar czf "$BACKUP_DIR/config_$TIMESTAMP.tar.gz" -C "$BACKUP_DIR/config" . \
        2>> "$LOG_FILE"

    # Create checksum
    sha256sum "$BACKUP_DIR/config_$TIMESTAMP.tar.gz" \
        > "$BACKUP_DIR/config_$TIMESTAMP.tar.gz.sha256"

    success "Configuration backup completed"
}

################################################################################
# Backup SSL Certificates
################################################################################

backup_ssl() {
    log "Backing up SSL certificates..."

    local ssl_paths=(
        "nginx/ssl"
        "nginx/ssl/letsencrypt"
    )

    for ssl_path in "${ssl_paths[@]}"; do
        local source_path="$PROJECT_ROOT/$ssl_path"
        if [[ -d "$source_path" ]]; then
            log "Backing up: $ssl_path"

            local dest_path="$BACKUP_DIR/ssl"
            mkdir -p "$dest_path"

            # Copy with permissions preserved
            cp -rp "$source_path" "$dest_path/"
        fi
    done

    if [[ -d "$BACKUP_DIR/ssl" ]]; then
        # Create encrypted tarball for SSL certs
        tar czf - -C "$BACKUP_DIR/ssl" . 2>> "$LOG_FILE" | \
            gpg --batch --yes --passphrase "$GPG_RECIPIENT" -c \
            > "$BACKUP_DIR/ssl_$TIMESTAMP.tar.gz.gpg" 2>> "$LOG_FILE"

        success "SSL certificates backed up (encrypted)"
    else
        warning "No SSL certificates found"
    fi
}

################################################################################
# Backup Application Data
################################################################################

backup_app_data() {
    log "Backing up application data..."

    local app_data_paths=(
        "logs"
        "uploads"
        "media"
        "static"
    )

    for data_path in "${app_data_paths[@]}"; do
        local source_path="$PROJECT_ROOT/$data_path"
        if [[ -d "$source_path" ]]; then
            log "Backing up: $data_path"

            tar czf "$BACKUP_DIR/app-data/${data_path}_$TIMESTAMP.tar.gz" \
                -C "$PROJECT_ROOT" "$data_path" \
                2>> "$LOG_FILE"

            # Create checksum
            sha256sum "$BACKUP_DIR/app-data/${data_path}_$TIMESTAMP.tar.gz" \
                > "$BACKUP_DIR/app-data/${data_path}_$TIMESTAMP.tar.gz.sha256"
        fi
    done

    success "Application data backup completed"
}

################################################################################
# Create Backup Manifest
################################################################################

create_manifest() {
    log "Creating backup manifest..."

    cat > "$BACKUP_DIR/MANIFEST.txt" <<EOF
PromptForge Full System Backup
===============================

Backup Date: $(date)
Backup ID: $TIMESTAMP
Hostname: $(hostname)
Script Version: 1.0

Components:
-----------
Database: $([ "$SKIP_DATABASE" == "true" ] && echo "Skipped" || echo "Included")
Docker Volumes: $([ "$SKIP_VOLUMES" == "true" ] && echo "Skipped" || echo "Included")
Configuration Files: Included
SSL Certificates: Included
Application Data: Included

Options:
--------
Encryption: $([ "$ENCRYPT_BACKUP" == "true" ] && echo "Enabled" || echo "Disabled")
Off-site Copy: $([ "$OFFSITE_BACKUP" == "true" ] && echo "Enabled" || echo "Disabled")
Compression Level: $COMPRESSION_LEVEL

Backup Contents:
----------------
EOF

    # List all files with sizes
    du -h "$BACKUP_DIR"/* >> "$BACKUP_DIR/MANIFEST.txt"

    # Add checksums
    echo "" >> "$BACKUP_DIR/MANIFEST.txt"
    echo "SHA256 Checksums:" >> "$BACKUP_DIR/MANIFEST.txt"
    echo "-----------------" >> "$BACKUP_DIR/MANIFEST.txt"
    find "$BACKUP_DIR" -name "*.sha256" -exec cat {} \; >> "$BACKUP_DIR/MANIFEST.txt"

    success "Manifest created"
}

################################################################################
# Encrypt Backup
################################################################################

encrypt_backup() {
    if [[ "$ENCRYPT_BACKUP" != "true" ]]; then
        return 0
    fi

    log "Encrypting backup..."

    # Create tarball of entire backup
    local backup_tarball="$BACKUP_BASE_DIR/promptforge-backup-$TIMESTAMP.tar.gz"
    tar czf "$backup_tarball" -C "$BACKUP_BASE_DIR" "full-backup-$TIMESTAMP" \
        2>> "$LOG_FILE"

    # Encrypt with GPG
    gpg --batch --yes --recipient "$GPG_RECIPIENT" --encrypt \
        --output "${backup_tarball}.gpg" "$backup_tarball" \
        2>> "$LOG_FILE"

    # Remove unencrypted tarball
    rm "$backup_tarball"

    success "Backup encrypted"
}

################################################################################
# Off-site Backup
################################################################################

offsite_backup() {
    if [[ "$OFFSITE_BACKUP" != "true" ]]; then
        return 0
    fi

    if [[ -z "$REMOTE_HOST" ]]; then
        warning "Remote host not configured, skipping off-site backup"
        return 0
    fi

    log "Copying backup to remote server: $REMOTE_HOST"

    # Test SSH connection
    if ! ssh -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "echo 'Connection OK'" &> /dev/null; then
        error "Cannot connect to remote server"
        return 1
    fi

    # Create remote directory
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p $REMOTE_PATH" 2>> "$LOG_FILE"

    # Rsync backup
    rsync -avz --progress \
        "$BACKUP_DIR/" \
        "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/full-backup-$TIMESTAMP/" \
        2>&1 | tee -a "$LOG_FILE"

    # If encrypted tarball exists, copy that too
    if [[ -f "$BACKUP_BASE_DIR/promptforge-backup-$TIMESTAMP.tar.gz.gpg" ]]; then
        rsync -avz --progress \
            "$BACKUP_BASE_DIR/promptforge-backup-$TIMESTAMP.tar.gz.gpg" \
            "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/" \
            2>&1 | tee -a "$LOG_FILE"
    fi

    success "Off-site backup completed"
}

################################################################################
# Cleanup Old Backups
################################################################################

cleanup_old_backups() {
    log "Cleaning up old backups (retention: $RETENTION_DAYS days)..."

    # Find and delete old backups
    local deleted_count=0

    while IFS= read -r old_backup; do
        if [[ -n "$old_backup" ]]; then
            log "Deleting old backup: $(basename "$old_backup")"
            rm -rf "$old_backup"
            ((deleted_count++))
        fi
    done < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -name "full-backup-*" -type d -mtime +$RETENTION_DAYS)

    # Clean up old encrypted tarballs
    while IFS= read -r old_tarball; do
        if [[ -n "$old_tarball" ]]; then
            log "Deleting old encrypted backup: $(basename "$old_tarball")"
            rm -f "$old_tarball"
            ((deleted_count++))
        fi
    done < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -name "promptforge-backup-*.tar.gz.gpg" -type f -mtime +$RETENTION_DAYS)

    if [[ $deleted_count -gt 0 ]]; then
        success "Deleted $deleted_count old backup(s)"
    else
        log "No old backups to delete"
    fi
}

################################################################################
# Display Summary
################################################################################

show_summary() {
    local backup_size=$(du -sh "$BACKUP_DIR" | cut -f1)
    local total_size=$(du -sh "$BACKUP_BASE_DIR" | cut -f1)

    echo ""
    success "=========================================="
    success "  Full System Backup Complete!"
    success "=========================================="
    echo ""
    log "Backup Details:"
    echo "  Timestamp: $TIMESTAMP"
    echo "  Location: $BACKUP_DIR"
    echo "  Size: $backup_size"
    echo ""
    log "Components Backed Up:"
    echo "  ✓ Database: $([ "$SKIP_DATABASE" == "true" ] && echo "Skipped" || echo "Yes")"
    echo "  ✓ Docker Volumes: $([ "$SKIP_VOLUMES" == "true" ] && echo "Skipped" || echo "Yes")"
    echo "  ✓ Configuration Files: Yes"
    echo "  ✓ SSL Certificates: Yes"
    echo "  ✓ Application Data: Yes"
    echo ""
    log "Options:"
    echo "  Encrypted: $([ "$ENCRYPT_BACKUP" == "true" ] && echo "Yes" || echo "No")"
    echo "  Off-site Copy: $([ "$OFFSITE_BACKUP" == "true" ] && echo "Yes" || echo "No")"
    echo ""
    log "All Backups Size: $total_size"
    log "Retention: $RETENTION_DAYS days"
    echo ""
    log "Manifest: $BACKUP_DIR/MANIFEST.txt"
    log "Log File: $LOG_FILE"
    echo ""
}

################################################################################
# Main Script
################################################################################

echo "=========================================="
echo "  PromptForge Full System Backup"
echo "=========================================="
echo ""

load_config
check_prerequisites
backup_database
backup_volumes
backup_config
backup_ssl
backup_app_data
create_manifest
encrypt_backup
offsite_backup
cleanup_old_backups
show_summary

exit 0

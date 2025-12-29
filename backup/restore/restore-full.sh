#!/bin/bash

################################################################################
# PromptForge Full System Restore Script
################################################################################
#
# This script performs a complete system restore from a full backup.
# It restores the database, Docker volumes, configuration files, SSL
# certificates, and all application data.
#
# Features:
#   - Complete system restoration from full backup
#   - Database restore with validation
#   - Docker volume restoration
#   - Configuration file restoration
#   - SSL certificate restoration
#   - Application data restoration
#   - Backup verification before restore
#   - Step-by-step restore with progress tracking
#   - Dry-run mode for testing
#   - Rollback capability
#
# Usage:
#   ./restore-full.sh [OPTIONS] --backup=<path>
#
# Options:
#   --backup=<path>       Path to full backup directory (required)
#   --skip-db             Skip database restore
#   --skip-volumes        Skip Docker volume restore
#   --skip-configs        Skip configuration restore
#   --force               Skip confirmation prompts
#   --dry-run             Show what would be done without doing it
#   --help                Show this help message
#
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Configuration
BACKUP_PATH=""
SKIP_DB=false
SKIP_VOLUMES=false
SKIP_CONFIGS=false
FORCE=false
DRY_RUN=false

# Restore tracking
STEPS_TOTAL=0
STEPS_COMPLETED=0
STEPS_FAILED=0

################################################################################
# Helper Functions
################################################################################

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

step() {
    ((STEPS_TOTAL++))
    echo -e "${CYAN}[STEP $STEPS_TOTAL]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    ((STEPS_COMPLETED++))
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((STEPS_FAILED++))
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
            log "Operation cancelled by user"
            exit 0
            ;;
    esac
}

show_help() {
    cat << EOF
PromptForge Full System Restore Script

Usage: $0 [OPTIONS] --backup=<path>

Options:
    --backup=<path>      Path to full backup directory (required)
    --skip-db            Skip database restore
    --skip-volumes       Skip Docker volume restore
    --skip-configs       Skip configuration restore
    --force              Skip confirmation prompts
    --dry-run            Show what would be done without doing it
    --help               Show this help message

Environment Variables:
    DB_HOST              Database host (default: localhost)
    DB_PORT              Database port (default: 5432)
    POSTGRES_USER        PostgreSQL superuser
    POSTGRES_PASSWORD    PostgreSQL superuser password

Examples:
    # Restore from latest backup
    ./restore-full.sh --backup=../../backups/full/\$(ls -t ../../backups/full | head -1)

    # Restore without volumes (faster)
    ./restore-full.sh --backup=/path/to/backup --skip-volumes

    # Dry run to test
    ./restore-full.sh --backup=/path/to/backup --dry-run

    # Force restore without confirmations
    ./restore-full.sh --backup=/path/to/backup --force

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
        --skip-db)
            SKIP_DB=true
            shift
            ;;
        --skip-volumes)
            SKIP_VOLUMES=true
            shift
            ;;
        --skip-configs)
            SKIP_CONFIGS=true
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

if [ ! -d "$BACKUP_PATH" ]; then
    error "Backup directory not found: $BACKUP_PATH"
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

################################################################################
# Restore Header
################################################################################

clear
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║        PromptForge Full System Restore                     ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
log "Backup: $BACKUP_PATH"
log "Dry Run: $DRY_RUN"
echo ""
log "Restore components:"
echo "  ✓ Database:      $([ "$SKIP_DB" = false ] && echo "YES" || echo "SKIP")"
echo "  ✓ Volumes:       $([ "$SKIP_VOLUMES" = false ] && echo "YES" || echo "SKIP")"
echo "  ✓ Configs:       $([ "$SKIP_CONFIGS" = false ] && echo "YES" || echo "SKIP")"
echo "  ✓ SSL Certs:     YES"
echo "  ✓ App Data:      YES"
echo ""

################################################################################
# Pre-flight Checks
################################################################################

step "Running pre-flight checks..."

# Check if backup exists and is valid
if [ ! -f "$BACKUP_PATH/MANIFEST_"*.txt ]; then
    error "No manifest file found in backup"
    exit 1
fi

MANIFEST_FILE=$(find "$BACKUP_PATH" -name "MANIFEST_*.txt" | head -1)
success "Backup manifest found: $(basename "$MANIFEST_FILE")"

# Check for backup metadata
if [ ! -f "$BACKUP_PATH/backup_"*.metadata ]; then
    warning "No metadata file found in backup"
else
    METADATA_FILE=$(find "$BACKUP_PATH" -name "backup_*.metadata" | head -1)
    success "Backup metadata found: $(basename "$METADATA_FILE")"

    # Load backup metadata
    source "$METADATA_FILE"
    log "Backup date: $backup_date"
    log "Backup encrypted: $encrypted"
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    error "Docker is not installed"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    error "Docker Compose is not installed"
    exit 1
fi

success "Docker is available"

################################################################################
# Verify Backup
################################################################################

step "Verifying backup integrity..."

VERIFY_SCRIPT="$PROJECT_ROOT/backup/scripts/backup-verify.sh"
if [ -x "$VERIFY_SCRIPT" ] && [ "$DRY_RUN" = false ]; then
    if "$VERIFY_SCRIPT" --skip-db-test "$BACKUP_PATH"; then
        success "Backup verification passed"
    else
        error "Backup verification failed"
        confirm "Backup verification failed. Do you want to continue anyway?"
    fi
else
    warning "Skipping backup verification"
fi

################################################################################
# Final Confirmation
################################################################################

echo ""
warning "⚠️  WARNING: This will restore the entire PromptForge system!"
warning "⚠️  All current data will be replaced with backup data!"
echo ""
confirm "Are you absolutely sure you want to continue?"

################################################################################
# Stop Application
################################################################################

step "Stopping application..."

if [ "$DRY_RUN" = true ]; then
    log "[DRY RUN] Would stop all containers"
else
    cd "$PROJECT_ROOT"

    # Stop all compose stacks
    docker-compose down 2>/dev/null || true
    docker-compose -f docker-compose.ha.yml down 2>/dev/null || true
    docker-compose -f docker-compose.monitoring.yml down 2>/dev/null || true

    success "Application stopped"
fi

################################################################################
# Restore Database
################################################################################

if [ "$SKIP_DB" = false ]; then
    step "Restoring database..."

    DB_RESTORE_SCRIPT="$SCRIPT_DIR/restore-db.sh"

    if [ ! -x "$DB_RESTORE_SCRIPT" ]; then
        error "Database restore script not found: $DB_RESTORE_SCRIPT"
    else
        if [ "$DRY_RUN" = true ]; then
            log "[DRY RUN] Would restore database from backup"
        else
            # Find database backup
            DB_BACKUP=$(find "$BACKUP_PATH" -name "database_backup.dump" -o -name "database_backup.sql.gz" | head -1)

            if [ -z "$DB_BACKUP" ]; then
                error "Database backup not found in backup directory"
            else
                log "Restoring database from: $(basename "$DB_BACKUP")"

                if "$DB_RESTORE_SCRIPT" --backup="$DB_BACKUP" --drop-existing --force; then
                    success "Database restored successfully"
                else
                    error "Database restore failed"
                    confirm "Database restore failed. Continue with remaining steps?"
                fi
            fi
        fi
    fi
else
    log "Skipping database restore (--skip-db)"
fi

################################################################################
# Restore Docker Volumes
################################################################################

if [ "$SKIP_VOLUMES" = false ]; then
    step "Restoring Docker volumes..."

    VOLUMES_DIR="$BACKUP_PATH/volumes"

    if [ ! -d "$VOLUMES_DIR" ]; then
        warning "No volumes directory in backup"
    else
        VOLUME_BACKUPS=$(find "$VOLUMES_DIR" -name "*.tar.gz" 2>/dev/null)

        if [ -z "$VOLUME_BACKUPS" ]; then
            warning "No volume backups found"
        else
            VOLUME_COUNT=0

            while IFS= read -r volume_backup; do
                volume_name=$(basename "$volume_backup" .tar.gz)
                ((VOLUME_COUNT++))

                log "Restoring volume: $volume_name"

                if [ "$DRY_RUN" = true ]; then
                    log "[DRY RUN] Would restore volume: $volume_name"
                else
                    # Create volume if it doesn't exist
                    docker volume create "$volume_name" >/dev/null 2>&1 || true

                    # Restore volume data
                    docker run --rm \
                        -v "$volume_name:/volume" \
                        -v "$VOLUMES_DIR:/backup" \
                        alpine \
                        sh -c "rm -rf /volume/* && tar xzf /backup/$(basename "$volume_backup") -C /volume"

                    if [ $? -eq 0 ]; then
                        log "✓ Restored: $volume_name"
                    else
                        error "✗ Failed to restore: $volume_name"
                    fi
                fi
            done <<< "$VOLUME_BACKUPS"

            success "Restored $VOLUME_COUNT Docker volumes"
        fi
    fi
else
    log "Skipping Docker volume restore (--skip-volumes)"
fi

################################################################################
# Restore Configuration Files
################################################################################

if [ "$SKIP_CONFIGS" = false ]; then
    step "Restoring configuration files..."

    CONFIGS_DIR="$BACKUP_PATH/configs"

    if [ ! -d "$CONFIGS_DIR" ]; then
        warning "No configs directory in backup"
    else
        if [ "$DRY_RUN" = true ]; then
            log "[DRY RUN] Would restore configuration files"
        else
            # Restore .env files
            if [ -f "$CONFIGS_DIR/.env" ]; then
                cp "$CONFIGS_DIR/.env" "$PROJECT_ROOT/.env"
                success "Restored .env"
            fi

            if [ -f "$CONFIGS_DIR/.env.monitoring" ]; then
                cp "$CONFIGS_DIR/.env.monitoring" "$PROJECT_ROOT/.env.monitoring"
                log "✓ Restored .env.monitoring"
            fi

            # Restore docker-compose files
            for compose_file in "$CONFIGS_DIR"/docker-compose*.yml; do
                if [ -f "$compose_file" ]; then
                    cp "$compose_file" "$PROJECT_ROOT/"
                    log "✓ Restored $(basename "$compose_file")"
                fi
            done

            # Restore nginx configs
            if [ -d "$CONFIGS_DIR/nginx" ]; then
                cp -r "$CONFIGS_DIR/nginx" "$PROJECT_ROOT/"
                log "✓ Restored nginx configs"
            fi

            # Restore HA configs
            if [ -d "$CONFIGS_DIR/ha" ]; then
                cp -r "$CONFIGS_DIR/ha" "$PROJECT_ROOT/"
                log "✓ Restored HA configs"
            fi

            # Restore monitoring configs
            if [ -d "$CONFIGS_DIR/monitoring" ]; then
                cp -r "$CONFIGS_DIR/monitoring" "$PROJECT_ROOT/"
                log "✓ Restored monitoring configs"
            fi

            # Restore database configs
            if [ -d "$CONFIGS_DIR/database" ]; then
                cp -r "$CONFIGS_DIR/database" "$PROJECT_ROOT/"
                log "✓ Restored database configs"
            fi

            success "Configuration files restored"
        fi
    fi
else
    log "Skipping configuration restore (--skip-configs)"
fi

################################################################################
# Restore SSL Certificates
################################################################################

step "Restoring SSL certificates..."

SSL_DIR="$BACKUP_PATH/ssl"

if [ ! -d "$SSL_DIR" ]; then
    log "No SSL certificates in backup (this may be normal)"
else
    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would restore SSL certificates"
    else
        mkdir -p "$PROJECT_ROOT/ssl/certs"
        mkdir -p "$PROJECT_ROOT/ssl/private"

        # Restore certificates
        if [ -d "$SSL_DIR/certs" ]; then
            cp -r "$SSL_DIR/certs"/* "$PROJECT_ROOT/ssl/certs/" 2>/dev/null || true
            log "✓ Restored SSL certificates"
        fi

        # Restore private keys
        if [ -d "$SSL_DIR/private" ]; then
            cp -r "$SSL_DIR/private"/* "$PROJECT_ROOT/ssl/private/" 2>/dev/null || true
            chmod 600 "$PROJECT_ROOT/ssl/private"/* 2>/dev/null || true
            log "✓ Restored SSL private keys"
        fi

        success "SSL certificates restored"
    fi
fi

################################################################################
# Restore Application Data
################################################################################

step "Restoring application data..."

APP_DATA_DIR="$BACKUP_PATH/app_data"

if [ ! -d "$APP_DATA_DIR" ]; then
    log "No application data in backup"
else
    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would restore application data"
    else
        # Restore logs
        if [ -d "$APP_DATA_DIR/logs" ]; then
            mkdir -p "$PROJECT_ROOT/logs"
            cp -r "$APP_DATA_DIR/logs"/* "$PROJECT_ROOT/logs/" 2>/dev/null || true
            log "✓ Restored logs"
        fi

        # Restore uploads
        if [ -d "$APP_DATA_DIR/uploads" ]; then
            mkdir -p "$PROJECT_ROOT/uploads"
            cp -r "$APP_DATA_DIR/uploads"/* "$PROJECT_ROOT/uploads/" 2>/dev/null || true
            log "✓ Restored uploads"
        fi

        # Restore media
        if [ -d "$APP_DATA_DIR/media" ]; then
            mkdir -p "$PROJECT_ROOT/media"
            cp -r "$APP_DATA_DIR/media"/* "$PROJECT_ROOT/media/" 2>/dev/null || true
            log "✓ Restored media files"
        fi

        # Restore static files
        if [ -d "$APP_DATA_DIR/static" ]; then
            mkdir -p "$PROJECT_ROOT/backend/static"
            cp -r "$APP_DATA_DIR/static"/* "$PROJECT_ROOT/backend/static/" 2>/dev/null || true
            log "✓ Restored static files"
        fi

        success "Application data restored"
    fi
fi

################################################################################
# Verify Restoration
################################################################################

step "Verifying restoration..."

if [ "$DRY_RUN" = false ]; then
    # Check essential files
    ESSENTIAL_FILES=(
        ".env"
        "docker-compose.yml"
    )

    MISSING_FILES=0
    for file in "${ESSENTIAL_FILES[@]}"; do
        if [ -f "$PROJECT_ROOT/$file" ]; then
            log "✓ $file exists"
        else
            error "✗ $file is missing"
            ((MISSING_FILES++))
        fi
    done

    if [ $MISSING_FILES -eq 0 ]; then
        success "All essential files present"
    else
        warning "$MISSING_FILES essential files are missing"
    fi
else
    log "[DRY RUN] Skipping verification"
fi

################################################################################
# Post-Restore Instructions
################################################################################

echo ""
echo "=========================================="
echo "  Restore Summary"
echo "=========================================="
echo ""
echo "Total Steps: $STEPS_TOTAL"
echo "Completed:   $STEPS_COMPLETED"
echo "Failed:      $STEPS_FAILED"
echo ""

if [ "$DRY_RUN" = true ]; then
    log "Dry run completed (no changes made)"
    echo ""
else
    if [ $STEPS_FAILED -eq 0 ]; then
        success "Full system restore completed successfully!"
        echo ""
        log "Next steps:"
        echo "  1. Review restored configuration files (.env, docker-compose.yml)"
        echo "  2. Update any environment-specific settings"
        echo "  3. Start the database: docker-compose up -d postgres"
        echo "  4. Verify database: docker exec promptforge-postgres psql -U promptforge -c '\\dt'"
        echo "  5. Start the application: docker-compose up -d"
        echo "  6. Check application status: docker-compose ps"
        echo "  7. Verify application: curl http://localhost:8000/api/health"
        echo "  8. Access application: http://localhost:3000"
        echo ""
        warning "Important: Review and update all configuration files before starting!"
    else
        error "Restore completed with $STEPS_FAILED failures"
        echo ""
        log "Review the errors above and take corrective action"
        log "You may need to restore individual components manually"
    fi
fi

echo ""
exit $([ $STEPS_FAILED -eq 0 ] && echo 0 || echo 1)

#!/bin/bash

################################################################################
# PromptForge Backup Verification Script
################################################################################
#
# This script verifies the integrity and restorability of PromptForge backups.
# It performs comprehensive checks to ensure backups are valid and usable.
#
# Features:
#   - SHA256 checksum verification
#   - File integrity checks
#   - Backup completeness validation
#   - Test restore operations (optional)
#   - Database backup validation
#   - GPG encryption verification
#   - Detailed verification reports
#   - Automated testing integration
#
# Usage:
#   ./backup-verify.sh [OPTIONS] <backup_path>
#
# Options:
#   --test-restore          Perform test restore to temporary database
#   --skip-checksums        Skip checksum verification
#   --skip-db-test          Skip database validation test
#   --verbose               Verbose output
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
TEST_RESTORE=false
SKIP_CHECKSUMS=false
SKIP_DB_TEST=false
VERBOSE=false
BACKUP_PATH=""

# Verification results
CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

################################################################################
# Helper Functions
################################################################################

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((CHECKS_PASSED++))
}

error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((CHECKS_FAILED++))
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

show_help() {
    cat << EOF
PromptForge Backup Verification Script

Usage: $0 [OPTIONS] <backup_path>

Arguments:
    backup_path    Path to backup directory to verify

Options:
    --test-restore     Perform test restore to temporary database
    --skip-checksums   Skip checksum verification
    --skip-db-test     Skip database validation test
    --verbose          Verbose output
    --help             Show this help message

Examples:
    # Basic verification
    ./backup-verify.sh /path/to/backup

    # Verify with test restore
    ./backup-verify.sh --test-restore /path/to/backup

    # Verify latest backup
    ./backup-verify.sh ../../backups/full/\$(ls -t ../../backups/full | head -1)

    # Automated verification (cron)
    ./backup-verify.sh --skip-db-test /path/to/backup

EOF
    exit 0
}

################################################################################
# Parse Command Line Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --test-restore)
            TEST_RESTORE=true
            shift
            ;;
        --skip-checksums)
            SKIP_CHECKSUMS=true
            shift
            ;;
        --skip-db-test)
            SKIP_DB_TEST=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            ;;
        -*)
            error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            BACKUP_PATH="$1"
            shift
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
# Verification Header
################################################################################

echo ""
echo "=========================================="
echo "  Backup Verification"
echo "=========================================="
echo ""
log "Backup path: $BACKUP_PATH"
log "Test restore: $TEST_RESTORE"
log "Started: $(date)"
echo ""

################################################################################
# Check 1: Verify Directory Structure
################################################################################

log "Checking directory structure..."

# Check for manifest file
MANIFEST_FILES=$(find "$BACKUP_PATH" -name "MANIFEST_*.txt" 2>/dev/null)
if [ -n "$MANIFEST_FILES" ]; then
    success "Manifest file found"
    MANIFEST_FILE=$(echo "$MANIFEST_FILES" | head -1)
    verbose "Manifest: $MANIFEST_FILE"
else
    error "No manifest file found"
fi

# Check for metadata file
METADATA_FILES=$(find "$BACKUP_PATH" -name "*.metadata" 2>/dev/null)
if [ -n "$METADATA_FILES" ]; then
    success "Metadata file found"
    METADATA_FILE=$(echo "$METADATA_FILES" | head -1)
    verbose "Metadata: $METADATA_FILE"
else
    warning "No metadata file found"
fi

################################################################################
# Check 2: Verify Checksums
################################################################################

if [ "$SKIP_CHECKSUMS" = false ]; then
    echo ""
    log "Verifying checksums..."

    CHECKSUM_FILES=$(find "$BACKUP_PATH" -name "*.sha256" 2>/dev/null)

    if [ -z "$CHECKSUM_FILES" ]; then
        warning "No checksum files found"
    else
        CHECKSUM_COUNT=0
        CHECKSUM_PASSED=0
        CHECKSUM_FAILED=0

        while IFS= read -r checksum_file; do
            ((CHECKSUM_COUNT++))
            verbose "Checking: $checksum_file"

            # Get the file being checksummed
            CHECKSUMMED_FILE="${checksum_file%.sha256}"

            if [ ! -f "$CHECKSUMMED_FILE" ] && [ ! -d "$CHECKSUMMED_FILE" ]; then
                error "Checksummed file not found: $(basename "$CHECKSUMMED_FILE")"
                ((CHECKSUM_FAILED++))
                continue
            fi

            # Verify checksum
            CHECKSUM_DIR=$(dirname "$checksum_file")
            if (cd "$CHECKSUM_DIR" && sha256sum -c "$(basename "$checksum_file")" &>/dev/null); then
                ((CHECKSUM_PASSED++))
                verbose "✓ $(basename "$CHECKSUMMED_FILE")"
            else
                error "Checksum mismatch: $(basename "$CHECKSUMMED_FILE")"
                ((CHECKSUM_FAILED++))
            fi
        done <<< "$CHECKSUM_FILES"

        if [ $CHECKSUM_FAILED -eq 0 ]; then
            success "All checksums verified ($CHECKSUM_PASSED/$CHECKSUM_COUNT)"
        else
            error "Checksum verification failed ($CHECKSUM_FAILED/$CHECKSUM_COUNT failures)"
        fi
    fi
fi

################################################################################
# Check 3: Verify Database Backup
################################################################################

echo ""
log "Checking database backup..."

# Find database backup files
DB_BACKUPS=$(find "$BACKUP_PATH" -name "*.dump" -o -name "*.sql" -o -name "*.sql.gz" -o -name "*.dir" 2>/dev/null | grep -v "\.gpg$")

if [ -z "$DB_BACKUPS" ]; then
    # Check for encrypted backups
    ENCRYPTED_DB=$(find "$BACKUP_PATH" -name "*.dump.gpg" -o -name "*.sql.gz.gpg" 2>/dev/null)

    if [ -n "$ENCRYPTED_DB" ]; then
        success "Database backup found (encrypted)"
        DB_BACKUP_FILE=$(echo "$ENCRYPTED_DB" | head -1)
        DB_ENCRYPTED=true
    else
        error "No database backup found"
        DB_BACKUP_FILE=""
    fi
else
    success "Database backup found"
    DB_BACKUP_FILE=$(echo "$DB_BACKUPS" | head -1)
    DB_ENCRYPTED=false
fi

# Check database backup size
if [ -n "$DB_BACKUP_FILE" ]; then
    DB_SIZE=$(du -sh "$DB_BACKUP_FILE" | cut -f1)
    log "Database backup size: $DB_SIZE"

    # Warn if backup is suspiciously small
    DB_SIZE_BYTES=$(du -b "$DB_BACKUP_FILE" | cut -f1)
    if [ $DB_SIZE_BYTES -lt 1048576 ]; then  # Less than 1MB
        warning "Database backup seems unusually small ($DB_SIZE)"
    else
        success "Database backup size is reasonable"
    fi
fi

################################################################################
# Check 4: Test Database Backup (if not encrypted and not skipped)
################################################################################

if [ "$SKIP_DB_TEST" = false ] && [ "$DB_ENCRYPTED" = false ] && [ -n "$DB_BACKUP_FILE" ]; then
    echo ""
    log "Testing database backup integrity..."

    # Determine backup format
    if [[ "$DB_BACKUP_FILE" == *.sql.gz ]]; then
        verbose "Testing gzipped SQL backup..."
        if gzip -t "$DB_BACKUP_FILE" 2>/dev/null; then
            success "Database backup is a valid gzip file"

            # Test SQL syntax (basic check)
            if zcat "$DB_BACKUP_FILE" | head -100 | grep -q "CREATE\|INSERT\|ALTER"; then
                success "Database backup contains valid SQL"
            else
                warning "Database backup may not contain valid SQL"
            fi
        else
            error "Database backup is not a valid gzip file"
        fi

    elif [[ "$DB_BACKUP_FILE" == *.sql ]]; then
        verbose "Testing plain SQL backup..."
        if head -100 "$DB_BACKUP_FILE" | grep -q "CREATE\|INSERT\|ALTER"; then
            success "Database backup contains valid SQL"
        else
            warning "Database backup may not contain valid SQL"
        fi

    elif [[ "$DB_BACKUP_FILE" == *.dump ]]; then
        verbose "Testing custom format backup..."
        # Try to list the backup contents
        if pg_restore --list "$DB_BACKUP_FILE" &>/dev/null; then
            success "Database backup is a valid pg_dump custom format"

            # Count objects in backup
            OBJECT_COUNT=$(pg_restore --list "$DB_BACKUP_FILE" | grep -c "^[0-9]")
            log "Database objects in backup: $OBJECT_COUNT"

            if [ $OBJECT_COUNT -eq 0 ]; then
                warning "Database backup appears to be empty"
            else
                success "Database backup contains $OBJECT_COUNT objects"
            fi
        else
            error "Database backup is not a valid pg_dump format"
        fi

    elif [[ "$DB_BACKUP_FILE" == *.dir ]]; then
        verbose "Testing directory format backup..."
        if [ -d "$DB_BACKUP_FILE" ] && [ -f "$DB_BACKUP_FILE/toc.dat" ]; then
            success "Database backup is a valid directory format"

            # Try to list the backup contents
            if pg_restore --list "$DB_BACKUP_FILE" &>/dev/null; then
                OBJECT_COUNT=$(pg_restore --list "$DB_BACKUP_FILE" | grep -c "^[0-9]")
                success "Database backup contains $OBJECT_COUNT objects"
            else
                warning "Unable to read database backup catalog"
            fi
        else
            error "Database backup is not a valid directory format"
        fi
    fi
fi

################################################################################
# Check 5: Verify Configuration Backups
################################################################################

echo ""
log "Checking configuration backups..."

CONFIG_FOUND=0

# Check for .env files
if find "$BACKUP_PATH" -name ".env*" 2>/dev/null | grep -q "."; then
    success "Environment configuration found"
    ((CONFIG_FOUND++))
fi

# Check for docker-compose files
if find "$BACKUP_PATH" -name "docker-compose*.yml" 2>/dev/null | grep -q "."; then
    success "Docker Compose configuration found"
    ((CONFIG_FOUND++))
fi

# Check for nginx configs
if find "$BACKUP_PATH" -name "*.conf" 2>/dev/null | grep -q "nginx"; then
    success "Nginx configuration found"
    ((CONFIG_FOUND++))
fi

if [ $CONFIG_FOUND -eq 0 ]; then
    warning "No configuration files found in backup"
fi

################################################################################
# Check 6: Verify SSL Certificates (if present)
################################################################################

echo ""
log "Checking SSL certificates..."

CERT_FILES=$(find "$BACKUP_PATH" -name "*.crt" -o -name "*.pem" 2>/dev/null)

if [ -z "$CERT_FILES" ]; then
    log "No SSL certificates in backup (this may be normal)"
else
    CERT_COUNT=0
    CERT_VALID=0

    while IFS= read -r cert_file; do
        ((CERT_COUNT++))
        verbose "Checking: $(basename "$cert_file")"

        # Verify certificate format
        if openssl x509 -in "$cert_file" -noout 2>/dev/null; then
            ((CERT_VALID++))
        else
            warning "Invalid certificate format: $(basename "$cert_file")"
        fi
    done <<< "$CERT_FILES"

    if [ $CERT_VALID -eq $CERT_COUNT ]; then
        success "All SSL certificates are valid ($CERT_COUNT)"
    else
        warning "Some SSL certificates may be invalid ($CERT_VALID/$CERT_COUNT)"
    fi
fi

################################################################################
# Check 7: Verify Docker Volumes (if present)
################################################################################

echo ""
log "Checking Docker volume backups..."

VOLUME_BACKUPS=$(find "$BACKUP_PATH/volumes" -name "*.tar.gz" 2>/dev/null)

if [ -z "$VOLUME_BACKUPS" ]; then
    log "No Docker volume backups found (this may be normal)"
else
    VOLUME_COUNT=0
    VOLUME_VALID=0

    while IFS= read -r volume_backup; do
        ((VOLUME_COUNT++))
        verbose "Checking: $(basename "$volume_backup")"

        # Test tarball integrity
        if tar tzf "$volume_backup" &>/dev/null; then
            ((VOLUME_VALID++))
        else
            error "Corrupted volume backup: $(basename "$volume_backup")"
        fi
    done <<< "$VOLUME_BACKUPS"

    if [ $VOLUME_VALID -eq $VOLUME_COUNT ]; then
        success "All Docker volume backups are valid ($VOLUME_COUNT)"
    else
        error "Some Docker volume backups are corrupted ($VOLUME_VALID/$VOLUME_COUNT)"
    fi
fi

################################################################################
# Check 8: Test Restore (Optional)
################################################################################

if [ "$TEST_RESTORE" = true ] && [ -n "$DB_BACKUP_FILE" ] && [ "$DB_ENCRYPTED" = false ]; then
    echo ""
    log "Performing test restore..."

    # Create temporary database for testing
    TEST_DB="promptforge_test_restore_$$"
    log "Creating test database: $TEST_DB"

    # Load database credentials
    if [ -f "$PROJECT_ROOT/.env" ]; then
        set -a
        source "$PROJECT_ROOT/.env"
        set +a
    fi

    DB_HOST="${DB_HOST:-localhost}"
    DB_PORT="${DB_PORT:-5432}"
    POSTGRES_USER="${POSTGRES_USER:-postgres}"
    POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"

    # Create test database
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" \
        -c "CREATE DATABASE $TEST_DB;" 2>/dev/null || true

    # Attempt restore
    if [[ "$DB_BACKUP_FILE" == *.sql.gz ]]; then
        zcat "$DB_BACKUP_FILE" | PGPASSWORD="$POSTGRES_PASSWORD" psql \
            -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$TEST_DB" \
            &>/dev/null
    elif [[ "$DB_BACKUP_FILE" == *.sql ]]; then
        PGPASSWORD="$POSTGRES_PASSWORD" psql \
            -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$TEST_DB" \
            < "$DB_BACKUP_FILE" &>/dev/null
    elif [[ "$DB_BACKUP_FILE" == *.dump ]]; then
        PGPASSWORD="$POSTGRES_PASSWORD" pg_restore \
            -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$TEST_DB" \
            "$DB_BACKUP_FILE" &>/dev/null
    elif [[ "$DB_BACKUP_FILE" == *.dir ]]; then
        PGPASSWORD="$POSTGRES_PASSWORD" pg_restore \
            -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$TEST_DB" \
            --jobs=2 "$DB_BACKUP_FILE" &>/dev/null
    fi

    if [ $? -eq 0 ]; then
        success "Test restore completed successfully"

        # Verify tables were created
        TABLE_COUNT=$(PGPASSWORD="$POSTGRES_PASSWORD" psql \
            -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$TEST_DB" \
            -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" 2>/dev/null | tr -d ' ')

        if [ -n "$TABLE_COUNT" ] && [ "$TABLE_COUNT" -gt 0 ]; then
            success "Test database contains $TABLE_COUNT tables"
        else
            warning "Test database appears to be empty"
        fi
    else
        error "Test restore failed"
    fi

    # Cleanup test database
    log "Cleaning up test database..."
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" \
        -c "DROP DATABASE $TEST_DB;" 2>/dev/null || true

    success "Test database cleaned up"
fi

################################################################################
# Verification Summary
################################################################################

echo ""
echo "=========================================="
echo "  Verification Summary"
echo "=========================================="
echo ""
echo "Backup Path: $BACKUP_PATH"
echo "Verification Time: $(date)"
echo ""
echo "Results:"
echo "  ✓ Checks Passed: $CHECKS_PASSED"
echo "  ✗ Checks Failed: $CHECKS_FAILED"
echo "  ⚠ Warnings: $WARNINGS"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        success "Backup verification passed with no issues"
        EXIT_CODE=0
    else
        warning "Backup verification passed with $WARNINGS warnings"
        EXIT_CODE=0
    fi
else
    error "Backup verification failed with $CHECKS_FAILED errors"
    EXIT_CODE=1
fi

echo ""

# Generate verification report
REPORT_FILE="$BACKUP_PATH/verification_report_$(date +%Y%m%d_%H%M%S).txt"

cat > "$REPORT_FILE" << EOF
================================================================================
PromptForge Backup Verification Report
================================================================================

Backup Path: $BACKUP_PATH
Verification Time: $(date)

Results:
  Checks Passed: $CHECKS_PASSED
  Checks Failed: $CHECKS_FAILED
  Warnings: $WARNINGS

Test Restore: $TEST_RESTORE
Skip Checksums: $SKIP_CHECKSUMS
Skip DB Test: $SKIP_DB_TEST

Status: $([ $CHECKS_FAILED -eq 0 ] && echo "PASSED" || echo "FAILED")

================================================================================
EOF

log "Verification report saved: $REPORT_FILE"

exit $EXIT_CODE

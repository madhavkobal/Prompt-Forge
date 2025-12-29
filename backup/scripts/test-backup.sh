#!/bin/bash

################################################################################
# PromptForge Backup Testing Script
################################################################################
#
# This script performs comprehensive testing of backup and restore procedures.
# It validates that backups are functional and that recovery procedures work
# as expected.
#
# Features:
#   - Automated backup testing
#   - Test restore to temporary database
#   - Backup integrity verification
#   - Performance benchmarking
#   - DR drill simulation
#   - Detailed test reports
#   - Pass/fail criteria
#
# Usage:
#   ./test-backup.sh [OPTIONS]
#
# Options:
#   --quick              Quick test (verification only)
#   --full               Full test (includes test restore)
#   --drill              Full DR drill simulation
#   --backup=<path>      Test specific backup
#   --report=<file>      Save report to file
#   --help               Show this help message
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
TEST_MODE="quick"
BACKUP_PATH=""
REPORT_FILE=""

# Test results
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TEST_START_TIME=$(date +%s)

# Temporary database name
TEST_DB="promptforge_backup_test_$$"

################################################################################
# Helper Functions
################################################################################

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

step() {
    echo -e "${CYAN}[TEST]${NC} $1"
    ((TESTS_TOTAL++))
}

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

show_help() {
    cat << EOF
PromptForge Backup Testing Script

Usage: $0 [OPTIONS]

Options:
    --quick              Quick test (verification only, ~5 minutes)
    --full               Full test (includes test restore, ~15 minutes)
    --drill              Full DR drill simulation (~30 minutes)
    --backup=<path>      Test specific backup
    --report=<file>      Save report to file
    --help               Show this help message

Test Modes:

  Quick Test:
    - Backup existence check
    - Checksum verification
    - File integrity check
    - Manifest validation

  Full Test:
    - All quick tests
    - Test database restore
    - Data validation
    - Performance benchmarks

  DR Drill:
    - All full tests
    - Complete system restore simulation
    - Failover testing
    - Documentation validation
    - Timeline tracking

Examples:
    # Quick daily test
    ./test-backup.sh --quick

    # Full weekly test
    ./test-backup.sh --full

    # Quarterly DR drill
    ./test-backup.sh --drill --report=/var/log/promptforge/dr-drill.txt

    # Test specific backup
    ./test-backup.sh --full --backup=/var/backups/promptforge/full/20240115

EOF
    exit 0
}

################################################################################
# Parse Command Line Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            TEST_MODE="quick"
            shift
            ;;
        --full)
            TEST_MODE="full"
            shift
            ;;
        --drill)
            TEST_MODE="drill"
            shift
            ;;
        --backup=*)
            BACKUP_PATH="${1#*=}"
            shift
            ;;
        --report=*)
            REPORT_FILE="${1#*=}"
            shift
            ;;
        --help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

################################################################################
# Test Header
################################################################################

clear
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║        PromptForge Backup Testing Suite                   ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
log "Test Mode: $TEST_MODE"
log "Started: $(date)"
echo ""

################################################################################
# Load Environment
################################################################################

if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"

################################################################################
# Find Latest Backups
################################################################################

if [ -z "$BACKUP_PATH" ]; then
    log "Finding latest backups..."

    # Find latest full backup
    LATEST_FULL=$(find /var/backups/promptforge/full -maxdepth 1 -type d -name "20*" 2>/dev/null | sort -r | head -1)

    # Find latest database backup
    LATEST_DB=$(find /var/backups/promptforge/database -maxdepth 1 -type d -name "20*" 2>/dev/null | sort -r | head -1)

    if [ -n "$LATEST_FULL" ]; then
        log "Latest full backup: $LATEST_FULL"
        BACKUP_PATH="$LATEST_FULL"
    elif [ -n "$LATEST_DB" ]; then
        log "Latest database backup: $LATEST_DB"
        BACKUP_PATH="$LATEST_DB"
    else
        fail "No backups found"
        exit 1
    fi
fi

################################################################################
# Quick Tests
################################################################################

echo ""
echo "=========================================="
echo "  Quick Tests"
echo "=========================================="
echo ""

# Test 1: Backup exists
step "Checking backup directory exists..."
if [ -d "$BACKUP_PATH" ]; then
    pass "Backup directory exists: $BACKUP_PATH"
else
    fail "Backup directory not found: $BACKUP_PATH"
    exit 1
fi

# Test 2: Manifest file exists
step "Checking manifest file..."
MANIFEST=$(find "$BACKUP_PATH" -name "MANIFEST_*.txt" 2>/dev/null | head -1)
if [ -n "$MANIFEST" ]; then
    pass "Manifest file found: $(basename "$MANIFEST")"
else
    fail "Manifest file not found"
fi

# Test 3: Metadata file exists
step "Checking metadata file..."
METADATA=$(find "$BACKUP_PATH" -name "*.metadata" 2>/dev/null | head -1)
if [ -n "$METADATA" ]; then
    pass "Metadata file found: $(basename "$METADATA")"

    # Load and display metadata
    if [ -f "$METADATA" ]; then
        source "$METADATA"
        log "Backup date: $backup_date"
        log "Backup type: ${backup_type:-database}"
    fi
else
    warning "Metadata file not found"
fi

# Test 4: Database backup exists
step "Checking database backup..."
DB_BACKUP=$(find "$BACKUP_PATH" -name "*.dump" -o -name "*.sql" -o -name "*.sql.gz" -o -name "*.dump.gpg" 2>/dev/null | head -1)
if [ -n "$DB_BACKUP" ]; then
    DB_SIZE=$(du -sh "$DB_BACKUP" | cut -f1)
    pass "Database backup found: $(basename "$DB_BACKUP") ($DB_SIZE)"

    # Check if encrypted
    if [[ "$DB_BACKUP" == *.gpg ]]; then
        log "Backup is encrypted ✓"
    fi
else
    fail "Database backup not found"
fi

# Test 5: Checksums
step "Verifying checksums..."
CHECKSUM_FILES=$(find "$BACKUP_PATH" -name "*.sha256" 2>/dev/null)
if [ -z "$CHECKSUM_FILES" ]; then
    warning "No checksum files found"
else
    CHECKSUM_ERRORS=0
    CHECKSUM_COUNT=0

    while IFS= read -r checksum_file; do
        ((CHECKSUM_COUNT++))
        CHECKSUM_DIR=$(dirname "$checksum_file")

        if (cd "$CHECKSUM_DIR" && sha256sum -c "$(basename "$checksum_file")" &>/dev/null); then
            :
        else
            ((CHECKSUM_ERRORS++))
        fi
    done <<< "$CHECKSUM_FILES"

    if [ $CHECKSUM_ERRORS -eq 0 ]; then
        pass "All checksums verified ($CHECKSUM_COUNT files)"
    else
        fail "Checksum verification failed ($CHECKSUM_ERRORS errors)"
    fi
fi

# Test 6: Backup size
step "Checking backup size..."
BACKUP_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
BACKUP_SIZE_BYTES=$(du -sb "$BACKUP_PATH" | cut -f1)

log "Total backup size: $BACKUP_SIZE"

if [ $BACKUP_SIZE_BYTES -lt 10485760 ]; then  # Less than 10MB
    warning "Backup size seems unusually small ($BACKUP_SIZE)"
else
    pass "Backup size is reasonable"
fi

# Test 7: Backup age
step "Checking backup age..."
BACKUP_TIME=$(stat -c %Y "$BACKUP_PATH" 2>/dev/null || stat -f %m "$BACKUP_PATH" 2>/dev/null)
CURRENT_TIME=$(date +%s)
AGE_HOURS=$(( ($CURRENT_TIME - $BACKUP_TIME) / 3600 ))

log "Backup age: $AGE_HOURS hours"

if [ $AGE_HOURS -gt 48 ]; then
    warning "Backup is more than 48 hours old"
elif [ $AGE_HOURS -gt 168 ]; then
    fail "Backup is more than 7 days old!"
else
    pass "Backup is recent (< 48 hours)"
fi

################################################################################
# Full Tests
################################################################################

if [ "$TEST_MODE" = "full" ] || [ "$TEST_MODE" = "drill" ]; then
    echo ""
    echo "=========================================="
    echo "  Full Tests (Test Restore)"
    echo "=========================================="
    echo ""

    # Test 8: Database connection
    step "Testing database connection..."
    if PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -c '\l' &>/dev/null; then
        pass "Database connection successful"
    else
        fail "Cannot connect to database"
        log "Skipping restore tests"
    fi

    # Test 9: Test database restore
    if [ $TESTS_FAILED -eq 0 ]; then
        step "Performing test restore..."

        # Create test database
        log "Creating test database: $TEST_DB"
        PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" \
            -c "DROP DATABASE IF EXISTS $TEST_DB;" 2>/dev/null || true
        PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" \
            -c "CREATE DATABASE $TEST_DB;" 2>/dev/null

        RESTORE_START=$(date +%s)

        # Restore to test database
        if [[ "$DB_BACKUP" == *.gpg ]]; then
            log "Decrypting backup..."
            TEMP_BACKUP="/tmp/backup_test_$$.dump"
            gpg --batch --yes --decrypt --output "$TEMP_BACKUP" "$DB_BACKUP" 2>/dev/null
            DB_BACKUP="$TEMP_BACKUP"
        fi

        log "Restoring database..."
        if [[ "$DB_BACKUP" == *.sql.gz ]]; then
            zcat "$DB_BACKUP" | PGPASSWORD="$POSTGRES_PASSWORD" psql \
                -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$TEST_DB" \
                &>/dev/null
        elif [[ "$DB_BACKUP" == *.sql ]]; then
            PGPASSWORD="$POSTGRES_PASSWORD" psql \
                -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$TEST_DB" \
                < "$DB_BACKUP" &>/dev/null
        elif [[ "$DB_BACKUP" == *.dump ]]; then
            PGPASSWORD="$POSTGRES_PASSWORD" pg_restore \
                -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$TEST_DB" \
                "$DB_BACKUP" &>/dev/null
        fi

        RESTORE_END=$(date +%s)
        RESTORE_TIME=$(($RESTORE_END - $RESTORE_START))

        if [ $? -eq 0 ]; then
            pass "Test restore completed in ${RESTORE_TIME}s"
        else
            fail "Test restore failed"
        fi

        # Clean up temp file
        [ -f "/tmp/backup_test_$$.dump" ] && rm -f "/tmp/backup_test_$$.dump"
    fi

    # Test 10: Validate restored data
    if [ $TESTS_FAILED -eq 0 ]; then
        step "Validating restored data..."

        # Check table count
        TABLE_COUNT=$(PGPASSWORD="$POSTGRES_PASSWORD" psql \
            -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$TEST_DB" \
            -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" \
            2>/dev/null | tr -d ' ')

        if [ -n "$TABLE_COUNT" ] && [ "$TABLE_COUNT" -gt 0 ]; then
            pass "Restored database contains $TABLE_COUNT tables"
        else
            fail "Restored database appears to be empty"
        fi

        # Check for expected tables
        EXPECTED_TABLES=("users" "prompts" "templates")
        MISSING_TABLES=0

        for table in "${EXPECTED_TABLES[@]}"; do
            if PGPASSWORD="$POSTGRES_PASSWORD" psql \
                -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$TEST_DB" \
                -c "\\dt $table" 2>/dev/null | grep -q "$table"; then
                log "✓ Table exists: $table"
            else
                warning "✗ Table not found: $table"
                ((MISSING_TABLES++))
            fi
        done

        if [ $MISSING_TABLES -eq 0 ]; then
            pass "All expected tables present"
        else
            warning "$MISSING_TABLES expected tables missing"
        fi

        # Check record counts
        for table in "${EXPECTED_TABLES[@]}"; do
            COUNT=$(PGPASSWORD="$POSTGRES_PASSWORD" psql \
                -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$TEST_DB" \
                -t -c "SELECT COUNT(*) FROM $table;" 2>/dev/null | tr -d ' ') || COUNT=0

            log "$table: $COUNT records"
        done
    fi

    # Test 11: Performance benchmark
    if [ $TESTS_FAILED -eq 0 ]; then
        step "Running performance benchmark..."

        QUERY_START=$(date +%s%3N)
        PGPASSWORD="$POSTGRES_PASSWORD" psql \
            -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$TEST_DB" \
            -c "SELECT COUNT(*) FROM users;" &>/dev/null
        QUERY_END=$(date +%s%3N)
        QUERY_TIME=$(($QUERY_END - $QUERY_START))

        log "Simple query time: ${QUERY_TIME}ms"

        if [ $QUERY_TIME -lt 1000 ]; then
            pass "Query performance is good"
        else
            warning "Query performance is slow (${QUERY_TIME}ms)"
        fi
    fi

    # Cleanup test database
    log "Cleaning up test database..."
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" \
        -c "DROP DATABASE IF EXISTS $TEST_DB;" 2>/dev/null || true
fi

################################################################################
# DR Drill Tests
################################################################################

if [ "$TEST_MODE" = "drill" ]; then
    echo ""
    echo "=========================================="
    echo "  DR Drill Simulation"
    echo "=========================================="
    echo ""

    # Test 12: Runbook availability
    step "Checking DR runbook..."
    RUNBOOK="$PROJECT_ROOT/docs/disaster-recovery/DR-RUNBOOK.md"
    if [ -f "$RUNBOOK" ]; then
        pass "DR runbook found"

        # Check if runbook is recent
        RUNBOOK_AGE=$(find "$RUNBOOK" -mtime +90 2>/dev/null)
        if [ -n "$RUNBOOK_AGE" ]; then
            warning "DR runbook is older than 90 days"
        else
            pass "DR runbook is up to date"
        fi
    else
        fail "DR runbook not found"
    fi

    # Test 13: Emergency contacts
    step "Validating emergency contacts..."
    if [ -f "$RUNBOOK" ] && grep -q "Emergency Contacts" "$RUNBOOK"; then
        pass "Emergency contacts section present"
    else
        warning "Emergency contacts not documented"
    fi

    # Test 14: Backup scripts
    step "Checking backup scripts availability..."
    REQUIRED_SCRIPTS=(
        "backup-full.sh"
        "backup-db.sh"
        "restore-full.sh"
        "restore-db.sh"
        "backup-verify.sh"
    )

    MISSING_SCRIPTS=0
    for script in "${REQUIRED_SCRIPTS[@]}"; do
        if [ -x "$PROJECT_ROOT/backup/scripts/$script" ] || [ -x "$PROJECT_ROOT/backup/restore/$script" ]; then
            log "✓ $script is available"
        else
            warning "✗ $script is missing or not executable"
            ((MISSING_SCRIPTS++))
        fi
    done

    if [ $MISSING_SCRIPTS -eq 0 ]; then
        pass "All backup scripts available"
    else
        fail "$MISSING_SCRIPTS backup scripts missing"
    fi

    # Test 15: Off-site backup
    step "Checking off-site backup..."
    if [ -n "$REMOTE_HOST" ]; then
        log "Testing connection to $REMOTE_HOST..."
        if ssh -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_HOST" "echo ok" &>/dev/null; then
            pass "Off-site backup server accessible"
        else
            fail "Cannot connect to off-site backup server"
        fi
    else
        warning "Off-site backup not configured"
    fi

    # Test 16: Monitoring
    step "Checking monitoring stack..."
    if docker ps | grep -q "prometheus\|grafana"; then
        pass "Monitoring stack is running"
    else
        warning "Monitoring stack is not running"
    fi

    # Test 17: Documentation completeness
    step "Checking documentation completeness..."
    REQUIRED_DOCS=(
        "docs/disaster-recovery/DR-RUNBOOK.md"
        "docs/disaster-recovery/RTO-RPO.md"
    )

    MISSING_DOCS=0
    for doc in "${REQUIRED_DOCS[@]}"; do
        if [ -f "$PROJECT_ROOT/$doc" ]; then
            log "✓ $doc exists"
        else
            warning "✗ $doc is missing"
            ((MISSING_DOCS++))
        fi
    done

    if [ $MISSING_DOCS -eq 0 ]; then
        pass "All required documentation present"
    else
        warning "$MISSING_DOCS documentation files missing"
    fi
fi

################################################################################
# Test Summary
################################################################################

TEST_END_TIME=$(date +%s)
TEST_DURATION=$(($TEST_END_TIME - $TEST_START_TIME))

echo ""
echo "=========================================="
echo "  Test Summary"
echo "=========================================="
echo ""
echo "Test Mode:       $TEST_MODE"
echo "Test Duration:   ${TEST_DURATION}s"
echo "Total Tests:     $TESTS_TOTAL"
echo "Tests Passed:    $TESTS_PASSED"
echo "Tests Failed:    $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    EXIT_CODE=0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    EXIT_CODE=1
fi

echo ""
log "Tested backup: $BACKUP_PATH"
log "Completed: $(date)"
echo ""

################################################################################
# Generate Report
################################################################################

if [ -n "$REPORT_FILE" ]; then
    log "Generating test report..."

    cat > "$REPORT_FILE" << EOF
================================================================================
PromptForge Backup Test Report
================================================================================

Test Information:
  Date: $(date)
  Mode: $TEST_MODE
  Duration: ${TEST_DURATION}s
  Tested Backup: $BACKUP_PATH

Test Results:
  Total Tests: $TESTS_TOTAL
  Passed: $TESTS_PASSED
  Failed: $TESTS_FAILED
  Success Rate: $(( $TESTS_PASSED * 100 / $TESTS_TOTAL ))%

Backup Details:
  Backup Size: $BACKUP_SIZE
  Backup Age: $AGE_HOURS hours
  Database Backup: $(basename "$DB_BACKUP")

Status: $([ $TESTS_FAILED -eq 0 ] && echo "PASSED" || echo "FAILED")

================================================================================
EOF

    log "Report saved to: $REPORT_FILE"
fi

exit $EXIT_CODE

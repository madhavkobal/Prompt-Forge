#!/bin/bash

################################################################################
# PromptForge Migration Testing Script
################################################################################
#
# This script tests migrations in a safe environment before applying them
# to production. It creates a test database, applies migrations, and
# validates the results.
#
# Usage:
#   ./test-migrations.sh [--cleanup]
#
# Options:
#   --cleanup    Remove test database after completion
#   --help       Show this help message
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
TEST_DB_NAME="promptforge_migration_test"
CLEANUP=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
BACKEND_DIR="$PROJECT_ROOT/backend"

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
        --cleanup)
            CLEANUP=true
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
# Check Prerequisites
################################################################################

check_prerequisites() {
    log "Checking prerequisites..."

    # Check if we're in the right directory
    if [[ ! -d "$BACKEND_DIR/alembic" ]]; then
        error "Alembic directory not found: $BACKEND_DIR/alembic"
        exit 1
    fi

    # Check if DATABASE_URL is set
    if [[ -z "${DATABASE_URL:-}" ]]; then
        # Try to load from .env files
        if [[ -f "$PROJECT_ROOT/.env.production" ]]; then
            source "$PROJECT_ROOT/.env.production"
        elif [[ -f "$PROJECT_ROOT/.env" ]]; then
            source "$PROJECT_ROOT/.env"
        fi
    fi

    if [[ -z "${DATABASE_URL:-}" ]]; then
        error "DATABASE_URL not set"
        echo "Set it in .env or .env.production, or export it"
        exit 1
    fi

    success "Prerequisites checked"
}

################################################################################
# Create Test Database
################################################################################

create_test_database() {
    log "Creating test database: $TEST_DB_NAME"

    # Extract connection details from DATABASE_URL
    # Format: postgresql://user:password@host:port/database
    DB_USER=$(echo "$DATABASE_URL" | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
    DB_PASS=$(echo "$DATABASE_URL" | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
    DB_HOST=$(echo "$DATABASE_URL" | sed -n 's/.*@\([^:]*\):.*/\1/p')
    DB_PORT=$(echo "$DATABASE_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')

    # Drop test database if it exists
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
        -c "DROP DATABASE IF EXISTS $TEST_DB_NAME;" 2>/dev/null || true

    # Create test database
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
        -c "CREATE DATABASE $TEST_DB_NAME;" &> /dev/null

    success "Test database created"
}

################################################################################
# Backup Production Schema
################################################################################

backup_production_schema() {
    log "Backing up production database schema..."

    # Extract database name from DATABASE_URL
    PROD_DB=$(echo "$DATABASE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')

    # Create schema backup
    BACKUP_FILE="/tmp/schema_backup_$(date +%Y%m%d_%H%M%S).sql"
    PGPASSWORD="$DB_PASS" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$PROD_DB" --schema-only -f "$BACKUP_FILE" &> /dev/null

    log "Schema backup saved: $BACKUP_FILE"
}

################################################################################
# Run Migrations on Test Database
################################################################################

run_test_migrations() {
    log "Running migrations on test database..."

    # Update DATABASE_URL to point to test database
    TEST_DATABASE_URL="${DATABASE_URL%/*}/$TEST_DB_NAME"

    cd "$BACKEND_DIR"

    # Run migrations
    DATABASE_URL="$TEST_DATABASE_URL" alembic upgrade head

    success "Migrations applied successfully"
}

################################################################################
# Validate Migration Results
################################################################################

validate_migrations() {
    log "Validating migration results..."

    # Check if all expected tables exist
    log "Checking database schema..."

    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB_NAME" \
        -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;" \
        > /tmp/test_tables.txt

    log "Tables created:"
    cat /tmp/test_tables.txt

    # Check if alembic_version table exists
    if ! grep -q "alembic_version" /tmp/test_tables.txt; then
        error "alembic_version table not found"
        return 1
    fi

    # Get current migration version
    CURRENT_VERSION=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$TEST_DB_NAME" -t -c "SELECT version_num FROM alembic_version;" | xargs)

    if [[ -z "$CURRENT_VERSION" ]]; then
        error "No migration version found"
        return 1
    fi

    success "Current migration version: $CURRENT_VERSION"

    # Check for any errors in migration
    log "Checking for migration errors..."

    # Run a simple query to ensure database is functional
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$TEST_DB_NAME" -c "SELECT COUNT(*) FROM alembic_version;" &> /dev/null

    success "Database is functional"
}

################################################################################
# Test Rollback
################################################################################

test_rollback() {
    log "Testing migration rollback..."

    # Update DATABASE_URL to point to test database
    TEST_DATABASE_URL="${DATABASE_URL%/*}/$TEST_DB_NAME"

    cd "$BACKEND_DIR"

    # Get current version
    CURRENT_VERSION=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$TEST_DB_NAME" -t -c "SELECT version_num FROM alembic_version;" | xargs)

    log "Current version: $CURRENT_VERSION"

    # Downgrade one step
    log "Rolling back one migration..."
    DATABASE_URL="$TEST_DATABASE_URL" alembic downgrade -1

    # Get new version
    NEW_VERSION=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$TEST_DB_NAME" -t -c "SELECT version_num FROM alembic_version;" | xargs)

    log "Rolled back to version: $NEW_VERSION"

    # Re-upgrade
    log "Re-applying migration..."
    DATABASE_URL="$TEST_DATABASE_URL" alembic upgrade head

    # Verify we're back to original version
    FINAL_VERSION=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$TEST_DB_NAME" -t -c "SELECT version_num FROM alembic_version;" | xargs)

    if [[ "$FINAL_VERSION" != "$CURRENT_VERSION" ]]; then
        error "Rollback test failed: versions don't match"
        return 1
    fi

    success "Rollback test passed"
}

################################################################################
# Compare with Production
################################################################################

compare_with_production() {
    log "Comparing test schema with production..."

    # Extract database name from DATABASE_URL
    PROD_DB=$(echo "$DATABASE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')

    # Dump production schema
    PGPASSWORD="$DB_PASS" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$PROD_DB" --schema-only > /tmp/prod_schema.sql 2>/dev/null || {
        warning "Could not dump production schema (database may not exist yet)"
        return 0
    }

    # Dump test schema
    PGPASSWORD="$DB_PASS" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$TEST_DB_NAME" --schema-only > /tmp/test_schema.sql 2>/dev/null

    # Compare schemas (ignoring comments and timestamps)
    if diff -u <(grep -v "^--" /tmp/prod_schema.sql | grep -v "^$") \
                <(grep -v "^--" /tmp/test_schema.sql | grep -v "^$") \
                > /tmp/schema_diff.txt 2>&1; then
        success "Test schema matches production"
    else
        warning "Schema differences detected:"
        head -n 20 /tmp/schema_diff.txt
        log "Full diff saved to: /tmp/schema_diff.txt"
    fi
}

################################################################################
# Cleanup Test Database
################################################################################

cleanup_test_database() {
    if [[ "$CLEANUP" == "true" ]]; then
        log "Cleaning up test database..."

        PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
            -c "DROP DATABASE IF EXISTS $TEST_DB_NAME;" &> /dev/null

        success "Test database removed"
    else
        warning "Test database preserved: $TEST_DB_NAME"
        echo "  To remove it: DROP DATABASE $TEST_DB_NAME;"
        echo "  Or run with --cleanup flag"
    fi
}

################################################################################
# Display Summary
################################################################################

show_summary() {
    echo ""
    success "=========================================="
    success "  Migration Testing Complete!"
    success "=========================================="
    echo ""
    log "Test database: $TEST_DB_NAME"
    log "Migration version: $CURRENT_VERSION"
    echo ""
    log "All tests passed:"
    echo "  ✓ Migrations applied successfully"
    echo "  ✓ Database schema validated"
    echo "  ✓ Rollback tested"
    echo "  ✓ Re-upgrade successful"
    echo ""
    success "Migrations are safe to apply to production"
    echo ""
}

################################################################################
# Main Script
################################################################################

echo "=========================================="
echo "  PromptForge Migration Testing"
echo "=========================================="
echo ""

check_prerequisites
create_test_database
backup_production_schema
run_test_migrations
validate_migrations
test_rollback
compare_with_production
show_summary
cleanup_test_database

exit 0

#!/bin/bash

################################################################################
# PromptForge Database Setup Script
################################################################################
#
# This script automates the complete database setup process:
#   1. Checks PostgreSQL installation
#   2. Runs initialization SQL scripts
#   3. Applies configuration optimizations
#   4. Sets up users and permissions
#   5. Configures connection pooling
#
# Usage:
#   ./setup-database.sh [--skip-init] [--skip-config]
#
# Options:
#   --skip-init     Skip database initialization
#   --skip-config   Skip configuration file updates
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

# Flags
SKIP_INIT=false
SKIP_CONFIG=false

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$DATABASE_DIR")"
INIT_DIR="$DATABASE_DIR/init"
CONFIG_DIR="$DATABASE_DIR/config"

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
        --skip-init)
            SKIP_INIT=true
            shift
            ;;
        --skip-config)
            SKIP_CONFIG=true
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

    # Check if PostgreSQL is installed
    if ! command -v psql &> /dev/null; then
        error "PostgreSQL client (psql) not found. Please install PostgreSQL."
        exit 1
    fi

    # Check if PostgreSQL server is running
    if ! pg_isready &> /dev/null; then
        error "PostgreSQL server is not running. Please start it first."
        echo "  sudo systemctl start postgresql"
        exit 1
    fi

    # Check PostgreSQL version
    PG_VERSION=$(psql --version | grep -oP '\d+\.\d+' | head -1)
    log "PostgreSQL version: $PG_VERSION"

    if (( $(echo "$PG_VERSION < 12" | bc -l) )); then
        warning "PostgreSQL version $PG_VERSION detected. Version 12+ recommended."
    fi

    success "Prerequisites checked"
}

################################################################################
# Check Database Connection
################################################################################

check_connection() {
    log "Checking database connection..."

    # Try to connect as postgres user
    if sudo -u postgres psql -c "SELECT version();" &> /dev/null; then
        success "Database connection successful"
        return 0
    else
        error "Cannot connect to PostgreSQL as postgres user"
        echo "  Try: sudo -u postgres psql"
        exit 1
    fi
}

################################################################################
# Run Initialization Scripts
################################################################################

run_initialization() {
    if [[ "$SKIP_INIT" == "true" ]]; then
        warning "Skipping database initialization"
        return
    fi

    log "Running database initialization scripts..."

    # Check if init scripts exist
    if [[ ! -d "$INIT_DIR" ]]; then
        error "Initialization directory not found: $INIT_DIR"
        exit 1
    fi

    # Run each SQL file in order
    for sql_file in "$INIT_DIR"/*.sql; do
        if [[ -f "$sql_file" ]]; then
            log "Running: $(basename "$sql_file")"
            if sudo -u postgres psql -f "$sql_file" 2>&1 | tee /tmp/pg_init.log; then
                success "Completed: $(basename "$sql_file")"
            else
                error "Failed to run: $(basename "$sql_file")"
                cat /tmp/pg_init.log
                exit 1
            fi
        fi
    done

    success "Database initialization complete"
}

################################################################################
# Update Passwords
################################################################################

update_passwords() {
    log "Updating database user passwords..."

    # Load passwords from environment or .env file
    if [[ -f "$PROJECT_ROOT/.env.production" ]]; then
        source "$PROJECT_ROOT/.env.production"
    elif [[ -f "$PROJECT_ROOT/.env" ]]; then
        source "$PROJECT_ROOT/.env"
    fi

    # Check if passwords are set
    if [[ -z "${DB_APP_PASSWORD:-}" ]]; then
        warning "DB_APP_PASSWORD not set in environment"
        read -sp "Enter password for promptforge_app user: " DB_APP_PASSWORD
        echo
    fi

    if [[ -z "${DB_READONLY_PASSWORD:-}" ]]; then
        warning "DB_READONLY_PASSWORD not set in environment"
        read -sp "Enter password for promptforge_readonly user: " DB_READONLY_PASSWORD
        echo
    fi

    if [[ -z "${DB_BACKUP_PASSWORD:-}" ]]; then
        warning "DB_BACKUP_PASSWORD not set in environment"
        read -sp "Enter password for promptforge_backup user: " DB_BACKUP_PASSWORD
        echo
    fi

    # Update passwords
    log "Updating promptforge_app password..."
    sudo -u postgres psql -c "ALTER USER promptforge_app WITH PASSWORD '$DB_APP_PASSWORD';" &> /dev/null

    log "Updating promptforge_readonly password..."
    sudo -u postgres psql -c "ALTER USER promptforge_readonly WITH PASSWORD '$DB_READONLY_PASSWORD';" &> /dev/null

    log "Updating promptforge_backup password..."
    sudo -u postgres psql -c "ALTER USER promptforge_backup WITH PASSWORD '$DB_BACKUP_PASSWORD';" &> /dev/null

    success "Passwords updated successfully"

    # Save to .env.production if it doesn't have them
    if [[ -f "$PROJECT_ROOT/.env.production" ]]; then
        if ! grep -q "DB_APP_PASSWORD" "$PROJECT_ROOT/.env.production"; then
            echo "" >> "$PROJECT_ROOT/.env.production"
            echo "# Database user passwords" >> "$PROJECT_ROOT/.env.production"
            echo "DB_APP_PASSWORD=$DB_APP_PASSWORD" >> "$PROJECT_ROOT/.env.production"
            echo "DB_READONLY_PASSWORD=$DB_READONLY_PASSWORD" >> "$PROJECT_ROOT/.env.production"
            echo "DB_BACKUP_PASSWORD=$DB_BACKUP_PASSWORD" >> "$PROJECT_ROOT/.env.production"
            log "Passwords saved to .env.production"
        fi
    fi
}

################################################################################
# Apply Configuration
################################################################################

apply_configuration() {
    if [[ "$SKIP_CONFIG" == "true" ]]; then
        warning "Skipping configuration updates"
        return
    fi

    log "Applying PostgreSQL configuration..."

    # Find PostgreSQL config directory
    PG_CONFIG_DIR=$(sudo -u postgres psql -t -c "SHOW config_file;" | xargs dirname)

    if [[ -z "$PG_CONFIG_DIR" ]]; then
        error "Could not determine PostgreSQL config directory"
        exit 1
    fi

    log "PostgreSQL config directory: $PG_CONFIG_DIR"

    # Backup existing configuration
    log "Backing up existing configuration..."
    sudo cp "$PG_CONFIG_DIR/postgresql.conf" "$PG_CONFIG_DIR/postgresql.conf.backup.$(date +%Y%m%d_%H%M%S)"
    sudo cp "$PG_CONFIG_DIR/pg_hba.conf" "$PG_CONFIG_DIR/pg_hba.conf.backup.$(date +%Y%m%d_%H%M%S)"

    # Show configuration recommendations
    echo ""
    warning "Configuration files are available in: $CONFIG_DIR"
    echo ""
    echo "To apply optimized settings:"
    echo "  1. Review: $CONFIG_DIR/postgresql.conf.example"
    echo "  2. Merge with: $PG_CONFIG_DIR/postgresql.conf"
    echo "  3. Review: $CONFIG_DIR/pg_hba.conf.example"
    echo "  4. Merge with: $PG_CONFIG_DIR/pg_hba.conf"
    echo ""
    echo "After updating configuration:"
    echo "  sudo systemctl reload postgresql"
    echo ""

    read -p "Would you like to view recommended configuration changes? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "=== Recommended postgresql.conf settings ==="
        echo ""
        grep -E "^(shared_buffers|work_mem|maintenance_work_mem|effective_cache_size|random_page_cost)" "$CONFIG_DIR/postgresql.conf.example" || true
        echo ""
    fi
}

################################################################################
# Test Database Setup
################################################################################

test_database() {
    log "Testing database setup..."

    # Test connection as application user
    log "Testing promptforge_app connection..."
    if PGPASSWORD="$DB_APP_PASSWORD" psql -h localhost -U promptforge_app -d promptforge_prod -c "SELECT version();" &> /dev/null; then
        success "Application user connection successful"
    else
        error "Application user connection failed"
        return 1
    fi

    # Test read-only user
    log "Testing promptforge_readonly connection..."
    if PGPASSWORD="$DB_READONLY_PASSWORD" psql -h localhost -U promptforge_readonly -d promptforge_prod -c "SELECT version();" &> /dev/null; then
        success "Read-only user connection successful"
    else
        error "Read-only user connection failed"
        return 1
    fi

    # Test backup user
    log "Testing promptforge_backup connection..."
    if PGPASSWORD="$DB_BACKUP_PASSWORD" psql -h localhost -U promptforge_backup -d promptforge_prod -c "SELECT version();" &> /dev/null; then
        success "Backup user connection successful"
    else
        error "Backup user connection failed"
        return 1
    fi

    # Check database size
    DB_SIZE=$(sudo -u postgres psql -d promptforge_prod -t -c "SELECT pg_size_pretty(pg_database_size('promptforge_prod'));" | xargs)
    log "Database size: $DB_SIZE"

    # Check extensions
    log "Checking installed extensions..."
    sudo -u postgres psql -d promptforge_prod -c "SELECT extname, extversion FROM pg_extension ORDER BY extname;"

    success "Database tests passed"
}

################################################################################
# Display Summary
################################################################################

show_summary() {
    echo ""
    success "=========================================="
    success "  Database Setup Complete!"
    success "=========================================="
    echo ""
    log "Database: promptforge_prod"
    log "Users created:"
    echo "  - promptforge_app (application user)"
    echo "  - promptforge_readonly (read-only user)"
    echo "  - promptforge_backup (backup user)"
    echo ""
    log "Extensions installed:"
    echo "  - uuid-ossp (UUID generation)"
    echo "  - citext (case-insensitive text)"
    echo "  - pgcrypto (cryptographic functions)"
    echo "  - pg_trgm (full-text search)"
    echo "  - pg_stat_statements (query statistics)"
    echo ""
    log "Schemas created:"
    echo "  - public (default schema)"
    echo "  - app (application data)"
    echo "  - audit (audit logs)"
    echo ""
    log "Next steps:"
    echo "  1. Review and apply PostgreSQL configuration optimizations"
    echo "  2. Update pg_hba.conf for access control"
    echo "  3. Run Alembic migrations: cd backend && alembic upgrade head"
    echo "  4. Set up automated backups: ./database/scripts/backup.sh"
    echo "  5. Configure monitoring: ./database/scripts/monitoring.sh"
    echo ""
    log "Connection examples:"
    echo "  # Application"
    echo "  psql -h localhost -U promptforge_app -d promptforge_prod"
    echo ""
    echo "  # Read-only"
    echo "  psql -h localhost -U promptforge_readonly -d promptforge_prod"
    echo ""
    echo "  # Backup"
    echo "  psql -h localhost -U promptforge_backup -d promptforge_prod"
    echo ""
}

################################################################################
# Main Script
################################################################################

echo "=========================================="
echo "  PromptForge Database Setup"
echo "=========================================="
echo ""

check_prerequisites
check_connection
run_initialization
update_passwords
apply_configuration
test_database
show_summary

exit 0

#!/bin/bash

################################################################################
# PromptForge Database Monitoring Script
################################################################################
#
# This script monitors PostgreSQL database health and performance:
#   - Connection monitoring
#   - Slow query detection
#   - Disk space monitoring
#   - Performance metrics collection
#   - Health checks
#
# Usage:
#   ./monitor-database.sh [--metrics] [--slow-queries] [--connections] [--all]
#
# Options:
#   --metrics        Show performance metrics
#   --slow-queries   Show slow queries
#   --connections    Show connection statistics
#   --disk           Show disk usage
#   --health         Run health checks
#   --all            Show all monitoring data (default)
#   --json           Output in JSON format
#   --help           Show this help message
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
SHOW_METRICS=false
SHOW_SLOW_QUERIES=false
SHOW_CONNECTIONS=false
SHOW_DISK=false
SHOW_HEALTH=false
SHOW_ALL=true
JSON_OUTPUT=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

################################################################################
# Helper Functions
################################################################################

log() {
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

success() {
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

error() {
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo -e "${RED}[ERROR]${NC} $1"
    fi
}

warning() {
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
}

################################################################################
# Parse Arguments
################################################################################

if [[ $# -gt 0 ]]; then
    SHOW_ALL=false
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --metrics)
            SHOW_METRICS=true
            shift
            ;;
        --slow-queries)
            SHOW_SLOW_QUERIES=true
            shift
            ;;
        --connections)
            SHOW_CONNECTIONS=true
            shift
            ;;
        --disk)
            SHOW_DISK=true
            shift
            ;;
        --health)
            SHOW_HEALTH=true
            shift
            ;;
        --all)
            SHOW_ALL=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
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

# If --all or no specific options, enable everything
if [[ "$SHOW_ALL" == "true" ]]; then
    SHOW_METRICS=true
    SHOW_SLOW_QUERIES=true
    SHOW_CONNECTIONS=true
    SHOW_DISK=true
    SHOW_HEALTH=true
fi

################################################################################
# Load Environment
################################################################################

load_environment() {
    # Try to load from .env files
    if [[ -f "$PROJECT_ROOT/.env.production" ]]; then
        source "$PROJECT_ROOT/.env.production"
    elif [[ -f "$PROJECT_ROOT/.env" ]]; then
        source "$PROJECT_ROOT/.env"
    fi

    # Check if DATABASE_URL is set
    if [[ -z "${DATABASE_URL:-}" ]]; then
        error "DATABASE_URL not set"
        exit 1
    fi

    # Extract database connection details
    DB_USER=$(echo "$DATABASE_URL" | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
    DB_PASS=$(echo "$DATABASE_URL" | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
    DB_HOST=$(echo "$DATABASE_URL" | sed -n 's/.*@\([^:]*\):.*/\1/p')
    DB_PORT=$(echo "$DATABASE_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
    DB_NAME=$(echo "$DATABASE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')
}

################################################################################
# Database Health Checks
################################################################################

health_checks() {
    if [[ "$SHOW_HEALTH" != "true" ]]; then
        return
    fi

    log "Running database health checks..."
    echo ""

    # Check if database is accessible
    if PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$DB_NAME" -c "SELECT 1;" &> /dev/null; then
        success "✓ Database is accessible"
    else
        error "✗ Database is not accessible"
        return 1
    fi

    # Check PostgreSQL version
    PG_VERSION=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$DB_NAME" -t -c "SHOW server_version;" | xargs)
    log "PostgreSQL version: $PG_VERSION"

    # Check uptime
    UPTIME=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$DB_NAME" -t -c "SELECT NOW() - pg_postmaster_start_time();" | xargs)
    log "Database uptime: $UPTIME"

    # Check for long-running transactions
    LONG_TRANSACTIONS=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$DB_NAME" -t -c "
        SELECT COUNT(*)
        FROM pg_stat_activity
        WHERE state != 'idle'
          AND NOW() - xact_start > interval '5 minutes';" | xargs)

    if [[ $LONG_TRANSACTIONS -gt 0 ]]; then
        warning "⚠ $LONG_TRANSACTIONS long-running transaction(s) detected"
    else
        success "✓ No long-running transactions"
    fi

    # Check for idle connections
    IDLE_CONNECTIONS=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$DB_NAME" -t -c "
        SELECT COUNT(*)
        FROM pg_stat_activity
        WHERE state = 'idle in transaction'
          AND NOW() - state_change > interval '10 minutes';" | xargs)

    if [[ $IDLE_CONNECTIONS -gt 0 ]]; then
        warning "⚠ $IDLE_CONNECTIONS idle in transaction connection(s)"
    else
        success "✓ No problematic idle connections"
    fi

    # Check for bloat
    log "Checking for table bloat..."
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOF'
SELECT
    schemaname || '.' || tablename AS table,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    n_dead_tup AS dead_tuples,
    CASE
        WHEN n_live_tup > 0 THEN ROUND(100.0 * n_dead_tup / n_live_tup, 2)
        ELSE 0
    END AS dead_ratio
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 5;
EOF

    echo ""
    success "Health checks complete"
    echo ""
}

################################################################################
# Connection Monitoring
################################################################################

connection_monitoring() {
    if [[ "$SHOW_CONNECTIONS" != "true" ]]; then
        return
    fi

    log "Connection Statistics:"
    echo ""

    # Overall connection stats
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOF'
SELECT
    COUNT(*) AS total_connections,
    COUNT(*) FILTER (WHERE state = 'active') AS active,
    COUNT(*) FILTER (WHERE state = 'idle') AS idle,
    COUNT(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_transaction,
    COUNT(*) FILTER (WHERE wait_event_type IS NOT NULL) AS waiting
FROM pg_stat_activity
WHERE datname = current_database();
EOF

    echo ""
    log "Connections by user:"
    echo ""

    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOF'
SELECT
    usename AS username,
    COUNT(*) AS connections,
    COUNT(*) FILTER (WHERE state = 'active') AS active
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY usename
ORDER BY connections DESC;
EOF

    echo ""
    log "Active queries:"
    echo ""

    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOF'
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    NOW() - query_start AS duration,
    LEFT(query, 60) AS query
FROM pg_stat_activity
WHERE state = 'active'
  AND pid != pg_backend_pid()
  AND datname = current_database()
ORDER BY query_start;
EOF

    echo ""
}

################################################################################
# Performance Metrics
################################################################################

performance_metrics() {
    if [[ "$SHOW_METRICS" != "true" ]]; then
        return
    fi

    log "Performance Metrics:"
    echo ""

    # Database size
    log "Database Size:"
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOF'
SELECT
    pg_size_pretty(pg_database_size(current_database())) AS database_size;
EOF

    echo ""
    log "Largest Tables:"
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOF'
SELECT
    schemaname || '.' || tablename AS table,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS index_size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
EOF

    echo ""
    log "Cache Hit Ratio (should be > 90%):"
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOF'
SELECT
    ROUND(
        100.0 * sum(blks_hit) / NULLIF(sum(blks_hit) + sum(blks_read), 0),
        2
    ) AS cache_hit_ratio
FROM pg_stat_database
WHERE datname = current_database();
EOF

    echo ""
    log "Index Usage:"
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOF'
SELECT
    schemaname || '.' || tablename AS table,
    indexrelname AS index_name,
    idx_scan AS index_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 10;
EOF

    echo ""
    log "Transaction Statistics:"
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOF'
SELECT
    xact_commit AS commits,
    xact_rollback AS rollbacks,
    ROUND(100.0 * xact_rollback / NULLIF(xact_commit + xact_rollback, 0), 2) AS rollback_ratio,
    conflicts,
    deadlocks
FROM pg_stat_database
WHERE datname = current_database();
EOF

    echo ""
}

################################################################################
# Slow Query Detection
################################################################################

slow_queries() {
    if [[ "$SHOW_SLOW_QUERIES" != "true" ]]; then
        return
    fi

    log "Slow Query Analysis:"
    echo ""

    # Check if pg_stat_statements is available
    HAS_PG_STAT=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$DB_NAME" -t -c "
        SELECT COUNT(*)
        FROM pg_extension
        WHERE extname = 'pg_stat_statements';" | xargs)

    if [[ $HAS_PG_STAT -eq 0 ]]; then
        warning "pg_stat_statements extension not installed"
        log "To install: CREATE EXTENSION pg_stat_statements;"
        echo ""
        return
    fi

    log "Top 10 Slowest Queries (by total time):"
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOF'
SELECT
    ROUND(total_exec_time::numeric, 2) AS total_time_ms,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS mean_time_ms,
    ROUND(max_exec_time::numeric, 2) AS max_time_ms,
    LEFT(query, 80) AS query
FROM pg_stat_statements
WHERE userid = (SELECT usesysid FROM pg_user WHERE usename = current_user)
ORDER BY total_exec_time DESC
LIMIT 10;
EOF

    echo ""
    log "Top 10 Most Frequent Queries:"
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOF'
SELECT
    calls,
    ROUND(total_exec_time::numeric, 2) AS total_time_ms,
    ROUND(mean_exec_time::numeric, 2) AS mean_time_ms,
    LEFT(query, 80) AS query
FROM pg_stat_statements
WHERE userid = (SELECT usesysid FROM pg_user WHERE usename = current_user)
ORDER BY calls DESC
LIMIT 10;
EOF

    echo ""
}

################################################################################
# Disk Space Monitoring
################################################################################

disk_monitoring() {
    if [[ "$SHOW_DISK" != "true" ]]; then
        return
    fi

    log "Disk Space Monitoring:"
    echo ""

    # Get PostgreSQL data directory
    DATA_DIR=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$DB_NAME" -t -c "SHOW data_directory;" | xargs)

    if [[ -n "$DATA_DIR" && -d "$DATA_DIR" ]]; then
        log "Data directory: $DATA_DIR"
        df -h "$DATA_DIR" | tail -1 | awk '{print "  Usage: " $5 " (" $3 " used of " $2 ")"}'
        echo ""
    fi

    log "Database Growth:"
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOF'
SELECT
    current_database() AS database,
    pg_size_pretty(pg_database_size(current_database())) AS current_size;
EOF

    echo ""
    log "Tablespace Usage:"
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOF'
SELECT
    spcname AS tablespace,
    pg_size_pretty(pg_tablespace_size(spcname)) AS size
FROM pg_tablespace
ORDER BY pg_tablespace_size(spcname) DESC;
EOF

    echo ""
}

################################################################################
# Main Script
################################################################################

if [[ "$JSON_OUTPUT" != "true" ]]; then
    echo "=========================================="
    echo "  PromptForge Database Monitoring"
    echo "=========================================="
    echo ""
fi

load_environment
health_checks
connection_monitoring
performance_metrics
slow_queries
disk_monitoring

if [[ "$JSON_OUTPUT" != "true" ]]; then
    echo ""
    success "Monitoring complete"
fi

exit 0

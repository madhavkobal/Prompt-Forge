#!/bin/bash
################################################################################
# PromptForge Database Maintenance Script
################################################################################

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$PROJECT_ROOT"

log "Running database maintenance..."

# Vacuum analyze
log "Running VACUUM ANALYZE..."
docker-compose exec -T postgres psql -U promptforge -d promptforge -c "VACUUM ANALYZE;"
success "Database vacuumed"

# Reindex
log "Reindexing database..."
docker-compose exec -T postgres psql -U promptforge -d promptforge -c "REINDEX DATABASE promptforge;"
success "Database reindexed"

# Show database size
SIZE=$(docker-compose exec -T postgres psql -U promptforge -t -c "SELECT pg_size_pretty(pg_database_size('promptforge'));" | tr -d ' ')
log "Database size: $SIZE"

# Show table sizes
echo ""
log "Top 5 largest tables:"
docker-compose exec -T postgres psql -U promptforge -d promptforge -c "
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 5;"

success "Database maintenance completed"

#!/bin/bash
################################################################################
# PromptForge Rollback Script
################################################################################

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

VERSION="$1"

clear
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              PromptForge Rollback                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

cd "$PROJECT_ROOT"

# Show available versions
log "Available versions:"
git tag -l --sort=-v:refname | head -10
echo ""

if [ -z "$VERSION" ]; then
    read -p "Enter version to rollback to: " VERSION
    if [ -z "$VERSION" ]; then
        error "Version is required"
        exit 1
    fi
fi

CURRENT_VERSION=$(git describe --tags --always)
log "Current version: $CURRENT_VERSION"
log "Rolling back to: $VERSION"
echo ""

read -p "Are you sure? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    log "Rollback cancelled"
    exit 0
fi

# Backup current database
log "Backing up current database..."
"$PROJECT_ROOT/backup/scripts/backup-db.sh" --format=custom || warning "Backup failed"

# Checkout version
log "Checking out version $VERSION..."
git checkout "$VERSION"

# Rebuild and restart
log "Rebuilding services..."
docker-compose build

log "Restarting services..."
docker-compose down
docker-compose up -d

# Wait and health check
sleep 15
if curl -sf http://localhost:8000/api/health &>/dev/null; then
    success "✓ Backend is healthy"
else
    error "✗ Backend health check failed"
fi

if curl -sf http://localhost:3000 &>/dev/null; then
    success "✓ Frontend is healthy"
else
    error "✗ Frontend health check failed"
fi

echo ""
success "Rolled back to version $VERSION"
log "Verify: http://localhost:3000"

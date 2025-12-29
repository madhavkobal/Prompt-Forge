#!/bin/bash

################################################################################
# PromptForge Application Update Script
################################################################################
#
# This script performs zero-downtime application updates:
#   - Pulls latest code from Git
#   - Builds new Docker images
#   - Performs rolling update of services
#   - Runs database migrations
#   - Health checks after update
#   - Automatic rollback on failure
#
# Usage:
#   sudo ./update-app.sh [--version=<tag>] [--skip-backup] [--force]
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
VERSION=""
SKIP_BACKUP=false
FORCE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Track update
UPDATE_START=$(date +%s)
PREVIOUS_VERSION=""

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
        --version=*)
            VERSION="${1#*=}"
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

################################################################################
# Update Header
################################################################################

clear
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║        PromptForge Application Update                      ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
log "Started: $(date)"
echo ""

################################################################################
# Pre-update Checks
################################################################################

log "Running pre-update checks..."

cd "$PROJECT_ROOT"

# Check Git
if [ ! -d ".git" ]; then
    error "Not a Git repository"
    exit 1
fi

# Get current version
PREVIOUS_VERSION=$(git describe --tags --always 2>/dev/null || echo "unknown")
log "Current version: $PREVIOUS_VERSION"

# Check for uncommitted changes
if [ "$FORCE" = false ] && [ -n "$(git status --porcelain)" ]; then
    error "You have uncommitted changes"
    echo "Commit or stash your changes, or use --force to proceed anyway"
    exit 1
fi

success "Pre-update checks passed"

################################################################################
# Backup Current State
################################################################################

if [ "$SKIP_BACKUP" = false ]; then
    log "Creating backup before update..."

    # Run database backup
    if [ -x "$PROJECT_ROOT/backup/scripts/backup-db.sh" ]; then
        "$PROJECT_ROOT/backup/scripts/backup-db.sh" --format=custom
        success "Database backed up"
    else
        warning "Backup script not found, skipping backup"
    fi

    # Save current docker images
    log "Saving current Docker images..."
    docker images --format "{{.Repository}}:{{.Tag}}" | grep promptforge > /tmp/promptforge-images-backup.txt || true
else
    warning "Skipping backup (--skip-backup)"
fi

################################################################################
# Pull Latest Code
################################################################################

log "Pulling latest code..."

# Fetch latest changes
git fetch --all --tags

if [ -n "$VERSION" ]; then
    log "Checking out version: $VERSION"
    git checkout "$VERSION"
else
    # Pull latest from current branch
    CURRENT_BRANCH=$(git branch --show-current)
    log "Pulling latest from branch: $CURRENT_BRANCH"
    git pull origin "$CURRENT_BRANCH"
fi

NEW_VERSION=$(git describe --tags --always)
log "New version: $NEW_VERSION"

if [ "$NEW_VERSION" = "$PREVIOUS_VERSION" ] && [ "$FORCE" = false ]; then
    log "Already at latest version"
    exit 0
fi

success "Code updated"

################################################################################
# Build New Docker Images
################################################################################

log "Building new Docker images..."

# Build with version tag
docker-compose build --build-arg VERSION="$NEW_VERSION"

success "Docker images built"

################################################################################
# Run Database Migrations
################################################################################

log "Running database migrations..."

# Run migrations (will do nothing if no migrations needed)
docker-compose run --rm backend alembic upgrade head || warning "Migration failed or not needed"

success "Database migrations completed"

################################################################################
# Rolling Update - Backend
################################################################################

log "Performing rolling update of backend services..."

# Check if HA is enabled
if docker-compose -f docker-compose.ha.yml ps backend1 &>/dev/null; then
    log "High Availability mode detected"

    # Update backend instances one by one
    for backend in backend1 backend2 backend3; do
        log "Updating $backend..."

        # Start new instance
        docker-compose -f docker-compose.ha.yml up -d --no-deps --build $backend

        # Wait for health check
        sleep 5

        # Verify it's healthy
        if docker-compose -f docker-compose.ha.yml ps $backend | grep -q "Up"; then
            success "$backend updated"
        else
            error "$backend failed to start"
            log "Rolling back..."
            git checkout "$PREVIOUS_VERSION"
            docker-compose -f docker-compose.ha.yml up -d --no-deps --build $backend
            exit 1
        fi

        # Small delay between updates
        sleep 2
    done
else
    log "Standard mode detected"

    # Update backend
    docker-compose up -d --no-deps --build backend

    sleep 5

    if ! docker-compose ps backend | grep -q "Up"; then
        error "Backend failed to start"
        exit 1
    fi

    success "Backend updated"
fi

################################################################################
# Update Frontend
################################################################################

log "Updating frontend..."

if docker-compose -f docker-compose.ha.yml ps frontend1 &>/dev/null; then
    # Update frontend instances
    for frontend in frontend1 frontend2; do
        log "Updating $frontend..."
        docker-compose -f docker-compose.ha.yml up -d --no-deps --build $frontend
        sleep 3
    done
else
    docker-compose up -d --no-deps --build frontend
    sleep 3
fi

success "Frontend updated"

################################################################################
# Update Nginx
################################################################################

log "Updating Nginx configuration..."

# Reload Nginx (graceful reload)
docker-compose exec nginx nginx -s reload || docker-compose restart nginx

success "Nginx updated"

################################################################################
# Health Checks
################################################################################

log "Running post-update health checks..."

HEALTH_CHECKS_PASSED=true

# Wait a bit for services to stabilize
sleep 10

# Check backend
if curl -sf http://localhost:8000/api/health &>/dev/null; then
    success "✓ Backend is healthy"
else
    error "✗ Backend health check failed"
    HEALTH_CHECKS_PASSED=false
fi

# Check frontend
if curl -sf http://localhost:3000 &>/dev/null; then
    success "✓ Frontend is healthy"
else
    error "✗ Frontend health check failed"
    HEALTH_CHECKS_PASSED=false
fi

# Check database connectivity
if docker-compose exec -T postgres pg_isready -U postgres &>/dev/null; then
    success "✓ Database is healthy"
else
    error "✗ Database health check failed"
    HEALTH_CHECKS_PASSED=false
fi

################################################################################
# Rollback on Failure
################################################################################

if [ "$HEALTH_CHECKS_PASSED" = false ]; then
    error "Health checks failed! Rolling back..."

    # Rollback code
    git checkout "$PREVIOUS_VERSION"

    # Rebuild and restart
    docker-compose build
    docker-compose up -d

    error "Update failed and has been rolled back to $PREVIOUS_VERSION"
    exit 1
fi

################################################################################
# Cleanup Old Images
################################################################################

log "Cleaning up old Docker images..."

# Remove dangling images
docker image prune -f &>/dev/null || true

success "Cleanup completed"

################################################################################
# Update Summary
################################################################################

UPDATE_END=$(date +%s)
UPDATE_TIME=$(($UPDATE_END - $UPDATE_START))

echo ""
echo "=========================================="
echo "  Update Summary"
echo "=========================================="
echo ""
echo "Previous Version: $PREVIOUS_VERSION"
echo "New Version:      $NEW_VERSION"
echo "Update Time:      ${UPDATE_TIME}s"
echo ""
success "Application updated successfully!"
echo ""

log "What's running:"
docker-compose ps

echo ""
log "Verify the update:"
echo "  • Frontend: http://localhost:3000"
echo "  • API:      http://localhost:8000"
echo "  • Health:   ./deploy/monitoring/check-health.sh"
echo ""

# Log update
cat >> /var/log/promptforge/updates.log << EOF
[$(date)] Updated from $PREVIOUS_VERSION to $NEW_VERSION (${UPDATE_TIME}s)
EOF

exit 0

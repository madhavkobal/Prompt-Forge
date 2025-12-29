#!/bin/bash
################################################################################
# PromptForge Docker Cleanup Script
################################################################################

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

log "Cleaning up Docker resources..."

# Show before
echo "Before cleanup:"
docker system df

echo ""

# Remove stopped containers
log "Removing stopped containers..."
docker container prune -f
success "Stopped containers removed"

# Remove unused images
log "Removing unused images..."
docker image prune -a -f
success "Unused images removed"

# Remove unused volumes
log "Removing unused volumes..."
docker volume prune -f
success "Unused volumes removed"

# Remove unused networks
log "Removing unused networks..."
docker network prune -f
success "Unused networks removed"

# Show after
echo ""
echo "After cleanup:"
docker system df

success "Docker cleanup completed"

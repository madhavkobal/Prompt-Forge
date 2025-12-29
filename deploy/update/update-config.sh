#!/bin/bash
################################################################################
# PromptForge Configuration Update Script
################################################################################

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$PROJECT_ROOT"

log "Updating configuration..."

# Backup current .env
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
success ".env backed up"

# Reload environment in running containers
log "Reloading configuration in containers..."
docker-compose up -d --force-recreate --no-deps backend frontend

sleep 5

# Reload Nginx
docker-compose exec nginx nginx -s reload

success "Configuration updated and services reloaded"
log "Check: docker-compose ps"

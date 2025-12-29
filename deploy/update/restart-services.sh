#!/bin/bash
################################################################################
# PromptForge Graceful Service Restart Script
################################################################################

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

SERVICE="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$PROJECT_ROOT"

if [ -z "$SERVICE" ]; then
    log "Restarting all services gracefully..."
    docker-compose restart
    success "All services restarted"
else
    log "Restarting $SERVICE..."
    docker-compose restart "$SERVICE"
    success "$SERVICE restarted"
fi

sleep 5
log "Service status:"
docker-compose ps

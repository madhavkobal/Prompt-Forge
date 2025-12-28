#!/bin/bash

################################################################################
# PromptForge Zero-Downtime Update Script
################################################################################
#
# Performs a rolling update with minimal downtime.
#
# Usage:
#   ./update.sh [OPTIONS]
#
# Options:
#   --skip-backup    Skip database backup
#   --skip-build     Skip building images (use existing)
#   --help           Show this help message
#
################################################################################

set -e

COMPOSE_FILE="docker-compose.prod.yml"
SKIP_BACKUP=false
SKIP_BUILD=false

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --help)
            grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "Starting zero-downtime update..."

# Backup database
if [[ "$SKIP_BACKUP" != "true" ]]; then
    echo "Creating backup..."
    ./backup.sh
fi

# Pull latest code
echo "Pulling latest changes..."
git pull

# Pull/build images
if [[ "$SKIP_BUILD" != "true" ]]; then
    echo "Building new images..."
    docker-compose -f "$COMPOSE_FILE" build
else
    echo "Pulling images..."
    docker-compose -f "$COMPOSE_FILE" pull
fi

# Update services one by one
echo "Updating backend..."
docker-compose -f "$COMPOSE_FILE" up -d --no-deps --build backend
sleep 10

echo "Running migrations..."
docker-compose -f "$COMPOSE_FILE" exec -T backend alembic upgrade head

echo "Updating frontend..."
docker-compose -f "$COMPOSE_FILE" up -d --no-deps --build frontend
sleep 5

echo "Updating nginx..."
docker-compose -f "$COMPOSE_FILE" up -d --no-deps nginx

echo -e "${GREEN}Update completed successfully${NC}"
echo "Check status: docker-compose -f $COMPOSE_FILE ps"

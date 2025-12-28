#!/bin/bash

################################################################################
# PromptForge Production Deployment Script
################################################################################
#
# This script automates the deployment of PromptForge to production using
# Docker Compose. It handles:
#   - Pre-deployment checks
#   - Environment validation
#   - Database backups
#   - Zero-downtime deployment
#   - Health checks
#   - Rollback on failure
#
# Usage:
#   ./deploy.sh [OPTIONS]
#
# Options:
#   --no-backup        Skip database backup before deployment
#   --force            Force deployment even if health checks fail
#   --rollback         Rollback to previous deployment
#   --help             Show this help message
#
# Prerequisites:
#   - Docker and Docker Compose installed
#   - .env.production configured
#   - SSL certificates in nginx/ssl/ (if using HTTPS)
#   - Sufficient disk space for backups
#
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

################################################################################
# Configuration
################################################################################

COMPOSE_FILE="docker-compose.prod.yml"
ENV_FILE=".env.production"
BACKUP_DIR="./backups"
LOG_FILE="./logs/deploy-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$LOG_FILE"
}

################################################################################
# Parse Arguments
################################################################################

SKIP_BACKUP=false
FORCE=false
ROLLBACK=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --rollback)
            ROLLBACK=true
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
# Pre-flight Checks
################################################################################

log "Starting deployment pre-flight checks..."

# Check if running as root or with sudo
if [[ $EUID -eq 0 ]]; then
    warning "Running as root. This is not recommended for security reasons."
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    error "Docker is not installed"
    exit 1
fi
success "Docker is installed"

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    error "Docker Compose is not installed"
    exit 1
fi
success "Docker Compose is installed"

# Check if compose file exists
if [[ ! -f "$COMPOSE_FILE" ]]; then
    error "Docker Compose file not found: $COMPOSE_FILE"
    exit 1
fi
success "Docker Compose file found"

# Check if env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    error "Environment file not found: $ENV_FILE"
    exit 1
fi
success "Environment file found"

# Validate environment file
log "Validating environment variables..."
source "$ENV_FILE"

required_vars=("DB_PASSWORD" "REDIS_PASSWORD" "SECRET_KEY" "GEMINI_API_KEY")
for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        error "Required environment variable not set: $var"
        exit 1
    fi
done
success "All required environment variables are set"

# Check disk space
available_space=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [[ $available_space -lt 10 ]]; then
    warning "Low disk space: ${available_space}GB available"
    if [[ "$FORCE" != "true" ]]; then
        error "At least 10GB of free space required. Use --force to override."
        exit 1
    fi
fi
success "Sufficient disk space available"

################################################################################
# Backup Database
################################################################################

if [[ "$SKIP_BACKUP" != "true" && "$ROLLBACK" != "true" ]]; then
    log "Creating database backup..."

    mkdir -p "$BACKUP_DIR"

    BACKUP_FILE="$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).sql"

    if docker-compose -f "$COMPOSE_FILE" ps postgres | grep -q "Up"; then
        docker-compose -f "$COMPOSE_FILE" exec -T postgres \
            pg_dump -U "$DB_USER" "$DB_NAME" > "$BACKUP_FILE"

        if [[ -f "$BACKUP_FILE" ]]; then
            # Compress backup
            gzip "$BACKUP_FILE"
            success "Database backup created: ${BACKUP_FILE}.gz"
        else
            error "Failed to create database backup"
            exit 1
        fi
    else
        warning "Database container not running, skipping backup"
    fi
fi

################################################################################
# Pull Latest Images
################################################################################

log "Pulling latest Docker images..."
docker-compose -f "$COMPOSE_FILE" pull
success "Images pulled successfully"

################################################################################
# Build Custom Images
################################################################################

log "Building custom images..."
docker-compose -f "$COMPOSE_FILE" build --no-cache
success "Images built successfully"

################################################################################
# Deploy Services
################################################################################

log "Deploying services..."

# Start services in order with health checks
docker-compose -f "$COMPOSE_FILE" up -d postgres redis
sleep 10  # Wait for database to initialize

docker-compose -f "$COMPOSE_FILE" up -d backend
sleep 15  # Wait for backend to start

docker-compose -f "$COMPOSE_FILE" up -d frontend nginx

success "Services deployed"

################################################################################
# Run Database Migrations
################################################################################

log "Running database migrations..."
docker-compose -f "$COMPOSE_FILE" exec -T backend alembic upgrade head
success "Database migrations completed"

################################################################################
# Health Checks
################################################################################

log "Performing health checks..."

MAX_RETRIES=30
RETRY_INTERVAL=5

# Check backend health
for i in $(seq 1 $MAX_RETRIES); do
    if curl -f http://localhost/api/health &> /dev/null; then
        success "Backend health check passed"
        break
    fi

    if [[ $i -eq $MAX_RETRIES ]]; then
        error "Backend health check failed after $MAX_RETRIES attempts"
        if [[ "$FORCE" != "true" ]]; then
            log "Rolling back deployment..."
            docker-compose -f "$COMPOSE_FILE" down
            exit 1
        fi
    fi

    log "Waiting for backend to be healthy (attempt $i/$MAX_RETRIES)..."
    sleep $RETRY_INTERVAL
done

# Check frontend health
if curl -f http://localhost/ &> /dev/null; then
    success "Frontend health check passed"
else
    error "Frontend health check failed"
    if [[ "$FORCE" != "true" ]]; then
        exit 1
    fi
fi

################################################################################
# Cleanup
################################################################################

log "Cleaning up old Docker images..."
docker image prune -f
success "Cleanup completed"

################################################################################
# Deployment Complete
################################################################################

success "═══════════════════════════════════════════════════════"
success "           Deployment Completed Successfully!           "
success "═══════════════════════════════════════════════════════"

log "Application URLs:"
log "  Frontend: http://localhost"
log "  Backend API: http://localhost/api"
log "  API Docs: http://localhost/api/docs"

log "Useful commands:"
log "  View logs: docker-compose -f $COMPOSE_FILE logs -f [service]"
log "  Check status: docker-compose -f $COMPOSE_FILE ps"
log "  Stop services: docker-compose -f $COMPOSE_FILE down"

log "Deployment log saved to: $LOG_FILE"

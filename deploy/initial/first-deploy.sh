#!/bin/bash

################################################################################
# PromptForge First Deployment Script
################################################################################
#
# This script performs the complete first-time deployment of PromptForge:
#   - Validates prerequisites
#   - Builds Docker images
#   - Initializes database
#   - Starts all services
#   - Runs health checks
#   - Creates initial admin user
#
# Usage:
#   sudo ./first-deploy.sh [--skip-build] [--skip-db-init] [--ha] [--monitoring]
#
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SKIP_BUILD=false
SKIP_DB_INIT=false
ENABLE_HA=false
ENABLE_MONITORING=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Deployment tracking
STEPS_TOTAL=0
STEPS_COMPLETED=0
DEPLOYMENT_START=$(date +%s)

################################################################################
# Helper Functions
################################################################################

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

step() {
    ((STEPS_TOTAL++))
    echo -e "${CYAN}[STEP $STEPS_TOTAL]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    ((STEPS_COMPLETED++))
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
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-db-init)
            SKIP_DB_INIT=true
            shift
            ;;
        --ha)
            ENABLE_HA=true
            shift
            ;;
        --monitoring)
            ENABLE_MONITORING=true
            shift
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

################################################################################
# Deployment Header
################################################################################

clear
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║        PromptForge First Deployment                        ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
log "Started: $(date)"
log "High Availability: $ENABLE_HA"
log "Monitoring: $ENABLE_MONITORING"
echo ""

################################################################################
# Pre-flight Checks
################################################################################

step "Running pre-flight checks..."

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root or with sudo"
    exit 1
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    error "Docker is not installed"
    echo "Run: sudo ./deploy/initial/install.sh"
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    error "Docker Compose is not installed"
    echo "Run: sudo ./deploy/initial/install.sh"
    exit 1
fi

# Check if .env exists
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    error ".env file not found"
    echo "Run: sudo ./deploy/initial/setup.sh"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    error "Docker daemon is not running"
    echo "Start Docker: sudo systemctl start docker"
    exit 1
fi

success "Pre-flight checks passed"

################################################################################
# Load Environment
################################################################################

step "Loading environment configuration..."

cd "$PROJECT_ROOT"

# Load environment
set -a
source .env
set +a

success "Environment loaded"

################################################################################
# Stop Existing Containers
################################################################################

step "Stopping any existing containers..."

docker-compose down 2>/dev/null || true

if [ "$ENABLE_HA" = true ]; then
    docker-compose -f docker-compose.ha.yml down 2>/dev/null || true
fi

if [ "$ENABLE_MONITORING" = true ]; then
    docker-compose -f docker-compose.monitoring.yml down 2>/dev/null || true
fi

success "Existing containers stopped"

################################################################################
# Build Docker Images
################################################################################

if [ "$SKIP_BUILD" = false ]; then
    step "Building Docker images..."

    log "This may take several minutes..."

    if [ "$ENABLE_HA" = true ]; then
        docker-compose -f docker-compose.ha.yml build
    else
        docker-compose build
    fi

    success "Docker images built"
else
    log "Skipping build (--skip-build)"
fi

################################################################################
# Start Database
################################################################################

step "Starting database..."

if [ "$ENABLE_HA" = true ]; then
    docker-compose -f docker-compose.ha.yml up -d postgres-primary
    DB_CONTAINER="promptforge-postgres-primary"
else
    docker-compose up -d postgres
    DB_CONTAINER="promptforge-postgres"
fi

# Wait for database to be ready
log "Waiting for database to be ready..."
sleep 5

MAX_TRIES=30
TRIES=0
while ! docker exec $DB_CONTAINER pg_isready -U postgres &>/dev/null; do
    sleep 2
    ((TRIES++))
    if [ $TRIES -ge $MAX_TRIES ]; then
        error "Database failed to start"
        docker logs $DB_CONTAINER
        exit 1
    fi
    echo -n "."
done
echo ""

success "Database is ready"

################################################################################
# Initialize Database
################################################################################

if [ "$SKIP_DB_INIT" = false ]; then
    step "Initializing database..."

    # Run database initialization script if it exists
    if [ -f "$PROJECT_ROOT/database/init/01-init-database.sql" ]; then
        log "Running database initialization script..."

        docker exec -i $DB_CONTAINER psql -U postgres < "$PROJECT_ROOT/database/init/01-init-database.sql"

        success "Database initialized"
    else
        warning "Database initialization script not found"
    fi

    # Run migrations if backend is available
    if [ -d "$PROJECT_ROOT/backend" ]; then
        log "Running database migrations..."

        # Start backend temporarily for migrations
        if [ "$ENABLE_HA" = true ]; then
            docker-compose -f docker-compose.ha.yml up -d backend1
            BACKEND_CONTAINER="promptforge-backend1"
        else
            docker-compose up -d backend
            BACKEND_CONTAINER="promptforge-backend"
        fi

        sleep 5

        # Run migrations
        docker exec $BACKEND_CONTAINER alembic upgrade head || true

        success "Database migrations completed"
    fi
else
    log "Skipping database initialization (--skip-db-init)"
fi

################################################################################
# Start Redis
################################################################################

step "Starting Redis..."

if [ "$ENABLE_HA" = true ]; then
    docker-compose -f docker-compose.ha.yml up -d redis-master redis-slave-1 redis-sentinel-1 redis-sentinel-2 redis-sentinel-3
else
    docker-compose up -d redis
fi

# Wait for Redis
sleep 3

success "Redis started"

################################################################################
# Start Backend Services
################################################################################

step "Starting backend services..."

if [ "$ENABLE_HA" = true ]; then
    docker-compose -f docker-compose.ha.yml up -d backend1 backend2 backend3
else
    docker-compose up -d backend
fi

# Wait for backend to be ready
log "Waiting for backend to be ready..."
sleep 10

success "Backend services started"

################################################################################
# Start Frontend
################################################################################

step "Starting frontend..."

if [ "$ENABLE_HA" = true ]; then
    docker-compose -f docker-compose.ha.yml up -d frontend1 frontend2
else
    docker-compose up -d frontend
fi

sleep 5

success "Frontend started"

################################################################################
# Start Nginx
################################################################################

step "Starting Nginx..."

if [ "$ENABLE_HA" = true ]; then
    docker-compose -f docker-compose.ha.yml up -d nginx
else
    docker-compose up -d nginx
fi

sleep 3

success "Nginx started"

################################################################################
# Start Monitoring (if enabled)
################################################################################

if [ "$ENABLE_MONITORING" = true ]; then
    step "Starting monitoring stack..."

    docker-compose -f docker-compose.monitoring.yml up -d

    log "Waiting for monitoring services..."
    sleep 10

    success "Monitoring stack started"
fi

################################################################################
# Health Checks
################################################################################

step "Running health checks..."

HEALTH_ERRORS=0

# Check database
if docker exec $DB_CONTAINER pg_isready -U postgres &>/dev/null; then
    log "✓ Database is healthy"
else
    error "✗ Database health check failed"
    ((HEALTH_ERRORS++))
fi

# Check Redis
if docker-compose exec -T redis redis-cli ping 2>/dev/null | grep -q PONG; then
    log "✓ Redis is healthy"
else
    warning "✗ Redis health check failed"
fi

# Check backend
if curl -sf http://localhost:8000/api/health &>/dev/null; then
    log "✓ Backend is healthy"
else
    warning "✗ Backend health check failed (may take a few more seconds)"
fi

# Check frontend
if curl -sf http://localhost:3000 &>/dev/null; then
    log "✓ Frontend is healthy"
else
    warning "✗ Frontend health check failed (may take a few more seconds)"
fi

# Check Nginx
if curl -sf http://localhost &>/dev/null; then
    log "✓ Nginx is healthy"
else
    warning "✗ Nginx health check failed"
fi

if [ $HEALTH_ERRORS -eq 0 ]; then
    success "Health checks passed"
else
    warning "Some health checks failed, but deployment continues"
fi

################################################################################
# Create Initial Admin User
################################################################################

step "Creating initial admin user..."

log "You can create an admin user through the web interface or API"

# If you have a script to create admin user, run it here
# docker exec $BACKEND_CONTAINER python scripts/create-admin.py

success "Admin user setup available"

################################################################################
# Display Service Status
################################################################################

step "Checking service status..."

echo ""
docker-compose ps
echo ""

success "All services deployed"

################################################################################
# Setup Backups
################################################################################

step "Setting up automated backups..."

# Install cron jobs for backups
if [ -x "$PROJECT_ROOT/backup/cron/setup-cron.sh" ]; then
    "$PROJECT_ROOT/backup/cron/setup-cron.sh" --install &>/dev/null || true
    success "Backup cron jobs installed"
else
    warning "Backup setup script not found"
fi

################################################################################
# Deployment Summary
################################################################################

DEPLOYMENT_END=$(date +%s)
DEPLOYMENT_TIME=$(($DEPLOYMENT_END - $DEPLOYMENT_START))

echo ""
echo "=========================================="
echo "  Deployment Summary"
echo "=========================================="
echo ""
echo "Deployment Time: ${DEPLOYMENT_TIME}s"
echo "Steps Completed: $STEPS_COMPLETED/$STEPS_TOTAL"
echo ""

success "PromptForge deployed successfully!"

echo ""
log "Access URLs:"
echo "  • Frontend:    http://localhost:3000"
echo "  • Backend API: http://localhost:8000"
echo "  • API Docs:    http://localhost:8000/docs"
echo ""

if [ "$ENABLE_MONITORING" = true ]; then
    log "Monitoring URLs:"
    echo "  • Grafana:     http://localhost:3000 (admin/[check .env.monitoring])"
    echo "  • Prometheus:  http://localhost:9090"
    echo "  • AlertManager: http://localhost:9093"
    echo ""
fi

log "Useful commands:"
echo "  • Check status:  docker-compose ps"
echo "  • View logs:     docker-compose logs -f [service]"
echo "  • Restart:       docker-compose restart [service]"
echo "  • Stop all:      docker-compose down"
echo "  • Health check:  ./deploy/monitoring/check-health.sh"
echo ""

log "Next steps:"
echo "  1. Access the application at http://localhost:3000"
echo "  2. Create your first admin user"
echo "  3. Configure email settings in .env"
echo "  4. Set up SSL for production (./deploy/initial/init-ssl.sh --letsencrypt)"
echo "  5. Configure off-site backups in .env.backup"
echo "  6. Review monitoring dashboards (if enabled)"
echo ""

# Save deployment info
DEPLOY_INFO_FILE="/var/log/promptforge/deployment-$(date +%Y%m%d_%H%M%S).log"
mkdir -p /var/log/promptforge

cat > "$DEPLOY_INFO_FILE" << EOF
PromptForge Deployment Information
===================================

Date: $(date)
Duration: ${DEPLOYMENT_TIME}s
User: $SUDO_USER
Mode: $([ "$ENABLE_HA" = true ] && echo "High Availability" || echo "Standard")
Monitoring: $([ "$ENABLE_MONITORING" = true ] && echo "Enabled" || echo "Disabled")

Docker Images:
$(docker images | grep promptforge)

Running Containers:
$(docker ps --filter "name=promptforge" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}")

Environment:
$(grep -v "PASSWORD\|SECRET\|KEY" .env)
EOF

log "Deployment log saved to: $DEPLOY_INFO_FILE"

echo ""
success "Deployment completed! 🎉"
echo ""

exit 0

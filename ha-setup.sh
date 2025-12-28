#!/bin/bash

################################################################################
# PromptForge High Availability Setup Script
################################################################################
#
# This script helps set up high availability deployment for PromptForge.
#
# Options:
#   1. Docker Compose HA (simple, single-host)
#   2. Docker Swarm (orchestration, multi-host capable)
#
# Usage:
#   ./ha-setup.sh [--compose|--swarm|--check]
#
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
# Check Prerequisites
################################################################################

check_prerequisites() {
    log "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        warning "Docker Compose is not installed"
        echo "Install with: sudo apt-get install docker-compose"
    fi

    # Check .env.production
    if [ ! -f .env.production ]; then
        error ".env.production not found"
        echo "Copy .env.production.example and configure it"
        exit 1
    fi

    success "Prerequisites checked"
}

################################################################################
# Setup Docker Compose HA
################################################################################

setup_compose_ha() {
    log "Setting up Docker Compose HA deployment..."

    # Create necessary directories
    mkdir -p logs/nginx logs/backend1 logs/backend2 logs/backend3

    # Check if SSL certificates exist
    if [ ! -f nginx/ssl/cert.pem ] || [ ! -f nginx/ssl/key.pem ]; then
        warning "SSL certificates not found"
        echo "Run: ./ssl-setup.sh self-signed"
        echo "Or configure Let's Encrypt certificates"
        read -p "Continue without SSL? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Start services
    log "Starting HA services with Docker Compose..."
    docker-compose -f docker-compose.ha.yml up -d

    # Wait for services to start
    log "Waiting for services to initialize..."
    sleep 15

    # Check health
    log "Checking service health..."
    docker-compose -f docker-compose.ha.yml ps

    echo ""
    success "Docker Compose HA deployment complete!"
    echo ""
    log "Services:"
    echo "  - Nginx Load Balancer: http://localhost"
    echo "  - Backend instances: 3 (backend1, backend2, backend3)"
    echo "  - Frontend instances: 2 (frontend1, frontend2)"
    echo "  - PostgreSQL: Primary + Replica"
    echo "  - Redis: Master + Replica + 3 Sentinels"
    echo ""
    log "Monitoring:"
    echo "  - Nginx status: http://localhost:8080/nginx_status"
    echo "  - Logs: docker-compose -f docker-compose.ha.yml logs -f"
    echo "  - Health: ./health-check.sh"
    echo ""
}

################################################################################
# Setup Docker Swarm
################################################################################

setup_swarm() {
    log "Setting up Docker Swarm deployment..."

    # Run swarm setup script
    if [ -f ha/swarm/setup-swarm.sh ]; then
        cd ha/swarm
        ./setup-swarm.sh --init
        ./setup-swarm.sh --deploy
        cd "$SCRIPT_DIR"

        success "Docker Swarm deployment complete!"
        echo ""
        log "View status: ./ha/swarm/setup-swarm.sh --status"
    else
        error "Swarm setup script not found"
        exit 1
    fi
}

################################################################################
# Health Check
################################################################################

health_check() {
    log "Running health checks..."

    echo ""
    log "Container Health:"
    if command -v docker-compose &> /dev/null && [ -f docker-compose.ha.yml ]; then
        docker-compose -f docker-compose.ha.yml ps
    elif docker info 2>/dev/null | grep -q "Swarm: active"; then
        docker service ls
    else
        warning "No HA deployment found"
    fi

    echo ""
    log "Testing endpoints..."

    # Test Nginx
    if curl -sf http://localhost/health > /dev/null; then
        success "✓ Nginx load balancer is healthy"
    else
        error "✗ Nginx load balancer is not responding"
    fi

    # Test Backend API
    if curl -sf http://localhost/api/health > /dev/null; then
        success "✓ Backend API is healthy"
    else
        error "✗ Backend API is not responding"
    fi

    # Test PostgreSQL
    if docker exec promptforge-postgres-primary pg_isready &> /dev/null; then
        success "✓ PostgreSQL primary is healthy"
    else
        error "✗ PostgreSQL primary is not responding"
    fi

    # Test Redis
    if docker exec promptforge-redis-master redis-cli ping &> /dev/null; then
        success "✓ Redis master is healthy"
    else
        error "✗ Redis master is not responding"
    fi

    # Test Redis Sentinel
    if docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster &> /dev/null; then
        success "✓ Redis Sentinel is healthy"
        MASTER=$(docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster 2>/dev/null | head -1)
        log "Current Redis master: $MASTER"
    else
        error "✗ Redis Sentinel is not responding"
    fi

    echo ""
}

################################################################################
# Show HA Status
################################################################################

show_status() {
    echo "=========================================="
    echo "  PromptForge HA Status"
    echo "=========================================="
    echo ""

    # Check which deployment is running
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        log "Deployment Type: Docker Swarm"
        echo ""

        log "Swarm Nodes:"
        docker node ls

        echo ""
        log "Services:"
        docker service ls

        echo ""
        log "For detailed status: ./ha/swarm/setup-swarm.sh --status"

    elif docker-compose -f docker-compose.ha.yml ps &> /dev/null; then
        log "Deployment Type: Docker Compose HA"
        echo ""

        docker-compose -f docker-compose.ha.yml ps

        echo ""
        log "Nginx upstream status:"
        curl -s http://localhost:8080/nginx_status || echo "Status page not available"

    else
        warning "No HA deployment detected"
    fi

    echo ""
}

################################################################################
# Test Failover
################################################################################

test_failover() {
    warning "This will simulate failures to test high availability"
    read -p "Continue? (yes/no): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi

    echo ""
    log "Testing backend failover..."
    log "Stopping backend1..."
    docker stop promptforge-backend-1 || true

    log "Waiting 5 seconds..."
    sleep 5

    log "Testing API (should still work via backend2/backend3)..."
    if curl -sf http://localhost/api/health > /dev/null; then
        success "✓ Backend failover working - API still accessible"
    else
        error "✗ Backend failover failed - API not accessible"
    fi

    log "Restarting backend1..."
    docker start promptforge-backend-1 || true

    echo ""
    log "Testing Redis failover..."
    log "Current Redis master:"
    docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster

    log "Stopping Redis master..."
    docker stop promptforge-redis-master || true

    log "Waiting for Sentinel to promote replica (10 seconds)..."
    sleep 10

    log "New Redis master:"
    docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster

    log "Restarting original Redis master (now becomes replica)..."
    docker start promptforge-redis-master || true

    echo ""
    success "Failover tests complete"
    log "Check logs: docker-compose -f docker-compose.ha.yml logs redis-sentinel-1"
}

################################################################################
# Main Menu
################################################################################

case "${1:-}" in
    --compose)
        echo "=========================================="
        echo "  Docker Compose HA Setup"
        echo "=========================================="
        echo ""
        check_prerequisites
        setup_compose_ha
        ;;

    --swarm)
        echo "=========================================="
        echo "  Docker Swarm Setup"
        echo "=========================================="
        echo ""
        check_prerequisites
        setup_swarm
        ;;

    --check)
        health_check
        ;;

    --status)
        show_status
        ;;

    --test-failover)
        test_failover
        ;;

    *)
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║                                                            ║"
        echo "║        PromptForge High Availability Setup                 ║"
        echo "║                                                            ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Usage: $0 [OPTION]"
        echo ""
        echo "Options:"
        echo "  --compose        Setup Docker Compose HA (single-host)"
        echo "  --swarm          Setup Docker Swarm (multi-host capable)"
        echo "  --check          Run health checks"
        echo "  --status         Show current HA status"
        echo "  --test-failover  Test failover capabilities"
        echo ""
        echo "HA Features:"
        echo "  ✓ Load balancing across multiple backend instances"
        echo "  ✓ PostgreSQL replication (primary + replica)"
        echo "  ✓ Redis Sentinel for automatic failover"
        echo "  ✓ Health checks and automatic recovery"
        echo "  ✓ Rolling updates (Swarm mode)"
        echo ""
        echo "Quick Start:"
        echo "  1. Copy and configure .env.production"
        echo "  2. Setup SSL certificates: ./ssl-setup.sh"
        echo "  3. Choose deployment:"
        echo "     - Single host:  $0 --compose"
        echo "     - Multi host:   $0 --swarm"
        echo "  4. Check health:   $0 --check"
        echo ""
        echo "Documentation: docs/high-availability.md"
        echo ""
        exit 0
        ;;
esac

exit 0

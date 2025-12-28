#!/bin/bash

################################################################################
# Docker Swarm Setup Script for PromptForge
################################################################################
#
# This script initializes and configures Docker Swarm for PromptForge
# high availability deployment.
#
# Usage:
#   ./setup-swarm.sh [--init|--join|--deploy|--remove]
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
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

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

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
        exit 1
    fi

    # Check Docker version (Swarm requires 1.12+)
    DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' | cut -d. -f1)
    if [ "$DOCKER_VERSION" -lt 1 ]; then
        error "Docker version 1.12+ required for Swarm"
        exit 1
    fi

    success "Prerequisites checked"
}

################################################################################
# Initialize Swarm
################################################################################

init_swarm() {
    log "Initializing Docker Swarm..."

    # Check if swarm is already initialized
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        warning "Docker Swarm is already initialized"
        docker node ls
        return 0
    fi

    # Get primary IP address
    PRIMARY_IP=$(hostname -I | awk '{print $1}')
    log "Primary IP address: $PRIMARY_IP"

    # Initialize swarm
    log "Initializing swarm on $PRIMARY_IP..."
    docker swarm init --advertise-addr "$PRIMARY_IP"

    success "Docker Swarm initialized"

    # Show join tokens
    echo ""
    log "To add worker nodes, run this command on other machines:"
    docker swarm join-token worker

    echo ""
    log "To add manager nodes, run this command on other machines:"
    docker swarm join-token manager

    echo ""
}

################################################################################
# Create Overlay Network
################################################################################

create_network() {
    log "Creating overlay network..."

    if docker network ls | grep -q promptforge_network; then
        warning "Network 'promptforge_network' already exists"
    else
        docker network create \
            --driver overlay \
            --attachable \
            --subnet 10.0.9.0/24 \
            promptforge_network
        success "Overlay network created"
    fi
}

################################################################################
# Setup Docker Registry (for local images)
################################################################################

setup_registry() {
    log "Setting up local Docker registry..."

    if docker service ls 2>/dev/null | grep -q registry; then
        warning "Registry service already exists"
    else
        docker service create \
            --name registry \
            --publish 5000:5000 \
            --constraint node.role==manager \
            registry:2
        success "Local registry created at localhost:5000"
    fi

    # Wait for registry to be ready
    log "Waiting for registry to be ready..."
    sleep 5
}

################################################################################
# Build and Push Images
################################################################################

build_and_push_images() {
    log "Building and pushing images to local registry..."

    cd "$PROJECT_ROOT"

    # Build backend image
    log "Building backend image..."
    docker build -t localhost:5000/promptforge-backend:latest -f backend/Dockerfile.prod backend/

    # Push backend image
    log "Pushing backend image..."
    docker push localhost:5000/promptforge-backend:latest

    # Build frontend image
    log "Building frontend image..."
    docker build -t localhost:5000/promptforge-frontend:latest \
        --build-arg VITE_API_URL="${VITE_API_URL}" \
        -f frontend/Dockerfile.prod frontend/

    # Push frontend image
    log "Pushing frontend image..."
    docker push localhost:5000/promptforge-frontend:latest

    success "Images built and pushed"
}

################################################################################
# Deploy Stack
################################################################################

deploy_stack() {
    log "Deploying PromptForge stack..."

    cd "$PROJECT_ROOT"

    # Load environment variables
    if [ -f .env.production ]; then
        export $(cat .env.production | grep -v '^#' | xargs)
    else
        error ".env.production not found"
        exit 1
    fi

    # Deploy stack
    docker stack deploy \
        -c ha/swarm/docker-stack.yml \
        --with-registry-auth \
        promptforge

    success "Stack deployed"

    # Wait for services to start
    log "Waiting for services to start..."
    sleep 10

    # Show stack status
    echo ""
    log "Stack status:"
    docker stack ps promptforge

    echo ""
    log "Service status:"
    docker service ls
}

################################################################################
# Remove Stack
################################################################################

remove_stack() {
    warning "Removing PromptForge stack..."

    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log "Cancelled"
        exit 0
    fi

    docker stack rm promptforge

    log "Waiting for stack to be removed..."
    sleep 10

    success "Stack removed"
}

################################################################################
# Scale Services
################################################################################

scale_services() {
    log "Current service status:"
    docker service ls

    echo ""
    log "Scaling recommendations:"
    echo "  Backend (CPU-intensive): 3-5 replicas"
    echo "  Frontend (lightweight): 2-3 replicas"
    echo "  Nginx: 2 replicas (for redundancy)"

    echo ""
    read -p "Scale backend to how many replicas? (default: 3): " backend_replicas
    backend_replicas=${backend_replicas:-3}

    read -p "Scale frontend to how many replicas? (default: 2): " frontend_replicas
    frontend_replicas=${frontend_replicas:-2}

    log "Scaling backend to $backend_replicas replicas..."
    docker service scale promptforge_backend="$backend_replicas"

    log "Scaling frontend to $frontend_replicas replicas..."
    docker service scale promptforge_frontend="$frontend_replicas"

    success "Services scaled"

    echo ""
    docker service ls
}

################################################################################
# Show Status
################################################################################

show_status() {
    echo "=========================================="
    echo "  PromptForge Swarm Status"
    echo "=========================================="
    echo ""

    log "Swarm Nodes:"
    docker node ls

    echo ""
    log "Services:"
    docker service ls

    echo ""
    log "Stack Tasks:"
    docker stack ps promptforge

    echo ""
    log "Networks:"
    docker network ls | grep promptforge

    echo ""
}

################################################################################
# Main Script
################################################################################

case "${1:-}" in
    --init)
        echo "=========================================="
        echo "  Initialize Docker Swarm"
        echo "=========================================="
        echo ""
        check_prerequisites
        init_swarm
        create_network
        setup_registry
        ;;

    --deploy)
        echo "=========================================="
        echo "  Deploy PromptForge Stack"
        echo "=========================================="
        echo ""
        check_prerequisites
        build_and_push_images
        deploy_stack
        ;;

    --remove)
        echo "=========================================="
        echo "  Remove PromptForge Stack"
        echo "=========================================="
        echo ""
        remove_stack
        ;;

    --scale)
        echo "=========================================="
        echo "  Scale Services"
        echo "=========================================="
        echo ""
        scale_services
        ;;

    --status)
        show_status
        ;;

    *)
        echo "Docker Swarm Setup for PromptForge"
        echo ""
        echo "Usage: $0 [--init|--deploy|--remove|--scale|--status]"
        echo ""
        echo "Commands:"
        echo "  --init      Initialize Docker Swarm cluster"
        echo "  --deploy    Build and deploy PromptForge stack"
        echo "  --remove    Remove PromptForge stack"
        echo "  --scale     Scale services"
        echo "  --status    Show current status"
        echo ""
        echo "Quick Start:"
        echo "  1. Initialize swarm:  $0 --init"
        echo "  2. Deploy stack:      $0 --deploy"
        echo "  3. Check status:      $0 --status"
        echo ""
        exit 1
        ;;
esac

exit 0

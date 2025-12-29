#!/bin/bash

################################################################################
# PromptForge Dependency Installation Script
################################################################################
#
# This script installs all required dependencies for PromptForge including:
#   - Docker and Docker Compose
#   - System utilities
#   - Python dependencies
#   - Node.js and npm
#   - PostgreSQL client tools
#   - Nginx (if needed)
#
# Usage:
#   sudo ./install.sh [--skip-docker] [--skip-node] [--minimal]
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
SKIP_DOCKER=false
SKIP_NODE=false
MINIMAL=false

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
# Check Root
################################################################################

if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root"
    echo "Please run: sudo $0"
    exit 1
fi

################################################################################
# Parse Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-docker)
            SKIP_DOCKER=true
            shift
            ;;
        --skip-node)
            SKIP_NODE=true
            shift
            ;;
        --minimal)
            MINIMAL=true
            shift
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

################################################################################
# Installation Header
################################################################################

clear
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║        PromptForge Dependency Installation                 ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
log "Starting installation..."
echo ""

################################################################################
# Detect OS
################################################################################

log "Detecting operating system..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    error "Cannot detect OS"
    exit 1
fi

log "Operating System: $OS $VER"

if [ "$OS" != "ubuntu" ] && [ "$OS" != "debian" ]; then
    warning "This script is tested on Ubuntu/Debian. Proceeding anyway..."
fi

################################################################################
# Update System
################################################################################

log "Updating package lists..."
apt-get update -qq

success "Package lists updated"

################################################################################
# Install Basic Utilities
################################################################################

log "Installing basic utilities..."

apt-get install -y -qq \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    net-tools \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    unzip \
    jq \
    rsync \
    cron

success "Basic utilities installed"

################################################################################
# Install Docker
################################################################################

if [ "$SKIP_DOCKER" = false ]; then
    log "Installing Docker..."

    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        log "Docker is already installed: $DOCKER_VERSION"
    else
        # Add Docker's official GPG key
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        # Set up Docker repository
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
            $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Install Docker
        apt-get update -qq
        apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        # Start and enable Docker
        systemctl start docker
        systemctl enable docker

        success "Docker installed successfully"
    fi

    # Install Docker Compose (standalone)
    if ! command -v docker-compose &> /dev/null; then
        log "Installing Docker Compose..."

        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
        curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose

        success "Docker Compose installed: $COMPOSE_VERSION"
    else
        COMPOSE_VERSION=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
        log "Docker Compose is already installed: $COMPOSE_VERSION"
    fi

    # Add current user to docker group (if not root)
    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker $SUDO_USER
        log "Added $SUDO_USER to docker group (logout required)"
    fi
else
    log "Skipping Docker installation (--skip-docker)"
fi

################################################################################
# Install PostgreSQL Client
################################################################################

log "Installing PostgreSQL client tools..."

apt-get install -y -qq postgresql-client

success "PostgreSQL client installed"

################################################################################
# Install Python
################################################################################

log "Installing Python..."

apt-get install -y -qq \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential

# Upgrade pip
python3 -m pip install --upgrade pip

success "Python installed"

################################################################################
# Install Node.js
################################################################################

if [ "$SKIP_NODE" = false ]; then
    log "Installing Node.js..."

    # Check if Node.js is already installed
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        log "Node.js is already installed: $NODE_VERSION"
    else
        # Install NodeSource repository for latest LTS
        curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
        apt-get install -y -qq nodejs

        success "Node.js installed: $(node --version)"
    fi

    # Install yarn (optional)
    if ! command -v yarn &> /dev/null; then
        npm install -g yarn
        success "Yarn installed"
    fi
else
    log "Skipping Node.js installation (--skip-node)"
fi

################################################################################
# Install Redis Tools
################################################################################

log "Installing Redis tools..."

apt-get install -y -qq redis-tools

success "Redis tools installed"

################################################################################
# Install System Monitoring Tools
################################################################################

if [ "$MINIMAL" = false ]; then
    log "Installing monitoring tools..."

    apt-get install -y -qq \
        sysstat \
        iotop \
        iftop \
        ncdu \
        tree

    success "Monitoring tools installed"
fi

################################################################################
# Install Security Tools
################################################################################

log "Installing security tools..."

apt-get install -y -qq \
    ufw \
    fail2ban \
    certbot

success "Security tools installed"

################################################################################
# Install Backup Tools
################################################################################

log "Installing backup tools..."

apt-get install -y -qq \
    gpg \
    pigz \
    pv

success "Backup tools installed"

################################################################################
# Configure Firewall (UFW)
################################################################################

log "Configuring firewall..."

# Enable UFW if not enabled
if ! ufw status | grep -q "Status: active"; then
    # Allow SSH first
    ufw allow ssh
    ufw allow 22/tcp

    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp

    # Enable firewall
    echo "y" | ufw enable

    success "Firewall configured and enabled"
else
    log "Firewall already enabled"
fi

################################################################################
# Configure Fail2Ban
################################################################################

log "Configuring fail2ban..."

systemctl enable fail2ban
systemctl start fail2ban

success "Fail2ban enabled"

################################################################################
# Install Additional Tools (if not minimal)
################################################################################

if [ "$MINIMAL" = false ]; then
    log "Installing additional tools..."

    # Install ctop (container monitoring)
    if ! command -v ctop &> /dev/null; then
        wget https://github.com/bcicen/ctop/releases/download/v0.7.7/ctop-0.7.7-linux-amd64 -O /usr/local/bin/ctop
        chmod +x /usr/local/bin/ctop
        success "ctop installed"
    fi

    # Install lazydocker (Docker UI)
    if ! command -v lazydocker &> /dev/null; then
        curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
        success "lazydocker installed"
    fi
fi

################################################################################
# Create System Directories
################################################################################

log "Creating system directories..."

mkdir -p /var/log/promptforge
mkdir -p /var/backups/promptforge
mkdir -p /etc/promptforge

chown -R $SUDO_USER:$SUDO_USER /var/log/promptforge 2>/dev/null || true
chown -R $SUDO_USER:$SUDO_USER /var/backups/promptforge 2>/dev/null || true

success "System directories created"

################################################################################
# Install Custom Scripts
################################################################################

log "Installing custom scripts..."

# Create symbolic links to deployment scripts
ln -sf "$PROJECT_ROOT/deploy/monitoring/check-health.sh" /usr/local/bin/promptforge-health 2>/dev/null || true
ln -sf "$PROJECT_ROOT/deploy/update/restart-services.sh" /usr/local/bin/promptforge-restart 2>/dev/null || true

success "Custom scripts installed"

################################################################################
# System Optimization
################################################################################

log "Applying system optimizations..."

# Increase file descriptor limits
cat >> /etc/security/limits.conf << EOF
# PromptForge optimizations
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
EOF

# Optimize sysctl for production
cat >> /etc/sysctl.conf << EOF
# PromptForge optimizations
vm.swappiness=10
vm.dirty_ratio=60
vm.dirty_background_ratio=2
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_intvl=60
net.ipv4.tcp_keepalive_probes=3
net.core.somaxconn=4096
net.ipv4.tcp_max_syn_backlog=4096
EOF

sysctl -p &>/dev/null || true

success "System optimizations applied"

################################################################################
# Verify Installation
################################################################################

echo ""
log "Verifying installation..."
echo ""

ERRORS=0

# Check Docker
if command -v docker &> /dev/null; then
    echo "✓ Docker: $(docker --version | awk '{print $3}' | sed 's/,//')"
else
    echo "✗ Docker: Not installed"
    ((ERRORS++))
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null; then
    echo "✓ Docker Compose: $(docker-compose --version | awk '{print $3}' | sed 's/,//')"
else
    echo "✗ Docker Compose: Not installed"
    ((ERRORS++))
fi

# Check Python
if command -v python3 &> /dev/null; then
    echo "✓ Python: $(python3 --version | awk '{print $2}')"
else
    echo "✗ Python: Not installed"
    ((ERRORS++))
fi

# Check Node.js
if command -v node &> /dev/null; then
    echo "✓ Node.js: $(node --version)"
else
    echo "✗ Node.js: Not installed"
fi

# Check PostgreSQL client
if command -v psql &> /dev/null; then
    echo "✓ PostgreSQL client: $(psql --version | awk '{print $3}')"
else
    echo "✗ PostgreSQL client: Not installed"
    ((ERRORS++))
fi

# Check Git
if command -v git &> /dev/null; then
    echo "✓ Git: $(git --version | awk '{print $3}')"
else
    echo "✗ Git: Not installed"
    ((ERRORS++))
fi

echo ""

################################################################################
# Installation Summary
################################################################################

echo "=========================================="
echo "  Installation Summary"
echo "=========================================="
echo ""

if [ $ERRORS -eq 0 ]; then
    success "All dependencies installed successfully!"
    echo ""
    log "Next steps:"
    echo "  1. Logout and login again (for Docker group changes)"
    echo "  2. Run: cd $PROJECT_ROOT"
    echo "  3. Run: sudo ./deploy/initial/setup.sh"
    echo "  4. Run: sudo ./deploy/initial/first-deploy.sh"
    echo ""
else
    error "$ERRORS required dependencies failed to install"
    echo "Please review the errors above and fix them before proceeding"
    exit 1
fi

exit 0

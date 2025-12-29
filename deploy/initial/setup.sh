#!/bin/bash

################################################################################
# PromptForge Initial Setup Script
################################################################################
#
# This script performs initial setup for PromptForge:
#   - Creates required directories
#   - Sets proper permissions
#   - Generates configuration files
#   - Sets up environment variables
#   - Initializes database structure
#
# Usage:
#   sudo ./setup.sh [--prod|--dev]
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
ENVIRONMENT="prod"
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

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
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
        --prod)
            ENVIRONMENT="prod"
            shift
            ;;
        --dev)
            ENVIRONMENT="dev"
            shift
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

################################################################################
# Setup Header
################################################################################

clear
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║        PromptForge Initial Setup                           ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
log "Environment: $ENVIRONMENT"
log "Project root: $PROJECT_ROOT"
echo ""

################################################################################
# Create Directory Structure
################################################################################

log "Creating directory structure..."

# Application directories
mkdir -p "$PROJECT_ROOT/logs/nginx"
mkdir -p "$PROJECT_ROOT/logs/backend"
mkdir -p "$PROJECT_ROOT/logs/frontend"
mkdir -p "$PROJECT_ROOT/uploads"
mkdir -p "$PROJECT_ROOT/media"
mkdir -p "$PROJECT_ROOT/static"

# SSL certificates
mkdir -p "$PROJECT_ROOT/ssl/certs"
mkdir -p "$PROJECT_ROOT/ssl/private"

# Database
mkdir -p "$PROJECT_ROOT/database/data"
mkdir -p "$PROJECT_ROOT/database/backups"

# Backups
mkdir -p "$PROJECT_ROOT/backups/full"
mkdir -p "$PROJECT_ROOT/backups/database"
mkdir -p "$PROJECT_ROOT/backups/volumes"

# System directories
mkdir -p /var/log/promptforge
mkdir -p /var/backups/promptforge/full
mkdir -p /var/backups/promptforge/database
mkdir -p /var/backups/promptforge/wal_archive
mkdir -p /etc/promptforge

success "Directory structure created"

################################################################################
# Set Permissions
################################################################################

log "Setting permissions..."

# Get the non-root user
if [ -n "$SUDO_USER" ]; then
    APP_USER="$SUDO_USER"
else
    APP_USER="promptforge"
fi

# Application directories
chown -R $APP_USER:$APP_USER "$PROJECT_ROOT/logs"
chown -R $APP_USER:$APP_USER "$PROJECT_ROOT/uploads"
chown -R $APP_USER:$APP_USER "$PROJECT_ROOT/media"
chown -R $APP_USER:$APP_USER "$PROJECT_ROOT/static"
chown -R $APP_USER:$APP_USER "$PROJECT_ROOT/backups"

# SSL certificates
chmod 700 "$PROJECT_ROOT/ssl/private"
chmod 755 "$PROJECT_ROOT/ssl/certs"

# System directories
chown -R $APP_USER:$APP_USER /var/log/promptforge
chown -R $APP_USER:$APP_USER /var/backups/promptforge

# Make scripts executable
chmod +x "$PROJECT_ROOT"/deploy/initial/*.sh
chmod +x "$PROJECT_ROOT"/deploy/update/*.sh
chmod +x "$PROJECT_ROOT"/deploy/monitoring/*.sh
chmod +x "$PROJECT_ROOT"/deploy/maintenance/*.sh
chmod +x "$PROJECT_ROOT"/backup/scripts/*.sh
chmod +x "$PROJECT_ROOT"/backup/restore/*.sh

success "Permissions set"

################################################################################
# Generate Environment File
################################################################################

log "Generating environment configuration..."

if [ -f "$PROJECT_ROOT/.env" ]; then
    warning ".env file already exists, creating backup..."
    cp "$PROJECT_ROOT/.env" "$PROJECT_ROOT/.env.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Generate secure passwords
DB_PASSWORD=$(generate_password)
POSTGRES_PASSWORD=$(generate_password)
SECRET_KEY=$(generate_password)
JWT_SECRET=$(generate_password)
REDIS_PASSWORD=$(generate_password)

cat > "$PROJECT_ROOT/.env" << EOF
# PromptForge Environment Configuration
# Generated: $(date)
# Environment: $ENVIRONMENT

################################################################################
# Application
################################################################################

# Environment (production, development, staging)
ENVIRONMENT=$ENVIRONMENT

# Debug mode (true/false)
DEBUG=$([ "$ENVIRONMENT" = "dev" ] && echo "true" || echo "false")

# Application URL
APP_URL=http://localhost
APP_PORT=3000

# API URL
API_URL=http://localhost:8000

################################################################################
# Security
################################################################################

# Secret key for session encryption
SECRET_KEY=$SECRET_KEY

# JWT secret for token signing
JWT_SECRET=$JWT_SECRET

# CORS allowed origins (comma-separated)
CORS_ORIGINS=http://localhost:3000,http://localhost

################################################################################
# Database (PostgreSQL)
################################################################################

# Database connection
DB_HOST=postgres
DB_PORT=5432
DB_NAME=promptforge
DB_USER=promptforge
DB_PASS=$DB_PASSWORD

# PostgreSQL superuser
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# Connection pool
DB_POOL_SIZE=20
DB_MAX_OVERFLOW=10

################################################################################
# Redis
################################################################################

REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_DB=0

# Redis Sentinel (for HA)
REDIS_SENTINEL_HOSTS=redis-sentinel-1:26379,redis-sentinel-2:26379,redis-sentinel-3:26379
REDIS_SENTINEL_MASTER=mymaster

################################################################################
# Email (SMTP)
################################################################################

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM_EMAIL=noreply@promptforge.io
SMTP_FROM_NAME=PromptForge

################################################################################
# File Storage
################################################################################

UPLOAD_DIR=/app/uploads
MAX_UPLOAD_SIZE=10485760  # 10MB in bytes

################################################################################
# Logging
################################################################################

LOG_LEVEL=$([ "$ENVIRONMENT" = "dev" ] && echo "DEBUG" || echo "INFO")
LOG_FORMAT=json

################################################################################
# Session
################################################################################

SESSION_LIFETIME=86400  # 24 hours
SESSION_COOKIE_NAME=promptforge_session
SESSION_COOKIE_SECURE=$([ "$ENVIRONMENT" = "prod" ] && echo "true" || echo "false")

################################################################################
# Rate Limiting
################################################################################

RATE_LIMIT_ENABLED=true
RATE_LIMIT_PER_MINUTE=60

################################################################################
# Backup
################################################################################

BACKUP_DIR=/var/backups/promptforge
RETENTION_DAYS=30
EOF

chown $APP_USER:$APP_USER "$PROJECT_ROOT/.env"
chmod 600 "$PROJECT_ROOT/.env"

success "Environment file created: $PROJECT_ROOT/.env"

################################################################################
# Generate Monitoring Environment
################################################################################

log "Generating monitoring configuration..."

cat > "$PROJECT_ROOT/.env.monitoring" << EOF
# PromptForge Monitoring Configuration
# Generated: $(date)

################################################################################
# Grafana
################################################################################

GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$(generate_password)
GRAFANA_PORT=3000

################################################################################
# Prometheus
################################################################################

PROMETHEUS_PORT=9090
PROMETHEUS_RETENTION=30d

################################################################################
# AlertManager
################################################################################

ALERTMANAGER_PORT=9093

# Email alerts
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
ALERT_EMAIL_FROM=alerts@promptforge.io
ALERT_EMAIL_CRITICAL=admin@promptforge.io
ALERT_EMAIL_DATABASE=dba@promptforge.io
ALERT_EMAIL_OPS=ops@promptforge.io

# Slack (optional)
SLACK_WEBHOOK_URL=

# PagerDuty (optional)
PAGERDUTY_SERVICE_KEY=

################################################################################
# Loki
################################################################################

LOKI_PORT=3100
LOKI_RETENTION=720h  # 30 days

################################################################################
# Exporters
################################################################################

NODE_EXPORTER_PORT=9100
CADVISOR_PORT=8080
POSTGRES_EXPORTER_PORT=9187
REDIS_EXPORTER_PORT=9121
NGINX_EXPORTER_PORT=9113
BLACKBOX_EXPORTER_PORT=9115
EOF

chown $APP_USER:$APP_USER "$PROJECT_ROOT/.env.monitoring"
chmod 600 "$PROJECT_ROOT/.env.monitoring"

success "Monitoring configuration created"

################################################################################
# Generate Backup Configuration
################################################################################

log "Generating backup configuration..."

cat > "$PROJECT_ROOT/.env.backup" << EOF
# PromptForge Backup Configuration
# Generated: $(date)

################################################################################
# Database Credentials
################################################################################

DB_PASS=$DB_PASSWORD
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

################################################################################
# Encryption
################################################################################

GPG_RECIPIENT=admin@promptforge.io

################################################################################
# Off-site Backup
################################################################################

REMOTE_USER=backup
REMOTE_HOST=
REMOTE_PATH=/backups/promptforge

################################################################################
# Email Notifications
################################################################################

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=

NOTIFY_EMAIL=admin@promptforge.io
NOTIFY_CRITICAL_EMAIL=admin@promptforge.io
EOF

chown $APP_USER:$APP_USER "$PROJECT_ROOT/.env.backup"
chmod 600 "$PROJECT_ROOT/.env.backup"

success "Backup configuration created"

################################################################################
# Display Credentials
################################################################################

echo ""
echo "=========================================="
echo "  Generated Credentials"
echo "=========================================="
echo ""
warning "IMPORTANT: Save these credentials securely!"
echo ""
echo "Database:"
echo "  User: promptforge"
echo "  Password: $DB_PASSWORD"
echo ""
echo "PostgreSQL Superuser:"
echo "  User: postgres"
echo "  Password: $POSTGRES_PASSWORD"
echo ""
echo "Redis:"
echo "  Password: $REDIS_PASSWORD"
echo ""
echo "Grafana:"
GRAFANA_PASS=$(grep GRAFANA_ADMIN_PASSWORD "$PROJECT_ROOT/.env.monitoring" | cut -d= -f2)
echo "  User: admin"
echo "  Password: $GRAFANA_PASS"
echo ""
warning "These credentials are saved in .env files (chmod 600)"
echo ""

# Save credentials to a secure file
CREDS_FILE="/etc/promptforge/credentials.txt"
cat > "$CREDS_FILE" << EOF
PromptForge Credentials
Generated: $(date)

Database:
  User: promptforge
  Password: $DB_PASSWORD

PostgreSQL Superuser:
  User: postgres
  Password: $POSTGRES_PASSWORD

Redis:
  Password: $REDIS_PASSWORD

Grafana:
  User: admin
  Password: $GRAFANA_PASS

Application:
  Secret Key: $SECRET_KEY
  JWT Secret: $JWT_SECRET
EOF

chmod 600 "$CREDS_FILE"
chown root:root "$CREDS_FILE"

log "Credentials also saved to: $CREDS_FILE"

################################################################################
# Initialize Git (if not already)
################################################################################

if [ ! -d "$PROJECT_ROOT/.git" ]; then
    log "Initializing Git repository..."

    cd "$PROJECT_ROOT"
    git init
    git add .
    git commit -m "Initial PromptForge setup"

    success "Git repository initialized"
fi

################################################################################
# Create Systemd Service (Optional)
################################################################################

log "Creating systemd service..."

cat > /etc/systemd/system/promptforge.service << EOF
[Unit]
Description=PromptForge Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_ROOT
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
User=$APP_USER
Group=$APP_USER

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

success "Systemd service created"

################################################################################
# Setup Summary
################################################################################

echo ""
echo "=========================================="
echo "  Setup Summary"
echo "=========================================="
echo ""
success "Initial setup completed successfully!"
echo ""
log "Next steps:"
echo "  1. Review and update .env file with your settings"
echo "  2. Configure SSL certificates: sudo ./deploy/initial/init-ssl.sh"
echo "  3. Deploy application: sudo ./deploy/initial/first-deploy.sh"
echo ""
log "Useful commands:"
echo "  • Check status: docker-compose ps"
echo "  • View logs: docker-compose logs -f"
echo "  • Restart: docker-compose restart"
echo "  • Stop: docker-compose down"
echo ""

exit 0

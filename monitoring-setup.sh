#!/bin/bash

################################################################################
# PromptForge Monitoring Stack Setup Script
################################################################################
#
# This script sets up the complete monitoring stack for PromptForge:
#   - Prometheus for metrics collection
#   - Grafana for visualization
#   - Loki + Promtail for log aggregation
#   - AlertManager for alerting
#   - Various exporters for system, database, and application metrics
#
# Usage:
#   ./monitoring-setup.sh [--start|--stop|--restart|--status|--logs]
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
        error "Docker Compose is not installed"
        exit 1
    fi

    # Check if monitoring directories exist
    if [ ! -d "$SCRIPT_DIR/monitoring" ]; then
        error "Monitoring directory not found"
        exit 1
    fi

    success "Prerequisites checked"
}

################################################################################
# Create Required Directories
################################################################################

create_directories() {
    log "Creating required directories..."

    mkdir -p logs/nginx
    mkdir -p logs/backend1 logs/backend2 logs/backend3

    success "Directories created"
}

################################################################################
# Configure Environment
################################################################################

configure_environment() {
    log "Configuring environment..."

    # Create .env.monitoring if it doesn't exist
    if [ ! -f .env.monitoring ]; then
        cat > .env.monitoring <<EOF
# Grafana Admin Credentials
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin

# AlertManager Email Configuration
SMTP_HOST=smtp.gmail.com:587
SMTP_USERNAME=
SMTP_PASSWORD=
ALERT_EMAIL_FROM=alerts@promptforge.io
ALERT_EMAIL_CRITICAL=admin@promptforge.io
ALERT_EMAIL_DATABASE=dba@promptforge.io
ALERT_EMAIL_OPS=ops@promptforge.io
ALERT_EMAIL_MONITORING=monitoring@promptforge.io

# Slack Webhook (optional)
SLACK_WEBHOOK_URL=

# PagerDuty (optional)
PAGERDUTY_SERVICE_KEY=
EOF
        warning "Created .env.monitoring - please configure email settings"
    fi

    success "Environment configured"
}

################################################################################
# Start Monitoring Stack
################################################################################

start_monitoring() {
    log "Starting monitoring stack..."

    docker-compose -f docker-compose.monitoring.yml up -d

    log "Waiting for services to start..."
    sleep 10

    success "Monitoring stack started"

    echo ""
    log "Access URLs:"
    echo "  Grafana:      http://localhost:3000 (admin/admin)"
    echo "  Prometheus:   http://localhost:9090"
    echo "  AlertManager: http://localhost:9093"
    echo "  Loki:         http://localhost:3100"
    echo "  cAdvisor:     http://localhost:8080"
    echo ""
    log "Grafana dashboards will be available after first login"
    echo ""
}

################################################################################
# Stop Monitoring Stack
################################################################################

stop_monitoring() {
    log "Stopping monitoring stack..."

    docker-compose -f docker-compose.monitoring.yml down

    success "Monitoring stack stopped"
}

################################################################################
# Restart Monitoring Stack
################################################################################

restart_monitoring() {
    log "Restarting monitoring stack..."

    docker-compose -f docker-compose.monitoring.yml restart

    success "Monitoring stack restarted"
}

################################################################################
# Show Status
################################################################################

show_status() {
    echo "=========================================="
    echo "  Monitoring Stack Status"
    echo "=========================================="
    echo ""

    docker-compose -f docker-compose.monitoring.yml ps

    echo ""
    log "Service Health:"

    # Check Grafana
    if curl -sf http://localhost:3000/api/health > /dev/null 2>&1; then
        success "✓ Grafana is healthy"
    else
        error "✗ Grafana is not responding"
    fi

    # Check Prometheus
    if curl -sf http://localhost:9090/-/healthy > /dev/null 2>&1; then
        success "✓ Prometheus is healthy"
    else
        error "✗ Prometheus is not responding"
    fi

    # Check AlertManager
    if curl -sf http://localhost:9093/-/healthy > /dev/null 2>&1; then
        success "✓ AlertManager is healthy"
    else
        error "✗ AlertManager is not responding"
    fi

    # Check Loki
    if curl -sf http://localhost:3100/ready > /dev/null 2>&1; then
        success "✓ Loki is healthy"
    else
        error "✗ Loki is not responding"
    fi

    echo ""
}

################################################################################
# Show Logs
################################################################################

show_logs() {
    local service=${1:-}

    if [ -z "$service" ]; then
        log "Showing logs for all services..."
        docker-compose -f docker-compose.monitoring.yml logs -f --tail=100
    else
        log "Showing logs for $service..."
        docker-compose -f docker-compose.monitoring.yml logs -f --tail=100 "$service"
    fi
}

################################################################################
# Test Alerts
################################################################################

test_alerts() {
    log "Sending test alert to AlertManager..."

    curl -H "Content-Type: application/json" -d '[
        {
            "labels": {
                "alertname": "TestAlert",
                "severity": "warning",
                "instance": "test-instance",
                "component": "test"
            },
            "annotations": {
                "summary": "This is a test alert",
                "description": "Testing AlertManager configuration"
            }
        }
    ]' http://localhost:9093/api/v1/alerts

    echo ""
    success "Test alert sent"
    log "Check AlertManager UI: http://localhost:9093"
}

################################################################################
# Configure Grafana
################################################################################

configure_grafana() {
    log "Configuring Grafana..."

    # Wait for Grafana to be ready
    log "Waiting for Grafana to start..."
    sleep 5

    # Check if Grafana is accessible
    if ! curl -sf http://localhost:3000/api/health > /dev/null 2>&1; then
        error "Grafana is not accessible. Please start the monitoring stack first."
        exit 1
    fi

    log "Grafana is ready at http://localhost:3000"
    log "Default credentials: admin/admin"
    log "You will be prompted to change the password on first login"

    success "Grafana configured"
}

################################################################################
# Main Menu
################################################################################

case "${1:-}" in
    --start)
        echo "=========================================="
        echo "  Start Monitoring Stack"
        echo "=========================================="
        echo ""
        check_prerequisites
        create_directories
        configure_environment
        start_monitoring
        configure_grafana
        ;;

    --stop)
        echo "=========================================="
        echo "  Stop Monitoring Stack"
        echo "=========================================="
        echo ""
        stop_monitoring
        ;;

    --restart)
        echo "=========================================="
        echo "  Restart Monitoring Stack"
        echo "=========================================="
        echo ""
        restart_monitoring
        ;;

    --status)
        show_status
        ;;

    --logs)
        show_logs "${2:-}"
        ;;

    --test-alert)
        test_alerts
        ;;

    *)
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║                                                            ║"
        echo "║        PromptForge Monitoring Stack Setup                  ║"
        echo "║                                                            ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Usage: $0 [OPTION]"
        echo ""
        echo "Options:"
        echo "  --start        Start the monitoring stack"
        echo "  --stop         Stop the monitoring stack"
        echo "  --restart      Restart the monitoring stack"
        echo "  --status       Show status of monitoring services"
        echo "  --logs [SVC]   Show logs (optionally for specific service)"
        echo "  --test-alert   Send a test alert to AlertManager"
        echo ""
        echo "Components:"
        echo "  ✓ Prometheus   - Metrics collection and storage"
        echo "  ✓ Grafana      - Visualization and dashboards"
        echo "  ✓ Loki         - Log aggregation"
        echo "  ✓ Promtail     - Log shipping"
        echo "  ✓ AlertManager - Alert routing and notifications"
        echo "  ✓ Exporters    - System, DB, Redis, Nginx metrics"
        echo ""
        echo "Quick Start:"
        echo "  1. Configure: Edit .env.monitoring"
        echo "  2. Start:     $0 --start"
        echo "  3. Access:    http://localhost:3000 (Grafana)"
        echo "  4. Status:    $0 --status"
        echo ""
        echo "Documentation: docs/monitoring.md"
        echo ""
        exit 0
        ;;
esac

exit 0

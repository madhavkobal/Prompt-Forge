#!/bin/bash

################################################################################
# PromptForge Health Check Script
################################################################################
#
# Checks the health of all services and reports status.
# Can be run manually or via monitoring tools.
#
# Usage:
#   ./health-check.sh [--verbose]
#
# Exit Codes:
#   0 - All services healthy
#   1 - One or more services unhealthy
#
################################################################################

COMPOSE_FILE="docker-compose.prod.yml"
VERBOSE=false

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
if [[ "$1" == "--verbose" ]]; then
    VERBOSE=true
fi

EXIT_CODE=0

echo "PromptForge Health Check"
echo "========================"
echo ""

# Check Docker
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running${NC}"
    exit 1
fi

# Check services
services=("postgres" "redis" "backend" "frontend" "nginx")

for service in "${services[@]}"; do
    if docker-compose -f "$COMPOSE_FILE" ps "$service" | grep -q "Up"; then
        # Check health status
        health=$(docker-compose -f "$COMPOSE_FILE" ps "$service" | grep "$service" | awk '{print $5}')

        if [[ "$health" == "Up" ]] || [[ "$health" == "Up (healthy)" ]]; then
            echo -e "${GREEN}✓${NC} $service: Healthy"

            if [[ "$VERBOSE" == "true" ]]; then
                # Show resource usage
                stats=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep "$service" || echo "")
                if [[ -n "$stats" ]]; then
                    echo "  $stats"
                fi
            fi
        else
            echo -e "${YELLOW}⚠${NC} $service: Running but unhealthy"
            EXIT_CODE=1
        fi
    else
        echo -e "${RED}✗${NC} $service: Not running"
        EXIT_CODE=1
    fi
done

echo ""

# Check endpoints
echo "Endpoint Checks:"
echo "----------------"

# Frontend
if curl -sf http://localhost/ > /dev/null; then
    echo -e "${GREEN}✓${NC} Frontend: Accessible"
else
    echo -e "${RED}✗${NC} Frontend: Not accessible"
    EXIT_CODE=1
fi

# Backend API
if curl -sf http://localhost/api/health > /dev/null; then
    echo -e "${GREEN}✓${NC} Backend API: Healthy"
else
    echo -e "${RED}✗${NC} Backend API: Unhealthy"
    EXIT_CODE=1
fi

echo ""

if [[ $EXIT_CODE -eq 0 ]]; then
    echo -e "${GREEN}All systems operational${NC}"
else
    echo -e "${RED}Some services are unhealthy${NC}"
fi

exit $EXIT_CODE

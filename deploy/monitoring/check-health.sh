#!/bin/bash
###############################################################################
# PromptForge Health Check Script
################################################################################

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "=========================================="
echo "  PromptForge Health Check"
echo "=========================================="
echo ""

ERRORS=0

# Check containers
echo "Container Status:"
if docker-compose -f "$PROJECT_ROOT/docker-compose.yml" ps | grep -q "Up"; then
    success "Containers are running"
else
    error "Some containers are down"
    ((ERRORS++))
fi

# Check backend
echo ""
echo "Backend Health:"
if curl -sf http://localhost:8000/api/health >/dev/null 2>&1; then
    success "Backend API is healthy"
    RESPONSE=$(curl -s http://localhost:8000/api/health)
    echo "  Response: $RESPONSE"
else
    error "Backend API is not responding"
    ((ERRORS++))
fi

# Check frontend
echo ""
echo "Frontend Health:"
if curl -sf http://localhost:3000 >/dev/null 2>&1; then
    success "Frontend is accessible"
else
    error "Frontend is not responding"
    ((ERRORS++))
fi

# Check database
echo ""
echo "Database Health:"
if docker-compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
    success "Database is ready"
    CONN_COUNT=$(docker-compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T postgres psql -U postgres -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | tr -d ' ')
    echo "  Active connections: $CONN_COUNT"
else
    error "Database is not ready"
    ((ERRORS++))
fi

# Check Redis
echo ""
echo "Redis Health:"
if docker-compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T redis redis-cli ping 2>/dev/null | grep -q PONG; then
    success "Redis is responding"
else
    warning "Redis is not responding"
fi

# Summary
echo ""
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All health checks passed!${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS health check(s) failed!${NC}"
    exit 1
fi

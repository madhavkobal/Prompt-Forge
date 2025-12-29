#!/bin/bash
################################################################################
# PromptForge Log Analysis Script
################################################################################

LINES="${1:-100}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "=========================================="
echo "  Recent Logs (last $LINES lines)"
echo "=========================================="
echo ""

cd "$PROJECT_ROOT"

# Show recent errors
echo "Recent Errors:"
docker-compose logs --tail=$LINES 2>&1 | grep -i "error\|exception\|fatal\|critical" | tail -20

echo ""
echo "Recent Warnings:"
docker-compose logs --tail=$LINES 2>&1 | grep -i "warn" | tail -10

echo ""
echo "Log Summary:"
echo "  Total errors: $(docker-compose logs --tail=$LINES 2>&1 | grep -ic "error")"
echo "  Total warnings: $(docker-compose logs --tail=$LINES 2>&1 | grep -ic "warn")"

echo ""
echo "Full logs: docker-compose logs -f [service]"

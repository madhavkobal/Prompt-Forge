#!/bin/bash
# Database migration script for production deployment

set -e

echo "PromptForge Database Migration Script"
echo "======================================"

# Check if DATABASE_URL is set
if [ -z "$DATABASE_URL" ]; then
    echo "Error: DATABASE_URL environment variable is not set"
    exit 1
fi

# Parse command line arguments
COMMAND=${1:-"upgrade"}

case "$COMMAND" in
    upgrade)
        echo "Applying database migrations..."
        alembic upgrade head
        echo "✓ Migrations applied successfully"
        ;;
    downgrade)
        STEPS=${2:-1}
        echo "Reverting $STEPS migration(s)..."
        alembic downgrade -$STEPS
        echo "✓ Migrations reverted successfully"
        ;;
    current)
        echo "Current database revision:"
        alembic current
        ;;
    history)
        echo "Migration history:"
        alembic history --verbose
        ;;
    check)
        echo "Checking for pending migrations..."
        alembic current
        echo "Latest available revision:"
        alembic heads
        ;;
    create)
        if [ -z "$2" ]; then
            echo "Error: Migration message is required"
            echo "Usage: ./migrate.sh create \"migration message\""
            exit 1
        fi
        echo "Creating new migration: $2"
        alembic revision --autogenerate -m "$2"
        echo "✓ Migration created successfully"
        ;;
    *)
        echo "Usage: ./migrate.sh {upgrade|downgrade|current|history|check|create} [args]"
        echo ""
        echo "Commands:"
        echo "  upgrade          - Apply all pending migrations (default)"
        echo "  downgrade [N]    - Revert N migrations (default: 1)"
        echo "  current          - Show current database revision"
        echo "  history          - Show migration history"
        echo "  check            - Check for pending migrations"
        echo "  create \"message\" - Create new migration with autogenerate"
        exit 1
        ;;
esac

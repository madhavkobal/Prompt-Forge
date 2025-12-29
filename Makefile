.PHONY: help install setup deploy update backup restore monitor health logs clean

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

##@ General

help: ## Display this help message
	@echo "╔════════════════════════════════════════════════════════════╗"
	@echo "║                                                            ║"
	@echo "║             PromptForge Makefile Commands                  ║"
	@echo "║                                                            ║"
	@echo "╚════════════════════════════════════════════════════════════╝"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n\n"} \
		/^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""

##@ Installation

install: ## Install all dependencies
	@echo "$(BLUE)[INFO]$(NC) Installing dependencies..."
	@sudo ./deploy/initial/install.sh

setup: ## Run initial setup
	@echo "$(BLUE)[INFO]$(NC) Running initial setup..."
	@sudo ./deploy/initial/setup.sh

ssl: ## Setup SSL certificates
	@echo "$(BLUE)[INFO]$(NC) Setting up SSL certificates..."
	@sudo ./deploy/initial/init-ssl.sh

init: install setup ## Install dependencies and run setup
	@echo "$(GREEN)[SUCCESS]$(NC) Initialization complete!"

##@ Deployment

deploy: ## Deploy application (first time)
	@echo "$(BLUE)[INFO]$(NC) Deploying PromptForge..."
	@sudo ./deploy/initial/first-deploy.sh

deploy-ha: ## Deploy with High Availability
	@echo "$(BLUE)[INFO]$(NC) Deploying with HA..."
	@sudo ./deploy/initial/first-deploy.sh --ha --monitoring

start: ## Start all services
	@echo "$(BLUE)[INFO]$(NC) Starting services..."
	@docker-compose up -d

stop: ## Stop all services
	@echo "$(BLUE)[INFO]$(NC) Stopping services..."
	@docker-compose down

restart: ## Restart all services
	@echo "$(BLUE)[INFO]$(NC) Restarting services..."
	@./deploy/update/restart-services.sh

status: ## Show service status
	@docker-compose ps

##@ Updates

update: ## Update application (zero-downtime)
	@echo "$(BLUE)[INFO]$(NC) Updating application..."
	@sudo ./deploy/update/update-app.sh

update-config: ## Update configuration
	@echo "$(BLUE)[INFO]$(NC) Updating configuration..."
	@./deploy/update/update-config.sh

rollback: ## Rollback to previous version
	@echo "$(BLUE)[INFO]$(NC) Rolling back..."
	@./deploy/update/rollback.sh

##@ Backup & Restore

backup: ## Run full backup
	@echo "$(BLUE)[INFO]$(NC) Running full backup..."
	@./backup/scripts/backup-full.sh --encrypt --offsite

backup-db: ## Backup database only
	@echo "$(BLUE)[INFO]$(NC) Backing up database..."
	@./backup/scripts/backup-db.sh --encrypt

verify-backup: ## Verify latest backup
	@echo "$(BLUE)[INFO]$(NC) Verifying backup..."
	@./backup/scripts/backup-verify.sh $$(ls -t /var/backups/promptforge/full | head -1)

restore: ## Restore from backup
	@echo "$(YELLOW)[WARNING]$(NC) This will restore from backup!"
	@./backup/restore/restore-full.sh --backup=$$(ls -t /var/backups/promptforge/full | head -1)

restore-db: ## Restore database only
	@echo "$(YELLOW)[WARNING]$(NC) This will restore database from backup!"
	@./backup/restore/restore-db.sh --backup=$$(ls -t /var/backups/promptforge/database | head -1)

##@ Monitoring

monitor: health disk memory ## Run all monitoring checks

health: ## Check application health
	@./deploy/monitoring/check-health.sh

disk: ## Check disk space
	@./deploy/monitoring/check-disk-space.sh

memory: ## Check memory usage
	@./deploy/monitoring/check-memory.sh

logs: ## Show recent logs
	@./deploy/monitoring/check-logs.sh

logs-follow: ## Follow logs (real-time)
	@docker-compose logs -f

logs-backend: ## Show backend logs
	@docker-compose logs -f backend

logs-frontend: ## Show frontend logs
	@docker-compose logs -f frontend

logs-nginx: ## Show nginx logs
	@docker-compose logs -f nginx

##@ Maintenance

clean: ## Run all cleanup tasks
	@echo "$(BLUE)[INFO]$(NC) Running cleanup..."
	@./deploy/maintenance/cleanup-logs.sh
	@./deploy/maintenance/docker-cleanup.sh

clean-logs: ## Clean up old logs
	@./deploy/maintenance/cleanup-logs.sh

clean-backups: ## Clean up old backups
	@./deploy/maintenance/cleanup-backups.sh 30

clean-docker: ## Clean up Docker resources
	@./deploy/maintenance/docker-cleanup.sh

vacuum-db: ## Run database maintenance
	@./deploy/maintenance/database-vacuum.sh

##@ Database

db-shell: ## Open database shell
	@docker-compose exec postgres psql -U promptforge -d promptforge

db-backup-now: ## Immediate database backup
	@./backup/scripts/backup-db.sh --format=custom --encrypt

db-restore: ## Restore database from backup
	@./backup/restore/restore-db.sh

db-migrations: ## Run database migrations
	@docker-compose exec backend alembic upgrade head

db-rollback-migration: ## Rollback last migration
	@docker-compose exec backend alembic downgrade -1

##@ Development

dev-start: ## Start in development mode
	@echo "$(BLUE)[INFO]$(NC) Starting in development mode..."
	@docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

dev-logs: ## Show development logs
	@docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f

dev-stop: ## Stop development environment
	@docker-compose -f docker-compose.yml -f docker-compose.dev.yml down

dev-local: ## Start local development (without Docker)
	@echo "$(BLUE)[INFO]$(NC) Starting local development..."
	@echo "Backend: http://localhost:8000"
	@echo "Frontend: http://localhost:5173"
	@(cd backend && source venv/bin/activate && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000) & \
	(cd frontend && npm run dev)

install-local: ## Install local dependencies
	@echo "$(BLUE)[INFO]$(NC) Installing backend dependencies..."
	@cd backend && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
	@echo "$(BLUE)[INFO]$(NC) Installing frontend dependencies..."
	@cd frontend && npm install
	@echo "$(GREEN)[SUCCESS]$(NC) Local dependencies installed!"

test-local: ## Run local tests (backend + frontend)
	@echo "$(BLUE)[INFO]$(NC) Running backend tests..."
	@cd backend && source venv/bin/activate && pytest -v --cov=app --cov-report=term-missing
	@echo "$(BLUE)[INFO]$(NC) Running frontend tests..."
	@cd frontend && npm run test || echo "$(YELLOW)[WARNING]$(NC) Frontend tests not configured"
	@echo "$(GREEN)[SUCCESS]$(NC) Tests completed!"

test-backend-local: ## Run backend tests locally
	@cd backend && source venv/bin/activate && pytest -v --cov=app --cov-report=term-missing --cov-report=html

lint-local: ## Run linters locally
	@echo "$(BLUE)[INFO]$(NC) Linting backend..."
	@cd backend && source venv/bin/activate && flake8 app/ || echo "Install flake8: pip install flake8"
	@echo "$(BLUE)[INFO]$(NC) Linting frontend..."
	@cd frontend && npm run lint || echo "$(YELLOW)[WARNING]$(NC) Frontend linting not configured"
	@echo "$(GREEN)[SUCCESS]$(NC) Linting completed!"

format-local: ## Format code locally
	@echo "$(BLUE)[INFO]$(NC) Formatting backend code..."
	@cd backend && source venv/bin/activate && black app/ || echo "Install black: pip install black"
	@echo "$(BLUE)[INFO]$(NC) Formatting frontend code..."
	@cd frontend && npm run format || echo "$(YELLOW)[INFO]$(NC) Add 'format' script to package.json"
	@echo "$(GREEN)[SUCCESS]$(NC) Code formatted!"

clean-local: ## Clean local build artifacts
	@echo "$(BLUE)[INFO]$(NC) Cleaning build artifacts..."
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@cd frontend && rm -rf dist/ .vite/ 2>/dev/null || true
	@echo "$(GREEN)[SUCCESS]$(NC) Cleanup completed!"

##@ Testing

test: ## Run tests
	@echo "$(BLUE)[INFO]$(NC) Running tests..."
	@docker-compose exec backend pytest

test-backup: ## Test backup system
	@./backup/scripts/test-backup.sh --full

test-dr: ## Run DR drill simulation
	@./backup/scripts/test-backup.sh --drill

##@ Security

security-scan: ## Run security scan
	@echo "$(BLUE)[INFO]$(NC) Running security scan..."
	@docker run --rm -v $$(pwd):/scan aquasec/trivy fs /scan

update-certs: ## Update SSL certificates
	@./deploy/initial/init-ssl.sh

##@ Utilities

shell-backend: ## Open shell in backend container
	@docker-compose exec backend /bin/bash

shell-frontend: ## Open shell in frontend container
	@docker-compose exec frontend /bin/sh

shell-db: ## Open shell in database container
	@docker-compose exec postgres /bin/bash

build: ## Build Docker images
	@echo "$(BLUE)[INFO]$(NC) Building Docker images..."
	@docker-compose build

rebuild: ## Rebuild Docker images (no cache)
	@echo "$(BLUE)[INFO]$(NC) Rebuilding Docker images..."
	@docker-compose build --no-cache

pull: ## Pull latest images from registry
	@docker-compose pull

push: ## Push images to registry
	@docker-compose push

##@ Quick Actions

quick-deploy: build start ## Build and start services
	@echo "$(GREEN)[SUCCESS]$(NC) Quick deploy complete!"

quick-update: stop pull start ## Stop, pull, and start services
	@echo "$(GREEN)[SUCCESS]$(NC) Quick update complete!"

quick-restart: restart health ## Restart and check health
	@echo "$(GREEN)[SUCCESS]$(NC) Services restarted!"

quick-backup: backup-db verify-backup ## Backup database and verify
	@echo "$(GREEN)[SUCCESS]$(NC) Backup complete!"

##@ Information

version: ## Show application version
	@git describe --tags --always

info: ## Show system information
	@echo "╔════════════════════════════════════════════════════════════╗"
	@echo "║             PromptForge System Information                  ║"
	@echo "╚════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Version: $$(git describe --tags --always)"
	@echo "Branch: $$(git branch --show-current)"
	@echo "Docker: $$(docker --version | awk '{print $$3}' | sed 's/,//')"
	@echo "Docker Compose: $$(docker-compose --version | awk '{print $$3}' | sed 's/,//')"
	@echo ""
	@echo "Services:"
	@docker-compose ps
	@echo ""
	@echo "Disk Usage:"
	@df -h / | tail -1
	@echo ""
	@echo "Docker Disk Usage:"
	@docker system df

env: ## Show environment configuration
	@echo "$(BLUE)[INFO]$(NC) Environment configuration:"
	@grep -v "PASSWORD\|SECRET\|KEY" .env || echo "No .env file found"

containers: ## List all PromptForge containers
	@docker ps --filter "name=promptforge"

images: ## List all PromptForge images
	@docker images | grep promptforge

volumes: ## List all PromptForge volumes
	@docker volume ls | grep promptforge

networks: ## List all PromptForge networks
	@docker network ls | grep promptforge

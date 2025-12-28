# Docker Deployment Guide

Deploy PromptForge using Docker and Docker Compose.

## Quick Deploy

```bash
# Clone repository
git clone https://github.com/madhavkobal/Prompt-Forge.git
cd Prompt-Forge

# Configure environment
cp backend/production.env.example backend/.env.production
# Edit backend/.env.production with your settings

# Build and start
docker-compose -f docker-compose.prod.yml up -d

# Access application
# Frontend: http://your-server:80
# Backend API: http://your-server:8000
```

## Production Docker Compose

Create `docker-compose.prod.yml`:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: promptforge_prod
      POSTGRES_USER: promptforge
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: always

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile.prod
    environment:
      DATABASE_URL: postgresql://promptforge:${DB_PASSWORD}@postgres:5432/promptforge_prod
      SECRET_KEY: ${SECRET_KEY}
      GEMINI_API_KEY: ${GEMINI_API_KEY}
      ENVIRONMENT: production
    depends_on:
      - postgres
    restart: always

  frontend:
    build:
      context: ./frontend
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - backend
    restart: always

volumes:
  postgres_data:
```

##SSL/HTTPS Setup

Add nginx with Let's Encrypt:

```yaml
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/ssl:/etc/nginx/ssl
      - certbot_data:/var/www/certbot
    depends_on:
      - backend
      - frontend

  certbot:
    image: certbot/certbot
    volumes:
      - certbot_data:/var/www/certbot
      - ./nginx/ssl:/etc/letsencrypt
    command: certonly --webroot --webroot-path=/var/www/certbot --email your@email.com --agree-tos --no-eff-email -d yourdomain.com
```

## Monitoring

Add Prometheus and Grafana:

```yaml
  prometheus:
    image: prom/prometheus
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}

volumes:
  postgres_data:
  prometheus_data:
  grafana_data:
  certbot_data:
```

## Maintenance Commands

```bash
# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Restart services
docker-compose -f docker-compose.prod.yml restart

# Update application
git pull
docker-compose -f docker-compose.prod.yml up -d --build

# Backup database
docker-compose -f docker-compose.prod.yml exec postgres pg_dump -U promptforge promptforge_prod > backup.sql

# Restore database
docker-compose -f docker-compose.prod.yml exec -T postgres psql -U promptforge promptforge_prod < backup.sql
```

# On-Premises Production Deployment Guide

Complete guide for deploying PromptForge on your own infrastructure using Docker Compose.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Architecture](#architecture)
4. [Pre-Deployment Setup](#pre-deployment-setup)
5. [Configuration](#configuration)
6. [Deployment](#deployment)
7. [SSL/TLS Setup](#ssltls-setup)
8. [Monitoring](#monitoring)
9. [Backup and Recovery](#backup-and-recovery)
10. [Maintenance](#maintenance)
11. [Scaling](#scaling)
12. [Troubleshooting](#troubleshooting)

---

## Overview

This guide covers deploying PromptForge to production on your own servers using Docker Compose. This deployment method is ideal for:

- Organizations with on-premises infrastructure requirements
- Teams with existing Docker/Kubernetes expertise
- Scenarios requiring full data control
- Cost-effective hosting for medium traffic
- Development and staging environments

**Production Stack:**
- **Nginx**: Reverse proxy, load balancer, SSL termination
- **FastAPI + Gunicorn**: Backend API (4+ workers)
- **React + Nginx**: Frontend static files
- **PostgreSQL 15**: Primary database
- **Redis 7**: Caching and session storage

---

## Prerequisites

### Hardware Requirements

**Minimum (Development/Small Scale):**
- CPU: 2 cores
- RAM: 4GB
- Storage: 20GB SSD
- Network: 10 Mbps

**Recommended (Production):**
- CPU: 4 cores (8 threads)
- RAM: 8GB+
- Storage: 100GB SSD
- Network: 100 Mbps+

### Software Requirements

**Required:**
- Ubuntu 22.04/24.04 LTS (or similar Linux distribution)
- Docker 24.0+
- Docker Compose 2.20+
- Git
- OpenSSL

**Optional:**
- UFW (firewall)
- Fail2ban (intrusion prevention)
- Certbot (Let's Encrypt SSL)

### Network Requirements

**Open Ports:**
- 80 (HTTP)
- 443 (HTTPS)
- 22 (SSH - for management)

**Closed Ports (internal only):**
- 5432 (PostgreSQL)
- 6379 (Redis)
- 8000 (Backend API)

### Domain Name

- Domain name pointed to your server's IP
- DNS A record configured
- (Optional) wildcard SSL certificate

---

## Architecture

### Component Overview

```
Internet
   |
   v
[Nginx Reverse Proxy] (Port 80/443)
   |
   +-- [Frontend] (React app served by Nginx)
   |
   +-- [Backend] (FastAPI + Gunicorn)
          |
          +-- [PostgreSQL] (Database)
          |
          +-- [Redis] (Cache)
```

### Network Layout

```
Docker Network: promptforge-network (172.25.0.0/16)
├── nginx (172.25.0.2)
├── frontend (172.25.0.3)
├── backend (172.25.0.4)
├── postgres (172.25.0.5)
└── redis (172.25.0.6)
```

### Data Flow

1. **Client Request** → Nginx (SSL termination)
2. **Static Files** → Nginx serves directly
3. **API Requests** → Nginx → Backend
4. **Database** → Backend → PostgreSQL
5. **Cache** → Backend → Redis

---

## Pre-Deployment Setup

### 1. Server Preparation

Update your server:

```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

### 2. Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
```

### 3. Install Docker Compose

```bash
# Download Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Make executable
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker-compose --version
```

### 4. Configure Firewall

```bash
# Install UFW
sudo apt install ufw -y

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (IMPORTANT: before enabling!)
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

### 5. Clone Repository

```bash
# Clone to /opt/promptforge
sudo mkdir -p /opt/promptforge
sudo chown $USER:$USER /opt/promptforge
cd /opt/promptforge

git clone https://github.com/your-repo/Prompt-Forge.git .
```

---

## Configuration

### 1. Environment Configuration

Copy and edit the production environment file:

```bash
cp .env.production.example .env.production
nano .env.production
```

**Critical Settings:**

```env
# Database (generate strong password)
DB_PASSWORD=$(openssl rand -base64 32)

# Redis (generate strong password)
REDIS_PASSWORD=$(openssl rand -base64 32)

# JWT Secret (64+ characters)
SECRET_KEY=$(openssl rand -hex 64)

# Gemini API Key
GEMINI_API_KEY=your-actual-api-key

# Your domain
VITE_API_URL=https://yourdomain.com/api
CORS_ORIGINS=["https://yourdomain.com"]
```

**Generate Secure Passwords:**

```bash
# Database password
openssl rand -base64 32

# Redis password
openssl rand -base64 32

# JWT secret key
openssl rand -hex 64
```

### 2. Create Data Directories

```bash
# Create directories for persistent data
mkdir -p data/postgres
mkdir -p data/redis
mkdir -p backups
mkdir -p logs/backend
mkdir -p logs/nginx
mkdir -p uploads

# Set permissions
chmod 700 data/postgres
chmod 700 data/redis
chmod 755 backups logs uploads
```

### 3. SSL Certificates

**Option A: Let's Encrypt (Recommended)**

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx -y

# Obtain certificate (replace with your domain)
sudo certbot certonly --standalone \
  -d yourdomain.com \
  -d www.yourdomain.com \
  --agree-tos \
  --email your@email.com

# Copy certificates to nginx directory
sudo mkdir -p nginx/ssl
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem nginx/ssl/cert.pem
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem nginx/ssl/key.pem
sudo chmod 644 nginx/ssl/*.pem
```

**Option B: Self-Signed (Development Only)**

```bash
# Generate self-signed certificate
mkdir -p nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=yourdomain.com"
```

### 4. Nginx Configuration

The nginx configuration is already set up in `nginx/nginx.conf` and `nginx/conf.d/`.

Review and customize if needed:

```bash
# Check nginx configuration
cat nginx/nginx.conf

# Test configuration (after deployment)
docker-compose -f docker-compose.prod.yml exec nginx nginx -t
```

---

## Deployment

### Method 1: Automated Deployment (Recommended)

Use the provided deployment script:

```bash
# First deployment
./deploy.sh

# With options
./deploy.sh --no-backup    # Skip backup (first time)
./deploy.sh --force        # Force deployment
```

The script will:
1. ✅ Perform pre-flight checks
2. ✅ Create database backup
3. ✅ Pull/build Docker images
4. ✅ Start services in order
5. ✅ Run database migrations
6. ✅ Verify health checks
7. ✅ Clean up old images

### Method 2: Manual Deployment

**Step 1: Build Images**

```bash
docker-compose -f docker-compose.prod.yml build
```

**Step 2: Start Services**

```bash
# Start database and redis first
docker-compose -f docker-compose.prod.yml up -d postgres redis

# Wait for them to be healthy
sleep 10

# Start backend
docker-compose -f docker-compose.prod.yml up -d backend

# Wait for backend
sleep 15

# Start frontend and nginx
docker-compose -f docker-compose.prod.yml up -d frontend nginx
```

**Step 3: Run Migrations**

```bash
docker-compose -f docker-compose.prod.yml exec backend alembic upgrade head
```

**Step 4: Verify Deployment**

```bash
# Check all services are running
docker-compose -f docker-compose.prod.yml ps

# Check logs
docker-compose -f docker-compose.prod.yml logs -f

# Test endpoints
curl http://localhost/
curl http://localhost/api/health
```

### Seed Demo Data (Optional)

```bash
docker-compose -f docker-compose.prod.yml exec backend \
  python scripts/seed_data.py
```

---

## SSL/TLS Setup

### 1. Configure HTTPS Redirect

Edit `nginx/conf.d/default.conf`:

```nginx
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;

    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Frontend
    location / {
        proxy_pass http://frontend:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Backend API
    location /api {
        proxy_pass http://backend:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 2. Auto-Renew Certificates

Set up automatic renewal for Let's Encrypt:

```bash
# Test renewal
sudo certbot renew --dry-run

# Add to cron (renew twice daily)
sudo crontab -e

# Add this line:
0 0,12 * * * certbot renew --quiet --post-hook "docker-compose -f /opt/promptforge/docker-compose.prod.yml exec nginx nginx -s reload"
```

---

## Monitoring

### 1. Health Checks

Use the provided health check script:

```bash
# Manual check
./health-check.sh

# Verbose output
./health-check.sh --verbose

# Add to cron (every 5 minutes)
*/5 * * * * /opt/promptforge/health-check.sh >> /var/log/promptforge-health.log 2>&1
```

### 2. Service Status

```bash
# Check all services
docker-compose -f docker-compose.prod.yml ps

# Check specific service
docker-compose -f docker-compose.prod.yml ps backend

# View logs
docker-compose -f docker-compose.prod.yml logs -f [service]

# View last 100 lines
docker-compose -f docker-compose.prod.yml logs --tail=100 backend
```

### 3. Resource Usage

```bash
# Real-time stats
docker stats

# Disk usage
docker system df

# Logs size
du -sh logs/*
```

### 4. Application Metrics

Access built-in metrics:

- Health: https://yourdomain.com/api/health
- Metrics: https://yourdomain.com/api/metrics (Prometheus format)
- Status: https://yourdomain.com/api/status

---

## Backup and Recovery

### Automated Backups

**Setup Daily Backups:**

```bash
# Make script executable
chmod +x backup.sh

# Test backup
./backup.sh

# Add to cron (daily at 2 AM)
crontab -e

# Add this line:
0 2 * * * /opt/promptforge/backup.sh >> /var/log/promptforge-backup.log 2>&1
```

**Backup Script Options:**

```bash
# Custom retention period
./backup.sh --keep-days 14

# Custom backup directory
./backup.sh --backup-dir /mnt/backups

# Skip compression
./backup.sh --no-compress
```

### Manual Backup

```bash
# Create backup
docker-compose -f docker-compose.prod.yml exec postgres \
  pg_dump -U promptforge promptforge > backup.sql

# Compress
gzip backup.sql
```

### Restore from Backup

```bash
# Using restore script
./restore.sh backups/promptforge-20241228-020000.sql.gz

# Manual restore
gunzip -c backup.sql.gz | \
  docker-compose -f docker-compose.prod.yml exec -T postgres \
  psql -U promptforge -d promptforge
```

### Offsite Backup

**Option 1: rsync to Remote Server**

```bash
# Sync to remote server
rsync -avz --delete \
  backups/ \
  user@backup-server:/backups/promptforge/
```

**Option 2: S3-Compatible Storage**

```bash
# Install AWS CLI
sudo apt install awscli -y

# Configure
aws configure

# Upload backups
aws s3 sync backups/ s3://your-bucket/promptforge-backups/
```

---

## Maintenance

### Updates

**Zero-Downtime Updates:**

```bash
# Using update script
./update.sh

# Manual update
git pull
docker-compose -f docker-compose.prod.yml build
docker-compose -f docker-compose.prod.yml up -d --no-deps backend
```

### Database Maintenance

**Vacuum and Analyze:**

```bash
docker-compose -f docker-compose.prod.yml exec postgres \
  vacuumdb -U promptforge -d promptforge --analyze
```

**Check Database Size:**

```bash
docker-compose -f docker-compose.prod.yml exec postgres \
  psql -U promptforge -d promptforge -c "\l+"
```

### Log Rotation

Configure log rotation for application logs:

```bash
sudo nano /etc/logrotate.d/promptforge
```

Add:

```
/opt/promptforge/logs/**/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0644 root root
    sharedscripts
    postrotate
        docker-compose -f /opt/promptforge/docker-compose.prod.yml restart backend nginx
    endscript
}
```

---

## Scaling

### Vertical Scaling

**Increase Resources:**

Edit `docker-compose.prod.yml`:

```yaml
backend:
  deploy:
    resources:
      limits:
        cpus: '4.0'  # Increase from 2.0
        memory: 4G   # Increase from 2G
```

**Increase Workers:**

Edit `.env.production`:

```env
BACKEND_WORKERS=8  # Increase from 4
```

### Horizontal Scaling

**Add Backend Replicas:**

```yaml
backend:
  deploy:
    replicas: 3  # Run 3 backend instances
```

**Load Balancer Configuration:**

Nginx will automatically load balance across replicas.

### Database Scaling

**Read Replicas:**

For high-read workloads, set up PostgreSQL read replicas.

**Connection Pooling:**

Increase connection pool:

```env
DB_POOL_SIZE=50
DB_MAX_OVERFLOW=20
```

---

## Troubleshooting

### Services Won't Start

**Check logs:**
```bash
docker-compose -f docker-compose.prod.yml logs [service]
```

**Check environment variables:**
```bash
docker-compose -f docker-compose.prod.yml config
```

### Database Connection Issues

**Test connection:**
```bash
docker-compose -f docker-compose.prod.yml exec postgres \
  psql -U promptforge -d promptforge -c "SELECT 1;"
```

**Check database logs:**
```bash
docker-compose -f docker-compose.prod.yml logs postgres
```

### High Memory Usage

**Check stats:**
```bash
docker stats
```

**Restart service:**
```bash
docker-compose -f docker-compose.prod.yml restart backend
```

### SSL Certificate Issues

**Verify certificates:**
```bash
openssl x509 -in nginx/ssl/cert.pem -text -noout
```

**Test SSL:**
```bash
curl -vI https://yourdomain.com
```

### Performance Issues

**Check backend workers:**
```bash
docker-compose -f docker-compose.prod.yml logs backend | grep workers
```

**Monitor database:**
```bash
docker-compose -f docker-compose.prod.yml exec postgres \
  psql -U promptforge -d promptforge -c "
    SELECT pid, query, state
    FROM pg_stat_activity
    WHERE state != 'idle';"
```

---

## Security Best Practices

### 1. Keep System Updated

```bash
# Regular updates
sudo apt update && sudo apt upgrade -y

# Docker updates
docker-compose -f docker-compose.prod.yml pull
```

### 2. Use Strong Passwords

- Database password: 32+ characters
- Redis password: 32+ characters
- JWT secret: 64+ characters
- All randomly generated (openssl rand)

### 3. Enable Fail2ban

```bash
sudo apt install fail2ban -y
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 4. Limit SSH Access

```bash
# Edit SSH config
sudo nano /etc/ssh/sshd_config

# Add:
PermitRootLogin no
PasswordAuthentication no
AllowUsers your-username
```

### 5. Monitor Logs

```bash
# Check for suspicious activity
sudo tail -f /var/log/auth.log
docker-compose -f docker-compose.prod.yml logs nginx | grep -i error
```

---

## Monitoring Dashboard (Optional)

### Setup Prometheus + Grafana

```bash
# Add to docker-compose.prod.yml
prometheus:
  image: prom/prometheus
  volumes:
    - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    - prometheus_data:/prometheus

grafana:
  image: grafana/grafana
  ports:
    - "3000:3000"
  volumes:
    - grafana_data:/var/lib/grafana
```

---

## Production Checklist

Before going live:

- [ ] All environment variables configured
- [ ] Strong passwords generated
- [ ] SSL certificates installed
- [ ] Firewall configured
- [ ] Backups automated
- [ ] Health checks working
- [ ] Logs rotation configured
- [ ] Monitoring set up
- [ ] Domain DNS configured
- [ ] Email notifications configured (optional)
- [ ] Security scan completed
- [ ] Load testing performed
- [ ] Rollback plan documented

---

## Support Resources

- **Documentation**: [docs/](../docs/)
- **GitHub Issues**: [Report a problem](https://github.com/your-repo/Prompt-Forge/issues)
- **Health Check**: `./health-check.sh`
- **Logs**: `docker-compose logs -f`

---

**Version:** 1.0.0
**Last Updated:** December 2024
**Maintained by:** PromptForge Team

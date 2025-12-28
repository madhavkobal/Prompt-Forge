# PromptForge Production Deployment Guide

Complete guide for deploying PromptForge to production.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Detailed Setup](#detailed-setup)
4. [SSL/TLS Configuration](#ssltls-configuration)
5. [Database Migrations](#database-migrations)
6. [Monitoring & Maintenance](#monitoring--maintenance)
7. [Troubleshooting](#troubleshooting)
8. [Security Checklist](#security-checklist)

---

## Prerequisites

### System Requirements

- **OS**: Ubuntu 20.04+ / Debian 11+ / CentOS 8+ (or any Linux with Docker support)
- **RAM**: Minimum 2GB, Recommended 4GB+
- **CPU**: Minimum 2 cores, Recommended 4+ cores
- **Disk**: Minimum 20GB free space
- **Domain**: Registered domain name with DNS configured

### Required Software

- Docker (20.10+)
- Docker Compose (2.0+)
- Git
- OpenSSL (for SSL certificate generation)

### API Keys

- Google Gemini API key (required)
- OpenAI API key (optional)

---

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/Prompt-Forge.git
cd Prompt-Forge
```

### 2. Configure Environment

```bash
# Copy environment template
cp .env.production.example .env.production

# Edit with your values
nano .env.production
```

**Required variables to update:**
- `POSTGRES_PASSWORD` - Strong database password
- `REDIS_PASSWORD` - Strong Redis password
- `SECRET_KEY` - Generate with: `openssl rand -hex 32`
- `GEMINI_API_KEY` - Your Google Gemini API key
- `VITE_API_URL` - Your production API URL
- `DOMAIN` - Your domain name
- `LETSENCRYPT_EMAIL` - Your email for SSL certificates

### 3. Configure Backend Environment

```bash
# Copy backend production config
cp backend/production.env.example backend/.env.production

# Edit with your values
nano backend/.env.production
```

Update the following:
- Database settings
- API keys
- Security settings
- Email/SMTP settings (if using)

### 4. Build and Start Services

```bash
# Build production images
docker-compose -f docker-compose.prod.yml build

# Start services
docker-compose -f docker-compose.prod.yml up -d

# Check status
docker-compose -f docker-compose.prod.yml ps
```

### 5. Run Database Migrations

```bash
# Run migrations
docker-compose -f docker-compose.prod.yml exec backend ./migrate.sh upgrade

# Verify migrations
docker-compose -f docker-compose.prod.yml exec backend ./migrate.sh current
```

### 6. Verify Deployment

```bash
# Check backend health
curl http://localhost/api/v1/health

# View logs
docker-compose -f docker-compose.prod.yml logs -f
```

---

## Detailed Setup

### Domain & DNS Configuration

1. **Purchase a domain** from a registrar (Namecheap, GoDaddy, etc.)

2. **Configure DNS records**:
   ```
   Type    Name    Value               TTL
   A       @       your.server.ip      3600
   A       www     your.server.ip      3600
   CNAME   api     yourdomain.com      3600
   ```

3. **Wait for DNS propagation** (can take up to 48 hours)
   ```bash
   # Test DNS
   nslookup yourdomain.com
   dig yourdomain.com
   ```

### Firewall Configuration

```bash
# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow SSH (if not already allowed)
sudo ufw allow 22/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

### Docker Installation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version
```

---

## SSL/TLS Configuration

### Option 1: Let's Encrypt (Recommended)

1. **Install Certbot**:
   ```bash
   sudo apt install certbot python3-certbot-nginx -y
   ```

2. **Obtain certificates**:
   ```bash
   sudo certbot certonly --webroot \
     -w /var/www/certbot \
     -d yourdomain.com \
     -d www.yourdomain.com \
     --email admin@yourdomain.com \
     --agree-tos
   ```

3. **Copy certificates**:
   ```bash
   sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem nginx/ssl/
   sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem nginx/ssl/
   chmod 644 nginx/ssl/fullchain.pem
   chmod 600 nginx/ssl/privkey.pem
   ```

4. **Enable HTTPS in nginx**:
   - Edit `nginx/conf.d/default.conf`
   - Uncomment HTTPS server block
   - Update `server_name` with your domain
   - Restart: `docker-compose -f docker-compose.prod.yml restart nginx`

5. **Set up auto-renewal**:
   ```bash
   sudo crontab -e
   # Add: 0 2 * * * certbot renew --quiet --deploy-hook "cd /path/to/Prompt-Forge && docker-compose -f docker-compose.prod.yml restart nginx"
   ```

### Option 2: Self-Signed (Testing Only)

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/privkey.pem \
  -out nginx/ssl/fullchain.pem \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=yourdomain.com"
```

---

## Database Migrations

### Initial Migration

```bash
# Run all migrations
docker-compose -f docker-compose.prod.yml exec backend ./migrate.sh upgrade

# Check current version
docker-compose -f docker-compose.prod.yml exec backend ./migrate.sh current
```

### Creating New Migrations

```bash
# After model changes, create migration
docker-compose -f docker-compose.prod.yml exec backend ./migrate.sh create "description of changes"

# Review generated migration in backend/alembic/versions/

# Apply migration
docker-compose -f docker-compose.prod.yml exec backend ./migrate.sh upgrade
```

### Rollback Migrations

```bash
# Rollback one migration
docker-compose -f docker-compose.prod.yml exec backend ./migrate.sh downgrade 1

# View migration history
docker-compose -f docker-compose.prod.yml exec backend ./migrate.sh history
```

---

## Monitoring & Maintenance

### Health Checks

```bash
# Backend health
curl https://yourdomain.com/api/v1/health

# Check all services
docker-compose -f docker-compose.prod.yml ps
```

### Viewing Logs

```bash
# All services
docker-compose -f docker-compose.prod.yml logs -f

# Specific service
docker-compose -f docker-compose.prod.yml logs -f backend
docker-compose -f docker-compose.prod.yml logs -f frontend
docker-compose -f docker-compose.prod.yml logs -f nginx

# Last 100 lines
docker-compose -f docker-compose.prod.yml logs --tail=100 backend
```

### Database Backup

```bash
# Manual backup
docker-compose -f docker-compose.prod.yml exec postgres pg_dump -U promptforge promptforge_prod > backup_$(date +%Y%m%d_%H%M%S).sql

# Automated daily backups (add to crontab)
0 2 * * * cd /path/to/Prompt-Forge && docker-compose -f docker-compose.prod.yml exec -T postgres pg_dump -U promptforge promptforge_prod > /backups/db_$(date +\%Y\%m\%d).sql
```

### Database Restore

```bash
# Restore from backup
docker-compose -f docker-compose.prod.yml exec -T postgres psql -U promptforge promptforge_prod < backup.sql
```

### Updating Application

```bash
# 1. Pull latest code
git pull origin main

# 2. Backup database
docker-compose -f docker-compose.prod.yml exec postgres pg_dump -U promptforge promptforge_prod > backup_pre_update.sql

# 3. Rebuild images
docker-compose -f docker-compose.prod.yml build

# 4. Stop services
docker-compose -f docker-compose.prod.yml down

# 5. Run migrations
docker-compose -f docker-compose.prod.yml up -d postgres redis
docker-compose -f docker-compose.prod.yml exec backend ./migrate.sh upgrade

# 6. Start all services
docker-compose -f docker-compose.prod.yml up -d

# 7. Check logs
docker-compose -f docker-compose.prod.yml logs -f
```

---

## Troubleshooting

### Services Won't Start

```bash
# Check logs
docker-compose -f docker-compose.prod.yml logs

# Check resource usage
docker stats

# Restart services
docker-compose -f docker-compose.prod.yml restart
```

### Database Connection Issues

```bash
# Verify database is running
docker-compose -f docker-compose.prod.yml ps postgres

# Check database logs
docker-compose -f docker-compose.prod.yml logs postgres

# Test connection
docker-compose -f docker-compose.prod.yml exec postgres psql -U promptforge -d promptforge_prod -c "SELECT 1;"
```

### nginx Errors

```bash
# Test nginx configuration
docker-compose -f docker-compose.prod.yml exec nginx nginx -t

# Reload nginx
docker-compose -f docker-compose.prod.yml exec nginx nginx -s reload

# Check nginx logs
docker-compose -f docker-compose.prod.yml logs nginx
```

### SSL Certificate Issues

```bash
# Verify certificate
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com

# Check certificate expiry
echo | openssl s_client -connect yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates

# Renew certificate manually
sudo certbot renew
```

### High Memory Usage

```bash
# Check memory usage
docker stats

# Restart services with lower resource limits
# Edit docker-compose.prod.yml and add resource limits
docker-compose -f docker-compose.prod.yml up -d
```

---

## Security Checklist

### Before Going Live

- [ ] Change all default passwords in `.env.production`
- [ ] Generate strong `SECRET_KEY` (32+ characters)
- [ ] Enable HTTPS with valid SSL certificate
- [ ] Configure firewall (ufw/iptables)
- [ ] Set up database backups
- [ ] Enable rate limiting in nginx
- [ ] Review and update CORS origins
- [ ] Disable debug mode (`DEBUG=False`)
- [ ] Set secure `ALLOWED_HOSTS` in backend config
- [ ] Remove or secure API documentation endpoints (`/docs`, `/redoc`)
- [ ] Enable Sentry or error tracking (optional)
- [ ] Set up monitoring (Prometheus, Grafana, etc.)
- [ ] Configure log rotation
- [ ] Test backup and restore procedures
- [ ] Set up SSL auto-renewal
- [ ] Review security headers in nginx
- [ ] Enable HSTS header
- [ ] Scan for vulnerabilities
- [ ] Update dependencies to latest stable versions
- [ ] Create admin user accounts
- [ ] Test all critical functionality

### Ongoing Security

- [ ] Regularly update Docker images
- [ ] Monitor security advisories for dependencies
- [ ] Review access logs regularly
- [ ] Rotate passwords and API keys periodically
- [ ] Keep SSL certificates up to date
- [ ] Monitor disk usage
- [ ] Review and update firewall rules
- [ ] Test backups monthly

---

## Performance Optimization

### Database Optimization

```sql
-- Create indexes for common queries
CREATE INDEX idx_prompts_owner_id ON prompts(owner_id);
CREATE INDEX idx_prompts_created_at ON prompts(created_at DESC);

-- Analyze tables
ANALYZE prompts;
ANALYZE users;
```

### nginx Caching

Add to nginx configuration:
```nginx
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m max_size=1g inactive=60m;
```

### Resource Limits

Edit `docker-compose.prod.yml`:
```yaml
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
```

---

## Additional Resources

- [Alembic Migrations Guide](backend/alembic/README_MIGRATIONS.md)
- [SSL Setup Guide](nginx/ssl/README.md)
- [Backend API Documentation](http://yourdomain.com/docs)
- [Docker Documentation](https://docs.docker.com/)
- [nginx Documentation](https://nginx.org/en/docs/)

---

## Support

For issues and questions:
- GitHub Issues: https://github.com/yourusername/Prompt-Forge/issues
- Documentation: https://github.com/yourusername/Prompt-Forge/wiki

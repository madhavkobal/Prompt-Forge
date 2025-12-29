# PromptForge On-Premises Configuration Guide

Comprehensive configuration guide for PromptForge on-premises deployment.

**Last Updated:** 2025-01-15
**Version:** 1.0

---

## Table of Contents

- [Environment Variables](#environment-variables)
- [SSL/TLS Configuration](#ssltls-configuration)
- [Database Configuration](#database-configuration)
- [Redis Configuration](#redis-configuration)
- [Email Configuration](#email-configuration)
- [API Keys & External Services](#api-keys--external-services)
- [Performance Tuning](#performance-tuning)
- [Security Configuration](#security-configuration)
- [High Availability Configuration](#high-availability-configuration)

---

## Environment Variables

PromptForge uses `.env` files for configuration. Multiple environment files are used for different purposes.

### Main Configuration File (.env)

Located at project root. Contains application configuration.

#### Application Settings

```bash
# Environment mode
ENVIRONMENT=production  # Options: production, development, staging
DEBUG=false            # Enable debug mode (true/false)

# Application URLs
APP_URL=https://promptforge.example.com
APP_PORT=3000
API_URL=https://promptforge.example.com/api
```

**Explanation:**
- `ENVIRONMENT`: Determines runtime behavior
  - `production`: Optimized for performance, minimal logging
  - `development`: Verbose logging, debug features enabled
  - `staging`: Production-like with additional logging
- `DEBUG`: Should always be `false` in production
- `APP_URL`: Public URL where application is accessed
- `API_URL`: Backend API endpoint

#### Security Settings

```bash
# Secret keys (auto-generated during setup)
SECRET_KEY=your_secret_key_here
JWT_SECRET=your_jwt_secret_here

# CORS settings
CORS_ORIGINS=https://promptforge.example.com,https://www.promptforge.example.com
```

**Explanation:**
- `SECRET_KEY`: Used for session encryption (keep secret!)
- `JWT_SECRET`: Used for JWT token signing (keep secret!)
- `CORS_ORIGINS`: Comma-separated list of allowed origins

**Security Best Practices:**
- Never commit secrets to version control
- Use strong, random secrets (auto-generated recommended)
- Rotate secrets periodically (quarterly recommended)
- Different secrets for each environment

#### Database Settings

```bash
# PostgreSQL connection
DB_HOST=postgres              # Container name or IP
DB_PORT=5432
DB_NAME=promptforge
DB_USER=promptforge
DB_PASS=auto_generated_password

# PostgreSQL superuser (for administrative tasks)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=auto_generated_password

# Connection pool settings
DB_POOL_SIZE=20              # Max connections in pool
DB_MAX_OVERFLOW=10           # Additional connections allowed
DB_POOL_TIMEOUT=30           # Connection timeout (seconds)
DB_POOL_RECYCLE=3600        # Recycle connections after (seconds)
```

**Tuning Guidelines:**
- Small deployment (< 100 users): POOL_SIZE=10
- Medium deployment (100-500 users): POOL_SIZE=20
- Large deployment (500+ users): POOL_SIZE=50+
- Set MAX_OVERFLOW to 50% of POOL_SIZE

#### Redis Settings

```bash
# Redis connection
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=auto_generated_password
REDIS_DB=0                   # Database number (0-15)

# Redis Sentinel (for HA)
REDIS_SENTINEL_HOSTS=redis-sentinel-1:26379,redis-sentinel-2:26379,redis-sentinel-3:26379
REDIS_SENTINEL_MASTER=mymaster

# Cache settings
REDIS_CACHE_TTL=3600        # Default cache TTL (seconds)
REDIS_MAX_CONNECTIONS=50
```

**Tuning Guidelines:**
- Increase MAX_CONNECTIONS for high-traffic sites
- Adjust CACHE_TTL based on data freshness requirements
- Use Sentinel for production HA deployments

#### Email Settings

```bash
# SMTP configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587                # TLS port (or 465 for SSL)
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_USE_TLS=true
SMTP_FROM_EMAIL=noreply@promptforge.io
SMTP_FROM_NAME=PromptForge

# Email features
EMAIL_VERIFICATION_REQUIRED=false
PASSWORD_RESET_ENABLED=true
```

**Common SMTP Providers:**

**Gmail:**
```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USE_TLS=true
# Requires App Password (not regular password)
```

**SendGrid:**
```bash
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=your_sendgrid_api_key
```

**Amazon SES:**
```bash
SMTP_HOST=email-smtp.us-east-1.amazonaws.com
SMTP_PORT=587
SMTP_USERNAME=your_ses_smtp_username
SMTP_PASSWORD=your_ses_smtp_password
```

**Mailgun:**
```bash
SMTP_HOST=smtp.mailgun.org
SMTP_PORT=587
SMTP_USERNAME=postmaster@your-domain.com
SMTP_PASSWORD=your_mailgun_password
```

#### File Storage Settings

```bash
# Upload configuration
UPLOAD_DIR=/app/uploads
MAX_UPLOAD_SIZE=10485760      # 10MB in bytes
ALLOWED_EXTENSIONS=.txt,.pdf,.doc,.docx,.jpg,.png

# Storage backend
STORAGE_BACKEND=local          # Options: local, s3
# For S3:
# S3_BUCKET=promptforge-uploads
# S3_REGION=us-east-1
# S3_ACCESS_KEY=your_key
# S3_SECRET_KEY=your_secret
```

#### Logging Settings

```bash
# Logging configuration
LOG_LEVEL=INFO                 # DEBUG, INFO, WARNING, ERROR, CRITICAL
LOG_FORMAT=json               # json or text
LOG_FILE=/var/log/promptforge/app.log
LOG_MAX_SIZE=100M
LOG_BACKUP_COUNT=10
```

**Log Levels:**
- `DEBUG`: All messages (development only)
- `INFO`: General information (recommended for production)
- `WARNING`: Warning messages only
- `ERROR`: Error messages only
- `CRITICAL`: Critical errors only

#### Session Settings

```bash
# Session configuration
SESSION_LIFETIME=86400         # 24 hours in seconds
SESSION_COOKIE_NAME=promptforge_session
SESSION_COOKIE_SECURE=true    # HTTPS only
SESSION_COOKIE_HTTPONLY=true
SESSION_COOKIE_SAMESITE=Lax
```

**Security Notes:**
- Always set COOKIE_SECURE=true in production with HTTPS
- HTTPONLY prevents JavaScript access (XSS protection)
- SAMESITE provides CSRF protection

#### Rate Limiting

```bash
# Rate limiting
RATE_LIMIT_ENABLED=true
RATE_LIMIT_PER_MINUTE=60
RATE_LIMIT_PER_HOUR=1000
RATE_LIMIT_PER_DAY=10000

# IP whitelist (optional)
RATE_LIMIT_WHITELIST=127.0.0.1,10.0.0.0/8
```

### Monitoring Configuration (.env.monitoring)

```bash
# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=auto_generated
GRAFANA_PORT=3000

# Prometheus
PROMETHEUS_PORT=9090
PROMETHEUS_RETENTION=30d

# Alert Manager
ALERTMANAGER_PORT=9093
SMTP_HOST=smtp.gmail.com
ALERT_EMAIL_FROM=alerts@promptforge.io
ALERT_EMAIL_CRITICAL=admin@promptforge.io

# Slack (optional)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Loki
LOKI_PORT=3100
LOKI_RETENTION=720h          # 30 days
```

### Backup Configuration (.env.backup)

```bash
# Database credentials
DB_PASS=your_db_password
POSTGRES_PASSWORD=your_postgres_password

# Encryption
GPG_RECIPIENT=admin@promptforge.io

# Off-site backup
REMOTE_USER=backup
REMOTE_HOST=backup.example.com
REMOTE_PATH=/backups/promptforge

# Retention
RETENTION_DAYS=30

# Email notifications
NOTIFY_EMAIL=admin@promptforge.io
```

---

## SSL/TLS Configuration

### SSL Certificate Paths

Certificates are stored in `ssl/` directory:

```
ssl/
├── certs/
│   ├── server.crt          # Server certificate
│   └── fullchain.pem       # Certificate chain
├── private/
│   └── server.key          # Private key
└── dhparam.pem            # DH parameters
```

### Nginx SSL Configuration

Edit `nginx/nginx.conf` for SSL settings:

```nginx
# SSL Configuration
ssl_certificate /etc/nginx/ssl/certs/fullchain.pem;
ssl_certificate_key /etc/nginx/ssl/private/server.key;
ssl_dhparam /etc/nginx/ssl/dhparam.pem;

# SSL Protocols and Ciphers
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
ssl_prefer_server_ciphers off;

# SSL Session
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;

# HSTS (optional but recommended)
add_header Strict-Transport-Security "max-age=63072000" always;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/nginx/ssl/certs/fullchain.pem;
```

### Let's Encrypt Auto-Renewal

Automatically configured during setup. Verify with:

```bash
# Check renewal timer
sudo systemctl status certbot.timer

# Test renewal
sudo certbot renew --dry-run

# View certificate info
sudo certbot certificates
```

Manual renewal if needed:

```bash
sudo certbot renew
sudo docker-compose restart nginx
```

### Custom Certificate Installation

```bash
# Copy certificates
sudo cp your-cert.crt ssl/certs/server.crt
sudo cp your-key.key ssl/private/server.key
sudo cp ca-bundle.crt ssl/certs/ca-bundle.crt

# Create full chain
sudo cat ssl/certs/server.crt ssl/certs/ca-bundle.crt > ssl/certs/fullchain.pem

# Set permissions
sudo chmod 644 ssl/certs/*
sudo chmod 600 ssl/private/server.key

# Reload Nginx
docker-compose restart nginx
```

---

## Database Configuration

### PostgreSQL Tuning

Edit `database/config/postgresql.conf`:

```ini
# Memory Settings (adjust based on available RAM)
shared_buffers = 2GB              # 25% of RAM
effective_cache_size = 4GB        # 50% of RAM
maintenance_work_mem = 512MB
work_mem = 16MB

# Connections
max_connections = 100
superuser_reserved_connections = 3

# WAL Settings
wal_level = replica              # For replication
max_wal_senders = 10
wal_keep_size = 1GB

# Checkpoints
checkpoint_completion_target = 0.9
checkpoint_timeout = 15min

# Query Planner
random_page_cost = 1.1           # SSD optimization
effective_io_concurrency = 200

# Logging
log_min_duration_statement = 1000  # Log slow queries (>1s)
log_connections = on
log_disconnections = on
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
```

**Memory Tuning Guidelines:**

**For 8 GB RAM:**
```ini
shared_buffers = 2GB
effective_cache_size = 4GB
maintenance_work_mem = 512MB
work_mem = 16MB
```

**For 16 GB RAM:**
```ini
shared_buffers = 4GB
effective_cache_size = 8GB
maintenance_work_mem = 1GB
work_mem = 32MB
```

**For 32 GB RAM:**
```ini
shared_buffers = 8GB
effective_cache_size = 16GB
maintenance_work_mem = 2GB
work_mem = 64MB
```

### Database Connection Pooling

Using PgBouncer (optional but recommended for high traffic):

```ini
# pgbouncer.ini
[databases]
promptforge = host=postgres port=5432 dbname=promptforge

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
min_pool_size = 5
reserve_pool_size = 5
reserve_pool_timeout = 3
```

Enable in docker-compose.yml:

```yaml
pgbouncer:
  image: pgbouncer/pgbouncer:latest
  environment:
    - DATABASES_HOST=postgres
    - DATABASES_PORT=5432
    - DATABASES_DBNAME=promptforge
    - POOL_MODE=transaction
    - MAX_CLIENT_CONN=1000
    - DEFAULT_POOL_SIZE=25
```

---

## Redis Configuration

### Redis Tuning

Edit `redis/redis.conf` (if using custom config):

```conf
# Memory
maxmemory 2gb
maxmemory-policy allkeys-lru

# Persistence (optional for cache)
save 900 1
save 300 10
save 60 10000

# Performance
tcp-backlog 511
timeout 0
tcp-keepalive 300

# Clients
maxclients 10000

# Security
requirepass your_redis_password

# Slow log
slowlog-log-slower-than 10000
slowlog-max-len 128
```

**Memory Policy Options:**
- `noeviction`: Return error when memory limit reached
- `allkeys-lru`: Evict least recently used keys
- `allkeys-random`: Evict random keys
- `volatile-lru`: Evict LRU among keys with TTL set
- `volatile-ttl`: Evict keys with nearest TTL

**Recommended:** `allkeys-lru` for cache use case

---

## Email Configuration

### Gmail Setup

1. Enable 2-Factor Authentication on Gmail
2. Generate App Password:
   - Go to Google Account Settings
   - Security → 2-Step Verification → App passwords
   - Generate password for "Mail" on "Other"

3. Configure in .env:
```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=generated-app-password
SMTP_USE_TLS=true
SMTP_FROM_EMAIL=noreply@yourdomain.com
```

### Testing Email Configuration

```bash
# Test email sending
docker-compose exec backend python -c "
from app.utils.email import send_email
send_email(
    to='test@example.com',
    subject='Test Email',
    body='This is a test email from PromptForge'
)
print('Email sent successfully!')
"
```

---

## API Keys & External Services

### Gemini API Configuration

```bash
# In .env
GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_MODEL=gemini-pro
GEMINI_TEMPERATURE=0.7
GEMINI_MAX_TOKENS=2048
```

Get API key from: https://makersuite.google.com/app/apikey

### Rate Limiting for External APIs

```bash
# Gemini API rate limits (free tier)
GEMINI_RATE_LIMIT_PER_MINUTE=60
GEMINI_RATE_LIMIT_PER_DAY=1500

# Enable request queuing
GEMINI_ENABLE_QUEUE=true
GEMINI_QUEUE_MAX_SIZE=100
```

---

## Performance Tuning

### Application Performance

```bash
# Worker processes
BACKEND_WORKERS=4               # CPU cores * 2
BACKEND_THREADS=2
BACKEND_WORKER_CLASS=uvicorn.workers.UvicornWorker

# Frontend
FRONTEND_NODE_OPTIONS=--max-old-space-size=4096

# Request timeouts
REQUEST_TIMEOUT=30
KEEPALIVE_TIMEOUT=5
```

### Nginx Performance

```nginx
# Worker processes
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    # Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript;

    # Buffers
    client_body_buffer_size 128k;
    client_max_body_size 10m;

    # Timeouts
    keepalive_timeout 65;
    send_timeout 30;

    # Cache
    open_file_cache max=1000 inactive=20s;
    open_file_cache_valid 30s;
}
```

### Docker Performance

```yaml
# In docker-compose.yml
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

## Security Configuration

### Firewall Rules

```bash
# UFW configuration
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### fail2ban Configuration

Create `/etc/fail2ban/jail.local`:

```ini
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5
```

### Security Headers

In nginx.conf:

```nginx
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
```

---

## High Availability Configuration

### Load Balancer Configuration

Edit `ha/nginx/load-balancer.conf`:

```nginx
upstream backend_api {
    least_conn;
    server backend1:8000 max_fails=3 fail_timeout=30s;
    server backend2:8000 max_fails=3 fail_timeout=30s;
    server backend3:8000 max_fails=3 fail_timeout=30s;

    keepalive 32;
}

upstream frontend_servers {
    server frontend1:3000;
    server frontend2:3000;
}
```

### PostgreSQL Replication

Primary configuration in `ha/postgresql/primary/postgresql.conf`:

```ini
wal_level = replica
max_wal_senders = 10
wal_keep_size = 1GB
hot_standby = on
```

### Redis Sentinel

Edit `ha/redis/sentinel.conf`:

```conf
sentinel monitor mymaster redis-master 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel parallel-syncs mymaster 1
sentinel failover-timeout mymaster 10000
```

---

## Configuration Checklist

- [ ] Environment variables reviewed and updated
- [ ] SSL certificates installed and verified
- [ ] Database connection tested
- [ ] Redis connection tested
- [ ] Email configuration tested (if applicable)
- [ ] API keys configured (if applicable)
- [ ] Performance tuning applied
- [ ] Security headers configured
- [ ] Firewall rules applied
- [ ] Monitoring configured
- [ ] Backup configuration verified
- [ ] High availability configured (if applicable)

---

**Document Version:** 1.0
**Last Updated:** 2025-01-15

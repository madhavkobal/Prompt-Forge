# PromptForge Deployment Guide

Complete deployment automation documentation for PromptForge.

## Table of Contents

- [Quick Start](#quick-start)
- [Initial Deployment](#initial-deployment)
- [Updates & Maintenance](#updates--maintenance)
- [Monitoring](#monitoring)
- [Backup & Restore](#backup--restore)
- [Makefile Commands](#makefile-commands)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

### Using Makefile (Recommended)

```bash
# Complete installation and deployment
make init          # Install dependencies and setup
make ssl           # Setup SSL certificates
make deploy        # Deploy application

# Or use the all-in-one command
make install && make setup && make deploy
```

### Manual Deployment

```bash
# 1. Install dependencies
sudo ./deploy/initial/install.sh

# 2. Initial setup
sudo ./deploy/initial/setup.sh

# 3. SSL certificates (optional for dev)
sudo ./deploy/initial/init-ssl.sh --self-signed

# 4. Deploy
sudo ./deploy/initial/first-deploy.sh
```

---

## Initial Deployment

### Prerequisites

- Ubuntu 22.04 LTS or Debian 11+ (recommended)
- Minimum 4GB RAM, 2 CPU cores
- 20GB free disk space
- Root or sudo access

### Step-by-Step Deployment

#### 1. Install Dependencies

```bash
sudo ./deploy/initial/install.sh
```

**What it installs:**
- Docker & Docker Compose
- PostgreSQL client tools
- Python 3 & pip
- Node.js & npm
- Redis tools
- System utilities (git, curl, wget, etc.)
- Security tools (ufw, fail2ban, certbot)
- Monitoring tools (htop, sysstat, etc.)

**Options:**
- `--skip-docker`: Skip Docker installation
- `--skip-node`: Skip Node.js installation
- `--minimal`: Skip optional tools

#### 2. Initial Setup

```bash
sudo ./deploy/initial/setup.sh [--prod|--dev]
```

**What it does:**
- Creates directory structure
- Sets proper permissions
- Generates `.env` configuration
- Creates secure passwords
- Sets up systemd service
- Initializes Git repository

**Generated files:**
- `.env` - Main configuration
- `.env.monitoring` - Monitoring configuration
- `.env.backup` - Backup configuration
- `/etc/promptforge/credentials.txt` - Secure credentials storage

#### 3. SSL Certificate Setup

```bash
sudo ./deploy/initial/init-ssl.sh [OPTIONS]
```

**Options:**
- `--self-signed`: Generate self-signed certificate (development)
- `--letsencrypt --domain=example.com --email=admin@example.com`: Let's Encrypt (production)
- `--custom`: Install custom certificate

**Examples:**

```bash
# Development (self-signed)
sudo ./deploy/initial/init-ssl.sh --self-signed

# Production (Let's Encrypt)
sudo ./deploy/initial/init-ssl.sh --letsencrypt \
  --domain=promptforge.example.com \
  --email=admin@example.com

# Custom certificate
sudo ./deploy/initial/init-ssl.sh --custom
```

#### 4. First Deployment

```bash
sudo ./deploy/initial/first-deploy.sh [OPTIONS]
```

**Options:**
- `--skip-build`: Skip building Docker images
- `--skip-db-init`: Skip database initialization
- `--ha`: Enable High Availability mode
- `--monitoring`: Enable monitoring stack

**What it does:**
- Validates prerequisites
- Builds Docker images
- Initializes database
- Starts all services
- Runs health checks
- Sets up automated backups

---

## Updates & Maintenance

### Application Updates

#### Zero-Downtime Update

```bash
sudo ./deploy/update/update-app.sh [OPTIONS]
```

**Options:**
- `--version=<tag>`: Update to specific version
- `--skip-backup`: Skip backup before update
- `--force`: Force update even with uncommitted changes

**Process:**
1. Backs up current state
2. Pulls latest code
3. Builds new Docker images
4. Runs database migrations
5. Rolling update of services
6. Health checks
7. Automatic rollback on failure

**Example:**

```bash
# Update to latest
sudo ./deploy/update/update-app.sh

# Update to specific version
sudo ./deploy/update/update-app.sh --version=v1.2.3

# Using Makefile
make update
```

#### Configuration Updates

```bash
./deploy/update/update-config.sh
```

**What it does:**
- Backs up current `.env`
- Reloads configuration in running containers
- Restarts affected services

#### Service Restart

```bash
./deploy/update/restart-services.sh [service_name]
```

**Examples:**

```bash
# Restart all services
./deploy/update/restart-services.sh

# Restart specific service
./deploy/update/restart-services.sh backend

# Using Makefile
make restart
```

### Rollback

```bash
./deploy/update/rollback.sh [version]
```

**Process:**
1. Shows available versions
2. Backs up current database
3. Checks out specified version
4. Rebuilds and restarts services
5. Health checks

**Example:**

```bash
# Interactive rollback
./deploy/update/rollback.sh

# Rollback to specific version
./deploy/update/rollback.sh v1.1.0

# Using Makefile
make rollback
```

---

## Monitoring

### Health Checks

#### Comprehensive Health Check

```bash
./deploy/monitoring/check-health.sh
```

**Checks:**
- ✓ Container status
- ✓ Backend API health
- ✓ Frontend accessibility
- ✓ Database connection
- ✓ Redis connectivity

**Using Makefile:**

```bash
make health
```

#### Disk Space Monitoring

```bash
./deploy/monitoring/check-disk-space.sh
```

**Monitors:**
- Root filesystem usage
- Backup directory size
- Docker disk usage

**Using Makefile:**

```bash
make disk
```

#### Memory Usage

```bash
./deploy/monitoring/check-memory.sh
```

**Shows:**
- System memory usage
- Container memory usage
- Memory percentage

**Using Makefile:**

```bash
make memory
```

#### Log Analysis

```bash
./deploy/monitoring/check-logs.sh [lines]
```

**Analyzes:**
- Recent errors
- Recent warnings
- Log summary

**Using Makefile:**

```bash
make logs           # Recent logs
make logs-follow    # Real-time logs
make logs-backend   # Backend logs only
```

### Run All Monitors

```bash
make monitor
```

Runs all monitoring checks (health, disk, memory).

---

## Backup & Restore

### Automated Backups

Backups run automatically via cron:
- **Daily database backup:** 1:00 AM
- **Weekly full backup:** 2:00 AM Sunday
- **Daily verification:** 3:00 AM

### Manual Backups

#### Full System Backup

```bash
./backup/scripts/backup-full.sh [OPTIONS]
```

**Options:**
- `--encrypt`: Encrypt backup with GPG
- `--offsite`: Copy to remote server

**Using Makefile:**

```bash
make backup              # Full backup with encryption and off-site
make backup-db           # Database only
```

#### Database Backup

```bash
./backup/scripts/backup-db.sh [OPTIONS]
```

**Options:**
- `--format=<plain|custom|directory>`: Backup format
- `--encrypt`: Encrypt backup
- `--compress=<0-9>`: Compression level

### Backup Verification

```bash
./backup/scripts/backup-verify.sh <backup_path>
```

**Using Makefile:**

```bash
make verify-backup
```

### Restore Procedures

#### Full System Restore

```bash
./backup/restore/restore-full.sh --backup=<path>
```

**Using Makefile:**

```bash
make restore
```

#### Database Restore

```bash
./backup/restore/restore-db.sh --backup=<path>
```

**Options:**
- `--target-db=<name>`: Restore to different database
- `--drop-existing`: Drop existing database
- `--dry-run`: Test without restoring

**Using Makefile:**

```bash
make restore-db
```

---

## Makefile Commands

### Installation & Setup

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make install` | Install dependencies |
| `make setup` | Run initial setup |
| `make ssl` | Setup SSL certificates |
| `make init` | Install + setup |

### Deployment

| Command | Description |
|---------|-------------|
| `make deploy` | Deploy application |
| `make deploy-ha` | Deploy with HA |
| `make start` | Start services |
| `make stop` | Stop services |
| `make restart` | Restart services |
| `make status` | Show service status |

### Updates

| Command | Description |
|---------|-------------|
| `make update` | Update application |
| `make update-config` | Update configuration |
| `make rollback` | Rollback version |

### Backup & Restore

| Command | Description |
|---------|-------------|
| `make backup` | Full backup |
| `make backup-db` | Database backup |
| `make verify-backup` | Verify backup |
| `make restore` | Restore full system |
| `make restore-db` | Restore database |

### Monitoring

| Command | Description |
|---------|-------------|
| `make monitor` | All health checks |
| `make health` | Application health |
| `make disk` | Disk space |
| `make memory` | Memory usage |
| `make logs` | Recent logs |
| `make logs-follow` | Real-time logs |

### Maintenance

| Command | Description |
|---------|-------------|
| `make clean` | All cleanup tasks |
| `make clean-logs` | Clean logs |
| `make clean-backups` | Clean backups |
| `make clean-docker` | Clean Docker |
| `make vacuum-db` | Database maintenance |

### Database

| Command | Description |
|---------|-------------|
| `make db-shell` | Database shell |
| `make db-backup-now` | Immediate backup |
| `make db-migrations` | Run migrations |

### Utilities

| Command | Description |
|---------|-------------|
| `make info` | System information |
| `make version` | Show version |
| `make env` | Show environment |
| `make build` | Build images |
| `make rebuild` | Rebuild (no cache) |

---

## Maintenance Scripts

### Log Cleanup

```bash
./deploy/maintenance/cleanup-logs.sh [days]
```

Default: 30 days

**Using Makefile:**

```bash
make clean-logs
```

### Backup Cleanup

```bash
./deploy/maintenance/cleanup-backups.sh [days]
```

Default: 30 days

**Using Makefile:**

```bash
make clean-backups
```

### Database Vacuum

```bash
./deploy/maintenance/database-vacuum.sh
```

**Performs:**
- VACUUM ANALYZE
- REINDEX
- Shows database size
- Shows largest tables

**Using Makefile:**

```bash
make vacuum-db
```

### Docker Cleanup

```bash
./deploy/maintenance/docker-cleanup.sh
```

**Removes:**
- Stopped containers
- Unused images
- Unused volumes
- Unused networks

**Using Makefile:**

```bash
make clean-docker
```

---

## Troubleshooting

### Services Won't Start

```bash
# Check logs
make logs

# Check specific service
docker-compose logs backend

# Check container status
make status

# Restart services
make restart
```

### Database Connection Issues

```bash
# Check database health
docker-compose exec postgres pg_isready

# Check database logs
docker-compose logs postgres

# Open database shell
make db-shell
```

### Out of Disk Space

```bash
# Check disk usage
make disk

# Clean up Docker
make clean-docker

# Clean up logs
make clean-logs

# Clean up old backups
make clean-backups
```

### High Memory Usage

```bash
# Check memory
make memory

# Check container stats
docker stats

# Restart memory-heavy services
docker-compose restart backend
```

### SSL Certificate Issues

```bash
# Verify certificate
openssl x509 -in ssl/certs/server.crt -text -noout

# Regenerate certificate
sudo ./deploy/initial/init-ssl.sh --self-signed

# Update Let's Encrypt
sudo certbot renew
```

### Update Failed

```bash
# Check logs
make logs

# Rollback
make rollback

# Restore from backup
make restore
```

---

## Production Checklist

### Before Deployment

- [ ] Update `.env` with production values
- [ ] Configure email settings (SMTP)
- [ ] Set up SSL certificates (Let's Encrypt)
- [ ] Configure off-site backups
- [ ] Set up monitoring alerts
- [ ] Review firewall rules
- [ ] Change default passwords

### After Deployment

- [ ] Run health checks: `make health`
- [ ] Test application access
- [ ] Verify HTTPS/SSL
- [ ] Test backup system: `make backup`
- [ ] Verify monitoring dashboards
- [ ] Test email notifications
- [ ] Document access credentials
- [ ] Train operations team

### Regular Maintenance

**Daily:**
- Review monitoring dashboards
- Check backup logs
- Review application logs

**Weekly:**
- Run full health check: `make monitor`
- Review disk space: `make disk`
- Test backup restoration

**Monthly:**
- Update application: `make update`
- Clean up old backups: `make clean-backups`
- Database maintenance: `make vacuum-db`
- Review security updates

**Quarterly:**
- DR drill: `make test-dr`
- Review and update documentation
- Security audit: `make security-scan`
- Capacity planning review

---

## Environment Variables

See `.env.example` for all available environment variables.

**Critical Variables:**

- `ENVIRONMENT`: prod/dev/staging
- `SECRET_KEY`: Application secret
- `JWT_SECRET`: JWT signing key
- `DB_PASS`: Database password
- `POSTGRES_PASSWORD`: PostgreSQL superuser password
- `REDIS_PASSWORD`: Redis password

---

## Support

- **Documentation**: `/docs`
- **Logs**: `/var/log/promptforge`
- **Backups**: `/var/backups/promptforge`
- **Configuration**: `.env` files

---

**Last Updated:** 2024-01-15
**Version:** 1.0

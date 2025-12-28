# PromptForge Database Management

This directory contains all database management tools, scripts, and configuration for PromptForge on-premises deployments.

## Quick Start

```bash
# 1. Initial database setup
cd database/scripts
./setup-database.sh

# 2. Run migrations
cd ../../backend
./migrate.sh upgrade

# 3. Setup automated backups
crontab -e
# Add: 0 2 * * * /path/to/database/scripts/backup-database.sh --verify --retention 30
```

## Directory Structure

```
database/
├── init/               # Database initialization scripts
│   └── 01-init-database.sql
├── config/             # PostgreSQL configuration examples
│   ├── postgresql.conf.example
│   └── pg_hba.conf.example
├── scripts/            # Management scripts
│   ├── setup-database.sh
│   ├── backup-database.sh
│   ├── restore-database.sh
│   ├── test-migrations.sh
│   └── monitor-database.sh
└── README.md           # This file
```

## Scripts Overview

### setup-database.sh

Initial database setup and configuration.

```bash
./setup-database.sh [--skip-init] [--skip-config]
```

Features:
- Creates database and users
- Installs extensions
- Sets up schemas
- Configures permissions
- Applies optimizations

### backup-database.sh

Automated database backups with retention.

```bash
./backup-database.sh [--verify] [--external] [--retention DAYS]
```

Features:
- Full pg_dump backups
- Gzip compression
- SHA256 checksums
- Backup verification
- External storage (S3, NFS)
- 30-day retention (default)

### restore-database.sh

Safe database restoration with verification.

```bash
./restore-database.sh <backup_file> [--force] [--verify]
```

Features:
- Pre-restore backup
- Connection termination
- Database recreation
- Restore verification
- Safety confirmations

### test-migrations.sh

Test migrations before production deployment.

```bash
./test-migrations.sh [--cleanup]
```

Features:
- Creates test database
- Applies migrations
- Tests rollback
- Verifies integrity
- Compares with production

### monitor-database.sh

Database health and performance monitoring.

```bash
./monitor-database.sh [--health] [--metrics] [--slow-queries] [--all]
```

Features:
- Health checks
- Connection monitoring
- Performance metrics
- Slow query detection
- Disk space monitoring

## Common Tasks

### Initial Setup

```bash
# Setup database
./scripts/setup-database.sh

# Apply migrations
cd ../backend && ./migrate.sh upgrade
```

### Daily Operations

```bash
# Backup database
./scripts/backup-database.sh --verify

# Monitor health
./scripts/monitor-database.sh --health

# Check slow queries
./scripts/monitor-database.sh --slow-queries
```

### Migrations

```bash
# Test migration
./scripts/test-migrations.sh --cleanup

# Apply migration
cd ../backend && ./migrate.sh upgrade

# Rollback if needed
cd ../backend && ./migrate.sh downgrade 1
```

### Troubleshooting

```bash
# Full health check
./scripts/monitor-database.sh

# Check connections
./scripts/monitor-database.sh --connections

# Restore from backup
./scripts/restore-database.sh /path/to/backup.sql.gz
```

## Configuration

### PostgreSQL Optimization

Copy and customize configuration:

```bash
sudo cp config/postgresql.conf.example /etc/postgresql/*/main/postgresql.conf
sudo systemctl restart postgresql
```

### Access Control

Configure pg_hba.conf:

```bash
sudo cp config/pg_hba.conf.example /etc/postgresql/*/main/pg_hba.conf
sudo systemctl reload postgresql
```

### Environment Variables

Set in `.env.production`:

```bash
DATABASE_URL=postgresql://user:password@host:5432/database
DB_APP_PASSWORD=secure_password
DB_READONLY_PASSWORD=secure_password
DB_BACKUP_PASSWORD=secure_password
```

## Monitoring

### Health Checks

```bash
# Quick health check
./scripts/monitor-database.sh --health

# Full monitoring
./scripts/monitor-database.sh --all

# JSON output for monitoring tools
./scripts/monitor-database.sh --json
```

### Automated Monitoring

Setup cron jobs:

```bash
crontab -e

# Health check every hour
0 * * * * /path/to/scripts/monitor-database.sh --health >> /var/log/db-health.log

# Daily backup at 2 AM
0 2 * * * /path/to/scripts/backup-database.sh --verify --retention 30
```

## Documentation

For complete documentation, see:

- **[Database Management Guide](../docs/database-management.md)** - Comprehensive guide
- **[Deployment Guide](../docs/deployment-onprem.md)** - On-premises deployment
- **[Migrations README](../backend/alembic/README_MIGRATIONS.md)** - Migration guide

## Support

For issues or questions:

- Check logs: `/var/log/postgresql/postgresql-*-main.log`
- Review documentation in `docs/database-management.md`
- GitHub Issues: https://github.com/madhavkobal/Prompt-Forge/issues

---

**Note**: Always test scripts in a non-production environment first!

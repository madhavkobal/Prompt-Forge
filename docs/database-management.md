# PromptForge Database Management Guide

Comprehensive guide for managing the PostgreSQL database in on-premises deployments.

## Table of Contents

1. [Overview](#overview)
2. [Database Setup](#database-setup)
3. [Migration Management](#migration-management)
4. [Backup and Recovery](#backup-and-recovery)
5. [Monitoring and Performance](#monitoring-and-performance)
6. [Maintenance](#maintenance)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

---

## Overview

PromptForge uses PostgreSQL as its primary database with the following components:

- **Database**: PostgreSQL 12+ (14+ recommended)
- **ORM**: SQLAlchemy
- **Migrations**: Alembic
- **Connection Pooling**: SQLAlchemy connection pool
- **Backup**: pg_dump with compression
- **Monitoring**: pg_stat_statements, custom health checks

### Architecture

```
┌─────────────────────────────────────────────────┐
│                  Application                     │
│              (FastAPI + SQLAlchemy)              │
└──────────────────┬──────────────────────────────┘
                   │
                   │ Connection Pool
                   │ (5-20 connections)
                   │
┌──────────────────▼──────────────────────────────┐
│              PostgreSQL Database                 │
│  ┌───────────┐  ┌───────────┐  ┌──────────────┐│
│  │  public   │  │    app    │  │    audit     ││
│  │  schema   │  │  schema   │  │   schema     ││
│  └───────────┘  └───────────┘  └──────────────┘│
└─────────────────────────────────────────────────┘
```

### Database Users

- **promptforge_app**: Application user (read/write access)
- **promptforge_readonly**: Read-only user (for reporting/analytics)
- **promptforge_backup**: Backup user (read access for backups)
- **postgres**: Superuser (administrative tasks only)

---

## Database Setup

### Initial Setup

Run the automated setup script:

```bash
cd database/scripts
./setup-database.sh
```

This script will:
1. ✓ Create the `promptforge_prod` database
2. ✓ Install required extensions (uuid-ossp, pgcrypto, pg_stat_statements, etc.)
3. ✓ Create database users with appropriate permissions
4. ✓ Set up schemas (public, app, audit)
5. ✓ Configure audit logging
6. ✓ Apply performance optimizations

### Manual Setup

If you prefer manual setup:

```bash
# 1. Create database and users
sudo -u postgres psql -f database/init/01-init-database.sql

# 2. Update passwords
sudo -u postgres psql -c "ALTER USER promptforge_app WITH PASSWORD 'your_secure_password';"

# 3. Configure access control
sudo cp database/config/pg_hba.conf.example /etc/postgresql/*/main/pg_hba.conf
sudo systemctl reload postgresql

# 4. Apply optimizations
sudo cp database/config/postgresql.conf.example /etc/postgresql/*/main/postgresql.conf
sudo systemctl restart postgresql
```

### Configuration Files

#### postgresql.conf

Optimized settings for moderate workload (8GB RAM, 4 CPU cores):

```ini
# Memory
shared_buffers = 2GB
work_mem = 16MB
maintenance_work_mem = 512MB
effective_cache_size = 4GB

# WAL
wal_buffers = 16MB
min_wal_size = 1GB
max_wal_size = 4GB

# Query Planner
random_page_cost = 1.1  # For SSD
effective_io_concurrency = 8

# Autovacuum
autovacuum = on
autovacuum_vacuum_scale_factor = 0.1
autovacuum_analyze_scale_factor = 0.05

# Logging
log_min_duration_statement = 1000  # Log queries > 1s
log_checkpoints = on
log_connections = on
```

#### pg_hba.conf

Access control configuration:

```
# Local connections
local   all             postgres                                peer
local   promptforge_prod    promptforge_app                     scram-sha-256

# Docker network
host    promptforge_prod    promptforge_app     172.25.0.0/16   scram-sha-256

# Internal network (adjust IP range)
host    promptforge_prod    promptforge_app     192.168.1.0/24  scram-sha-256
```

### Environment Variables

```bash
# .env.production
DATABASE_URL=postgresql://promptforge_app:password@localhost:5432/promptforge_prod
DB_APP_PASSWORD=secure_app_password
DB_READONLY_PASSWORD=secure_readonly_password
DB_BACKUP_PASSWORD=secure_backup_password
```

---

## Migration Management

### Overview

Database schema changes are managed using **Alembic** migrations.

### Migration Workflow

#### 1. Creating Migrations

```bash
cd backend

# Auto-generate migration from model changes
./migrate.sh create "add user preferences table"

# Or manually
alembic revision -m "add user preferences table"
```

#### 2. Review Migration

Always review auto-generated migrations:

```bash
# View the generated migration file
cat alembic/versions/xxxx_add_user_preferences_table.py
```

Edit as needed to ensure:
- ✓ Both upgrade() and downgrade() are implemented
- ✓ Data transformations are correct
- ✓ Indexes are created/dropped appropriately

#### 3. Test Migration

Test migrations before applying to production:

```bash
cd database/scripts

# Run full migration test suite
./test-migrations.sh --cleanup

# This will:
# - Create test database
# - Apply all migrations
# - Test rollback
# - Verify data integrity
# - Compare with production schema
```

#### 4. Apply to Production

```bash
cd backend

# Check pending migrations
./migrate.sh check

# Apply migrations
./migrate.sh upgrade

# Verify current version
./migrate.sh current
```

### Migration Best Practices

1. **Always test migrations** on a copy of production data
2. **Backup before migrating** - automatic in deployment scripts
3. **Run during maintenance windows** for large changes
4. **Keep migrations atomic** - one logical change per migration
5. **Write reversible migrations** - always implement downgrade()

### Rollback Procedure

If a migration causes issues:

```bash
# 1. Stop the application
docker-compose -f docker-compose.prod.yml stop backend

# 2. Rollback the migration
cd backend
./migrate.sh downgrade 1

# 3. Verify database state
./migrate.sh current

# 4. Redeploy previous application version
git checkout <previous_commit>
./deploy.sh --no-migrations

# 5. Restart application
docker-compose -f docker-compose.prod.yml up -d
```

### Common Migration Scenarios

#### Adding a New Column

```python
def upgrade():
    op.add_column('users', sa.Column('phone', sa.String(20), nullable=True))

def downgrade():
    op.drop_column('users', 'phone')
```

#### Creating an Index

```python
def upgrade():
    op.create_index('idx_users_email', 'users', ['email'])

def downgrade():
    op.drop_index('idx_users_email', table_name='users')
```

#### Data Migration

```python
from sqlalchemy import orm
from app.models import User

def upgrade():
    # Add column
    op.add_column('users', sa.Column('full_name', sa.String(200)))

    # Migrate data
    bind = op.get_bind()
    session = orm.Session(bind=bind)

    for user in session.query(User).all():
        user.full_name = f"{user.first_name} {user.last_name}"

    session.commit()

def downgrade():
    op.drop_column('users', 'full_name')
```

---

## Backup and Recovery

### Automated Backups

#### Setup Daily Backups

```bash
# Run backup manually
cd database/scripts
./backup-database.sh --verify --external

# Setup cron for daily backups
crontab -e

# Add:
0 2 * * * /path/to/database/scripts/backup-database.sh --verify --retention 30
```

#### Backup Features

- ✓ Full database dumps (pg_dump)
- ✓ Schema-only backups
- ✓ Gzip compression
- ✓ SHA256 checksums
- ✓ Backup verification
- ✓ 30-day retention (configurable)
- ✓ External storage (S3, NFS)
- ✓ Point-in-time recovery (PITR) setup

### Backup Types

#### 1. Full Backup (Recommended)

```bash
./backup-database.sh --verify

# Output:
# /var/backups/promptforge/database/promptforge_prod_full_20240115_020000.sql.gz
# /var/backups/promptforge/database/promptforge_prod_full_20240115_020000.sql.gz.sha256
# /var/backups/promptforge/database/promptforge_prod_full_20240115_020000.sql.gz.meta
```

#### 2. Schema-Only Backup

```bash
# Automatically created with full backups
# Useful for setting up development environments
```

#### 3. Point-in-Time Recovery (PITR)

Enable WAL archiving in postgresql.conf:

```ini
wal_level = replica
archive_mode = on
archive_command = 'test ! -f /var/backups/promptforge/database/wal_archive/%f && cp %p /var/backups/promptforge/database/wal_archive/%f'
archive_timeout = 300  # 5 minutes
```

### Backup to External Storage

#### S3-Compatible Storage

```bash
# Install AWS CLI
apt-get install awscli

# Configure credentials
aws configure

# Run backup with S3 upload
./backup-database.sh --external --s3-bucket my-backup-bucket
```

#### NFS Storage

```bash
# Mount NFS share
sudo mount -t nfs 192.168.1.100:/backups /mnt/backups

# Run backup with NFS copy
./backup-database.sh --external --nfs-path /mnt/backups
```

### Backup Verification

```bash
# Verify checksum
sha256sum -c promptforge_prod_full_20240115_020000.sql.gz.sha256

# Test backup integrity
gzip -t promptforge_prod_full_20240115_020000.sql.gz

# Test restore (creates temporary database)
VERIFY_RESTORE=true ./backup-database.sh --verify
```

### Restore Procedures

#### Full Database Restore

```bash
cd database/scripts

# Restore from backup
./restore-database.sh /var/backups/promptforge/database/promptforge_prod_full_20240115_020000.sql.gz

# Follow prompts to confirm
# - Enter 'yes' to proceed
# - Type database name to confirm
```

The script will:
1. ✓ Validate backup file
2. ✓ Create pre-restore backup
3. ✓ Terminate active connections
4. ✓ Drop and recreate database
5. ✓ Restore from backup
6. ✓ Verify restore
7. ✓ Run ANALYZE for query optimization

#### Point-in-Time Recovery

```bash
# 1. Restore base backup
./restore-database.sh <base_backup.sql.gz>

# 2. Create recovery.conf
cat > /var/lib/postgresql/14/main/recovery.conf <<EOF
restore_command = 'cp /var/backups/promptforge/database/wal_archive/%f %p'
recovery_target_time = '2024-01-15 14:30:00'
EOF

# 3. Restart PostgreSQL
sudo systemctl restart postgresql
```

#### Selective Table Restore

```bash
# Extract specific table from backup
gunzip -c backup.sql.gz | grep -A 10000 "CREATE TABLE users" > users_table.sql

# Restore just that table
psql -U promptforge_app -d promptforge_prod -f users_table.sql
```

---

## Monitoring and Performance

### Health Monitoring

#### Run Health Checks

```bash
cd database/scripts

# Full health check
./monitor-database.sh

# Specific checks
./monitor-database.sh --health
./monitor-database.sh --connections
./monitor-database.sh --metrics
./monitor-database.sh --slow-queries
./monitor-database.sh --disk
```

#### Health Check Output

```
✓ Database is accessible
✓ No long-running transactions
✓ No problematic idle connections
✓ Cache hit ratio: 98.5% (good)
✓ No table bloat detected
```

### Connection Monitoring

```bash
# View active connections
./monitor-database.sh --connections
```

Shows:
- Total connections by state (active, idle, idle in transaction)
- Connections per user
- Active queries with duration
- Waiting queries

### Performance Metrics

#### Key Metrics to Monitor

1. **Cache Hit Ratio** (should be > 90%)
```sql
SELECT ROUND(100.0 * sum(blks_hit) / NULLIF(sum(blks_hit) + sum(blks_read), 0), 2) AS cache_hit_ratio
FROM pg_stat_database;
```

2. **Database Size Growth**
```sql
SELECT pg_size_pretty(pg_database_size(current_database()));
```

3. **Table Bloat**
```sql
SELECT schemaname || '.' || tablename AS table,
       n_dead_tup AS dead_tuples,
       ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup, 0), 2) AS bloat_ratio
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
```

4. **Index Usage**
```sql
SELECT schemaname || '.' || tablename AS table,
       indexrelname AS index,
       idx_scan AS scans
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Slow Query Detection

#### Enable pg_stat_statements

```sql
-- In postgresql.conf
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.max = 10000
pg_stat_statements.track = all

-- Restart PostgreSQL
sudo systemctl restart postgresql

-- Create extension
CREATE EXTENSION pg_stat_statements;
```

#### Find Slow Queries

```bash
./monitor-database.sh --slow-queries
```

Or manually:

```sql
SELECT
    ROUND(total_exec_time::numeric, 2) AS total_time_ms,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS mean_time_ms,
    query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

### Automated Monitoring

#### Setup Monitoring Cron Job

```bash
crontab -e

# Run monitoring every hour, alert on issues
0 * * * * /path/to/database/scripts/monitor-database.sh --health >> /var/log/db-health.log 2>&1
```

#### Integration with Monitoring Tools

**Prometheus + Grafana**:
- Install [postgres_exporter](https://github.com/prometheus-community/postgres_exporter)
- Configure metrics endpoint
- Import Grafana dashboard

**Nagios/Icinga**:
- Use monitoring script with --json flag
- Parse output for alerts

---

## Maintenance

### Routine Maintenance Tasks

#### Daily
- ✓ Monitor disk space
- ✓ Check backup completion
- ✓ Review error logs

#### Weekly
- ✓ Review slow queries
- ✓ Check for table bloat
- ✓ Verify backup restoration (test one backup)

#### Monthly
- ✓ Analyze growth trends
- ✓ Review and optimize indexes
- ✓ Update statistics
- ✓ Clean up old backups

### Vacuum and Analyze

#### Manual VACUUM

```bash
# Full database vacuum
psql -U promptforge_app -d promptforge_prod -c "VACUUM VERBOSE;"

# Aggressive vacuum (slower, more thorough)
psql -U promptforge_app -d promptforge_prod -c "VACUUM FULL VERBOSE;"

# Specific table
psql -U promptforge_app -d promptforge_prod -c "VACUUM VERBOSE users;"
```

#### ANALYZE Statistics

```bash
# Update query planner statistics
psql -U promptforge_app -d promptforge_prod -c "ANALYZE;"

# Specific table
psql -U promptforge_app -d promptforge_prod -c "ANALYZE users;"
```

#### Autovacuum Tuning

Monitor autovacuum effectiveness:

```sql
SELECT schemaname, tablename,
       last_vacuum, last_autovacuum,
       n_dead_tup, n_live_tup
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

Adjust autovacuum settings in postgresql.conf if needed.

### Index Maintenance

#### Rebuild Indexes

```sql
-- Rebuild all indexes on a table
REINDEX TABLE users;

-- Rebuild specific index
REINDEX INDEX idx_users_email;

-- Rebuild all indexes in database (slow!)
REINDEX DATABASE promptforge_prod;
```

#### Remove Unused Indexes

```sql
-- Find unused indexes
SELECT schemaname || '.' || tablename AS table,
       indexrelname AS index,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelname NOT LIKE '%_pkey'  -- Keep primary keys
ORDER BY pg_relation_size(indexrelid) DESC;

-- Drop unused index
DROP INDEX idx_unused_index;
```

### Log Management

#### Configure Log Rotation

```bash
# /etc/logrotate.d/postgresql
/var/log/postgresql/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    missingok
    su postgres postgres
    postrotate
        /usr/bin/systemctl reload postgresql
    endscript
}
```

---

## Troubleshooting

### Common Issues

#### 1. Cannot Connect to Database

```bash
# Check if PostgreSQL is running
sudo systemctl status postgresql

# Check if port is listening
sudo netstat -tlnp | grep 5432

# Test connection
psql -h localhost -U promptforge_app -d promptforge_prod

# Check pg_hba.conf
sudo cat /etc/postgresql/*/main/pg_hba.conf | grep -v "^#"

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-*-main.log
```

#### 2. Slow Queries

```bash
# Enable slow query logging (already in config)
# Check logs for slow queries
sudo grep "duration:" /var/log/postgresql/postgresql-*-main.log | tail -20

# Analyze specific query
psql -U promptforge_app -d promptforge_prod
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@example.com';

# Check for missing indexes
./monitor-database.sh --metrics
```

#### 3. Disk Space Full

```bash
# Check database size
psql -U promptforge_app -d promptforge_prod -c "SELECT pg_size_pretty(pg_database_size(current_database()));"

# Find largest tables
psql -U promptforge_app -d promptforge_prod -c "
SELECT schemaname || '.' || tablename AS table,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;"

# Clean up old data
# - Archive old records
# - Drop unused tables/indexes
# - Run VACUUM FULL
```

#### 4. High Connection Count

```bash
# View current connections
psql -U postgres -c "SELECT * FROM pg_stat_activity;"

# Terminate idle connections
psql -U postgres -d promptforge_prod -c "SELECT public.terminate_idle_connections(30);"

# Increase max_connections (if needed)
# Edit postgresql.conf
sudo nano /etc/postgresql/*/main/postgresql.conf
# max_connections = 200
sudo systemctl restart postgresql
```

#### 5. Lock Contention

```bash
# View blocked queries
psql -U postgres -d promptforge_prod -c "
SELECT blocked_locks.pid AS blocked_pid,
       blocked_activity.usename AS blocked_user,
       blocking_locks.pid AS blocking_pid,
       blocking_activity.usename AS blocking_user,
       blocked_activity.query AS blocked_statement,
       blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;"

# Terminate blocking query (if necessary)
psql -U postgres -c "SELECT pg_terminate_backend(<pid>);"
```

---

## Best Practices

### Security

1. **Use strong passwords** for all database users
2. **Restrict network access** via pg_hba.conf
3. **Use SSL/TLS** for remote connections
4. **Regular security updates** for PostgreSQL
5. **Audit database access** via audit schema
6. **Encrypt backups** before uploading to external storage
7. **Rotate credentials** periodically

### Performance

1. **Connection pooling** - Use SQLAlchemy pool (5-20 connections)
2. **Indexes** - Create indexes on foreign keys and frequently queried columns
3. **Query optimization** - Monitor and optimize slow queries
4. **Partitioning** - Consider partitioning large tables (> 10M rows)
5. **Caching** - Use Redis for frequently accessed data
6. **Vacuum** - Ensure autovacuum is running effectively
7. **Statistics** - Keep table statistics up to date

### Reliability

1. **Backups** - Automated daily backups with verification
2. **Monitoring** - Continuous health monitoring
3. **Replication** - Consider streaming replication for HA
4. **Testing** - Test migrations and backups regularly
5. **Documentation** - Keep runbooks updated
6. **Capacity planning** - Monitor growth and plan ahead

### Development

1. **Schema versioning** - All changes via Alembic migrations
2. **Code reviews** - Review all migration scripts
3. **Testing** - Test migrations on staging before production
4. **Rollback plans** - Always have a rollback strategy
5. **Documentation** - Document schema changes in migration comments

---

## Quick Reference

### Essential Commands

```bash
# Database
psql -U promptforge_app -d promptforge_prod

# Migrations
cd backend && ./migrate.sh upgrade
cd backend && ./migrate.sh downgrade 1

# Backup
cd database/scripts && ./backup-database.sh --verify

# Restore
cd database/scripts && ./restore-database.sh <backup_file>

# Monitor
cd database/scripts && ./monitor-database.sh

# Health Check
cd database/scripts && ./monitor-database.sh --health
```

### Important Files

```
database/
├── init/
│   └── 01-init-database.sql          # Database initialization
├── config/
│   ├── postgresql.conf.example        # PostgreSQL optimization
│   └── pg_hba.conf.example           # Access control
├── scripts/
│   ├── setup-database.sh             # Initial setup
│   ├── backup-database.sh            # Backup automation
│   ├── restore-database.sh           # Restore procedure
│   ├── test-migrations.sh            # Migration testing
│   └── monitor-database.sh           # Health monitoring
└── docs/
    └── database-management.md        # This file

backend/
├── alembic/                          # Migration scripts
│   └── versions/                     # Migration history
├── alembic.ini                       # Alembic configuration
└── migrate.sh                        # Migration helper
```

### Useful SQL Queries

```sql
-- Database size
SELECT pg_size_pretty(pg_database_size(current_database()));

-- Table sizes
SELECT schemaname || '.' || tablename AS table,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Active connections
SELECT pid, usename, application_name, client_addr, state, query
FROM pg_stat_activity
WHERE datname = current_database() AND state = 'active';

-- Cache hit ratio
SELECT ROUND(100.0 * sum(blks_hit) / NULLIF(sum(blks_hit) + sum(blks_read), 0), 2)
FROM pg_stat_database WHERE datname = current_database();

-- Terminate idle connections
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = current_database()
  AND state = 'idle'
  AND state_change < NOW() - INTERVAL '30 minutes';
```

---

## Support

For additional help:

- PostgreSQL Documentation: https://www.postgresql.org/docs/
- Alembic Documentation: https://alembic.sqlalchemy.org/
- SQLAlchemy Documentation: https://docs.sqlalchemy.org/
- PromptForge GitHub Issues: https://github.com/madhavkobal/Prompt-Forge/issues

---

*Last Updated: 2024-01-15*

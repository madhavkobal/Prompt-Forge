# Maintenance Guide

Operations guide for maintaining PromptForge in production.

## Backup and Recovery

### Database Backups

**Automated Daily Backups:**
```bash
# PostgreSQL backup script
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/promptforge"
DB_NAME="promptforge_prod"

pg_dump -U promptforge -h localhost $DB_NAME | gzip > $BACKUP_DIR/backup_$DATE.sql.gz

# Retain only last 30 days
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +30 -delete
```

**Manual Backup:**
```bash
# PostgreSQL
pg_dump -U promptforge promptforge_prod > backup.sql

# Docker container
docker exec postgres pg_dump -U promptforge promptforge_prod > backup.sql

# Kubernetes
kubectl exec -n promptforge postgres-pod -- pg_dump -U promptforge promptforge_prod > backup.sql
```

**Restore:**
```bash
psql -U promptforge promptforge_prod < backup.sql
```

### Application Data Backup

**Backup user uploads (if applicable):**
```bash
tar -czf uploads_backup.tar.gz /app/uploads
```

**Backup configuration:**
```bash
tar -czf config_backup.tar.gz /app/config
```

## Updates and Upgrades

### Application Updates

**Zero-Downtime Update:**
```bash
# 1. Pull latest code
git pull origin main

# 2. Build new version
docker build -t promptforge-backend:v1.1.0 ./backend

# 3. Rolling update (Kubernetes)
kubectl set image deployment/promptforge-backend backend=promptforge-backend:v1.1.0

# 4. Monitor rollout
kubectl rollout status deployment/promptforge-backend

# 5. Rollback if issues
kubectl rollout undo deployment/promptforge-backend
```

**With Downtime:**
```bash
# 1. Notify users of maintenance window
# 2. Stop services
docker-compose down

# 3. Backup database
pg_dump promptforge_prod > backup_before_update.sql

# 4. Update code
git pull origin main

# 5. Run migrations
cd backend
alembic upgrade head

# 6. Rebuild and start
docker-compose up -d --build

# 7. Verify health
curl http://localhost:8000/health
```

### Database Migrations

**Before Migration:**
```bash
# 1. Backup database
pg_dump promptforge_prod > pre_migration_backup.sql

# 2. Test migration in staging
alembic upgrade head --sql > migration.sql  # Review SQL
```

**Run Migration:**
```bash
cd backend
alembic upgrade head
```

**Rollback Migration:**
```bash
alembic downgrade -1  # Rollback one version
```

### Dependency Updates

**Backend Dependencies:**
```bash
# Update dependencies
pip install --upgrade -r requirements.txt

# Check for security vulnerabilities
safety check

# Test thoroughly before deploying
pytest
```

**Frontend Dependencies:**
```bash
# Check for updates
npm outdated

# Update packages
npm update

# Check for vulnerabilities
npm audit
npm audit fix

# Test
npm test
npm run build
```

## Monitoring

### Health Checks

**Automated Monitoring:**
```bash
# Cron job for health checks
*/5 * * * * curl -f http://localhost:8000/health || echo "Health check failed" | mail -s "PromptForge Down" admin@example.com
```

**Manual Checks:**
```bash
# Basic health
curl http://localhost:8000/health

# Detailed health with dependencies
curl http://localhost:8000/health/detailed

# System metrics
curl http://localhost:8000/health/system
```

### Log Management

**View Logs:**
```bash
# Docker
docker-compose logs -f backend
docker-compose logs -f --tail=100 backend

# Kubernetes
kubectl logs -f deployment/promptforge-backend -n promptforge
kubectl logs --previous pod-name  # Previous instance logs

# System logs
journalctl -u promptforge-backend -f
```

**Log Rotation:**
```bash
# /etc/logrotate.d/promptforge
/var/log/promptforge/*.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 promptforge promptforge
    sharedscripts
    postrotate
        systemctl reload promptforge
    endscript
}
```

### Performance Monitoring

**Database Performance:**
```sql
-- Long running queries
SELECT pid, now() - query_start as duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '1 minute';

-- Database size
SELECT pg_size_pretty(pg_database_size('promptforge_prod'));

-- Table sizes
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

**Application Metrics:**
```bash
# Prometheus metrics
curl http://localhost:8000/metrics

# CPU and Memory (Docker)
docker stats

# Disk usage
df -h
du -sh /var/lib/docker
```

## Scaling

### Horizontal Scaling

**Add More Replicas:**
```bash
# Docker Compose
docker-compose up -d --scale backend=3

# Kubernetes
kubectl scale deployment promptforge-backend --replicas=5
```

**Auto-Scaling (Kubernetes):**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: promptforge-backend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: promptforge-backend
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Database Scaling

**Connection Pooling:**
```python
# In config.py
DATABASE_POOL_SIZE = 20
DATABASE_MAX_OVERFLOW = 10
```

**Read Replicas:**
```python
# Configure read replicas for heavy read workloads
READ_REPLICA_URL = "postgresql://..."
```

## Security Maintenance

### Certificate Renewal

**Let's Encrypt Auto-Renewal:**
```bash
# Certbot auto-renew (runs twice daily)
certbot renew

# Manual renewal
certbot renew --force-renewal
```

### Security Updates

**Weekly Security Checks:**
```bash
# Backend
cd backend
safety check

# Frontend
cd frontend
npm audit

# Docker images
docker scan promptforge-backend:latest
```

### Access Control Review

**Quarterly Review:**
- Review user access levels
- Disable inactive accounts
- Rotate API keys
- Review database user permissions
- Audit firewall rules

## Performance Optimization

### Database Optimization

**Vacuum and Analyze:**
```sql
VACUUM ANALYZE;
```

**Reindex:**
```sql
REINDEX DATABASE promptforge_prod;
```

**Query Optimization:**
```sql
EXPLAIN ANALYZE SELECT * FROM prompts WHERE owner_id = 1;
```

### Cache Management

**Clear Cache (if using Redis):**
```bash
redis-cli FLUSHDB
```

### Static File Optimization

**CDN Cache Invalidation:**
```bash
# CloudFront
aws cloudfront create-invalidation --distribution-id E123456 --paths "/*"
```

## Disaster Recovery

### Recovery Plan

1. **Assess Damage**
   - Check what's affected
   - Review error logs
   - Identify root cause

2. **Restore from Backup**
```bash
# Stop services
docker-compose down

# Restore database
psql -U promptforge promptforge_prod < latest_backup.sql

# Restore files
tar -xzf uploads_backup.tar.gz -C /

# Restart services
docker-compose up -d
```

3. **Verify Recovery**
```bash
# Health check
curl http://localhost:8000/health/detailed

# Test critical functionality
pytest tests/test_critical.py
```

4. **Post-Incident Review**
   - Document what happened
   - Identify improvements
   - Update runbooks
   - Communicate to stakeholders

## Scheduled Maintenance

### Daily Tasks
- [x] Check health endpoints
- [x] Review error logs
- [x] Monitor disk space
- [x] Database backup

### Weekly Tasks
- [x] Review security vulnerabilities
- [x] Check dependency updates
- [x] Review performance metrics
- [x] Test backup restoration

### Monthly Tasks
- [x] Update dependencies (if safe)
- [x] Review and rotate logs
- [x] Database optimization (VACUUM)
- [x] Review and update documentation

### Quarterly Tasks
- [x] Access control review
- [x] Disaster recovery drill
- [x] Performance optimization
- [x] Security audit

---

**Emergency Contacts:**
- On-call Engineer: +1-xxx-xxx-xxxx
- Database Admin: dba@example.com
- DevOps Lead: devops@example.com

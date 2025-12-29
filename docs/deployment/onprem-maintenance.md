# PromptForge On-Premises Maintenance Guide

Comprehensive maintenance procedures for PromptForge on-premises deployment.

**Last Updated:** 2025-01-15
**Version:** 1.0

---

## Table of Contents

- [Maintenance Schedule](#maintenance-schedule)
- [Daily Tasks](#daily-tasks)
- [Weekly Tasks](#weekly-tasks)
- [Monthly Tasks](#monthly-tasks)
- [Quarterly Tasks](#quarterly-tasks)
- [Backup Procedures](#backup-procedures)
- [Update Procedures](#update-procedures)
- [Monitoring Guidelines](#monitoring-guidelines)
- [Troubleshooting](#troubleshooting)
- [Performance Optimization](#performance-optimization)

---

## Maintenance Schedule

### Quick Reference

| Task | Frequency | Time Required | Priority |
|------|-----------|---------------|----------|
| Health check | Daily | 5 min | High |
| Log review | Daily | 10 min | High |
| Backup verification | Daily | 5 min | Critical |
| Disk space check | Weekly | 5 min | High |
| Update check | Weekly | 10 min | Medium |
| Database vacuum | Weekly | 15-30 min | Medium |
| Security updates | Monthly | 30-60 min | Critical |
| Performance review | Monthly | 30 min | Medium |
| Full system backup | Weekly | Automated | Critical |
| DR drill | Quarterly | 2-4 hours | Critical |

---

## Daily Tasks

### Morning Health Check (5-10 minutes)

```bash
# Run comprehensive health check
make health

# Or manually:
./deploy/monitoring/check-health.sh
```

**What to check:**
- ✅ All containers are running
- ✅ Backend API is responding
- ✅ Frontend is accessible
- ✅ Database is healthy
- ✅ Redis is responding

**If issues found:** See [Troubleshooting](#troubleshooting)

### Backup Verification (5 minutes)

```bash
# Check if last night's backup succeeded
ls -lht /var/backups/promptforge/database | head -5

# Verify backup integrity
./backup/scripts/backup-verify.sh /var/backups/promptforge/database/$(ls -t /var/backups/promptforge/database | head -1)
```

**Expected:** Backup from last night (< 24 hours old)

**If backup failed:**
```bash
# Check backup logs
tail -100 /var/log/promptforge/backup-db.log

# Run manual backup
./backup/scripts/backup-db.sh --encrypt --offsite
```

### Log Review (10 minutes)

```bash
# Check for errors
./deploy/monitoring/check-logs.sh 1000

# Or manually:
docker-compose logs --tail=1000 | grep -i "error\|exception\|critical"
```

**What to look for:**
- ❌ Database connection errors
- ❌ Authentication failures (potential security issue)
- ❌ API timeouts
- ❌ Memory errors
- ⚠️ Unusual warning patterns

**Document any recurring errors**

### Monitoring Dashboard Review (5 minutes)

If monitoring is enabled:

```bash
# Access Grafana
# http://your-server:3000

# Review:
- CPU usage trends
- Memory usage trends
- API response times
- Error rates
```

**Alerts to watch:**
- CPU > 80% sustained
- Memory > 85%
- Disk > 80%
- Error rate increase

### Daily Checklist

- [ ] Health check passed
- [ ] Backup completed and verified
- [ ] No critical errors in logs
- [ ] Monitoring dashboards reviewed
- [ ] Any issues documented and addressed

**Time Required:** 15-30 minutes

---

## Weekly Tasks

### Disk Space Check (5 minutes)

```bash
# Check disk usage
make disk

# Or:
./deploy/monitoring/check-disk-space.sh

# Clean up if needed
make clean-logs      # Remove old logs
make clean-docker    # Clean Docker resources
```

**Thresholds:**
- ⚠️ 80%: Plan for cleanup
- ❌ 90%: Immediate action required

### Application Update Check (10 minutes)

```bash
# Check for updates
cd /opt/promptforge
git fetch --all --tags

# List available updates
git log HEAD..origin/main --oneline

# Review release notes
git log --oneline --graph --decorate
```

**Decision:**
- Critical security fix → Update immediately
- Bug fixes → Schedule during maintenance window
- New features → Test in staging first

### Database Maintenance (15-30 minutes)

```bash
# Run database vacuum and analyze
make vacuum-db

# Or manually:
./deploy/maintenance/database-vacuum.sh
```

**What this does:**
- VACUUM ANALYZE (reclaim space, update statistics)
- REINDEX (rebuild indexes)
- Show database size
- Show largest tables

**Best time:** Off-peak hours (e.g., Sunday 2 AM)

### Log Rotation and Cleanup (5 minutes)

```bash
# Clean logs older than 30 days
make clean-logs

# Or manually:
./deploy/maintenance/cleanup-logs.sh 30
```

**What gets cleaned:**
- Application logs > 30 days
- System logs > 30 days
- Large log files (> 100MB) get truncated
- Old logs get compressed

### Backup Cleanup (5 minutes)

```bash
# Remove backups older than 30 days
make clean-backups

# Or:
./deploy/maintenance/cleanup-backups.sh 30
```

### Security Updates (As needed)

```bash
# Check for security updates
sudo apt update
sudo apt list --upgradable | grep -i security

# Apply security updates
sudo apt upgrade -y

# Reboot if kernel updated
sudo reboot  # Schedule during maintenance window
```

### Weekly Checklist

- [ ] Disk space checked and cleaned
- [ ] Update check performed
- [ ] Database maintenance completed
- [ ] Logs rotated and cleaned
- [ ] Old backups removed
- [ ] Security updates applied
- [ ] All services restarted if needed

**Time Required:** 45-60 minutes

---

## Monthly Tasks

### Full System Update (30-60 minutes)

```bash
# Update application
make update

# Or:
sudo ./deploy/update/update-app.sh

# This performs:
# 1. Backup current state
# 2. Pull latest code
# 3. Build new images
# 4. Run migrations
# 5. Rolling update
# 6. Health checks
# 7. Auto-rollback if fails
```

**Schedule:** First Sunday of month, 2 AM

**Post-update verification:**
```bash
# Health check
make health

# Check version
git describe --tags

# Test key features
# - Login
# - Create prompt
# - API access
```

### Performance Review (30 minutes)

```bash
# Memory usage trends
make memory
free -h
docker stats --no-stream

# Database performance
docker-compose exec postgres psql -U promptforge -d promptforge -c "
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
       n_live_tup as rows
FROM pg_tables
JOIN pg_stat_user_tables USING (schemaname, tablename)
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;"

# Slow query analysis
docker-compose exec postgres psql -U promptforge -d promptforge -c "
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 10;"
```

**Review:**
- Database growth trends
- Cache hit rates
- Slow queries
- Resource usage patterns

**Actions:**
- Add indexes for slow queries
- Archive old data if needed
- Adjust resource limits

### SSL Certificate Check (5 minutes)

```bash
# Check certificate expiration
openssl x509 -in ssl/certs/server.crt -noout -dates

# For Let's Encrypt
sudo certbot certificates

# Test auto-renewal
sudo certbot renew --dry-run
```

**Action if < 30 days:**
- Let's Encrypt: Auto-renews (verify it's working)
- Custom certificate: Renew manually

### User Account Audit (15 minutes)

```bash
# List all users
docker-compose exec backend python scripts/list-users.py

# Check for inactive accounts
docker-compose exec backend python scripts/inactive-users.py --days=90

# Review admin accounts
docker-compose exec postgres psql -U promptforge -d promptforge -c "
SELECT email, is_admin, is_active, created_at, last_login
FROM users
WHERE is_admin = true
ORDER BY last_login DESC;"
```

**Actions:**
- Disable inactive accounts
- Review admin privileges
- Remove test accounts

### Configuration Review (15 minutes)

```bash
# Review .env for any needed changes
nano .env

# Check for deprecated settings
grep -i "deprecated" docs/*.md

# Verify SSL configuration
curl -I https://your-domain.com | grep -i "strict-transport"

# Check firewall rules
sudo ufw status numbered
```

### Monthly Checklist

- [ ] Application updated to latest version
- [ ] Performance metrics reviewed
- [ ] SSL certificates checked
- [ ] User accounts audited
- [ ] Configuration reviewed
- [ ] Full system backup verified
- [ ] Documentation updated if changes made

**Time Required:** 2-3 hours

---

## Quarterly Tasks

### Disaster Recovery Drill (2-4 hours)

```bash
# Run full DR simulation
./backup/scripts/test-backup.sh --drill --report=/var/log/promptforge/dr-drill-$(date +%Y%m%d).txt
```

**DR Drill Steps:**
1. Document current state
2. Simulate failure (controlled environment)
3. Execute recovery procedures
4. Measure recovery time (RTO)
5. Verify data integrity
6. Document lessons learned
7. Update DR procedures

**See:** [Disaster Recovery Guide](onprem-disaster-recovery.md)

### Capacity Planning Review (1-2 hours)

**Data to Collect:**
```bash
# Database growth
docker-compose exec postgres psql -U promptforge -d promptforge -c "
SELECT pg_size_pretty(pg_database_size('promptforge'));"

# Disk usage trends
df -h /

# User growth
docker-compose exec postgres psql -U promptforge -d promptforge -c "
SELECT DATE_TRUNC('month', created_at) as month, COUNT(*)
FROM users
GROUP BY month
ORDER BY month DESC
LIMIT 12;"

# Resource usage
docker stats --no-stream
```

**Analysis:**
- Calculate monthly growth rates
- Project 6-12 months forward
- Identify bottlenecks
- Plan upgrades if needed

### Security Audit (2-3 hours)

```bash
# Run security scan
make security-scan

# Check for vulnerabilities
docker run --rm -v /opt/promptforge:/scan aquasec/trivy fs /scan

# Review logs for security issues
grep -i "unauthorized\|forbidden\|401\|403" /var/log/nginx/access.log | tail -100

# Check fail2ban bans
sudo fail2ban-client status sshd
```

**Review:**
- Access logs for suspicious activity
- Failed login attempts
- Firewall rules
- SSL configuration
- Dependency vulnerabilities

**Actions:**
- Update vulnerable dependencies
- Tighten security rules
- Review and rotate secrets

### Documentation Update (1 hour)

- [ ] Update architecture diagrams
- [ ] Review and update runbooks
- [ ] Document any configuration changes
- [ ] Update troubleshooting guides
- [ ] Review team training materials

### Quarterly Checklist

- [ ] DR drill completed and documented
- [ ] Capacity planning reviewed
- [ ] Security audit performed
- [ ] Dependencies updated
- [ ] Documentation updated
- [ ] Team training conducted
- [ ] Lessons learned documented

**Time Required:** 6-10 hours

---

## Backup Procedures

### Automated Backups

**Schedule (via cron):**
- Daily database backup: 1:00 AM
- Weekly full backup: 2:00 AM Sunday
- Daily verification: 3:00 AM

**Verify cron jobs:**
```bash
sudo crontab -l | grep promptforge
```

### Manual Backup

```bash
# Database only
make backup-db

# Full system
make backup

# With verification
make backup && make verify-backup
```

### Backup Verification

```bash
# Quick verification
./backup/scripts/backup-verify.sh /var/backups/promptforge/database/latest

# Full verification with test restore
./backup/scripts/backup-verify.sh --test-restore /var/backups/promptforge/database/latest
```

### Off-Site Backup

```bash
# Configure in .env.backup
REMOTE_USER=backup
REMOTE_HOST=backup.example.com
REMOTE_PATH=/backups/promptforge

# Test off-site sync
./backup/scripts/backup-db.sh --offsite
```

**See:** [Backup System Documentation](../backup-and-disaster-recovery.md)

---

## Update Procedures

### Minor Updates (Patches)

```bash
# Check for updates
git fetch --tags

# Update to specific version
make update --version=v1.0.1

# Or latest
make update
```

**Zero-downtime:** ✅ Automatic rolling update

### Major Updates

1. **Review release notes**
2. **Test in staging** (recommended)
3. **Schedule maintenance window**
4. **Backup before update**
5. **Execute update**
6. **Verify functionality**

```bash
# 1. Backup
make backup

# 2. Update
make update

# 3. Verify
make health
# Test critical features
```

### Rollback Procedure

```bash
# Interactive rollback
make rollback

# To specific version
./deploy/update/rollback.sh v1.0.0
```

---

## Monitoring Guidelines

### Key Metrics to Monitor

**System Resources:**
- CPU usage (alert if > 80%)
- Memory usage (alert if > 85%)
- Disk space (alert if > 80%)
- Network bandwidth

**Application Metrics:**
- API response time (p95 < 200ms)
- Error rate (< 1%)
- Request rate
- Active users

**Database Metrics:**
- Connection count
- Query response time
- Cache hit ratio
- Replication lag (if HA)

### Setting Up Alerts

**Email alerts** (via AlertManager):
```yaml
# In monitoring/alertmanager/alertmanager.yml
receivers:
  - name: 'email'
    email_configs:
      - to: 'ops@example.com'
        from: 'alerts@promptforge.io'
```

**Slack alerts:**
```yaml
- name: 'slack'
  slack_configs:
    - api_url: 'YOUR_WEBHOOK_URL'
      channel: '#alerts'
```

### Log Monitoring

```bash
# Watch for errors in real-time
docker-compose logs -f | grep -i error

# Analyze error patterns
./deploy/monitoring/check-logs.sh 10000
```

---

## Troubleshooting

### High CPU Usage

**Diagnose:**
```bash
# Check process usage
docker stats

# Check backend processes
docker-compose exec backend top -bn1
```

**Solutions:**
- Scale horizontally (add more backend instances)
- Optimize slow queries
- Add caching
- Increase resources

### High Memory Usage

**Diagnose:**
```bash
# System memory
free -h

# Container memory
docker stats

# Check for memory leaks
docker-compose logs backend | grep -i "memory"
```

**Solutions:**
- Restart containers: `docker-compose restart`
- Increase memory limits
- Check for memory leaks in application
- Scale horizontally

### Slow Database Queries

**Diagnose:**
```bash
# Enable slow query logging
docker-compose exec postgres psql -U postgres -c "
ALTER SYSTEM SET log_min_duration_statement = 1000;
SELECT pg_reload_conf();"

# Check slow queries
docker-compose logs postgres | grep "duration:"
```

**Solutions:**
- Add indexes
- Optimize queries
- Run VACUUM ANALYZE: `make vacuum-db`
- Check connection pool settings

### Disk Space Full

**Immediate Action:**
```bash
# Clean Docker
make clean-docker

# Clean logs
make clean-logs

# Clean old backups
./deploy/maintenance/cleanup-backups.sh 7  # Keep only 7 days
```

**Long-term:**
- Add more storage
- Archive old data
- Adjust retention policies

### Cannot Connect to Application

**Check:**
```bash
# 1. Are containers running?
docker-compose ps

# 2. Check Nginx
docker-compose logs nginx

# 3. Check backend
docker-compose logs backend

# 4. Check firewall
sudo ufw status

# 5. Check ports
sudo netstat -tulpn | grep -E ':(80|443|3000|8000)'
```

**Common fixes:**
```bash
# Restart all services
make restart

# Rebuild if needed
make rebuild && make start
```

---

## Performance Optimization

### Database Optimization

```bash
# Run VACUUM ANALYZE
make vacuum-db

# Add indexes for slow queries
docker-compose exec postgres psql -U promptforge -d promptforge -c "
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);
CREATE INDEX CONCURRENTLY idx_prompts_user_id ON prompts(user_id);"

# Update statistics
docker-compose exec postgres psql -U promptforge -d promptforge -c "
ANALYZE users;
ANALYZE prompts;"
```

### Application Caching

```bash
# Monitor Redis cache hit rate
docker-compose exec redis redis-cli INFO stats | grep hits

# Clear cache if needed
docker-compose exec redis redis-cli FLUSHALL
```

### Nginx Optimization

```nginx
# Enable caching (in nginx.conf)
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=app_cache:10m max_size=1g;

location /api/ {
    proxy_cache app_cache;
    proxy_cache_valid 200 5m;
}
```

---

## Maintenance Best Practices

1. **Document everything** - Keep maintenance logs
2. **Test in staging** - Never test in production
3. **Schedule maintenance windows** - Inform users
4. **Automate where possible** - Reduce human error
5. **Monitor constantly** - Proactive vs reactive
6. **Keep backups tested** - Verify they actually work
7. **Stay updated** - Regular security patches
8. **Review and improve** - Continuous improvement

---

## Maintenance Checklist

### Daily
- [ ] Health check completed
- [ ] Backups verified
- [ ] Logs reviewed
- [ ] Monitoring checked

### Weekly
- [ ] Disk space checked
- [ ] Database maintenance run
- [ ] Logs cleaned up
- [ ] Updates checked

### Monthly
- [ ] Application updated
- [ ] Performance reviewed
- [ ] SSL checked
- [ ] Users audited

### Quarterly
- [ ] DR drill completed
- [ ] Capacity planning done
- [ ] Security audit performed
- [ ] Documentation updated

---

**Document Version:** 1.0
**Last Updated:** 2025-01-15

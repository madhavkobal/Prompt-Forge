# PromptForge Disaster Recovery Runbook

## Table of Contents

- [Overview](#overview)
- [Recovery Objectives](#recovery-objectives)
- [Emergency Contacts](#emergency-contacts)
- [Disaster Scenarios](#disaster-scenarios)
- [Pre-Disaster Preparation](#pre-disaster-preparation)
- [Recovery Procedures](#recovery-procedures)
- [Post-Recovery Validation](#post-recovery-validation)
- [Lessons Learned](#lessons-learned)

---

## Overview

This runbook provides step-by-step procedures for recovering the PromptForge system from various disaster scenarios. It is designed to be followed by operations personnel during emergency situations.

**Last Updated:** 2024-01-15
**Document Owner:** Operations Team
**Review Frequency:** Quarterly

### Purpose

- Provide clear, actionable recovery procedures
- Minimize downtime during disasters
- Ensure data integrity and system consistency
- Meet RTO (Recovery Time Objective) and RPO (Recovery Point Objective) targets

### Scope

This runbook covers:
- Complete system failures
- Database corruption
- Data center failures
- Ransomware attacks
- Accidental data deletion
- Hardware failures

---

## Recovery Objectives

### RTO (Recovery Time Objective)

**Target:** 4 hours

Maximum acceptable downtime for each component:

| Component | RTO | Priority |
|-----------|-----|----------|
| Database | 2 hours | Critical |
| Backend API | 3 hours | Critical |
| Frontend | 3 hours | High |
| Monitoring | 4 hours | Medium |
| Load Balancer | 1 hour | Critical |

### RPO (Recovery Point Objective)

**Target:** 24 hours

Maximum acceptable data loss:

| Data Type | RPO | Backup Frequency |
|-----------|-----|------------------|
| User Data | 1 hour | Continuous (WAL) |
| Prompts | 1 hour | Continuous (WAL) |
| Templates | 24 hours | Daily |
| Configuration | 24 hours | Daily |
| Logs | 7 days | Weekly |

---

## Emergency Contacts

### Primary Contacts

```
Role: System Administrator
Name: [Name]
Phone: [Phone]
Email: [Email]
Backup: [Backup Contact]

Role: Database Administrator
Name: [Name]
Phone: [Phone]
Email: [Email]
Backup: [Backup Contact]

Role: DevOps Engineer
Name: [Name]
Phone: [Phone]
Email: [Email]
Backup: [Backup Contact]
```

### Vendor Contacts

```
Cloud Provider Support: [Contact Info]
Database Support: [Contact Info]
Network Provider: [Contact Info]
Security Team: [Contact Info]
```

### Escalation Path

1. **Level 1:** On-call engineer
2. **Level 2:** Team lead
3. **Level 3:** Engineering manager
4. **Level 4:** CTO

---

## Disaster Scenarios

### Scenario 1: Complete System Failure

**Symptoms:**
- All services are down
- No response from application
- Database is inaccessible

**Impact:** Critical - Complete service outage

**Procedure:** [Scenario 1 Recovery](#scenario-1-complete-system-failure-1)

---

### Scenario 2: Database Corruption

**Symptoms:**
- Database errors in logs
- Data inconsistencies
- Failed queries

**Impact:** Critical - Data integrity at risk

**Procedure:** [Scenario 2 Recovery](#scenario-2-database-corruption-1)

---

### Scenario 3: Ransomware Attack

**Symptoms:**
- Encrypted files
- Ransom note
- Unusual file modifications

**Impact:** Critical - Data security breach

**Procedure:** [Scenario 3 Recovery](#scenario-3-ransomware-attack-1)

---

### Scenario 4: Data Center Failure

**Symptoms:**
- Complete loss of connectivity to primary data center
- Infrastructure is inaccessible

**Impact:** Critical - Complete site outage

**Procedure:** [Scenario 4 Recovery](#scenario-4-data-center-failure-1)

---

### Scenario 5: Accidental Data Deletion

**Symptoms:**
- Missing data reported by users
- Database tables or records deleted

**Impact:** High - Partial data loss

**Procedure:** [Scenario 5 Recovery](#scenario-5-accidental-data-deletion-1)

---

### Scenario 6: Hardware Failure

**Symptoms:**
- Disk failure
- Server crash
- Network issues

**Impact:** Medium to High - Depends on affected component

**Procedure:** [Scenario 6 Recovery](#scenario-6-hardware-failure-1)

---

## Pre-Disaster Preparation

### Daily Checklist

- [ ] Verify automated backups completed successfully
- [ ] Check backup verification logs
- [ ] Monitor disk space on backup server
- [ ] Review system health metrics
- [ ] Check database replication lag

### Weekly Checklist

- [ ] Test backup restoration (sample)
- [ ] Verify off-site backups
- [ ] Review and update emergency contacts
- [ ] Check SSL certificate expiration
- [ ] Audit user access

### Monthly Checklist

- [ ] Perform full backup verification
- [ ] Test database point-in-time recovery
- [ ] Review and update DR runbook
- [ ] Conduct tabletop disaster recovery drill
- [ ] Verify all monitoring alerts are working

### Quarterly Checklist

- [ ] Full disaster recovery drill
- [ ] Review and update RTO/RPO
- [ ] Audit backup retention policy
- [ ] Test failover procedures
- [ ] Review vendor SLAs

---

## Recovery Procedures

## Scenario 1: Complete System Failure

### Assessment Phase (15 minutes)

1. **Confirm the disaster:**
   ```bash
   # Check if services are responding
   curl http://your-domain.com/api/health
   curl http://your-domain.com

   # Check Docker containers
   ssh server "docker ps"

   # Check database
   ssh server "docker exec promptforge-postgres pg_isready"
   ```

2. **Notify stakeholders:**
   - Send initial incident notification
   - Activate incident response team
   - Update status page

3. **Assess backup availability:**
   ```bash
   # Check latest backups
   ls -lht /var/backups/promptforge/full | head -5
   ls -lht /var/backups/promptforge/database | head -5

   # Verify backup integrity
   ./backup/scripts/backup-verify.sh /var/backups/promptforge/full/latest
   ```

### Recovery Phase (2-4 hours)

1. **Prepare recovery environment:**
   ```bash
   # If on same hardware:
   cd /opt/promptforge

   # If on new hardware:
   # 1. Install Ubuntu 22.04 LTS
   # 2. Run: ./scripts/ubuntu-install.sh
   # 3. Clone repository: git clone https://github.com/your-org/promptforge.git
   # 4. cd promptforge
   ```

2. **Stop any running services:**
   ```bash
   docker-compose down
   docker-compose -f docker-compose.ha.yml down
   docker-compose -f docker-compose.monitoring.yml down
   ```

3. **Restore from full backup:**
   ```bash
   # Find latest backup
   LATEST_BACKUP=$(ls -t /var/backups/promptforge/full | head -1)

   # Restore full system
   sudo ./backup/restore/restore-full.sh \
     --backup=/var/backups/promptforge/full/$LATEST_BACKUP \
     --force
   ```

4. **Verify configuration:**
   ```bash
   # Check .env file
   cat .env

   # Update any environment-specific settings
   vim .env

   # Verify database password matches
   grep DB_PASS .env
   ```

5. **Start database first:**
   ```bash
   # Start PostgreSQL
   docker-compose up -d postgres

   # Wait for database to be ready
   docker exec promptforge-postgres pg_isready

   # Verify database
   docker exec promptforge-postgres psql -U promptforge -c '\dt'
   ```

6. **Start remaining services:**
   ```bash
   # Start Redis
   docker-compose up -d redis

   # Start backend
   docker-compose up -d backend

   # Start frontend
   docker-compose up -d frontend

   # Start nginx
   docker-compose up -d nginx
   ```

7. **Verify services:**
   ```bash
   # Check container status
   docker-compose ps

   # Check logs
   docker-compose logs --tail=50 backend
   docker-compose logs --tail=50 frontend

   # Test API
   curl http://localhost:8000/api/health

   # Test frontend
   curl http://localhost:3000
   ```

### Expected Timeline

| Task | Duration |
|------|----------|
| Assessment | 15 min |
| Backup verification | 15 min |
| System preparation | 30 min |
| Full restore | 60 min |
| Service startup | 15 min |
| Verification | 30 min |
| **Total** | **2.5 hours** |

---

## Scenario 2: Database Corruption

### Assessment Phase

1. **Identify corruption extent:**
   ```bash
   # Check database logs
   docker logs promptforge-postgres | grep -i error

   # Check for corrupted indexes
   docker exec promptforge-postgres psql -U promptforge -c "
     SELECT schemaname, tablename, indexname
     FROM pg_indexes
     WHERE schemaname = 'public';
   "

   # Verify data integrity
   docker exec promptforge-postgres psql -U promptforge -d promptforge -c "
     SELECT COUNT(*) FROM users;
     SELECT COUNT(*) FROM prompts;
     SELECT COUNT(*) FROM templates;
   "
   ```

2. **Determine recovery point:**
   - Identify when corruption occurred
   - Determine acceptable data loss
   - Select appropriate backup

### Recovery Phase

1. **Stop application:**
   ```bash
   docker-compose stop backend frontend
   ```

2. **Backup current state (even if corrupted):**
   ```bash
   # Emergency backup
   docker exec promptforge-postgres pg_dump \
     -U promptforge promptforge > /tmp/corrupted_db_$(date +%Y%m%d_%H%M%S).sql
   ```

3. **Choose recovery method:**

   **Option A: Full database restore**
   ```bash
   # Find latest good backup
   LATEST_DB_BACKUP=$(ls -t /var/backups/promptforge/database | head -1)

   # Restore database
   ./backup/restore/restore-db.sh \
     --backup=/var/backups/promptforge/database/$LATEST_DB_BACKUP \
     --drop-existing \
     --force
   ```

   **Option B: Point-in-time recovery (if WAL archiving enabled)**
   ```bash
   # Restore base backup
   ./backup/restore/restore-db.sh \
     --backup=/var/backups/promptforge/database/$BASE_BACKUP \
     --drop-existing

   # Apply WAL files up to specific time
   # See Point-in-Time Recovery section below
   ```

4. **Reindex database:**
   ```bash
   docker exec promptforge-postgres psql -U promptforge -d promptforge -c "REINDEX DATABASE promptforge;"
   ```

5. **Verify data integrity:**
   ```bash
   # Run data integrity checks
   docker exec promptforge-postgres psql -U promptforge -d promptforge -c "
     SELECT COUNT(*) FROM users;
     SELECT COUNT(*) FROM prompts;
     SELECT COUNT(*) FROM templates;
   "
   ```

6. **Restart application:**
   ```bash
   docker-compose up -d backend frontend
   ```

### Expected Timeline

| Task | Duration |
|------|----------|
| Assessment | 30 min |
| Emergency backup | 15 min |
| Database restore | 30 min |
| Reindexing | 15 min |
| Verification | 20 min |
| **Total** | **1.5-2 hours** |

---

## Scenario 3: Ransomware Attack

### Immediate Actions (DO NOT SKIP)

1. **ISOLATE THE SYSTEM IMMEDIATELY:**
   ```bash
   # Disconnect from network
   sudo ifconfig eth0 down

   # Stop all services
   docker-compose down

   # Document what you see
   ls -la > /tmp/ransomware_evidence.txt
   find / -name "*.encrypted" -o -name "*DECRYPT*" >> /tmp/ransomware_evidence.txt
   ```

2. **ALERT SECURITY TEAM:**
   - Notify security team immediately
   - Contact law enforcement if required
   - Preserve evidence

3. **DO NOT PAY RANSOM:**
   - Paying does not guarantee data recovery
   - Encourages further attacks
   - May be illegal in some jurisdictions

### Recovery Phase

1. **Assess damage:**
   ```bash
   # Check which files are encrypted
   find /opt/promptforge -type f -mtime -1

   # Check backup integrity (from isolated backup server)
   ssh backup-server "ls -lht /backups/promptforge"
   ```

2. **Rebuild on clean system:**
   ```bash
   # Provision new server
   # Install fresh Ubuntu 22.04

   # Install PromptForge
   ./scripts/ubuntu-install.sh

   # Clone clean code
   git clone https://github.com/your-org/promptforge.git
   cd promptforge
   ```

3. **Restore from off-site backup:**
   ```bash
   # Get backups from off-site location
   scp -r backup-server:/backups/promptforge/full/latest ./recovery/

   # Verify backup is clean (scan for malware)
   clamscan -r ./recovery/

   # Restore system
   ./backup/restore/restore-full.sh --backup=./recovery/latest --force
   ```

4. **Security hardening:**
   ```bash
   # Update all passwords
   ./scripts/reset-all-passwords.sh

   # Update SSL certificates
   ./ssl/generate-certs.sh

   # Review and update firewall rules
   sudo ufw status
   sudo ufw enable

   # Scan for vulnerabilities
   docker run --rm -v /opt/promptforge:/scan aquasec/trivy fs /scan
   ```

5. **Monitor for persistence:**
   - Check cron jobs: `crontab -l`
   - Check system services: `systemctl list-units`
   - Review logs: `journalctl -xe`
   - Monitor outbound connections: `netstat -tupn`

### Expected Timeline

| Task | Duration |
|------|----------|
| Immediate isolation | 15 min |
| Security notification | 15 min |
| Damage assessment | 1 hour |
| Clean system setup | 1 hour |
| Restore from backup | 2 hours |
| Security hardening | 2 hours |
| Monitoring setup | 1 hour |
| **Total** | **7-8 hours** |

---

## Scenario 4: Data Center Failure

### Prerequisites

- DR site configured and ready
- Regular backup replication to DR site
- DNS failover capability

### Recovery Phase

1. **Activate DR site:**
   ```bash
   # Connect to DR site
   ssh dr-site

   # Navigate to PromptForge directory
   cd /opt/promptforge

   # Verify latest backups
   ls -lht /backups/promptforge/full | head -5
   ```

2. **Restore from latest backup:**
   ```bash
   # Find latest replicated backup
   LATEST_BACKUP=$(ls -t /backups/promptforge/full | head -1)

   # Restore full system
   ./backup/restore/restore-full.sh \
     --backup=/backups/promptforge/full/$LATEST_BACKUP \
     --force
   ```

3. **Update configuration for DR site:**
   ```bash
   # Update .env with DR site settings
   vim .env

   # Update domain/IP addresses
   sed -i 's/primary-site.com/dr-site.com/g' .env

   # Update external service endpoints if needed
   ```

4. **Start services:**
   ```bash
   docker-compose up -d
   ```

5. **Update DNS:**
   ```bash
   # Update DNS A records to point to DR site
   # This step varies by DNS provider

   # Example with AWS Route53:
   aws route53 change-resource-record-sets \
     --hosted-zone-id Z1234567890ABC \
     --change-batch file://dns-failover.json

   # Verify DNS propagation
   dig your-domain.com
   ```

6. **Notify users:**
   - Send communication about temporary DR site
   - Update status page
   - Monitor for issues

### Expected Timeline

| Task | Duration |
|------|----------|
| DR site activation | 30 min |
| Full restore | 90 min |
| Configuration updates | 30 min |
| Service startup | 15 min |
| DNS updates | 30 min |
| User notification | 15 min |
| **Total** | **3.5 hours** |

---

## Scenario 5: Accidental Data Deletion

### Assessment Phase

1. **Determine what was deleted:**
   ```bash
   # Check database for missing data
   docker exec promptforge-postgres psql -U promptforge -d promptforge -c "
     SELECT * FROM users ORDER BY created_at DESC LIMIT 10;
   "

   # Check application logs for deletion events
   docker logs promptforge-backend | grep -i delete
   ```

2. **Identify deletion time:**
   - Check audit logs
   - Check user reports
   - Review application logs

### Recovery Phase

**Option A: Point-in-Time Recovery (Recommended)**

```bash
# Find backup just before deletion
./backup/scripts/backup-db.sh --list

# Restore to specific timestamp
./backup/restore/restore-db.sh \
  --backup=/var/backups/promptforge/database/YYYYMMDD_HHMMSS \
  --pitr="2024-01-15 14:30:00" \
  --target-db=promptforge_recovery

# Compare data between current and recovered
docker exec promptforge-postgres psql -U promptforge -c "
  SELECT COUNT(*) FROM promptforge.users;
  SELECT COUNT(*) FROM promptforge_recovery.users;
"

# Extract missing data
docker exec promptforge-postgres psql -U promptforge -c "
  INSERT INTO promptforge.users
  SELECT * FROM promptforge_recovery.users
  WHERE id NOT IN (SELECT id FROM promptforge.users);
"

# Drop recovery database
docker exec promptforge-postgres psql -U promptforge -c "DROP DATABASE promptforge_recovery;"
```

**Option B: Full Database Restore (if PITR unavailable)**

```bash
# Create backup of current state
./backup/scripts/backup-db.sh --format=custom

# Restore from backup before deletion
./backup/restore/restore-db.sh \
  --backup=/var/backups/promptforge/database/good_backup \
  --target-db=promptforge_recovery

# Compare and extract missing data (as above)
```

### Expected Timeline

| Task | Duration |
|------|----------|
| Assessment | 20 min |
| Identify backup | 10 min |
| PITR restoration | 30 min |
| Data comparison | 15 min |
| Data extraction | 15 min |
| Verification | 15 min |
| **Total** | **1.5 hours** |

---

## Scenario 6: Hardware Failure

### Disk Failure

1. **Identify failed disk:**
   ```bash
   # Check disk status
   sudo smartctl -a /dev/sda

   # Check RAID status (if applicable)
   sudo mdadm --detail /dev/md0

   # Check disk space
   df -h
   ```

2. **If database disk failed:**
   ```bash
   # Stop database immediately
   docker-compose stop postgres

   # Replace disk (hardware team)

   # Restore database from backup
   ./backup/restore/restore-db.sh \
     --backup=/var/backups/promptforge/database/latest \
     --force
   ```

3. **If backup disk failed:**
   ```bash
   # Replace disk

   # Restore backups from off-site
   rsync -avz backup-server:/backups/promptforge/ /var/backups/promptforge/
   ```

### Server Failure

1. **Provision replacement server:**
   ```bash
   # Install Ubuntu 22.04 on new server
   # Run installation script
   ./scripts/ubuntu-install.sh
   ```

2. **Restore full system:**
   ```bash
   # Clone repository
   git clone https://github.com/your-org/promptforge.git
   cd promptforge

   # Restore from latest backup
   ./backup/restore/restore-full.sh \
     --backup=/var/backups/promptforge/full/latest \
     --force
   ```

3. **Update network configuration:**
   - Update IP address
   - Update DNS records
   - Update load balancer

### Expected Timeline

| Task | Duration |
|------|----------|
| Hardware identification | 30 min |
| Hardware replacement | 1-4 hours |
| Software installation | 30 min |
| Restoration | 1-2 hours |
| Verification | 30 min |
| **Total** | **3-7 hours** |

---

## Point-in-Time Recovery (PITR)

### Prerequisites

- WAL archiving must be enabled
- WAL archive directory must be accessible
- Base backup available

### PITR Procedure

1. **Identify recovery target time:**
   ```
   Example: "2024-01-15 14:30:00"
   ```

2. **Find base backup before target time:**
   ```bash
   ls -lt /var/backups/promptforge/database/
   ```

3. **Restore base backup:**
   ```bash
   # Stop database
   docker-compose stop postgres

   # Restore base backup
   ./backup/restore/restore-db.sh \
     --backup=/var/backups/promptforge/database/base_backup \
     --no-verify
   ```

4. **Configure recovery:**
   ```bash
   # Create recovery signal file
   docker exec promptforge-postgres touch /var/lib/postgresql/data/recovery.signal

   # Create recovery configuration
   docker exec promptforge-postgres bash -c "cat > /var/lib/postgresql/data/postgresql.auto.conf << EOF
restore_command = 'cp /var/lib/postgresql/wal_archive/%f %p'
recovery_target_time = '2024-01-15 14:30:00'
recovery_target_action = 'promote'
EOF"
   ```

5. **Start database and let it recover:**
   ```bash
   docker-compose up -d postgres

   # Monitor recovery
   docker logs -f promptforge-postgres
   ```

6. **Verify recovery:**
   ```bash
   # Check database is accessible
   docker exec promptforge-postgres psql -U promptforge -c '\dt'

   # Verify data at recovery point
   docker exec promptforge-postgres psql -U promptforge -c "
     SELECT MAX(created_at) FROM users;
   "
   ```

---

## Post-Recovery Validation

### Database Validation

```bash
# Check database integrity
docker exec promptforge-postgres psql -U promptforge -d promptforge -c "
  SELECT COUNT(*) FROM users;
  SELECT COUNT(*) FROM prompts;
  SELECT COUNT(*) FROM templates;
"

# Run database health check
./database/scripts/monitor-database.sh --full

# Check for replication lag (if HA)
docker exec promptforge-postgres-primary psql -U promptforge -c "
  SELECT client_addr, state, sync_state, replay_lag
  FROM pg_stat_replication;
"
```

### Application Validation

```bash
# Test API endpoints
curl http://localhost:8000/api/health
curl http://localhost:8000/api/users/me
curl http://localhost:8000/api/prompts

# Check frontend
curl http://localhost:3000

# Test user login
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'

# Check logs for errors
docker-compose logs --tail=100 backend | grep -i error
docker-compose logs --tail=100 frontend | grep -i error
```

### System Validation

```bash
# Check all containers are running
docker-compose ps

# Check resource usage
docker stats --no-stream

# Check disk space
df -h

# Check network connectivity
ping -c 4 8.8.8.8

# Verify SSL certificates
openssl s_client -connect your-domain.com:443 < /dev/null
```

### Monitoring Validation

```bash
# Start monitoring stack
docker-compose -f docker-compose.monitoring.yml up -d

# Check Grafana
curl http://localhost:3000/api/health

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Verify alerting
curl http://localhost:9093/api/v2/alerts
```

### User Acceptance

- [ ] Test user login
- [ ] Test creating prompts
- [ ] Test saving templates
- [ ] Verify user data is intact
- [ ] Check recent activity is present
- [ ] Confirm no data corruption

---

## Communication Plan

### Initial Incident Notification

**Template:**

```
Subject: INCIDENT: PromptForge Service Disruption

Severity: [Critical/High/Medium]
Status: Investigating/Recovering/Resolved

Issue: [Brief description]
Impact: [What services are affected]
Started: [Date/Time]
Expected Resolution: [Estimate]

Current Actions:
- [Action 1]
- [Action 2]

Updates will be provided every 30 minutes.

Contact: [Name] [Email] [Phone]
```

### Status Updates

Send updates every 30 minutes during active incident.

### Resolution Notification

**Template:**

```
Subject: RESOLVED: PromptForge Service Restored

The PromptForge service has been fully restored.

Incident Duration: [X hours]
Root Cause: [Brief description]
Resolution: [What was done]

Data Loss: [None/Minimal/Description]
Outstanding Issues: [Any remaining items]

Followup Actions:
- [Action 1]
- [Action 2]

Post-mortem meeting scheduled for: [Date/Time]

Thank you for your patience.
```

---

## Lessons Learned

After each disaster recovery event, conduct a post-mortem meeting within 48 hours.

### Post-Mortem Template

**Incident Summary:**
- Date/Time:
- Duration:
- Severity:
- Services affected:

**Timeline:**
| Time | Event |
|------|-------|
| | |

**Root Cause:**
- What happened:
- Why it happened:
- Contributing factors:

**What Went Well:**
- Actions that helped:
- Effective processes:

**What Went Wrong:**
- Gaps identified:
- Improvement areas:

**Action Items:**
| Action | Owner | Due Date | Priority |
|--------|-------|----------|----------|
| | | | |

**Runbook Updates:**
- [ ] Update procedures
- [ ] Add new scenarios
- [ ] Update timelines
- [ ] Update contacts

---

## Appendix

### A. Backup Inventory

| Backup Type | Location | Frequency | Retention |
|-------------|----------|-----------|-----------|
| Full System | /var/backups/promptforge/full | Weekly | 30 days |
| Database | /var/backups/promptforge/database | Daily | 30 days |
| WAL Archive | /var/backups/promptforge/wal | Continuous | 7 days |
| Off-site | backup-server:/backups | Daily | 90 days |

### B. System Architecture

```
┌─────────────────────────────────────────────────┐
│                  Nginx (Load Balancer)          │
└────────────────┬────────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
┌───────▼──────┐  ┌──────▼────────┐  ┌──────────┐
│  Backend 1   │  │  Backend 2    │  │ Backend 3│
└───────┬──────┘  └──────┬────────┘  └─────┬────┘
        │                │                  │
        └────────┬───────┴──────────────────┘
                 │
        ┌────────▼─────────┐
        │   PostgreSQL     │
        │   (Primary)      │
        │                  │
        │   Redis          │
        │   (Master)       │
        └──────────────────┘
```

### C. Quick Reference Commands

```bash
# Check system status
docker-compose ps

# View logs
docker-compose logs -f [service]

# Restart service
docker-compose restart [service]

# Full system restart
docker-compose down && docker-compose up -d

# Database backup
./backup/scripts/backup-db.sh --encrypt --offsite

# Full system backup
./backup/scripts/backup-full.sh --encrypt --offsite

# Restore database
./backup/restore/restore-db.sh --backup=/path/to/backup

# Restore full system
./backup/restore/restore-full.sh --backup=/path/to/backup

# Verify backup
./backup/scripts/backup-verify.sh /path/to/backup
```

### D. Critical File Locations

```
Configuration:
  /opt/promptforge/.env
  /opt/promptforge/docker-compose.yml

Backups:
  /var/backups/promptforge/full/
  /var/backups/promptforge/database/
  /var/backups/promptforge/wal_archive/

Logs:
  /var/log/promptforge/
  /opt/promptforge/logs/

SSL Certificates:
  /opt/promptforge/ssl/certs/
  /opt/promptforge/ssl/private/

Scripts:
  /opt/promptforge/backup/scripts/
  /opt/promptforge/backup/restore/
```

---

**Document Version:** 1.0
**Last Reviewed:** 2024-01-15
**Next Review Due:** 2024-04-15

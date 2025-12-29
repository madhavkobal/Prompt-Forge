# PromptForge Disaster Recovery Guide

Quick reference guide for disaster recovery procedures.

**Last Updated:** 2025-01-15
**Version:** 1.0
**RTO:** 2-4 hours | **RPO:** 1-24 hours

---

## Emergency Contacts

```
Primary Administrator:
  Name: __________________
  Phone: _________________
  Email: _________________

Backup Administrator:
  Name: __________________
  Phone: _________________
  Email: _________________

Vendor Support:
  Contact: ________________
  Phone: _________________
```

---

## Quick Recovery Procedures

### Scenario 1: Complete System Failure

**RTO: 2-4 hours | RPO: 24 hours**

```bash
# 1. Access backup server
ssh backup-server

# 2. Find latest backup
ls -lt /backups/promptforge/full | head -5

# 3. Restore on new/repaired server
scp -r /backups/promptforge/full/latest new-server:/tmp/

# 4. On new server
ssh new-server
cd /opt/promptforge
sudo ./backup/restore/restore-full.sh --backup=/tmp/latest --force

# 5. Verify
./deploy/monitoring/check-health.sh
```

**Time:** 2-4 hours

### Scenario 2: Database Corruption

**RTO: 1-2 hours | RPO: 1 hour**

```bash
# 1. Stop application
docker-compose stop backend frontend

# 2. Backup corrupted DB
docker-compose exec postgres pg_dump -U promptforge promptforge > /tmp/corrupted_$(date +%Y%m%d).sql

# 3. Restore from latest backup
./backup/restore/restore-db.sh --backup=/var/backups/promptforge/database/latest --drop-existing --force

# 4. Restart
docker-compose up -d

# 5. Verify
docker-compose exec postgres psql -U promptforge -c "SELECT COUNT(*) FROM users;"
```

**Time:** 1-2 hours

### Scenario 3: Accidental Data Deletion

**RTO: 1 hour | RPO: 1 hour**

```bash
# 1. Determine deletion time
# 2. Find backup before deletion
# 3. Point-in-time recovery (if WAL archiving enabled)

./backup/restore/restore-db.sh \
  --backup=/var/backups/promptforge/database/YYYYMMDD_HHMMSS \
  --pitr="2024-01-15 14:00:00" \
  --target-db=promptforge_recovery

# 4. Extract missing data
docker-compose exec postgres psql -U promptforge -c "
INSERT INTO promptforge.table_name
SELECT * FROM promptforge_recovery.table_name
WHERE id NOT IN (SELECT id FROM promptforge.table_name);"

# 5. Drop recovery DB
docker-compose exec postgres psql -U promptforge -c "DROP DATABASE promptforge_recovery;"
```

**Time:** 1-2 hours

---

## Detailed Recovery Procedures

**See:** [Full DR Runbook](../disaster-recovery/DR-RUNBOOK.md)

Includes detailed procedures for:
- Complete system failure
- Database corruption
- Ransomware attack
- Data center failure
- Hardware failure
- Network outage

---

## Backup Locations

**On-premises:**
- `/var/backups/promptforge/full` - Full system backups
- `/var/backups/promptforge/database` - Database backups
- `/var/backups/promptforge/wal_archive` - WAL files

**Off-site:**
- Remote server: `backup-server:/backups/promptforge`
- S3 (if configured): `s3://promptforge-backups`

---

## Recovery Testing

**Schedule:** Quarterly DR drills

```bash
# Run automated DR drill
./backup/scripts/test-backup.sh --drill --report=/var/log/promptforge/dr-drill.txt
```

---

## Recovery Checklists

### Pre-Recovery
- [ ] Identify failure type
- [ ] Locate latest backup
- [ ] Verify backup integrity
- [ ] Notify stakeholders
- [ ] Document current state

### During Recovery
- [ ] Follow documented procedures
- [ ] Take screenshots/notes
- [ ] Monitor progress
- [ ] Test each component
- [ ] Document any deviations

### Post-Recovery
- [ ] Verify all services
- [ ] Test user access
- [ ] Check data integrity
- [ ] Update documentation
- [ ] Conduct post-mortem

---

**For Complete Procedures:** See [DR-RUNBOOK.md](../disaster-recovery/DR-RUNBOOK.md)

# PromptForge Deployment Checklist

Complete pre-deployment and post-deployment verification checklist for PromptForge on-premises deployment.

**Last Updated:** 2025-01-15
**Version:** 1.0

---

## Pre-Deployment Checklist

### Infrastructure Readiness

#### Hardware
- [ ] Server meets minimum CPU requirements (4+ cores for production)
- [ ] Server meets minimum RAM requirements (8GB+ for production)
- [ ] Server meets minimum storage requirements (100GB+ for production)
- [ ] SSD/NVMe storage configured for database
- [ ] Network bandwidth adequate (100 Mbps minimum)
- [ ] Backup storage available and accessible

#### Software
- [ ] Operating system is Ubuntu 22.04 LTS or supported version
- [ ] OS is fully updated (`sudo apt update && sudo apt upgrade`)
- [ ] Root/sudo access confirmed
- [ ] SSH access configured and tested
- [ ] SSH key-based authentication set up

#### Network
- [ ] Domain name registered and configured (production)
- [ ] DNS A record pointing to server IP
- [ ] DNS propagation verified (`dig your-domain.com`)
- [ ] Required ports available (80, 443, 22)
- [ ] Firewall plan documented
- [ ] SSL certificate plan in place

#### Access & Credentials
- [ ] Administrative access to server confirmed
- [ ] DNS management access available (if needed)
- [ ] Email account for notifications configured
- [ ] SMTP credentials available (if using email)
- [ ] Gemini API key obtained (if using AI features)
- [ ] Password manager ready for storing credentials

### Documentation Review
- [ ] Prerequisites documentation reviewed
- [ ] Installation guide reviewed
- [ ] Configuration guide reviewed
- [ ] Maintenance procedures reviewed
- [ ] DR procedures reviewed

### Team Preparation
- [ ] Team members assigned roles
- [ ] Installation schedule confirmed
- [ ] Maintenance windows scheduled
- [ ] Emergency contacts documented
- [ ] Escalation procedures defined

### Backup Plan
- [ ] Backup storage location identified
- [ ] Off-site backup location configured (recommended)
- [ ] Backup retention policy defined (default: 30 days)
- [ ] Restore procedures tested (in staging if available)

---

## Installation Checklist

### Phase 1: Preparation
- [ ] Connected to server via SSH
- [ ] System updated (`sudo apt update && sudo apt upgrade`)
- [ ] Hostname set (`sudo hostnamectl set-hostname promptforge`)
- [ ] Timezone configured (`sudo timedatectl set-timezone UTC`)
- [ ] Deployment user created (optional but recommended)

### Phase 2: Dependencies
- [ ] PromptForge repository cloned
- [ ] Dependency installation script executed (`./deploy/initial/install.sh`)
- [ ] Docker installed and verified (`docker --version`)
- [ ] Docker Compose installed (`docker-compose --version`)
- [ ] PostgreSQL client tools installed (`psql --version`)
- [ ] Python 3 installed (`python3 --version`)
- [ ] Node.js installed (`node --version`)
- [ ] All dependencies verified
- [ ] User added to docker group
- [ ] Logged out and back in for group changes

### Phase 3: Setup
- [ ] Initial setup script executed (`./deploy/initial/setup.sh --prod`)
- [ ] `.env` file created and verified
- [ ] `.env.monitoring` file created
- [ ] `.env.backup` file created
- [ ] Generated credentials saved securely
- [ ] Credentials stored in password manager
- [ ] Directory structure created
- [ ] Permissions set correctly

### Phase 4: Configuration
- [ ] `.env` file edited with production values
- [ ] `APP_URL` set to production domain
- [ ] `ENVIRONMENT` set to `production`
- [ ] `DEBUG` set to `false`
- [ ] Email/SMTP settings configured (if applicable)
- [ ] Gemini API key configured (if applicable)
- [ ] Rate limiting configured
- [ ] Session settings reviewed
- [ ] Configuration validated

### Phase 5: SSL Certificates
- [ ] SSL setup script executed
  - [ ] Let's Encrypt (production): `./deploy/initial/init-ssl.sh --letsencrypt`
  - [ ] Self-signed (development): `./deploy/initial/init-ssl.sh --self-signed`
  - [ ] Custom certificate: `./deploy/initial/init-ssl.sh --custom`
- [ ] Certificate installed successfully
- [ ] Certificate verified (`openssl x509 -in ssl/certs/server.crt -noout -text`)
- [ ] Auto-renewal configured (Let's Encrypt only)
- [ ] DH parameters generated

### Phase 6: Deployment
- [ ] First deployment script executed (`./deploy/initial/first-deploy.sh`)
- [ ] Docker images built successfully
- [ ] PostgreSQL database started
- [ ] Database initialized
- [ ] Database migrations completed
- [ ] Redis started
- [ ] Backend services started
- [ ] Frontend started
- [ ] Nginx started
- [ ] All containers running (`docker-compose ps`)
- [ ] No errors in deployment output

---

## Post-Deployment Verification

### Service Health Checks
- [ ] Health check script passes (`./deploy/monitoring/check-health.sh`)
- [ ] All containers show "Up" status (`docker-compose ps`)
- [ ] PostgreSQL is responding (`docker-compose exec postgres pg_isready`)
- [ ] Redis is responding (`docker-compose exec redis redis-cli ping`)
- [ ] Backend API is healthy (`curl http://localhost:8000/api/health`)
- [ ] Frontend is accessible (`curl http://localhost:3000`)
- [ ] Nginx is serving requests (`curl http://localhost`)

### Frontend Verification
- [ ] Frontend accessible in browser
- [ ] HTTPS working (if configured)
- [ ] SSL certificate valid (if production)
- [ ] No console errors in browser
- [ ] All assets loading correctly
- [ ] Login page displays correctly
- [ ] Responsive design working

### Backend API Verification
- [ ] API documentation accessible (`http://localhost:8000/docs`)
- [ ] Health endpoint responding (`/api/health`)
- [ ] API returns JSON responses
- [ ] CORS configured correctly
- [ ] Rate limiting working (if enabled)
- [ ] Authentication endpoints working

### Database Verification
- [ ] Database connection successful
- [ ] Required tables created (`docker-compose exec postgres psql -U promptforge -c "\dt"`)
- [ ] Sample query successful (`SELECT * FROM users LIMIT 1`)
- [ ] Database size reasonable (`SELECT pg_size_pretty(pg_database_size('promptforge'))`)
- [ ] No errors in database logs (`docker-compose logs postgres | grep ERROR`)

### User Management
- [ ] Admin user created
- [ ] Admin can login successfully
- [ ] User registration working (if enabled)
- [ ] Password reset working (if enabled)
- [ ] Email notifications working (if configured)

### Functional Testing
- [ ] User can login
- [ ] User can create a prompt
- [ ] User can save a template
- [ ] User can search prompts
- [ ] File upload working (if applicable)
- [ ] All core features tested
- [ ] No JavaScript errors in browser console

### Security Verification
- [ ] HTTPS enforced (production)
- [ ] HTTP redirects to HTTPS (production)
- [ ] Security headers present (`curl -I https://your-domain.com`)
- [ ] Firewall rules applied (`sudo ufw status`)
- [ ] SSH password authentication disabled
- [ ] fail2ban configured and running
- [ ] Secrets not exposed in logs
- [ ] `.env` files have correct permissions (600)

### Logging
- [ ] Application logs writing (`docker-compose logs backend | tail`)
- [ ] Access logs writing (`docker-compose logs nginx | tail`)
- [ ] Error logs writing (if any)
- [ ] Log rotation configured
- [ ] No sensitive data in logs

### Backup System
- [ ] Backup cron jobs installed (`sudo crontab -l | grep promptforge`)
- [ ] Manual backup tested (`./backup/scripts/backup-db.sh`)
- [ ] Backup verification tested (`./backup/scripts/backup-verify.sh`)
- [ ] Off-site backup configured (if applicable)
- [ ] Off-site backup tested (if applicable)
- [ ] Backup retention policy configured

### Monitoring (if enabled)
- [ ] Monitoring stack deployed (`docker-compose -f docker-compose.monitoring.yml up -d`)
- [ ] Grafana accessible (`http://localhost:3000`)
- [ ] Prometheus accessible (`http://localhost:9090`)
- [ ] Dashboards loading in Grafana
- [ ] Metrics being collected
- [ ] AlertManager configured
- [ ] Test alert sent and received

### Performance
- [ ] Page load time < 3 seconds
- [ ] API response time < 500ms
- [ ] No memory leaks observed
- [ ] CPU usage reasonable (< 50% idle)
- [ ] Memory usage reasonable (< 70%)
- [ ] Disk I/O acceptable

### Documentation
- [ ] Installation documented (date, version, who)
- [ ] Configuration changes documented
- [ ] Admin credentials documented securely
- [ ] Emergency contacts updated
- [ ] Runbooks accessible to team
- [ ] Known issues documented

---

## High Availability Verification (if applicable)

### Load Balancer
- [ ] Load balancer configured
- [ ] Health checks configured
- [ ] All backend instances registered
- [ ] Traffic distributed across instances
- [ ] Failover tested

### Database Replication
- [ ] Primary database running
- [ ] Replica database running
- [ ] Replication status verified (`SELECT * FROM pg_stat_replication;`)
- [ ] Replication lag acceptable (< 1 second)
- [ ] Failover procedure documented

### Redis Sentinel
- [ ] Sentinel instances running (3+)
- [ ] Master elected correctly
- [ ] Failover tested
- [ ] Client applications using Sentinel

---

## Production Readiness Checklist

### Security
- [ ] All default passwords changed
- [ ] Strong password policy enforced
- [ ] 2FA enabled for admin accounts (if available)
- [ ] Secrets rotated from defaults
- [ ] Security scanning completed
- [ ] Vulnerability assessment done
- [ ] Penetration testing completed (if required)

### Performance
- [ ] Load testing completed
- [ ] Performance benchmarks established
- [ ] Bottlenecks identified and addressed
- [ ] Caching configured and tested
- [ ] Database indexes optimized

### Compliance (if applicable)
- [ ] GDPR compliance reviewed
- [ ] Data retention policies documented
- [ ] Privacy policy updated
- [ ] Terms of service updated
- [ ] Cookie consent implemented (if needed)

### Operations
- [ ] Monitoring alerts configured
- [ ] On-call schedule established
- [ ] Incident response plan documented
- [ ] Maintenance windows scheduled
- [ ] Change management process defined

### Business Continuity
- [ ] Disaster recovery plan documented
- [ ] RTO/RPO defined and tested
- [ ] Backup restoration tested
- [ ] DR drill scheduled (quarterly)
- [ ] Business continuity plan updated

---

## Post-Deployment Tasks

### Immediate (Day 1)
- [ ] Monitor application for first 24 hours
- [ ] Review all logs for errors
- [ ] Test all critical user flows
- [ ] Verify backups ran successfully
- [ ] Send deployment completion notification

### Week 1
- [ ] Daily health checks
- [ ] Monitor performance metrics
- [ ] User feedback collected
- [ ] Minor issues logged and prioritized
- [ ] Documentation updates

### Week 2
- [ ] Review and address any issues
- [ ] Performance tuning as needed
- [ ] Security review
- [ ] User training (if needed)
- [ ] Post-deployment review meeting

### Month 1
- [ ] First monthly maintenance completed
- [ ] Backup restoration tested
- [ ] Performance baseline established
- [ ] Capacity planning initiated
- [ ] Team training on operations

---

## Sign-Off

### Deployment Team

| Role | Name | Signature | Date |
|------|------|-----------|------|
| System Administrator | | | |
| Database Administrator | | | |
| DevOps Engineer | | | |
| Security Engineer | | | |

### Stakeholders

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Project Manager | | | |
| Technical Lead | | | |
| Business Owner | | | |

---

## Deployment Information

**Deployment Date:** _______________

**Deployed Version:** _______________

**Deployed By:** _______________

**Environment:** Production / Staging / Development

**Server Information:**
- Hostname: _______________
- IP Address: _______________
- Domain: _______________

**Key Credentials Location:** _______________

**Backup Location:** _______________

**Monitoring URL:** _______________

**Documentation Location:** _______________

---

## Rollback Plan (if needed)

In case deployment fails:

1. **Stop new deployment:**
   ```bash
   docker-compose down
   ```

2. **Restore from backup:**
   ```bash
   ./backup/restore/restore-full.sh --backup=/var/backups/promptforge/full/latest
   ```

3. **Verify restoration:**
   ```bash
   ./deploy/monitoring/check-health.sh
   ```

4. **Notify stakeholders**

5. **Document failure reason**

6. **Schedule re-deployment**

---

## Notes and Issues

**Issues Encountered:**
```
(Document any issues found during deployment)
```

**Workarounds Applied:**
```
(Document any workarounds or deviations from standard procedure)
```

**Outstanding Items:**
```
(List any items to be addressed post-deployment)
```

---

**Checklist Version:** 1.0
**Last Updated:** 2025-01-15
**Next Review:** After each major deployment

# Production Deployment Checklist

Use this checklist to ensure all steps are completed before and after deployment.

## Pre-Deployment

### Environment Setup
- [ ] Server provisioned (2GB+ RAM, 2+ CPU cores, 20GB+ disk)
- [ ] Operating system updated (`sudo apt update && sudo apt upgrade`)
- [ ] Docker installed and running
- [ ] Docker Compose installed
- [ ] Domain name purchased and DNS configured
- [ ] DNS propagation completed (test with `nslookup`)
- [ ] Firewall configured (ports 80, 443, 22 open)

### Configuration Files
- [ ] `.env.production` created from `.env.production.example`
- [ ] `backend/.env.production` created from `backend/production.env.example`
- [ ] All passwords changed from defaults
- [ ] `SECRET_KEY` generated (32+ characters)
- [ ] `POSTGRES_PASSWORD` set to strong password
- [ ] `REDIS_PASSWORD` set to strong password
- [ ] `GEMINI_API_KEY` configured
- [ ] `VITE_API_URL` set to production URL
- [ ] `DOMAIN` set to your domain name
- [ ] `LETSENCRYPT_EMAIL` set for SSL notifications
- [ ] CORS origins configured in backend
- [ ] Allowed hosts configured in backend

### SSL/TLS Setup
- [ ] SSL certificate obtained (Let's Encrypt or other)
- [ ] Certificate files copied to `nginx/ssl/`
- [ ] Certificate permissions set correctly (644 for cert, 600 for key)
- [ ] HTTPS configuration enabled in `nginx/conf.d/default.conf`
- [ ] `server_name` updated with your domain
- [ ] Auto-renewal configured for Let's Encrypt

### Application Build
- [ ] Latest code pulled from repository
- [ ] Frontend `.env.production` configured
- [ ] Docker images built successfully
- [ ] No build errors or warnings

## Deployment

### Initial Deployment
- [ ] Services started: `docker-compose -f docker-compose.prod.yml up -d`
- [ ] All containers running: `docker-compose -f docker-compose.prod.yml ps`
- [ ] Database migrations run: `./backend/migrate.sh upgrade`
- [ ] Migration status verified: `./backend/migrate.sh current`
- [ ] Backend health check passing: `curl http://localhost/api/v1/health`
- [ ] Frontend accessible in browser
- [ ] API endpoints responding correctly

### Database Setup
- [ ] Database created and accessible
- [ ] Initial migrations applied
- [ ] Database backup configured
- [ ] Admin user created (if applicable)
- [ ] Test data removed from production

### Security Configuration
- [ ] HTTPS enabled and working
- [ ] HTTP redirects to HTTPS
- [ ] SSL certificate valid (check with browser)
- [ ] Security headers present (use securityheaders.com)
- [ ] HSTS enabled
- [ ] Debug mode disabled (`DEBUG=False`)
- [ ] API documentation secured or disabled in production
- [ ] Rate limiting configured and tested
- [ ] CORS properly configured
- [ ] Firewall rules verified

## Post-Deployment

### Testing
- [ ] Homepage loads correctly
- [ ] User registration works
- [ ] User login works
- [ ] Prompt analysis functionality works
- [ ] Template features work
- [ ] All API endpoints responding
- [ ] Static assets loading (CSS, JS, images)
- [ ] Mobile responsiveness verified
- [ ] Cross-browser compatibility tested
- [ ] Load testing performed (optional)

### Monitoring Setup
- [ ] Log rotation configured
- [ ] Health checks configured
- [ ] Error tracking setup (Sentry, optional)
- [ ] Uptime monitoring configured (optional)
- [ ] Disk usage monitoring
- [ ] Memory usage monitoring
- [ ] CPU usage monitoring

### Backup & Recovery
- [ ] Database backup script created
- [ ] Automated backups configured (cron job)
- [ ] Backup restoration tested
- [ ] Backup storage location secured
- [ ] Backup retention policy defined

### Documentation
- [ ] Deployment steps documented
- [ ] Environment variables documented
- [ ] Backup procedures documented
- [ ] Recovery procedures documented
- [ ] Team members trained on deployment process

## Ongoing Maintenance

### Daily
- [ ] Monitor error logs
- [ ] Check service health
- [ ] Review access logs for suspicious activity

### Weekly
- [ ] Review resource usage (CPU, memory, disk)
- [ ] Check SSL certificate expiry (should auto-renew)
- [ ] Review application logs
- [ ] Monitor database size

### Monthly
- [ ] Test backup restoration
- [ ] Review and update dependencies
- [ ] Security audit
- [ ] Performance review
- [ ] Review and rotate API keys (if needed)

### Quarterly
- [ ] Update Docker images
- [ ] Review and update SSL configuration
- [ ] Disaster recovery drill
- [ ] Security patches and updates
- [ ] Performance optimization review

## Rollback Plan

If deployment fails:
- [ ] Stop services: `docker-compose -f docker-compose.prod.yml down`
- [ ] Restore database from backup
- [ ] Checkout previous stable version: `git checkout <previous-tag>`
- [ ] Rebuild images: `docker-compose -f docker-compose.prod.yml build`
- [ ] Start services: `docker-compose -f docker-compose.prod.yml up -d`
- [ ] Verify services are running correctly
- [ ] Investigate and document the issue
- [ ] Plan fix for next deployment

## Emergency Contacts

- Server provider: _______________
- Domain registrar: _______________
- SSL certificate provider: _______________
- Database administrator: _______________
- DevOps team: _______________
- On-call engineer: _______________

## Notes

```
Deployment Date: ______________
Deployed By: ______________
Version/Tag: ______________
Special Instructions:
_________________________________
_________________________________
_________________________________
```

---

## Quick Commands Reference

```bash
# Start services
docker-compose -f docker-compose.prod.yml up -d

# Stop services
docker-compose -f docker-compose.prod.yml down

# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Restart service
docker-compose -f docker-compose.prod.yml restart <service>

# Check status
docker-compose -f docker-compose.prod.yml ps

# Run migrations
docker-compose -f docker-compose.prod.yml exec backend ./migrate.sh upgrade

# Backup database
docker-compose -f docker-compose.prod.yml exec postgres pg_dump -U promptforge promptforge_prod > backup.sql

# Access backend shell
docker-compose -f docker-compose.prod.yml exec backend /bin/bash

# View nginx config
docker-compose -f docker-compose.prod.yml exec nginx cat /etc/nginx/conf.d/default.conf

# Test nginx config
docker-compose -f docker-compose.prod.yml exec nginx nginx -t

# Reload nginx
docker-compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

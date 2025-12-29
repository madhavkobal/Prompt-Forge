# PromptForge On-Premises Installation Guide

Complete step-by-step installation guide for deploying PromptForge on-premises.

**Last Updated:** 2025-01-15
**Version:** 1.0
**Estimated Time:** 1-2 hours

---

## Table of Contents

- [Before You Begin](#before-you-begin)
- [Server Preparation](#server-preparation)
- [Installation Methods](#installation-methods)
- [Step-by-Step Installation](#step-by-step-installation)
- [Post-Installation Verification](#post-installation-verification)
- [Initial Configuration](#initial-configuration)
- [Troubleshooting](#troubleshooting)

---

## Before You Begin

### Prerequisites Check

Ensure you have completed the [Prerequisites](onprem-prerequisites.md) checklist:

- ✅ Hardware requirements met
- ✅ Supported operating system installed
- ✅ Network access configured
- ✅ Domain name configured (production)
- ✅ Administrative access available

### What You'll Need

**Access Information:**
- Server IP address or hostname
- SSH private key or password
- sudo/root access

**Configuration Details:**
- Domain name (production)
- Email address (for SSL and notifications)
- Gemini API key (if using AI features)
- SMTP credentials (if using email)

### Installation Time Estimates

| Deployment Type | Time Required |
|----------------|---------------|
| Development (minimal) | 30 minutes |
| Production (standard) | 1 hour |
| Production (HA) | 2-3 hours |
| Production (HA + monitoring) | 3-4 hours |

---

## Server Preparation

### Step 1: Connect to Server

```bash
# SSH into your server
ssh user@your-server-ip

# Or using SSH key
ssh -i /path/to/key.pem user@your-server-ip
```

### Step 2: Update System

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get upgrade -y

# RHEL/CentOS/Rocky
sudo yum update -y
# or
sudo dnf update -y
```

### Step 3: Set Hostname (Optional)

```bash
# Set a meaningful hostname
sudo hostnamectl set-hostname promptforge

# Verify
hostnamectl
```

### Step 4: Configure Timezone

```bash
# List available timezones
timedatectl list-timezones

# Set timezone (example: UTC)
sudo timedatectl set-timezone UTC

# Verify
timedatectl
```

### Step 5: Create Deployment User (Optional but Recommended)

```bash
# Create user
sudo useradd -m -s /bin/bash promptforge

# Add to sudo group
sudo usermod -aG sudo promptforge

# Set password
sudo passwd promptforge

# Add SSH key (if using)
sudo mkdir -p /home/promptforge/.ssh
sudo cp ~/.ssh/authorized_keys /home/promptforge/.ssh/
sudo chown -R promptforge:promptforge /home/promptforge/.ssh
sudo chmod 700 /home/promptforge/.ssh
sudo chmod 600 /home/promptforge/.ssh/authorized_keys

# Switch to new user
sudo su - promptforge
```

---

## Installation Methods

PromptForge offers three installation methods:

### Method 1: Automated Installation (Recommended)

**Pros:**
- Fastest installation
- All dependencies installed automatically
- Best for standard deployments

**Cons:**
- Less customization during install

**Best for:** Production deployments, quick setup

### Method 2: Manual Installation

**Pros:**
- Full control over each step
- Better understanding of components
- Easier troubleshooting

**Cons:**
- Time-consuming
- Requires more expertise

**Best for:** Custom deployments, learning

### Method 3: Docker Pre-built Images

**Pros:**
- Fastest deployment
- Pre-tested images
- Minimal local build time

**Cons:**
- Requires Docker registry access
- Less flexibility

**Best for:** Quick deployments, testing

---

## Step-by-Step Installation

We'll use **Method 1: Automated Installation** as it's the recommended approach.

### Step 1: Download PromptForge

```bash
# Clone the repository
git clone https://github.com/your-org/promptforge.git

# Navigate to directory
cd promptforge

# Checkout stable version (recommended for production)
git checkout tags/v1.0.0  # Replace with latest stable version

# Or stay on main branch for latest features
git checkout main
```

### Step 2: Run Dependency Installation

```bash
# Make script executable
chmod +x deploy/initial/install.sh

# Run installation script
sudo ./deploy/initial/install.sh
```

**What this installs:**
- Docker and Docker Compose
- PostgreSQL client tools
- Python 3 and pip
- Node.js and npm
- System utilities (git, curl, wget, etc.)
- Security tools (ufw, fail2ban, certbot)
- Monitoring tools (htop, sysstat, etc.)

**Expected output:**
```
[INFO] Installing dependencies...
[INFO] Detecting operating system...
[INFO] Operating System: ubuntu 22.04
[INFO] Updating package lists...
[SUCCESS] Package lists updated
[INFO] Installing basic utilities...
[SUCCESS] Basic utilities installed
[INFO] Installing Docker...
[SUCCESS] Docker installed successfully
[INFO] Installing Docker Compose...
[SUCCESS] Docker Compose installed: 2.20.0
...
[SUCCESS] All dependencies installed successfully!
```

**Time:** 10-15 minutes

**Important:** After installation completes, logout and login again for Docker group changes to take effect:

```bash
exit  # Exit current session
ssh user@your-server-ip  # Reconnect
```

### Step 3: Run Initial Setup

```bash
cd promptforge

# Make script executable
chmod +x deploy/initial/setup.sh

# Run setup script
sudo ./deploy/initial/setup.sh --prod
```

**What this does:**
- Creates directory structure
- Sets proper permissions
- Generates `.env` configuration files
- Creates secure random passwords
- Sets up systemd service
- Creates backup directories

**Expected output:**
```
[INFO] Creating directory structure...
[SUCCESS] Directory structure created
[INFO] Setting permissions...
[SUCCESS] Permissions set
[INFO] Generating environment configuration...
[SUCCESS] Environment file created: /opt/promptforge/.env

========================================
  Generated Credentials
========================================

Database:
  User: promptforge
  Password: [RANDOM_PASSWORD]

PostgreSQL Superuser:
  User: postgres
  Password: [RANDOM_PASSWORD]

Redis:
  Password: [RANDOM_PASSWORD]

Grafana:
  User: admin
  Password: [RANDOM_PASSWORD]

[WARNING] These credentials are saved in .env files (chmod 600)
[INFO] Credentials also saved to: /etc/promptforge/credentials.txt
```

**⚠️ IMPORTANT:** Save these credentials in a secure password manager!

**Time:** 2-3 minutes

### Step 4: Configure Environment Variables

```bash
# Edit the main environment file
nano .env

# Or use vim
vim .env
```

**Required Changes for Production:**

```bash
# Application URL (change to your domain)
APP_URL=https://promptforge.example.com

# Environment
ENVIRONMENT=production
DEBUG=false

# Email Configuration (if using email features)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_FROM_EMAIL=noreply@promptforge.example.com

# Gemini API (if using AI features)
GEMINI_API_KEY=your_gemini_api_key_here

# Keep the generated passwords as-is
```

**Optional Changes:**

```bash
# Session lifetime (default: 24 hours)
SESSION_LIFETIME=86400

# Rate limiting
RATE_LIMIT_PER_MINUTE=60

# File upload size (default: 10MB)
MAX_UPLOAD_SIZE=10485760
```

Save and exit (Ctrl+X, then Y, then Enter for nano).

**Time:** 5-10 minutes

### Step 5: Setup SSL Certificates

#### Option A: Let's Encrypt (Production - Recommended)

```bash
# Make script executable
chmod +x deploy/initial/init-ssl.sh

# Run SSL setup
sudo ./deploy/initial/init-ssl.sh --letsencrypt \
  --domain=promptforge.example.com \
  --email=admin@example.com
```

**Prerequisites:**
- Domain must point to your server's IP
- Port 80 must be accessible from internet
- DNS propagation complete

**Time:** 3-5 minutes

#### Option B: Self-Signed Certificate (Development/Internal)

```bash
sudo ./deploy/initial/init-ssl.sh --self-signed \
  --domain=localhost
```

**Time:** 1-2 minutes

#### Option C: Custom Certificate

```bash
sudo ./deploy/initial/init-ssl.sh --custom
```

Follow prompts to provide:
- Path to certificate file (.crt)
- Path to private key file (.key)
- Path to CA bundle (optional)

**Time:** 2-3 minutes

### Step 6: Deploy Application

```bash
# Make script executable
chmod +x deploy/initial/first-deploy.sh

# Run deployment
sudo ./deploy/initial/first-deploy.sh
```

**What this does:**
1. Validates prerequisites
2. Builds Docker images
3. Starts PostgreSQL database
4. Initializes database schema
5. Runs database migrations
6. Starts Redis cache
7. Starts backend services
8. Starts frontend
9. Starts Nginx reverse proxy
10. Runs health checks
11. Sets up automated backups

**Expected output:**
```
[STEP 1] Running pre-flight checks...
[SUCCESS] Pre-flight checks passed

[STEP 2] Loading environment configuration...
[SUCCESS] Environment loaded

[STEP 3] Building Docker images...
[INFO] This may take several minutes...
[SUCCESS] Docker images built

[STEP 4] Starting database...
[INFO] Waiting for database to be ready...
.....
[SUCCESS] Database is ready

[STEP 5] Initializing database...
[SUCCESS] Database initialized

[STEP 6] Starting Redis...
[SUCCESS] Redis started

[STEP 7] Starting backend services...
[SUCCESS] Backend services started

[STEP 8] Starting frontend...
[SUCCESS] Frontend started

[STEP 9] Starting Nginx...
[SUCCESS] Nginx started

[STEP 10] Running health checks...
✓ Database is healthy
✓ Backend is healthy
✓ Frontend is healthy
✓ Nginx is healthy
[SUCCESS] Health checks passed

========================================
  Deployment Summary
========================================

Deployment Time: 180s
Steps Completed: 10/10

[SUCCESS] PromptForge deployed successfully!

Access URLs:
  • Frontend:    http://localhost:3000
  • Backend API: http://localhost:8000
  • API Docs:    http://localhost:8000/docs
```

**Time:** 10-20 minutes (includes Docker image building)

### Step 7: Enable High Availability (Optional)

For High Availability deployment:

```bash
sudo ./deploy/initial/first-deploy.sh --ha --monitoring
```

This deploys:
- 3 backend instances with load balancing
- PostgreSQL replication (primary + replica)
- Redis Sentinel for cache failover
- Complete monitoring stack (Grafana, Prometheus, Loki)

**Time:** 20-30 minutes

---

## Post-Installation Verification

### Step 1: Verify Services are Running

```bash
# Check Docker containers
docker-compose ps

# Expected output: All services should show "Up"
```

### Step 2: Test Frontend Access

```bash
# From your local machine, open browser:
http://your-server-ip:3000

# Or with domain:
https://promptforge.example.com
```

You should see the PromptForge login/welcome page.

### Step 3: Test Backend API

```bash
# From server or local machine
curl http://your-server-ip:8000/api/health

# Expected output:
{"status":"healthy","timestamp":"2024-01-15T10:00:00Z"}
```

### Step 4: Test Database Connection

```bash
# On server
docker-compose exec postgres psql -U promptforge -d promptforge -c "SELECT version();"

# Should display PostgreSQL version
```

### Step 5: Check Logs for Errors

```bash
# View all logs
docker-compose logs --tail=50

# View backend logs only
docker-compose logs backend --tail=50

# Check for errors
docker-compose logs | grep -i error
```

If no errors, you're good!

### Step 6: Run Health Check Script

```bash
./deploy/monitoring/check-health.sh
```

All checks should pass ✓.

---

## Initial Configuration

### Create First Admin User

#### Option A: Through Web Interface

1. Open browser to your PromptForge URL
2. Click "Sign Up" or "Create Account"
3. Fill in details for admin user
4. Verify email (if email is configured)

#### Option B: Through Backend Container

```bash
# Access backend container
docker-compose exec backend /bin/bash

# Run user creation script (if available)
python scripts/create-admin.py

# Exit container
exit
```

### Configure Email Settings (If Not Done)

```bash
# Edit .env file
nano .env

# Update SMTP settings
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password

# Restart backend to apply changes
docker-compose restart backend
```

### Test Email Configuration

```bash
# If you have a test script
docker-compose exec backend python scripts/test-email.py
```

### Setup Monitoring (If Not Installed)

```bash
# Start monitoring stack
docker-compose -f docker-compose.monitoring.yml up -d

# Access Grafana
# http://your-server-ip:3000
# Default credentials in .env.monitoring
```

### Configure Backups

Backups are automatically configured during installation.

**Verify backup configuration:**

```bash
# Check backup cron jobs
sudo crontab -l | grep promptforge

# Test backup manually
./backup/scripts/backup-db.sh --format=custom
```

**Configure off-site backups:**

```bash
# Edit backup environment
nano .env.backup

# Update remote server details
REMOTE_USER=backup
REMOTE_HOST=backup.example.com
REMOTE_PATH=/backups/promptforge

# Test off-site backup
./backup/scripts/backup-db.sh --format=custom --offsite
```

---

## Troubleshooting

### Issue: Services Won't Start

**Symptoms:**
- Containers exit immediately
- `docker-compose ps` shows "Exit 1"

**Solutions:**

1. Check logs:
```bash
docker-compose logs backend
docker-compose logs postgres
```

2. Verify .env file:
```bash
cat .env | grep -v PASSWORD
```

3. Check port conflicts:
```bash
sudo netstat -tulpn | grep -E ':(3000|8000|5432|6379)'
```

4. Restart Docker:
```bash
sudo systemctl restart docker
docker-compose up -d
```

### Issue: Database Won't Initialize

**Symptoms:**
- "could not connect to database"
- Backend fails to start

**Solutions:**

1. Check PostgreSQL logs:
```bash
docker-compose logs postgres
```

2. Verify database is ready:
```bash
docker-compose exec postgres pg_isready -U postgres
```

3. Manually initialize:
```bash
docker-compose exec postgres psql -U postgres -f /docker-entrypoint-initdb.d/01-init-database.sql
```

4. Reset database (⚠️ destroys data):
```bash
docker-compose down -v
docker-compose up -d postgres
sleep 10
docker-compose up -d
```

### Issue: Cannot Access Frontend

**Symptoms:**
- Browser shows "Connection refused"
- Port 3000 not accessible

**Solutions:**

1. Check if container is running:
```bash
docker-compose ps frontend
```

2. Check frontend logs:
```bash
docker-compose logs frontend
```

3. Verify firewall allows port 3000:
```bash
sudo ufw status
sudo ufw allow 3000/tcp
```

4. Check if Nginx is properly configured:
```bash
docker-compose logs nginx
```

### Issue: SSL Certificate Errors

**Symptoms:**
- "Certificate not valid"
- "NET::ERR_CERT_AUTHORITY_INVALID"

**Solutions:**

1. For self-signed certificates (development):
   - This is expected
   - Click "Advanced" and proceed
   - Or add certificate to browser trust store

2. For Let's Encrypt:
   - Verify domain points to server
   - Check certbot logs: `sudo certbot certificates`
   - Renew if needed: `sudo certbot renew`

3. Regenerate certificate:
```bash
sudo ./deploy/initial/init-ssl.sh --letsencrypt \
  --domain=your-domain.com \
  --email=your-email@example.com
```

### Issue: High Memory Usage

**Symptoms:**
- System becomes slow
- Out of memory errors

**Solutions:**

1. Check memory usage:
```bash
free -h
docker stats
```

2. Reduce container memory limits:
```bash
# Edit docker-compose.yml
nano docker-compose.yml

# Add memory limits under each service:
deploy:
  resources:
    limits:
      memory: 512M

# Restart
docker-compose up -d
```

3. Increase server RAM or reduce concurrent services

### Issue: Disk Space Full

**Solutions:**

1. Check disk usage:
```bash
df -h
du -sh /var/lib/docker
```

2. Clean up Docker:
```bash
./deploy/maintenance/docker-cleanup.sh
```

3. Clean up logs:
```bash
./deploy/maintenance/cleanup-logs.sh
```

4. Clean up old backups:
```bash
./deploy/maintenance/cleanup-backups.sh 30
```

### Getting Help

If issues persist:

1. **Check logs** thoroughly
2. **Review documentation** - especially Configuration Guide
3. **Search GitHub issues**
4. **Create detailed bug report** with:
   - OS version
   - Docker version
   - Error messages
   - Steps to reproduce
   - Relevant logs

---

## Next Steps

After successful installation:

1. ✅ **Review** [Configuration Guide](onprem-configuration.md) for detailed configuration
2. ✅ **Setup** regular backups and verify they work
3. ✅ **Configure** monitoring and alerting
4. ✅ **Review** [Maintenance Guide](onprem-maintenance.md) for ongoing operations
5. ✅ **Test** disaster recovery procedures
6. ✅ **Train** your team on operations and maintenance

---

## Installation Checklist

Use this checklist to track your installation progress:

- [ ] Prerequisites verified
- [ ] Server prepared and updated
- [ ] Dependencies installed
- [ ] Initial setup completed
- [ ] Environment variables configured
- [ ] SSL certificates installed
- [ ] Application deployed
- [ ] Health checks passed
- [ ] Frontend accessible
- [ ] Backend API responding
- [ ] Database initialized
- [ ] Admin user created
- [ ] Email configured and tested (if applicable)
- [ ] Backups configured and tested
- [ ] Monitoring configured (optional)
- [ ] Documentation reviewed
- [ ] Team trained

---

**Document Version:** 1.0
**Last Updated:** 2025-01-15
**Next Review:** Quarterly

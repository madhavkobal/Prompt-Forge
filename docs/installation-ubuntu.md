# Ubuntu 24.04 Installation Guide

Complete guide for installing PromptForge on Ubuntu 24.04 LTS using the automated installation script.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Installation Options](#installation-options)
4. [What the Script Does](#what-the-script-does)
5. [Script Components Explained](#script-components-explained)
6. [Post-Installation Setup](#post-installation-setup)
7. [Manual Installation](#manual-installation)
8. [Troubleshooting](#troubleshooting)

---

## Quick Start

For a standard installation on Ubuntu 24.04:

```bash
# Clone the repository
git clone https://github.com/yourusername/Prompt-Forge.git
cd Prompt-Forge

# Make the script executable
chmod +x install-ubuntu.sh

# Run the installation
sudo ./install-ubuntu.sh --seed-demo
```

After installation:

```bash
# Terminal 1 - Start Backend
cd backend
source venv/bin/activate
uvicorn app.main:app --reload

# Terminal 2 - Start Frontend
cd frontend
npm run dev
```

Access at: http://localhost:5173

---

## Prerequisites

### System Requirements

- **Operating System:** Ubuntu 24.04 LTS (or 22.04)
- **RAM:** Minimum 2GB, recommended 4GB+
- **Disk Space:** At least 5GB free
- **Internet Connection:** Required for downloading packages
- **Sudo Privileges:** Required for installing system packages

### Before You Begin

1. **Update your system:**
   ```bash
   sudo apt update
   sudo apt upgrade -y
   ```

2. **Have your API keys ready:**
   - Google Gemini API key (get from [Google AI Studio](https://makersuite.google.com/app/apikey))

3. **Ensure ports are available:**
   - 5432 (PostgreSQL)
   - 8000 (Backend API)
   - 5173 (Frontend dev server)

---

## Installation Options

The script supports several command-line options:

### Basic Installation

```bash
sudo ./install-ubuntu.sh
```

Installs everything with default settings.

### With Demo Data

```bash
sudo ./install-ubuntu.sh --seed-demo
```

Includes sample templates, prompts, and a demo user account.

### Production Installation

```bash
sudo ./install-ubuntu.sh --production
```

Configures for production deployment with nginx, optimized settings.

### Skip Certain Steps

```bash
# Skip system package installation (if already installed)
sudo ./install-ubuntu.sh --skip-system-deps

# Skip database setup (if already configured)
sudo ./install-ubuntu.sh --skip-db-setup
```

### Combined Options

```bash
sudo ./install-ubuntu.sh --production --seed-demo
```

### Help

```bash
./install-ubuntu.sh --help
```

Shows all available options and usage information.

---

## What the Script Does

The installation script performs these steps automatically:

### 1. **Pre-flight Checks** ✓

- Verifies you're running Ubuntu (22.04 or higher)
- Checks for sudo privileges
- Validates the installation directory

**Why:** Ensures the system is compatible before making changes.

### 2. **System Dependencies Installation** 📦

Installs:
- PostgreSQL (auto-detects latest available: 14-16)
- Python 3 (auto-detects system default: 3.10-3.12)
- Node.js 20 (frontend build tools)
- Build essentials (compilers for native modules)
- nginx (optional, for production)

**Why:** PromptForge requires these specific versions for compatibility. Versions are automatically detected based on your Ubuntu version:
- **Ubuntu 24.04:** PostgreSQL 16, Python 3.12
- **Ubuntu 22.04:** PostgreSQL 14, Python 3.10

### 3. **Version Verification** 🔍

Checks installed versions:
- PostgreSQL 14.x - 16.x (depends on Ubuntu version)
- Python 3.10.x - 3.12.x (depends on Ubuntu version)
- Node.js 20.x
- npm 10.x

**Why:** Confirms all dependencies are correctly installed.

### 4. **Database Configuration** 🗄️

- Starts PostgreSQL service
- Creates `promptforge` database
- Creates `promptforge` user with secure password
- Sets up permissions and schema access
- Saves credentials to .env file

**Why:** Sets up isolated database environment for PromptForge.

### 5. **Project Directory Setup** 📁

- Validates project structure
- Checks for required files (README.md, backend/, frontend/)

**Why:** Ensures the script is running in the correct location.

### 6. **Backend Setup** 🐍

- Creates Python virtual environment (venv)
- Installs all Python dependencies
- Creates backend/.env with:
  - Database credentials
  - Secret keys for JWT
  - API configuration
  - Security settings

**Why:** Isolates Python packages and configures backend application.

### 7. **Frontend Setup** ⚛️

- Installs all npm packages
- Creates frontend/.env with:
  - API URL
  - Environment settings
  - Feature flags

**Why:** Sets up React development environment and build tools.

### 8. **Database Migrations** 🔄

- Runs Alembic migrations
- Creates all database tables
- Sets up schema structure

**Why:** Initializes the database with the correct schema.

### 9. **Demo Data Seeding** 🌱 (Optional)

If `--seed-demo` is used:
- Creates demo user account
- Loads 7 sample templates
- Creates 5 sample prompts with analysis
- Sets up version history examples

**Why:** Provides immediate working examples for testing.

### 10. **Cleanup** 🧹

- Removes temporary credential files
- Deactivates virtual environment
- Shows next steps

**Why:** Security and user guidance.

---

## Script Components Explained

### Color-Coded Output

The script uses colors for better readability:

```bash
# Color definitions
RED='\033[0;31m'      # Errors
GREEN='\033[0;32m'    # Success
YELLOW='\033[1;33m'   # Warnings
BLUE='\033[0;34m'     # Information
PURPLE='\033[0;35m'   # Headers
CYAN='\033[0;36m'     # Steps
```

**Example output:**
- ✓ Success messages (green)
- ✗ Error messages (red)
- ⚠ Warning messages (yellow)
- ℹ Information (blue)

### Error Handling

```bash
set -e  # Exit on any error
set -u  # Exit on undefined variable
```

**What this means:** If any command fails, the script stops immediately to prevent cascading errors.

### Security Features

#### 1. Secure Password Generation

```bash
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
```

- Generates cryptographically secure random password
- 25 characters long
- Used for database user

#### 2. Secret Key Generation

```bash
SECRET_KEY=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)
```

- Generates 64-character secret for JWT tokens
- Used for session security

#### 3. File Permissions

```bash
chmod 600 .env
```

- Restricts .env files to owner-only read/write
- Prevents other users from reading credentials

### PostgreSQL Setup Details

```sql
-- Create dedicated user
CREATE USER promptforge WITH PASSWORD 'secure_password';

-- Create database with owner
CREATE DATABASE promptforge OWNER promptforge;

-- Grant all privileges
GRANT ALL PRIVILEGES ON DATABASE promptforge TO promptforge;

-- Schema permissions
GRANT ALL ON SCHEMA public TO promptforge;
```

**Why this approach:**
- Follows principle of least privilege
- Isolates PromptForge from other databases
- Secure by default

### Virtual Environment Setup

```bash
python3 -m venv venv
source venv/bin/activate
```

**Benefits:**
- Isolates Python packages from system
- Prevents version conflicts
- Easy to reset (just delete venv/ folder)

### Node.js Repository Setup

```bash
# Add NodeSource repository for Node 20
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
    gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
```

**Why:** Ubuntu's default repositories have older Node versions. NodeSource provides the latest LTS releases.

---

## Post-Installation Setup

### 1. Configure API Keys

Edit the backend environment file:

```bash
nano backend/.env
```

Find and update:

```env
GEMINI_API_KEY=your-actual-api-key-here
```

Get your Gemini API key from: https://makersuite.google.com/app/apikey

### 2. Configure CORS (Optional)

If accessing from a different domain:

```bash
nano backend/.env
```

Update:

```env
CORS_ORIGINS=["http://localhost:5173","http://your-domain.com"]
```

### 3. Start Services

**Backend:**
```bash
cd backend
source venv/bin/activate
uvicorn app.main:app --reload
```

**Frontend:**
```bash
cd frontend
npm run dev
```

### 4. Verify Installation

Access these URLs:

- Frontend: http://localhost:5173
- Backend API: http://localhost:8000
- API Documentation: http://localhost:8000/docs
- Health Check: http://localhost:8000/health

### 5. Create First User (if not using demo)

Visit http://localhost:5173/register and create an account.

Or use the demo account:
- Username: `demo`
- Password: `DemoPassword123!`

---

## Manual Installation

If you prefer to install manually or the script fails, follow these steps:

### 1. Install PostgreSQL

```bash
sudo apt update
# Install PostgreSQL (installs the default version for your Ubuntu release)
# Ubuntu 24.04 → PostgreSQL 16, Ubuntu 22.04 → PostgreSQL 14
sudo apt install -y postgresql postgresql-contrib
```

### 2. Install Python 3

```bash
# Install Python 3 (installs the default version for your Ubuntu release)
# Ubuntu 24.04 → Python 3.12, Ubuntu 22.04 → Python 3.10
sudo apt install -y python3 python3-venv python3-dev python3-pip
```

### 3. Install Node.js 20

```bash
# Add NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

### 4. Create Database

```bash
sudo -u postgres psql <<EOF
CREATE USER promptforge WITH PASSWORD 'your_password';
CREATE DATABASE promptforge OWNER promptforge;
GRANT ALL PRIVILEGES ON DATABASE promptforge TO promptforge;
\c promptforge
GRANT ALL ON SCHEMA public TO promptforge;
\q
EOF
```

### 5. Setup Backend

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your settings
nano .env
```

### 6. Setup Frontend

```bash
cd frontend
npm install
cp .env.example .env
# Edit .env with your settings
nano .env
```

### 7. Run Migrations

```bash
cd backend
source venv/bin/activate
alembic upgrade head
```

### 8. Seed Demo Data (Optional)

```bash
python scripts/seed_data.py
```

---

## Troubleshooting

### Script Fails at System Dependencies

**Issue:** `apt-get install` fails with "Unable to locate package"

**Solution:**
```bash
sudo apt update
sudo apt upgrade -y
```

### PostgreSQL Connection Refused

**Issue:** Backend can't connect to database

**Check:**
```bash
sudo systemctl status postgresql
sudo systemctl start postgresql
```

**Test connection:**
```bash
psql -U promptforge -d promptforge -h localhost
```

### Python Version Incorrect

**Issue:** Wrong Python version detected

**Fix:**
```bash
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
python3 --version  # Should show 3.11.x
```

### Port Already in Use

**Issue:** Port 8000 or 5173 already in use

**Find process:**
```bash
sudo lsof -i :8000
sudo lsof -i :5173
```

**Kill process:**
```bash
sudo kill -9 <PID>
```

### Node.js/npm Installation Issues

**Issue:** Node or npm commands not found

**Reinstall:**
```bash
sudo apt remove --purge nodejs npm
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

### Virtual Environment Activation Fails

**Issue:** `source venv/bin/activate` doesn't work

**Check:**
```bash
# Recreate venv
rm -rf venv
python3 -m venv venv
source venv/bin/activate
```

### Database Migration Errors

**Issue:** Alembic upgrade fails

**Reset migrations:**
```bash
# Backup any important data first!
sudo -u postgres psql -c "DROP DATABASE promptforge;"
sudo -u postgres psql -c "CREATE DATABASE promptforge OWNER promptforge;"
alembic upgrade head
```

### Permission Denied Errors

**Issue:** Can't write to directories

**Fix permissions:**
```bash
sudo chown -R $USER:$USER ~/Prompt-Forge
chmod -R 755 ~/Prompt-Forge
```

### Frontend Build Errors

**Issue:** npm install fails with dependency errors

**Clear cache and retry:**
```bash
rm -rf node_modules package-lock.json
npm cache clean --force
npm install --legacy-peer-deps
```

---

## Environment Variables Reference

### Backend (.env)

```env
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/promptforge

# Security
SECRET_KEY=your-secret-key-here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# API Keys
GEMINI_API_KEY=your-gemini-api-key

# Environment
ENVIRONMENT=development  # or production

# CORS
CORS_ORIGINS=["http://localhost:5173"]

# Rate Limiting
RATE_LIMIT_ENABLED=true
RATE_LIMIT_PER_MINUTE=60

# Logging
LOG_LEVEL=DEBUG  # or INFO, WARNING, ERROR

# Server
HOST=0.0.0.0
PORT=8000
WORKERS=1  # Increase for production
```

### Frontend (.env)

```env
# API Configuration
VITE_API_URL=http://localhost:8000/api

# Environment
VITE_ENVIRONMENT=development

# Feature Flags
VITE_ENABLE_ANALYTICS=false
VITE_ENABLE_DEMO_MODE=true
```

---

## Production Deployment

For production deployment on Ubuntu 24.04:

### 1. Run with Production Flag

```bash
sudo ./install-ubuntu.sh --production
```

This configures:
- nginx as reverse proxy
- Production environment variables
- Optimized workers (4)
- INFO-level logging

### 2. Configure nginx

Edit `/etc/nginx/sites-available/promptforge`:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    # Frontend
    location / {
        root /var/www/promptforge/frontend/dist;
        try_files $uri $uri/ /index.html;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Enable site:
```bash
sudo ln -s /etc/nginx/sites-available/promptforge /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 3. Set Up Systemd Services

Create `/etc/systemd/system/promptforge-backend.service`:

```ini
[Unit]
Description=PromptForge Backend
After=network.target postgresql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/promptforge/backend
Environment="PATH=/var/www/promptforge/backend/venv/bin"
ExecStart=/var/www/promptforge/backend/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable promptforge-backend
sudo systemctl start promptforge-backend
```

### 4. SSL with Let's Encrypt

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

---

## Uninstalling

To completely remove PromptForge:

```bash
# Stop services
sudo systemctl stop promptforge-backend 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true

# Remove database
sudo -u postgres psql -c "DROP DATABASE IF EXISTS promptforge;"
sudo -u postgres psql -c "DROP USER IF EXISTS promptforge;"

# Remove packages (optional)
sudo apt remove --purge postgresql postgresql-contrib python3.11 nodejs

# Remove project files
rm -rf ~/Prompt-Forge

# Remove systemd service
sudo rm /etc/systemd/system/promptforge-backend.service
sudo systemctl daemon-reload
```

---

## Additional Resources

- **Full Documentation:** [docs/](../docs/)
- **API Reference:** [docs/api-reference.md](./api-reference.md)
- **Development Guide:** [docs/development.md](./development.md)
- **Troubleshooting:** [docs/troubleshooting.md](./troubleshooting.md)
- **GitHub Issues:** [Report a problem](https://github.com/yourusername/Prompt-Forge/issues)

---

**Installation Script Version:** 1.0.0
**Last Updated:** December 2024
**Tested On:** Ubuntu 24.04 LTS, Ubuntu 22.04 LTS

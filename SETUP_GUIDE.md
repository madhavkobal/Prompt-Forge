# PromptForge - Developer Setup Guide

This guide provides detailed step-by-step instructions for setting up your local development environment for PromptForge.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Getting API Keys](#getting-api-keys)
3. [Environment Configuration](#environment-configuration)
4. [Database Setup](#database-setup)
5. [Backend Setup](#backend-setup)
6. [Frontend Setup](#frontend-setup)
7. [Running the Application](#running-the-application)
8. [Verification](#verification)
9. [Common Issues](#common-issues)
10. [Development Workflow](#development-workflow)

---

## Prerequisites

### System Requirements

**Operating System:**
- macOS 10.15+ (Catalina or later)
- Ubuntu 20.04+ / Debian 11+
- Windows 10/11 with WSL2
- Any Linux distribution with modern package manager

**Required Software:**

| Software | Minimum Version | Recommended Version | Download Link |
|----------|----------------|---------------------|---------------|
| Python | 3.9 | 3.11+ | [python.org](https://www.python.org/downloads/) |
| Node.js | 18.0 | 20.x LTS | [nodejs.org](https://nodejs.org/) |
| PostgreSQL | 13 | 15+ | [postgresql.org](https://www.postgresql.org/download/) |
| Git | 2.30 | Latest | [git-scm.com](https://git-scm.com/downloads) |

**Optional (Recommended):**
- Docker Desktop 4.0+ - For containerized development
- Visual Studio Code - IDE with Python and TypeScript extensions
- Postman - For API testing
- pgAdmin 4 - PostgreSQL GUI management tool

### Verify Installations

```bash
# Check Python version
python --version  # Should output Python 3.9+ or 3.11+

# Check Node.js version
node --version  # Should output v18.x or v20.x

# Check PostgreSQL version
psql --version  # Should output psql 13.x or 15.x

# Check Git version
git --version  # Should output git version 2.30+

# Check npm version
npm --version  # Should output 9.x or 10.x
```

---

## Getting API Keys

### Google Gemini API Key

PromptForge requires a Google Gemini API key for AI-powered prompt analysis and enhancement.

**Step-by-Step:**

1. **Visit Google AI Studio**
   - Go to [https://makersuite.google.com/app/apikey](https://makersuite.google.com/app/apikey)

2. **Sign in with Google Account**
   - Use your existing Google account or create a new one

3. **Create API Key**
   - Click "Create API Key"
   - Select or create a Google Cloud project
   - Copy the generated API key

4. **Save the API Key Securely**
   ```
   Example format: AIzaSyB1234567890abcdefghijklmnopqrstuv
   ```

5. **Understand Free Tier Limits**
   - 60 requests per minute
   - No credit card required for free tier
   - Sufficient for development and testing

6. **Monitor Usage (Optional)**
   - Visit [https://makersuite.google.com](https://makersuite.google.com)
   - Check "Usage" section to monitor API calls

**Important Security Notes:**
- ⚠️ Never commit API keys to Git
- ⚠️ Never share API keys publicly
- ⚠️ Rotate keys if accidentally exposed
- ⚠️ Use environment variables for storage

---

## Environment Configuration

### Backend Environment Setup

1. **Navigate to backend directory**
   ```bash
   cd backend
   ```

2. **Copy the example environment file**
   ```bash
   cp .env.example .env
   ```

3. **Edit the .env file**
   ```bash
   # Using nano (beginner-friendly)
   nano .env

   # OR using vim
   vim .env

   # OR using VS Code
   code .env
   ```

4. **Configure required variables**

   **Minimum Required Configuration:**
   ```env
   # Database (for local development)
   DATABASE_URL=postgresql://promptforge:promptforge_dev_password@localhost:5432/promptforge_db

   # Security - MUST CHANGE!
   SECRET_KEY=your-generated-secret-key-here

   # Google Gemini - REQUIRED!
   GEMINI_API_KEY=your-gemini-api-key-from-google-ai-studio

   # CORS (default works for local dev)
   CORS_ORIGINS=http://localhost:5173,http://localhost:3000

   # Environment
   ENVIRONMENT=development
   ```

5. **Generate a secure SECRET_KEY**

   **Option 1: Using OpenSSL (Mac/Linux)**
   ```bash
   openssl rand -hex 32
   ```

   **Option 2: Using Python**
   ```bash
   python3 -c "import secrets; print(secrets.token_hex(32))"
   ```

   **Option 3: Using PowerShell (Windows)**
   ```powershell
   -join ((48..57) + (97..102) | Get-Random -Count 64 | % {[char]$_})
   ```

   Copy the generated key and paste it as the SECRET_KEY value.

### Frontend Environment Setup

1. **Navigate to frontend directory**
   ```bash
   cd frontend
   ```

2. **Copy the example environment file**
   ```bash
   cp .env.example .env
   ```

3. **Edit the .env file (optional)**
   ```bash
   nano .env
   ```

4. **Configure API URL (optional, defaults work)**
   ```env
   # Default value (you can leave this as-is for local dev)
   VITE_API_URL=http://localhost:8000
   ```

   **Note:** For local development, the defaults work fine. Only change if your backend runs on a different port.

---

## Database Setup

### PostgreSQL Installation

#### macOS (using Homebrew)

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install PostgreSQL
brew install postgresql@15

# Start PostgreSQL service
brew services start postgresql@15

# Verify installation
psql --version
```

#### Ubuntu/Debian

```bash
# Update package lists
sudo apt update

# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Check status
sudo systemctl status postgresql
```

#### Windows

1. Download installer from [postgresql.org/download/windows](https://www.postgresql.org/download/windows/)
2. Run the installer
3. Follow the setup wizard
4. Remember the password you set for postgres user
5. Add PostgreSQL bin to PATH

### Create Database and User

#### Option 1: Mac/Linux (Default Postgres User)

```bash
# Connect to PostgreSQL
psql postgres

# Or if that doesn't work:
sudo -u postgres psql
```

Then run these SQL commands:

```sql
-- Create user
CREATE USER promptforge WITH PASSWORD 'promptforge_dev_password';

-- Create database
CREATE DATABASE promptforge_db OWNER promptforge;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE promptforge_db TO promptforge;

-- Connect to database and grant schema privileges
\c promptforge_db
GRANT ALL ON SCHEMA public TO promptforge;

-- Exit
\q
```

#### Option 2: Using GUI (pgAdmin)

1. Open pgAdmin
2. Connect to local PostgreSQL server
3. Right-click "Databases" → "Create" → "Database"
4. Name: `promptforge_db`
5. Owner: postgres (or create new user "promptforge")
6. Save

#### Option 3: Quick Command Line

```bash
# Create database (as current user)
createdb promptforge_db

# Or with specific user
createdb -U postgres promptforge_db
```

### Verify Database Creation

```bash
# List all databases
psql -l

# You should see 'promptforge_db' in the list

# Connect to the database
psql promptforge_db

# List tables (should be empty initially)
\dt

# Exit
\q
```

### Update DATABASE_URL

Update your `backend/.env` file with the correct connection string:

```env
# Format: postgresql://username:password@host:port/database
DATABASE_URL=postgresql://promptforge:promptforge_dev_password@localhost:5432/promptforge_db
```

**Connection String Components:**
- `postgresql://` - Protocol
- `promptforge` - Database username
- `promptforge_dev_password` - Database password
- `localhost` - Database host (local machine)
- `5432` - PostgreSQL default port
- `promptforge_db` - Database name

---

## Backend Setup

### 1. Navigate to Backend Directory

```bash
cd backend
```

### 2. Create Python Virtual Environment

**Why use a virtual environment?**
- Isolates project dependencies
- Prevents conflicts with system Python packages
- Makes it easy to reproduce environment

**Create virtual environment:**

```bash
# Using venv (built-in)
python3 -m venv venv

# OR using virtualenv (if installed)
virtualenv venv

# OR using Python 3.9 specifically
python3.9 -m venv venv
```

### 3. Activate Virtual Environment

**macOS/Linux:**
```bash
source venv/bin/activate
```

**Windows (Command Prompt):**
```cmd
venv\Scripts\activate.bat
```

**Windows (PowerShell):**
```powershell
venv\Scripts\Activate.ps1
```

**Note:** If PowerShell gives execution policy error:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Verify activation:**
```bash
# Your prompt should show (venv) prefix
# (venv) user@machine:~/Prompt-Forge/backend$

# Check Python location
which python  # Should point to venv/bin/python
```

### 4. Upgrade pip

```bash
pip install --upgrade pip
```

### 5. Install Dependencies

```bash
# Install all required packages
pip install -r requirements.txt

# This installs:
# - FastAPI (web framework)
# - Uvicorn (ASGI server)
# - SQLAlchemy (ORM)
# - Pydantic (data validation)
# - Google Generative AI (Gemini SDK)
# - psycopg2 (PostgreSQL driver)
# - python-jose (JWT)
# - passlib (password hashing)
# - python-multipart (form data)
# and more...
```

**If installation fails:**
```bash
# For psycopg2 issues on Mac:
brew install postgresql
pip install psycopg2-binary

# For general issues:
pip install -r requirements.txt --no-cache-dir
```

### 6. Verify Installation

```bash
# List installed packages
pip list

# Check FastAPI installation
python -c "import fastapi; print(fastapi.__version__)"

# Check SQLAlchemy installation
python -c "import sqlalchemy; print(sqlalchemy.__version__)"
```

### 7. Initialize Database Tables

The application automatically creates tables on first run, but you can verify:

```bash
# Start Python interpreter
python

# Run this code:
from app.core.database import engine, Base
from app.models.user import User
from app.models.prompt import Prompt

Base.metadata.create_all(bind=engine)
print("Database tables created successfully!")

# Exit Python
exit()
```

---

## Frontend Setup

### 1. Navigate to Frontend Directory

```bash
cd frontend
```

### 2. Verify Node.js and npm

```bash
# Check Node.js version (should be 18+ or 20+)
node --version

# Check npm version
npm --version
```

### 3. Install Dependencies

```bash
# Install all packages from package.json
npm install

# This installs:
# - React, React DOM, React Router
# - TypeScript and type definitions
# - Vite (build tool)
# - Tailwind CSS
# - Axios (HTTP client)
# - Zustand (state management)
# - Monaco Editor
# - Recharts
# - Lucide React (icons)
# - React Hot Toast (notifications)
# and more...
```

**If installation is slow:**
```bash
# Use a faster package manager
npm install --legacy-peer-deps

# OR use yarn
yarn install

# OR use pnpm (fastest)
pnpm install
```

### 4. Verify Installation

```bash
# Check installed packages
npm list --depth=0

# Verify critical packages
npm list react
npm list typescript
npm list vite
```

### 5. Build TypeScript (optional check)

```bash
# Check TypeScript compilation
npm run type-check

# If successful, you should see no errors
```

---

## Running the Application

### Start Backend Server

1. **Open a terminal window**

2. **Navigate to backend directory**
   ```bash
   cd backend
   ```

3. **Activate virtual environment**
   ```bash
   source venv/bin/activate  # Mac/Linux
   # OR
   venv\Scripts\activate  # Windows
   ```

4. **Start the server**
   ```bash
   # Development mode with auto-reload
   uvicorn app.main:app --reload

   # With custom host and port
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

   # With specific log level
   uvicorn app.main:app --reload --log-level debug
   ```

5. **Verify backend is running**
   - Server should start on http://127.0.0.1:8000
   - You should see: "Application startup complete"

6. **Test endpoints**
   - Visit http://localhost:8000 (should show welcome message)
   - Visit http://localhost:8000/health (should show {"status":"healthy"})
   - Visit http://localhost:8000/docs (Swagger UI)

### Start Frontend Server

1. **Open a NEW terminal window** (keep backend running)

2. **Navigate to frontend directory**
   ```bash
   cd frontend
   ```

3. **Start development server**
   ```bash
   npm run dev
   ```

4. **Verify frontend is running**
   - Server should start on http://localhost:5173
   - Browser might open automatically
   - You should see the PromptForge login page

### Both Servers Running

You should now have:
- ✅ Backend running on http://localhost:8000
- ✅ Frontend running on http://localhost:5173
- ✅ Database running on localhost:5432

---

## Verification

### 1. Check Backend Health

```bash
# Using curl
curl http://localhost:8000/health

# Expected response:
# {"status":"healthy"}
```

### 2. Check API Documentation

Open browser and visit:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

You should see all API endpoints listed.

### 3. Test Frontend

1. Open http://localhost:5173
2. You should see the PromptForge login page
3. No console errors in browser dev tools (F12)

### 4. Test Database Connection

```bash
# In backend directory with venv activated
python

# Run this code:
from app.core.database import get_db
from sqlalchemy.orm import Session

db = next(get_db())
print("Database connection successful!")
db.close()
```

### 5. Create Test Account

1. Click "Register" on frontend
2. Fill in details:
   - Email: test@example.com
   - Username: testuser
   - Password: test123456
3. Click "Register"
4. You should be redirected to login
5. Login with your credentials
6. You should see the Analyzer page

### 6. Test API Endpoints

**Using curl:**

```bash
# Register a user
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testuser",
    "password": "test123456"
  }'

# Login
curl -X POST http://localhost:8000/api/v1/auth/login \
  -F "username=testuser" \
  -F "password=test123456"

# You should receive a token in response
```

**Using Swagger UI:**
1. Go to http://localhost:8000/docs
2. Expand "POST /api/v1/auth/register"
3. Click "Try it out"
4. Fill in the request body
5. Click "Execute"
6. Check the response

---

## Common Issues

### Issue 1: Port Already in Use

**Symptom:**
```
Error: Address already in use: 8000
```

**Solution:**
```bash
# Find process using port 8000
lsof -i :8000  # Mac/Linux
netstat -ano | findstr :8000  # Windows

# Kill the process
kill -9 <PID>  # Mac/Linux
taskkill /PID <PID> /F  # Windows

# Or use a different port
uvicorn app.main:app --port 8001 --reload
```

### Issue 2: Database Connection Failed

**Symptom:**
```
sqlalchemy.exc.OperationalError: could not connect to server
```

**Solutions:**

1. **Check if PostgreSQL is running:**
   ```bash
   # Mac
   brew services list | grep postgresql
   brew services start postgresql@15

   # Linux
   sudo systemctl status postgresql
   sudo systemctl start postgresql

   # Windows
   # Check Services app for "postgresql" service
   ```

2. **Verify DATABASE_URL:**
   - Check `backend/.env` file
   - Ensure username, password, and database name are correct
   - Test connection: `psql -U promptforge -d promptforge_db`

3. **Check PostgreSQL is listening:**
   ```bash
   psql -U postgres -c "SHOW port;"
   # Should show 5432
   ```

### Issue 3: Module Not Found

**Symptom:**
```
ModuleNotFoundError: No module named 'fastapi'
```

**Solution:**
```bash
# Ensure virtual environment is activated
source venv/bin/activate

# Reinstall dependencies
pip install -r requirements.txt

# Verify installation
pip list | grep fastapi
```

### Issue 4: Gemini API Errors

**Symptom:**
```
google.api_core.exceptions.PermissionDenied: 403 API key not valid
```

**Solutions:**

1. **Verify API key:**
   - Check `backend/.env` for GEMINI_API_KEY
   - Ensure no extra spaces or quotes
   - Verify key at https://makersuite.google.com

2. **Test API key:**
   ```bash
   # Using curl
   curl -H "Content-Type: application/json" \
     -d '{"contents":[{"parts":[{"text":"Hello"}]}]}' \
     "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=YOUR_API_KEY"
   ```

3. **Check quota:**
   - Visit Google AI Studio
   - Check if you've hit rate limits
   - Free tier: 60 requests/minute

### Issue 5: CORS Errors

**Symptom:**
```
Access to fetch at 'http://localhost:8000' has been blocked by CORS policy
```

**Solution:**

1. **Check CORS_ORIGINS in backend/.env:**
   ```env
   CORS_ORIGINS=http://localhost:5173,http://localhost:3000
   ```

2. **Restart backend server** after changing .env

3. **Clear browser cache and cookies**

4. **Check backend logs** for CORS messages

### Issue 6: Frontend Build Errors

**Symptom:**
```
Error: Cannot find module '@monaco-editor/react'
```

**Solution:**
```bash
# Delete node_modules and package-lock.json
rm -rf node_modules package-lock.json

# Clear npm cache
npm cache clean --force

# Reinstall
npm install

# If still failing, try:
npm install --legacy-peer-deps
```

### Issue 7: TypeScript Errors

**Symptom:**
```
Property 'xxx' does not exist on type 'yyy'
```

**Solution:**
```bash
# Restart TypeScript server in VS Code
# Cmd/Ctrl + Shift + P -> "TypeScript: Restart TS Server"

# Or regenerate types
npm run type-check

# Update TypeScript if needed
npm install -D typescript@latest
```

---

## Development Workflow

### Daily Development

1. **Start your development session:**
   ```bash
   # Terminal 1: Backend
   cd backend
   source venv/bin/activate
   uvicorn app.main:app --reload

   # Terminal 2: Frontend
   cd frontend
   npm run dev

   # Terminal 3: Database (if needed)
   psql promptforge_db
   ```

2. **Make code changes**
   - Backend changes auto-reload with `--reload` flag
   - Frontend changes auto-refresh in browser
   - Database changes require manual migration

3. **Test your changes**
   - Use browser dev tools (F12) for frontend debugging
   - Check terminal output for backend logs
   - Use http://localhost:8000/docs for API testing

4. **Commit your work:**
   ```bash
   git add .
   git commit -m "Description of changes"
   git push
   ```

### Useful Commands

**Backend:**
```bash
# Run tests
pytest

# Format code
black app/

# Lint code
flake8 app/

# Check types
mypy app/

# Create database backup
pg_dump promptforge_db > backup.sql

# Restore database
psql promptforge_db < backup.sql
```

**Frontend:**
```bash
# Run linter
npm run lint

# Type check
npm run type-check

# Build for production
npm run build

# Preview production build
npm run preview
```

### Environment Switching

**Development:**
```env
ENVIRONMENT=development
ACCESS_TOKEN_EXPIRE_MINUTES=10080
```

**Production:**
```env
ENVIRONMENT=production
ACCESS_TOKEN_EXPIRE_MINUTES=60
SECRET_KEY=<strong-random-key>
```

---

## Next Steps

After successful setup:

1. **Read the Documentation**
   - [API_ENDPOINTS.md](API_ENDPOINTS.md) - API reference
   - [README.md](README.md) - Project overview
   - [BACKEND_COMPLETION_SUMMARY.md](BACKEND_COMPLETION_SUMMARY.md) - Backend details

2. **Explore the Features**
   - Create and analyze prompts
   - Test enhancement features
   - Try template creation
   - Check version history

3. **Start Development**
   - Pick a feature from the roadmap
   - Create a new branch
   - Implement and test
   - Submit a pull request

4. **Join the Community**
   - Report bugs and issues
   - Suggest new features
   - Contribute to documentation
   - Share your prompts and templates

---

## Getting Help

If you encounter issues not covered in this guide:

1. **Check existing documentation**
2. **Search GitHub issues**
3. **Check troubleshooting section**
4. **Ask in discussions**
5. **Contact support**

---

**Happy Coding! 🚀**

*PromptForge - Building better AI prompts together*

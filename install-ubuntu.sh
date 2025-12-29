#!/bin/bash

################################################################################
# PromptForge Installation Script for Ubuntu
################################################################################
#
# This script automates the installation and setup of PromptForge on a fresh
# Ubuntu system. It installs all required dependencies, configures the
# database, sets up environment variables, and prepares the application for
# first run.
#
# Usage:
#   sudo ./install-ubuntu.sh [OPTIONS]
#
# Options:
#   --skip-system-deps    Skip system package installation (if already installed)
#   --skip-db-setup       Skip PostgreSQL database setup
#   --seed-demo           Load demo data after installation
#   --production          Configure for production deployment
#   --help                Show this help message
#
# Requirements:
#   - Ubuntu 24.04 LTS or Ubuntu 22.04 LTS
#   - Sudo privileges
#   - Internet connection
#
# What this script does:
#   1. Verifies system compatibility
#   2. Installs system dependencies (PostgreSQL 14-16, Python 3.10-3.12, Node.js 20)
#   3. Creates PostgreSQL database and user
#   4. Sets up Python virtual environment
#   5. Installs backend Python dependencies
#   6. Installs frontend Node.js dependencies
#   7. Creates environment configuration files
#   8. Runs database migrations
#   9. Optionally seeds demo data
#   10. Provides startup instructions
#
# Author: PromptForge Team
# License: MIT
# Version: 1.0.4
#
################################################################################

set -e  # Exit immediately if a command exits with a non-zero status
set -u  # Treat unset variables as an error

################################################################################
# Color codes for terminal output
################################################################################

# ANSI color codes make output more readable
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

################################################################################
# Utility Functions
################################################################################

# Print colored messages for different log levels
print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Print a step message with a number
print_step() {
    echo ""
    echo -e "${CYAN}[$1] $2${NC}"
}

################################################################################
# Parse Command Line Arguments
################################################################################

SKIP_SYSTEM_DEPS=false
SKIP_DB_SETUP=false
SEED_DEMO=false
PRODUCTION=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-system-deps)
            SKIP_SYSTEM_DEPS=true
            shift
            ;;
        --skip-db-setup)
            SKIP_DB_SETUP=true
            shift
            ;;
        --seed-demo)
            SEED_DEMO=true
            shift
            ;;
        --production)
            PRODUCTION=true
            shift
            ;;
        --help)
            grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^# \?//'
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

################################################################################
# Pre-flight Checks
################################################################################

print_header "🚀 PromptForge Installation Script"

print_step "1/10" "Running pre-flight checks..."

# Check if running as root (needed for apt operations)
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run with sudo privileges"
    echo "Please run: sudo $0"
    exit 1
fi

# Verify Ubuntu version
# We need Ubuntu 24.04 for the correct package versions
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        print_warning "This script is designed for Ubuntu. Detected: $ID"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Check version number
    VERSION_NUM=$(echo "$VERSION_ID" | cut -d. -f1)
    if [[ "$VERSION_NUM" -lt 22 ]]; then
        print_error "Ubuntu 22.04 or higher required. Detected: $VERSION_ID"
        exit 1
    fi

    print_success "Running on $PRETTY_NAME"
else
    print_warning "Could not detect OS version"
fi

# Check for required commands
command -v sudo >/dev/null 2>&1 || { print_error "sudo is required but not installed. Aborting."; exit 1; }

print_success "Pre-flight checks passed"

################################################################################
# Install System Dependencies
################################################################################

if [ "$SKIP_SYSTEM_DEPS" = false ]; then
    print_step "2/10" "Installing system dependencies..."

    # Update package index
    # This ensures we get the latest package versions
    print_info "Updating package index..."
    apt-get update -qq

    # Install essential build tools
    # These are needed for compiling some Python packages
    print_info "Installing build essentials..."
    apt-get install -y -qq \
        build-essential \
        curl \
        wget \
        git \
        software-properties-common \
        ca-certificates \
        gnupg \
        lsb-release

    # Install PostgreSQL (detect available version)
    # PostgreSQL is our primary database
    print_info "Installing PostgreSQL..."

    # Detect available PostgreSQL version in repositories
    # Ubuntu 24.04 has PostgreSQL 16, Ubuntu 22.04 has PostgreSQL 14
    AVAILABLE_PG_VERSIONS=$(apt-cache search --names-only '^postgresql-[0-9]+$' | grep -oP 'postgresql-\K[0-9]+' | sort -rn)

    if [ -z "$AVAILABLE_PG_VERSIONS" ]; then
        print_error "No PostgreSQL packages found in repositories"
        exit 1
    fi

    # Get the latest available version
    PG_VERSION=$(echo "$AVAILABLE_PG_VERSIONS" | head -n1)
    print_info "Installing PostgreSQL $PG_VERSION (latest available)..."

    apt-get install -y -qq postgresql-$PG_VERSION postgresql-contrib-$PG_VERSION postgresql-client-$PG_VERSION

    # Install Python 3 (use system default version)
    # PromptForge requires Python 3.10+ for modern features
    # Ubuntu 24.04 → Python 3.12, Ubuntu 22.04 → Python 3.10
    print_info "Installing Python 3..."

    # Install default Python 3 and development tools
    apt-get install -y -qq \
        python3 \
        python3-venv \
        python3-dev \
        python3-pip

    # Detect installed Python version
    PYTHON_VERSION=$(python3 --version 2>&1 | grep -oP '\d+\.\d+' | head -1)
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

    print_info "Detected Python $PYTHON_VERSION"

    # Verify Python version is 3.10 or higher
    if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]; then
        print_warning "Python 3.10+ recommended, but found $PYTHON_VERSION"
        print_info "Attempting to install Python 3.11 from deadsnakes PPA..."

        # Add deadsnakes PPA for newer Python versions
        add-apt-repository -y ppa:deadsnakes/ppa
        apt-get update -qq

        apt-get install -y -qq \
            python3.11 \
            python3.11-venv \
            python3.11-dev

        # Set Python 3.11 as the default
        update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

        print_success "Installed Python 3.11 from deadsnakes PPA"
    fi

    # Install Node.js 20.x
    # Required for the React frontend
    print_info "Installing Node.js 20.x..."

    # Add NodeSource repository for Node.js 20
    # Ubuntu's default repos have older versions
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
        gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

    NODE_MAJOR=20
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | \
        tee /etc/apt/sources.list.d/nodesource.list

    apt-get update -qq
    apt-get install -y -qq nodejs

    # Install nginx (optional, for production)
    if [ "$PRODUCTION" = true ]; then
        print_info "Installing nginx for production deployment..."
        apt-get install -y -qq nginx
    fi

    print_success "System dependencies installed"
else
    print_warning "Skipping system dependency installation"
fi

################################################################################
# Verify Installed Versions
################################################################################

print_step "3/10" "Verifying installed versions..."

# Check PostgreSQL
PG_VERSION=$(psql --version | awk '{print $3}')
print_info "PostgreSQL version: $PG_VERSION"

# Check Python
PYTHON_VERSION=$(python3 --version | awk '{print $2}')
print_info "Python version: $PYTHON_VERSION"

# Check Node.js
NODE_VERSION=$(node --version)
print_info "Node.js version: $NODE_VERSION"

# Check npm
NPM_VERSION=$(npm --version)
print_info "npm version: $NPM_VERSION"

print_success "Version verification complete"

################################################################################
# Configure PostgreSQL Database
################################################################################

if [ "$SKIP_DB_SETUP" = false ]; then
    print_step "4/10" "Configuring PostgreSQL database..."

    # Start PostgreSQL service
    # Ensure it's running before we create databases
    systemctl start postgresql
    systemctl enable postgresql

    # Check if database and user already exist
    USER_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='promptforge'" 2>/dev/null || echo "0")
    DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='promptforge'" 2>/dev/null || echo "0")

    # Generate a secure random password for the database user
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

    if [ "$USER_EXISTS" = "1" ] || [ "$DB_EXISTS" = "1" ]; then
        print_warning "Database or user already exists - updating password..."

        # Update existing user's password and ensure database exists
        sudo -u postgres psql <<EOF
-- Update user password if exists, create if not
DO \$\$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='promptforge') THEN
        ALTER USER promptforge WITH PASSWORD '$DB_PASSWORD';
    ELSE
        CREATE USER promptforge WITH PASSWORD '$DB_PASSWORD';
    END IF;
END
\$\$;

-- Create database if it doesn't exist
SELECT 'CREATE DATABASE promptforge OWNER promptforge'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'promptforge')\gexec

-- Grant all privileges
GRANT ALL PRIVILEGES ON DATABASE promptforge TO promptforge;

-- Connect to database and set permissions
\c promptforge

-- Grant schema permissions
GRANT ALL ON SCHEMA public TO promptforge;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO promptforge;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO promptforge;
\q
EOF
    else
        print_info "Creating PostgreSQL user and database..."

        # Run psql commands as the postgres user
        sudo -u postgres psql <<EOF
-- Create the database user
CREATE USER promptforge WITH PASSWORD '$DB_PASSWORD';

-- Create the database
CREATE DATABASE promptforge OWNER promptforge;

-- Grant all privileges
GRANT ALL PRIVILEGES ON DATABASE promptforge TO promptforge;

-- Connect to database and set permissions
\c promptforge

-- Grant schema permissions
GRANT ALL ON SCHEMA public TO promptforge;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO promptforge;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO promptforge;
\q
EOF
    fi

    # Save database credentials to a secure file
    # This will be used to generate the .env file
    cat > /tmp/db_credentials.txt <<EOF
DATABASE_URL=postgresql://promptforge:$DB_PASSWORD@localhost:5432/promptforge
DB_HOST=localhost
DB_PORT=5432
DB_NAME=promptforge
DB_USER=promptforge
DB_PASSWORD=$DB_PASSWORD
EOF

    chmod 600 /tmp/db_credentials.txt

    print_success "Database configured successfully"
    print_info "Database credentials saved to /tmp/db_credentials.txt"
else
    print_warning "Skipping database setup"
fi

################################################################################
# Set Up Project Directory
################################################################################

print_step "5/10" "Setting up project directory..."

# Get the directory where this script is located
# This should be the PromptForge root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

print_info "Working directory: $SCRIPT_DIR"

# Verify we're in the PromptForge directory
# Check for key files to ensure we're in the right place
if [ ! -f "README.md" ] || [ ! -d "backend" ] || [ ! -d "frontend" ]; then
    print_error "This doesn't appear to be the PromptForge root directory"
    print_error "Please run this script from the PromptForge root directory"
    exit 1
fi

print_success "Project directory validated"

################################################################################
# Set Up Backend
################################################################################

print_step "6/10" "Setting up backend..."

cd backend

# Create Python virtual environment
# This isolates our Python packages from the system
print_info "Creating Python virtual environment..."
python3 -m venv venv

# Activate virtual environment
# All pip installs will go into this venv
source venv/bin/activate

# Upgrade pip to the latest version
# Newer pip has better dependency resolution
print_info "Upgrading pip..."
pip install --upgrade pip -q

# Install backend dependencies
# requirements.txt contains all production dependencies
print_info "Installing backend dependencies..."
pip install -r requirements.txt -q

# Install test dependencies if in development mode
if [ "$PRODUCTION" = false ]; then
    print_info "Installing test dependencies..."
    pip install -r requirements-test.txt -q
fi

print_success "Backend dependencies installed"

# Create .env file for backend
print_info "Creating backend .env file..."

# Generate a secure secret key for JWT tokens
SECRET_KEY=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)

# Read database credentials
if [ -f /tmp/db_credentials.txt ]; then
    source /tmp/db_credentials.txt
else
    # Use default values if database setup was skipped
    DATABASE_URL="postgresql://promptforge:password@localhost:5432/promptforge"
fi

# Create .env file with all necessary variables
cat > .env <<EOF
# Database Configuration
DATABASE_URL=$DATABASE_URL

# Security
SECRET_KEY=$SECRET_KEY
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# API Keys
# Get your Gemini API key from: https://makersuite.google.com/app/apikey
GEMINI_API_KEY=your-gemini-api-key-here

# Environment
ENVIRONMENT=$([ "$PRODUCTION" = true ] && echo "production" || echo "development")

# CORS Settings
# Add your frontend URL here
CORS_ORIGINS=["http://localhost:5173","http://localhost:3000","http://localhost"]

# Rate Limiting
RATE_LIMIT_ENABLED=true
RATE_LIMIT_PER_MINUTE=60

# Logging
LOG_LEVEL=$([ "$PRODUCTION" = true ] && echo "INFO" || echo "DEBUG")
EOF

chmod 600 .env

print_success "Backend .env file created"
print_warning "⚠️  IMPORTANT: Edit backend/.env and add your GEMINI_API_KEY"

cd ..

################################################################################
# Set Up Frontend
################################################################################

print_step "7/10" "Setting up frontend..."

cd frontend

# Install Node.js dependencies
# This may take several minutes
print_info "Installing frontend dependencies (this may take a while)..."
npm install --legacy-peer-deps

# Create .env file for frontend
print_info "Creating frontend .env file..."

cat > .env <<EOF
# API Configuration
VITE_API_URL=$([ "$PRODUCTION" = true ] && echo "https://your-domain.com/api" || echo "http://localhost:8000/api")

# Environment
VITE_ENVIRONMENT=$([ "$PRODUCTION" = true ] && echo "production" || echo "development")

# Feature Flags
VITE_ENABLE_ANALYTICS=false
VITE_ENABLE_DEMO_MODE=true
EOF

chmod 600 .env

print_success "Frontend dependencies installed"
print_success "Frontend .env file created"

cd ..

################################################################################
# Run Database Migrations
################################################################################

print_step "8/10" "Running database migrations..."

cd backend

# Activate virtual environment
source venv/bin/activate

# Initialize Alembic if not already done
# Alembic handles database schema migrations
if [ ! -d "alembic/versions" ]; then
    print_info "Initializing Alembic..."
    mkdir -p alembic/versions
fi

# Run migrations to create all database tables
print_info "Applying database migrations..."
alembic upgrade head

print_success "Database migrations complete"

cd ..

################################################################################
# Seed Demo Data (Optional)
################################################################################

if [ "$SEED_DEMO" = true ]; then
    print_step "9/10" "Seeding demo data..."

    cd backend
    source venv/bin/activate

    print_info "Running seed script..."
    python scripts/seed_data.py

    print_success "Demo data seeded successfully"
    print_info "Demo account - Username: demo, Password: DemoPassword123!"

    cd ..
else
    print_step "9/10" "Skipping demo data (use --seed-demo to enable)"
fi

################################################################################
# Clean Up
################################################################################

print_step "10/10" "Cleaning up..."

# Remove temporary credentials file
if [ -f /tmp/db_credentials.txt ]; then
    rm -f /tmp/db_credentials.txt
fi

# Deactivate virtual environment
deactivate 2>/dev/null || true

print_success "Cleanup complete"

################################################################################
# Installation Complete
################################################################################

print_header "✅ Installation Complete!"

echo ""
echo -e "${GREEN}PromptForge has been successfully installed!${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${CYAN}📝 Next Steps:${NC}"
echo ""
echo "1. Configure API Keys:"
echo "   Edit backend/.env and add your Gemini API key:"
echo -e "   ${YELLOW}nano backend/.env${NC}"
echo ""
echo "2. Start the Backend:"
echo -e "   ${YELLOW}cd backend${NC}"
echo -e "   ${YELLOW}source venv/bin/activate${NC}"
echo -e "   ${YELLOW}uvicorn app.main:app --reload${NC}"
echo ""
echo "3. Start the Frontend (in a new terminal):"
echo -e "   ${YELLOW}cd frontend${NC}"
echo -e "   ${YELLOW}npm run dev${NC}"
echo ""
echo "4. Access the Application:"
echo -e "   Frontend: ${CYAN}http://localhost:5173${NC}"
echo -e "   Backend:  ${CYAN}http://localhost:8000${NC}"
echo -e "   API Docs: ${CYAN}http://localhost:8000/docs${NC}"
echo ""

if [ "$SEED_DEMO" = true ]; then
    echo "5. Demo Account (already seeded):"
    echo -e "   Username: ${GREEN}demo${NC}"
    echo -e "   Password: ${GREEN}DemoPassword123!${NC}"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${CYAN}📚 Documentation:${NC}"
echo "   User Guide:     docs/user-guide.md"
echo "   API Reference:  docs/api-reference.md"
echo "   Development:    docs/development.md"
echo ""
echo -e "${CYAN}🛠️  Troubleshooting:${NC}"
echo "   If you encounter issues, check:"
echo "   - docs/troubleshooting.md"
echo "   - Backend logs: backend/logs/"
echo "   - Database connection: psql -U promptforge -d promptforge"
echo ""
echo -e "${GREEN}Happy Prompt Engineering! 🚀${NC}"
echo ""

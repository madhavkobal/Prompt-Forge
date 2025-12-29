#!/bin/bash

################################################################################
# PromptForge SSL Certificate Setup Script
################################################################################
#
# This script sets up SSL certificates for PromptForge:
#   - Self-signed certificates (for development/testing)
#   - Let's Encrypt certificates (for production)
#   - Custom certificate installation
#
# Usage:
#   sudo ./init-ssl.sh [--self-signed|--letsencrypt|--custom]
#
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SSL_MODE="self-signed"
DOMAIN=""
EMAIL=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# SSL paths
SSL_DIR="$PROJECT_ROOT/ssl"
CERT_DIR="$SSL_DIR/certs"
KEY_DIR="$SSL_DIR/private"

################################################################################
# Helper Functions
################################################################################

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

################################################################################
# Check Root
################################################################################

if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root"
    echo "Please run: sudo $0"
    exit 1
fi

################################################################################
# Parse Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --self-signed)
            SSL_MODE="self-signed"
            shift
            ;;
        --letsencrypt)
            SSL_MODE="letsencrypt"
            shift
            ;;
        --custom)
            SSL_MODE="custom"
            shift
            ;;
        --domain=*)
            DOMAIN="${1#*=}"
            shift
            ;;
        --email=*)
            EMAIL="${1#*=}"
            shift
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

################################################################################
# SSL Header
################################################################################

clear
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║        PromptForge SSL Certificate Setup                   ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
log "SSL Mode: $SSL_MODE"
echo ""

################################################################################
# Create Directories
################################################################################

log "Creating SSL directories..."

mkdir -p "$CERT_DIR"
mkdir -p "$KEY_DIR"

chmod 755 "$CERT_DIR"
chmod 700 "$KEY_DIR"

success "SSL directories created"

################################################################################
# Self-Signed Certificate
################################################################################

if [ "$SSL_MODE" = "self-signed" ]; then
    log "Generating self-signed certificate..."

    # Prompt for domain if not provided
    if [ -z "$DOMAIN" ]; then
        read -p "Enter domain name (default: localhost): " DOMAIN
        DOMAIN=${DOMAIN:-localhost}
    fi

    # Generate private key
    openssl genrsa -out "$KEY_DIR/server.key" 4096

    # Generate certificate signing request
    openssl req -new -key "$KEY_DIR/server.key" -out "$SSL_DIR/server.csr" \
        -subj "/C=US/ST=State/L=City/O=PromptForge/OU=IT/CN=$DOMAIN"

    # Generate self-signed certificate (valid for 365 days)
    openssl x509 -req -days 365 -in "$SSL_DIR/server.csr" \
        -signkey "$KEY_DIR/server.key" -out "$CERT_DIR/server.crt"

    # Create certificate chain
    cp "$CERT_DIR/server.crt" "$CERT_DIR/fullchain.pem"

    # Create DH parameters
    log "Generating Diffie-Hellman parameters (this may take a while)..."
    openssl dhparam -out "$SSL_DIR/dhparam.pem" 2048

    # Set permissions
    chmod 600 "$KEY_DIR/server.key"
    chmod 644 "$CERT_DIR/server.crt"
    chmod 644 "$CERT_DIR/fullchain.pem"
    chmod 644 "$SSL_DIR/dhparam.pem"

    success "Self-signed certificate generated"

    warning "This is a self-signed certificate. Browsers will show a security warning."
    log "For production, use --letsencrypt or --custom"

################################################################################
# Let's Encrypt Certificate
################################################################################

elif [ "$SSL_MODE" = "letsencrypt" ]; then
    log "Setting up Let's Encrypt certificate..."

    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        error "certbot is not installed"
        echo "Run: sudo apt-get install certbot python3-certbot-nginx"
        exit 1
    fi

    # Prompt for domain if not provided
    if [ -z "$DOMAIN" ]; then
        read -p "Enter domain name: " DOMAIN
        if [ -z "$DOMAIN" ]; then
            error "Domain name is required for Let's Encrypt"
            exit 1
        fi
    fi

    # Prompt for email if not provided
    if [ -z "$EMAIL" ]; then
        read -p "Enter email address: " EMAIL
        if [ -z "$EMAIL" ]; then
            error "Email is required for Let's Encrypt"
            exit 1
        fi
    fi

    log "Obtaining certificate for: $DOMAIN"
    log "Email: $EMAIL"

    # Stop nginx if running
    if systemctl is-active --quiet nginx; then
        systemctl stop nginx
        NGINX_WAS_RUNNING=true
    fi

    # Obtain certificate
    certbot certonly --standalone \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        -d "$DOMAIN"

    # Create symbolic links
    ln -sf "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$CERT_DIR/fullchain.pem"
    ln -sf "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$KEY_DIR/server.key"
    ln -sf "/etc/letsencrypt/live/$DOMAIN/cert.pem" "$CERT_DIR/server.crt"

    # Generate DH parameters if not exists
    if [ ! -f "$SSL_DIR/dhparam.pem" ]; then
        log "Generating Diffie-Hellman parameters..."
        openssl dhparam -out "$SSL_DIR/dhparam.pem" 2048
    fi

    # Set up auto-renewal
    log "Setting up automatic renewal..."

    # Create renewal hook
    cat > /etc/letsencrypt/renewal-hooks/deploy/promptforge.sh << EOF
#!/bin/bash
# Reload nginx after certificate renewal
systemctl reload nginx 2>/dev/null || docker-compose -f $PROJECT_ROOT/docker-compose.yml restart nginx
EOF

    chmod +x /etc/letsencrypt/renewal-hooks/deploy/promptforge.sh

    # Add cron job for renewal check (if not exists)
    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
        (crontab -l 2>/dev/null; echo "0 0,12 * * * certbot renew --quiet") | crontab -
        log "Added certbot renewal cron job"
    fi

    # Restart nginx if it was running
    if [ "$NGINX_WAS_RUNNING" = true ]; then
        systemctl start nginx
    fi

    success "Let's Encrypt certificate obtained"
    log "Certificate will auto-renew before expiration"

################################################################################
# Custom Certificate
################################################################################

elif [ "$SSL_MODE" = "custom" ]; then
    log "Installing custom certificate..."

    echo ""
    log "Please provide the following files:"
    echo ""

    # Prompt for certificate file
    read -p "Path to certificate file (.crt): " CERT_FILE
    if [ ! -f "$CERT_FILE" ]; then
        error "Certificate file not found: $CERT_FILE"
        exit 1
    fi

    # Prompt for private key file
    read -p "Path to private key file (.key): " KEY_FILE
    if [ ! -f "$KEY_FILE" ]; then
        error "Private key file not found: $KEY_FILE"
        exit 1
    fi

    # Prompt for CA bundle (optional)
    read -p "Path to CA bundle file (optional, press Enter to skip): " CA_FILE

    # Copy certificate
    cp "$CERT_FILE" "$CERT_DIR/server.crt"
    chmod 644 "$CERT_DIR/server.crt"
    success "Certificate installed"

    # Copy private key
    cp "$KEY_FILE" "$KEY_DIR/server.key"
    chmod 600 "$KEY_DIR/server.key"
    success "Private key installed"

    # Create fullchain
    if [ -n "$CA_FILE" ] && [ -f "$CA_FILE" ]; then
        cat "$CERT_FILE" "$CA_FILE" > "$CERT_DIR/fullchain.pem"
        success "Certificate chain created"
    else
        cp "$CERT_FILE" "$CERT_DIR/fullchain.pem"
        warning "No CA bundle provided, using certificate only"
    fi

    chmod 644 "$CERT_DIR/fullchain.pem"

    # Generate DH parameters if not exists
    if [ ! -f "$SSL_DIR/dhparam.pem" ]; then
        log "Generating Diffie-Hellman parameters..."
        openssl dhparam -out "$SSL_DIR/dhparam.pem" 2048
        chmod 644 "$SSL_DIR/dhparam.pem"
    fi

    success "Custom certificate installed"
fi

################################################################################
# Verify Certificate
################################################################################

log "Verifying certificate..."

# Check certificate validity
if openssl x509 -in "$CERT_DIR/server.crt" -noout -text &>/dev/null; then
    success "Certificate is valid"

    # Display certificate info
    CERT_SUBJECT=$(openssl x509 -in "$CERT_DIR/server.crt" -noout -subject | sed 's/subject=//')
    CERT_ISSUER=$(openssl x509 -in "$CERT_DIR/server.crt" -noout -issuer | sed 's/issuer=//')
    CERT_DATES=$(openssl x509 -in "$CERT_DIR/server.crt" -noout -dates)
    CERT_NOT_BEFORE=$(echo "$CERT_DATES" | grep notBefore | sed 's/notBefore=//')
    CERT_NOT_AFTER=$(echo "$CERT_DATES" | grep notAfter | sed 's/notAfter=//')

    echo ""
    log "Certificate Information:"
    echo "  Subject: $CERT_SUBJECT"
    echo "  Issuer: $CERT_ISSUER"
    echo "  Valid From: $CERT_NOT_BEFORE"
    echo "  Valid Until: $CERT_NOT_AFTER"
    echo ""
else
    error "Certificate validation failed"
    exit 1
fi

# Check private key
if openssl rsa -in "$KEY_DIR/server.key" -check -noout &>/dev/null; then
    success "Private key is valid"
else
    error "Private key validation failed"
    exit 1
fi

# Check if certificate and key match
CERT_MODULUS=$(openssl x509 -in "$CERT_DIR/server.crt" -noout -modulus | md5sum)
KEY_MODULUS=$(openssl rsa -in "$KEY_DIR/server.key" -noout -modulus | md5sum)

if [ "$CERT_MODULUS" = "$KEY_MODULUS" ]; then
    success "Certificate and private key match"
else
    error "Certificate and private key do not match!"
    exit 1
fi

################################################################################
# Update Nginx Configuration
################################################################################

log "Updating Nginx configuration..."

# Update nginx config to use SSL
if [ -f "$PROJECT_ROOT/nginx/nginx.conf" ]; then
    # Backup existing config
    cp "$PROJECT_ROOT/nginx/nginx.conf" "$PROJECT_ROOT/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)"

    # Update SSL paths (if they exist in config)
    sed -i "s|ssl_certificate .*|ssl_certificate /etc/nginx/ssl/certs/fullchain.pem;|g" "$PROJECT_ROOT/nginx/nginx.conf"
    sed -i "s|ssl_certificate_key .*|ssl_certificate_key /etc/nginx/ssl/private/server.key;|g" "$PROJECT_ROOT/nginx/nginx.conf"
    sed -i "s|ssl_dhparam .*|ssl_dhparam /etc/nginx/ssl/dhparam.pem;|g" "$PROJECT_ROOT/nginx/nginx.conf"

    success "Nginx configuration updated"
fi

################################################################################
# Security Recommendations
################################################################################

echo ""
echo "=========================================="
echo "  SSL Setup Complete"
echo "=========================================="
echo ""
success "SSL certificates installed successfully!"
echo ""
log "Certificate files:"
echo "  • Certificate: $CERT_DIR/server.crt"
echo "  • Private Key: $KEY_DIR/server.key"
echo "  • Full Chain: $CERT_DIR/fullchain.pem"
echo "  • DH Params: $SSL_DIR/dhparam.pem"
echo ""

if [ "$SSL_MODE" = "self-signed" ]; then
    warning "Using self-signed certificate"
    log "For production, obtain a certificate from a trusted CA"
    echo ""
    log "Test with:"
    echo "  curl -k https://localhost"
    echo "  openssl s_client -connect localhost:443"
elif [ "$SSL_MODE" = "letsencrypt" ]; then
    log "Let's Encrypt certificate is production-ready"
    log "Auto-renewal is configured via cron"
    echo ""
    log "Test with:"
    echo "  curl https://$DOMAIN"
    echo "  openssl s_client -connect $DOMAIN:443"
fi

echo ""
log "Next steps:"
echo "  1. Review Nginx configuration: $PROJECT_ROOT/nginx/nginx.conf"
echo "  2. Deploy application: sudo ./deploy/initial/first-deploy.sh"
echo "  3. Test HTTPS access"
echo ""

exit 0

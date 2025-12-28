#!/bin/bash

################################################################################
# SSL/TLS Certificate Setup Script for PromptForge
################################################################################
#
# This script helps you set up SSL certificates for production deployment.
# It supports three methods:
#   1. Let's Encrypt (recommended for production)
#   2. Self-signed certificates (development/testing)
#   3. Corporate CA certificates (enterprise environments)
#
# Usage:
#   ./ssl-setup.sh [letsencrypt|self-signed|corporate]
#
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directories
SSL_DIR="./nginx/ssl"
LETSENCRYPT_DIR="$SSL_DIR/letsencrypt"
CERTBOT_DIR="$SSL_DIR/certbot"

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
# Check Prerequisites
################################################################################

check_prerequisites() {
    log "Checking prerequisites..."

    # Check if .env.production exists
    if [[ ! -f .env.production ]]; then
        error ".env.production not found. Please create it first."
        exit 1
    fi

    # Create SSL directories
    mkdir -p "$SSL_DIR" "$LETSENCRYPT_DIR" "$CERTBOT_DIR"

    success "Prerequisites checked"
}

################################################################################
# Let's Encrypt Setup
################################################################################

setup_letsencrypt() {
    log "Setting up Let's Encrypt SSL certificates..."

    # Check if domain is set
    source .env.production
    if [[ -z "${DOMAIN:-}" ]]; then
        error "DOMAIN not set in .env.production"
        echo "Add: DOMAIN=yourdomain.com"
        exit 1
    fi

    if [[ -z "${CERTBOT_EMAIL:-}" ]]; then
        error "CERTBOT_EMAIL not set in .env.production"
        echo "Add: CERTBOT_EMAIL=admin@yourdomain.com"
        exit 1
    fi

    log "Domain: $DOMAIN"
    log "Email: $CERTBOT_EMAIL"

    # Check if port 80 is accessible
    warning "Make sure port 80 is accessible from the internet for ACME validation"
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi

    # Start nginx without SSL for ACME challenge
    log "Starting nginx for ACME challenge..."
    docker-compose -f docker-compose.prod.yml up -d nginx

    # Wait for nginx to start
    sleep 5

    # Request certificate
    log "Requesting certificate from Let's Encrypt..."
    docker-compose -f docker-compose.prod.yml -f docker-compose.ssl.yml run --rm certbot \
        certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$CERTBOT_EMAIL" \
        --agree-tos \
        --no-eff-email \
        -d "$DOMAIN" \
        -d "www.$DOMAIN"

    if [[ $? -eq 0 ]]; then
        success "Certificate obtained successfully!"

        # Create symlinks for nginx
        ln -sf "$LETSENCRYPT_DIR/live/$DOMAIN/fullchain.pem" "$SSL_DIR/cert.pem"
        ln -sf "$LETSENCRYPT_DIR/live/$DOMAIN/privkey.pem" "$SSL_DIR/key.pem"

        # Generate DH parameters
        generate_dhparam

        # Reload nginx
        log "Reloading nginx with SSL configuration..."
        docker-compose -f docker-compose.prod.yml exec nginx nginx -s reload

        success "SSL setup complete!"
        log "Certificate location: $LETSENCRYPT_DIR/live/$DOMAIN/"

        # Setup auto-renewal
        setup_auto_renewal
    else
        error "Failed to obtain certificate"
        exit 1
    fi
}

################################################################################
# Self-Signed Certificate
################################################################################

setup_self_signed() {
    log "Generating self-signed SSL certificate..."

    # Get domain from env or prompt
    source .env.production 2>/dev/null || true
    DOMAIN=${DOMAIN:-localhost}

    echo ""
    echo "This will create a self-signed certificate valid for 365 days."
    echo "Self-signed certificates should only be used for development/testing."
    echo ""
    read -p "Domain name (default: $DOMAIN): " input_domain
    DOMAIN=${input_domain:-$DOMAIN}

    # Certificate details
    COUNTRY="US"
    STATE="State"
    CITY="City"
    ORG="PromptForge"
    OU="IT"

    log "Generating certificate for: $DOMAIN"

    # Generate private key and certificate
    openssl req -x509 \
        -nodes \
        -days 365 \
        -newkey rsa:4096 \
        -keyout "$SSL_DIR/key.pem" \
        -out "$SSL_DIR/cert.pem" \
        -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$OU/CN=$DOMAIN" \
        -addext "subjectAltName=DNS:$DOMAIN,DNS:www.$DOMAIN,DNS:localhost"

    if [[ $? -eq 0 ]]; then
        # Set permissions
        chmod 600 "$SSL_DIR/key.pem"
        chmod 644 "$SSL_DIR/cert.pem"

        # Generate DH parameters
        generate_dhparam

        success "Self-signed certificate created!"
        log "Certificate: $SSL_DIR/cert.pem"
        log "Private key: $SSL_DIR/key.pem"

        warning "This certificate is self-signed and will show security warnings in browsers."
        warning "Use Let's Encrypt for production deployments."

        # Show certificate info
        log "Certificate details:"
        openssl x509 -in "$SSL_DIR/cert.pem" -noout -subject -dates
    else
        error "Failed to generate certificate"
        exit 1
    fi
}

################################################################################
# Corporate CA Certificate
################################################################################

setup_corporate() {
    log "Setting up corporate CA certificate..."

    echo ""
    echo "For corporate CA certificates, you need:"
    echo "  1. Certificate file (cert.pem or cert.crt)"
    echo "  2. Private key file (key.pem or key.key)"
    echo "  3. (Optional) Intermediate/chain certificates"
    echo ""

    read -p "Path to certificate file: " cert_path
    read -p "Path to private key file: " key_path
    read -p "Path to CA chain file (optional, press Enter to skip): " chain_path

    # Validate files exist
    if [[ ! -f "$cert_path" ]]; then
        error "Certificate file not found: $cert_path"
        exit 1
    fi

    if [[ ! -f "$key_path" ]]; then
        error "Private key file not found: $key_path"
        exit 1
    fi

    # Copy certificate and key
    log "Installing certificate..."
    cp "$cert_path" "$SSL_DIR/cert.pem"
    cp "$key_path" "$SSL_DIR/key.pem"

    # If chain file provided, append to certificate
    if [[ -n "$chain_path" && -f "$chain_path" ]]; then
        log "Including certificate chain..."
        cat "$chain_path" >> "$SSL_DIR/cert.pem"
    fi

    # Set permissions
    chmod 600 "$SSL_DIR/key.pem"
    chmod 644 "$SSL_DIR/cert.pem"

    # Generate DH parameters
    generate_dhparam

    # Validate certificate
    log "Validating certificate..."
    if openssl x509 -in "$SSL_DIR/cert.pem" -noout -text >/dev/null 2>&1; then
        success "Certificate installed successfully!"

        # Show certificate info
        log "Certificate details:"
        openssl x509 -in "$SSL_DIR/cert.pem" -noout -subject -issuer -dates
    else
        error "Certificate validation failed"
        exit 1
    fi
}

################################################################################
# Generate DH Parameters
################################################################################

generate_dhparam() {
    if [[ -f "$SSL_DIR/dhparam.pem" ]]; then
        log "DH parameters already exist"
        return
    fi

    log "Generating DH parameters (this may take several minutes)..."
    openssl dhparam -out "$SSL_DIR/dhparam.pem" 2048

    if [[ $? -eq 0 ]]; then
        chmod 644 "$SSL_DIR/dhparam.pem"
        success "DH parameters generated"
    else
        warning "Failed to generate DH parameters (optional)"
    fi
}

################################################################################
# Auto-Renewal Setup
################################################################################

setup_auto_renewal() {
    log "Setting up automatic certificate renewal..."

    # Create renewal script
    cat > /tmp/renew-cert.sh << 'EOF'
#!/bin/bash
# PromptForge SSL Certificate Renewal Script
cd /opt/promptforge
docker-compose -f docker-compose.prod.yml -f docker-compose.ssl.yml run --rm certbot renew --quiet
if [ $? -eq 0 ]; then
    docker-compose -f docker-compose.prod.yml exec nginx nginx -s reload
    echo "Certificate renewed successfully"
fi
EOF

    chmod +x /tmp/renew-cert.sh

    log "Add this to crontab for automatic renewal:"
    echo ""
    echo -e "${GREEN}0 0,12 * * * /opt/promptforge/renew-cert.sh >> /var/log/certbot-renew.log 2>&1${NC}"
    echo ""
    echo "This will attempt renewal twice daily (certificates renew when <30 days remain)"
}

################################################################################
# Test SSL Configuration
################################################################################

test_ssl() {
    log "Testing SSL configuration..."

    if [[ ! -f "$SSL_DIR/cert.pem" || ! -f "$SSL_DIR/key.pem" ]]; then
        error "SSL certificates not found"
        return 1
    fi

    # Verify certificate and key match
    cert_modulus=$(openssl x509 -noout -modulus -in "$SSL_DIR/cert.pem" | openssl md5)
    key_modulus=$(openssl rsa -noout -modulus -in "$SSL_DIR/key.pem" 2>/dev/null | openssl md5)

    if [[ "$cert_modulus" == "$key_modulus" ]]; then
        success "Certificate and key match"
    else
        error "Certificate and key do not match!"
        return 1
    fi

    # Check certificate expiration
    expiry_date=$(openssl x509 -enddate -noout -in "$SSL_DIR/cert.pem" | cut -d= -f2)
    log "Certificate expires: $expiry_date"

    # Test nginx configuration
    if docker-compose -f docker-compose.prod.yml ps nginx | grep -q "Up"; then
        log "Testing nginx SSL configuration..."
        docker-compose -f docker-compose.prod.yml exec nginx nginx -t
    fi

    success "SSL configuration test complete"
}

################################################################################
# Main Script
################################################################################

echo "=================================="
echo "  PromptForge SSL Setup"
echo "=================================="
echo ""

check_prerequisites

# Determine setup method
if [[ $# -eq 0 ]]; then
    echo "Select SSL certificate type:"
    echo "  1) Let's Encrypt (recommended for production)"
    echo "  2) Self-signed (development/testing)"
    echo "  3) Corporate CA (enterprise)"
    echo ""
    read -p "Choice (1-3): " choice

    case $choice in
        1) METHOD="letsencrypt" ;;
        2) METHOD="self-signed" ;;
        3) METHOD="corporate" ;;
        *) error "Invalid choice"; exit 1 ;;
    esac
else
    METHOD="$1"
fi

# Execute selected method
case $METHOD in
    letsencrypt)
        setup_letsencrypt
        ;;
    self-signed)
        setup_self_signed
        ;;
    corporate)
        setup_corporate
        ;;
    test)
        test_ssl
        ;;
    *)
        error "Unknown method: $METHOD"
        echo "Usage: $0 [letsencrypt|self-signed|corporate|test]"
        exit 1
        ;;
esac

echo ""
success "=================================="
success "  SSL Setup Complete!"
success "=================================="
echo ""
log "Next steps:"
log "  1. Review nginx SSL configuration in nginx/conf.d/ssl.conf"
log "  2. Start/restart services: docker-compose -f docker-compose.prod.yml up -d"
log "  3. Test HTTPS: https://your-domain.com"
log "  4. Run SSL test: ./ssl-setup.sh test"
echo ""

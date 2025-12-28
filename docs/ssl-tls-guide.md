# SSL/TLS Certificate Management Guide

Complete guide for managing SSL/TLS certificates in PromptForge production deployments.

## Table of Contents

1. [Overview](#overview)
2. [Certificate Types](#certificate-types)
3. [Let's Encrypt Setup](#lets-encrypt-setup)
4. [Self-Signed Certificates](#self-signed-certificates)
5. [Corporate CA Certificates](#corporate-ca-certificates)
6. [Certificate Renewal](#certificate-renewal)
7. [SSL Configuration](#ssl-configuration)
8. [Testing and Validation](#testing-and-validation)
9. [Troubleshooting](#troubleshooting)

---

## Overview

PromptForge supports three SSL/TLS certificate management methods:

| Method | Use Case | Cost | Auto-Renewal | Trust Level |
|--------|----------|------|--------------|-------------|
| **Let's Encrypt** | Production | Free | Yes | Publicly trusted |
| **Self-Signed** | Development/Testing | Free | N/A | Not trusted |
| **Corporate CA** | Enterprise | Varies | Manual | Org-trusted |

**Recommended:** Let's Encrypt for production deployments.

---

## Certificate Types

### 1. Let's Encrypt (Recommended)

**Pros:**
- ✅ Free certificates
- ✅ Automatic renewal
- ✅ Trusted by all browsers
- ✅ Easy setup with Certbot
- ✅ Wildcard support (DNS challenge)

**Cons:**
- ❌ Requires public domain
- ❌ 90-day validity (needs renewal)
- ❌ Rate limits apply

**Best For:** Public-facing production deployments

### 2. Self-Signed Certificates

**Pros:**
- ✅ No external dependencies
- ✅ Works offline
- ✅ Instant generation
- ✅ Free

**Cons:**
- ❌ Browser warnings
- ❌ Not trusted by default
- ❌ Manual distribution needed

**Best For:** Development, testing, internal tools

### 3. Corporate CA Certificates

**Pros:**
- ✅ Organization-wide trust
- ✅ Longer validity (1-2 years)
- ✅ Internal CA control
- ✅ No rate limits

**Cons:**
- ❌ Requires CA infrastructure
- ❌ Manual renewal process
- ❌ Not publicly trusted

**Best For:** Enterprise environments with existing PKI

---

## Let's Encrypt Setup

### Quick Start

```bash
# Run the SSL setup script
./ssl-setup.sh letsencrypt
```

### Manual Setup

**Step 1: Configure Environment**

Add to `.env.production`:

```env
DOMAIN=yourdomain.com
CERTBOT_EMAIL=admin@yourdomain.com
```

**Step 2: Ensure DNS is Configured**

```bash
# Verify DNS points to your server
dig +short yourdomain.com
nslookup yourdomain.com
```

**Step 3: Open Port 80**

```bash
# Let's Encrypt needs port 80 for validation
sudo ufw allow 80/tcp
sudo ufw status
```

**Step 4: Start Nginx (HTTP mode)**

```bash
docker-compose -f docker-compose.prod.yml up -d nginx
```

**Step 5: Request Certificate**

```bash
# Using Docker Compose
docker-compose -f docker-compose.prod.yml -f docker-compose.ssl.yml run --rm certbot \
  certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email admin@yourdomain.com \
  --agree-tos \
  --no-eff-email \
  -d yourdomain.com \
  -d www.yourdomain.com
```

**Step 6: Create Symlinks**

```bash
# Link certificates for nginx
ln -sf nginx/ssl/letsencrypt/live/yourdomain.com/fullchain.pem nginx/ssl/cert.pem
ln -sf nginx/ssl/letsencrypt/live/yourdomain.com/privkey.pem nginx/ssl/key.pem
```

**Step 7: Generate DH Parameters**

```bash
# For enhanced security (takes 5-10 minutes)
openssl dhparam -out nginx/ssl/dhparam.pem 2048
```

**Step 8: Enable HTTPS**

```bash
# Restart nginx with SSL configuration
docker-compose -f docker-compose.prod.yml restart nginx
```

**Step 9: Test**

```bash
# Test HTTPS
curl -I https://yourdomain.com

# Verify redirect
curl -I http://yourdomain.com
```

### Wildcard Certificates

For wildcard certificates (*.yourdomain.com), use DNS challenge:

```bash
docker-compose run --rm certbot \
  certonly \
  --manual \
  --preferred-challenges dns \
  --email admin@yourdomain.com \
  --agree-tos \
  -d "*.yourdomain.com" \
  -d yourdomain.com
```

Follow the prompts to add DNS TXT records.

---

## Self-Signed Certificates

### Quick Start

```bash
# Run the SSL setup script
./ssl-setup.sh self-signed
```

### Manual Generation

**Generate Certificate:**

```bash
# Create directory
mkdir -p nginx/ssl

# Generate certificate (valid for 1 year)
openssl req -x509 \
  -nodes \
  -days 365 \
  -newkey rsa:4096 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem \
  -subj "/C=US/ST=State/L=City/O=PromptForge/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,DNS:*.localhost,IP:127.0.0.1"
```

**Set Permissions:**

```bash
chmod 600 nginx/ssl/key.pem
chmod 644 nginx/ssl/cert.pem
```

**Generate DH Parameters:**

```bash
openssl dhparam -out nginx/ssl/dhparam.pem 2048
```

### Trust Self-Signed Certificate

**On Ubuntu/Debian:**

```bash
# Copy certificate to trusted store
sudo cp nginx/ssl/cert.pem /usr/local/share/ca-certificates/promptforge.crt
sudo update-ca-certificates
```

**On macOS:**

```bash
# Add to keychain
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain \
  nginx/ssl/cert.pem
```

**In Browser:**

1. Visit https://localhost
2. Click "Advanced" → "Proceed to localhost"
3. (Chrome) chrome://settings/certificates → Import
4. Select `cert.pem` and trust for HTTPS

---

## Corporate CA Certificates

### Prerequisites

Obtain from your IT department:
- Server certificate (.pem or .crt)
- Private key (.key or .pem)
- Intermediate CA chain (.pem or .crt)
- Root CA certificate (optional)

### Installation

**Using Setup Script:**

```bash
./ssl-setup.sh corporate
```

**Manual Installation:**

```bash
# Copy files
cp /path/to/server.crt nginx/ssl/cert.pem
cp /path/to/server.key nginx/ssl/key.pem

# If you have intermediate certificates
cat /path/to/intermediate.crt >> nginx/ssl/cert.pem

# Set permissions
chmod 600 nginx/ssl/key.pem
chmod 644 nginx/ssl/cert.pem

# Generate DH parameters
openssl dhparam -out nginx/ssl/dhparam.pem 2048
```

### Certificate Chain Order

The correct order in `cert.pem`:

```
1. Server Certificate
2. Intermediate CA Certificate(s)
3. Root CA Certificate (optional)
```

Verify chain:

```bash
openssl crl2pkcs7 -nocrl -certfile nginx/ssl/cert.pem | \
  openssl pkcs7 -print_certs -noout
```

---

## Certificate Renewal

### Let's Encrypt Auto-Renewal

**Create Renewal Script:**

```bash
cat > /opt/promptforge/renew-cert.sh << 'EOF'
#!/bin/bash
cd /opt/promptforge
docker-compose -f docker-compose.prod.yml -f docker-compose.ssl.yml \
  run --rm certbot renew --quiet

if [ $? -eq 0 ]; then
    docker-compose -f docker-compose.prod.yml exec nginx nginx -s reload
    echo "$(date): Certificate renewed successfully"
fi
EOF

chmod +x /opt/promptforge/renew-cert.sh
```

**Add to Cron:**

```bash
# Edit crontab
crontab -e

# Add this line (runs twice daily)
0 0,12 * * * /opt/promptforge/renew-cert.sh >> /var/log/certbot-renew.log 2>&1
```

**Test Renewal:**

```bash
# Dry run (doesn't actually renew)
docker-compose run --rm certbot renew --dry-run
```

### Manual Renewal

```bash
# Force renewal
docker-compose -f docker-compose.prod.yml -f docker-compose.ssl.yml \
  run --rm certbot renew --force-renewal

# Reload nginx
docker-compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

### Certificate Expiration Monitoring

**Check Expiration:**

```bash
# Show expiration date
openssl x509 -enddate -noout -in nginx/ssl/cert.pem

# Days until expiration
echo $(( ($(date -d "$(openssl x509 -enddate -noout -in nginx/ssl/cert.pem | cut -d= -f2)" +%s) - $(date +%s)) / 86400 )) days
```

**Automated Monitoring:**

Add to cron (daily check):

```bash
0 8 * * * /opt/promptforge/check-cert-expiry.sh
```

Create `check-cert-expiry.sh`:

```bash
#!/bin/bash
CERT_FILE="/opt/promptforge/nginx/ssl/cert.pem"
DAYS_WARNING=30

expiry_date=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
expiry_epoch=$(date -d "$expiry_date" +%s)
now_epoch=$(date +%s)
days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))

if [ $days_left -lt $DAYS_WARNING ]; then
    echo "WARNING: SSL certificate expires in $days_left days"
    # Send alert (email, Slack, etc.)
fi
```

---

## SSL Configuration

### Nginx SSL Best Practices

Our configuration (`nginx/conf.d/ssl.conf`) implements:

**Security Features:**
- ✅ TLS 1.2 and 1.3 only
- ✅ Strong cipher suites (ECDHE with AES-GCM)
- ✅ Perfect Forward Secrecy (PFS)
- ✅ HSTS with preload
- ✅ OCSP stapling
- ✅ SSL session caching
- ✅ DH parameters (2048-bit)

**Security Headers:**
```nginx
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Content-Security-Policy: (custom policy)
Referrer-Policy: strict-origin-when-cross-origin
```

### Customizing SSL Configuration

Edit `nginx/conf.d/ssl.conf`:

**Change Ciphers:**

```nginx
ssl_ciphers 'YOUR_CIPHER_LIST_HERE';
```

**Adjust HSTS:**

```nginx
# Shorter max-age for testing
add_header Strict-Transport-Security "max-age=300" always;

# Production (1 year)
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
```

**Content Security Policy:**

```nginx
# Adjust based on your frontend requirements
add_header Content-Security-Policy "default-src 'self'; ..." always;
```

### SSL Session Configuration

**Performance Tuning:**

```nginx
# Larger cache for high traffic
ssl_session_cache shared:SSL:100m;

# Longer timeout (balance security vs performance)
ssl_session_timeout 4h;
```

---

## Testing and Validation

### SSL Labs Test

Test your deployment:

```bash
# Visit (replace with your domain)
https://www.ssllabs.com/ssltest/analyze.html?d=yourdomain.com
```

**Target Rating:** A+

**Required for A+:**
- TLS 1.2+ only
- Strong ciphers
- HSTS enabled
- No vulnerabilities

### Local Testing

**Verify Certificate:**

```bash
# Check certificate details
openssl x509 -in nginx/ssl/cert.pem -text -noout

# Verify key matches certificate
diff <(openssl x509 -noout -modulus -in nginx/ssl/cert.pem | openssl md5) \
     <(openssl rsa -noout -modulus -in nginx/ssl/key.pem | openssl md5)
```

**Test HTTPS Connection:**

```bash
# Connect with OpenSSL
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com

# Test specific TLS version
openssl s_client -connect yourdomain.com:443 -tls1_2
openssl s_client -connect yourdomain.com:443 -tls1_3

# Test that TLS 1.0/1.1 are disabled (should fail)
openssl s_client -connect yourdomain.com:443 -tls1
```

**Test Headers:**

```bash
curl -I https://yourdomain.com

# Should see:
# Strict-Transport-Security: max-age=31536000
# X-Frame-Options: SAMEORIGIN
# etc.
```

### Security Headers Test

```bash
# Visit
https://securityheaders.com/?q=yourdomain.com
```

**Target Rating:** A

### Mozilla Observatory

```bash
# Visit
https://observatory.mozilla.org/analyze/yourdomain.com
```

**Target Rating:** A+

---

## Troubleshooting

### Certificate Not Found

**Error:** `SSL: error:02001002:system library:fopen:No such file or directory`

**Solution:**

```bash
# Check files exist
ls -la nginx/ssl/
ls -la nginx/ssl/cert.pem nginx/ssl/key.pem

# Verify paths in nginx config
docker-compose -f docker-compose.prod.yml exec nginx cat /etc/nginx/conf.d/ssl.conf | grep ssl_certificate
```

### Certificate and Key Mismatch

**Error:** `SSL: error:0B080074:x509 certificate routines:X509_check_private_key:key values mismatch`

**Solution:**

```bash
# Verify they match
openssl x509 -noout -modulus -in nginx/ssl/cert.pem | openssl md5
openssl rsa -noout -modulus -in nginx/ssl/key.pem | openssl md5

# If different, regenerate or reinstall certificates
```

### Let's Encrypt Rate Limits

**Error:** `too many certificates already issued for exact set of domains`

**Solution:**

```bash
# Check current certificates
curl -s "https://crt.sh/?q=yourdomain.com&output=json" | jq

# Wait for rate limit to reset (1 week)
# Or use staging environment for testing:
docker-compose run --rm certbot \
  certonly \
  --staging \
  --webroot \
  --webroot-path=/var/www/certbot \
  -d yourdomain.com
```

### ACME Challenge Failed

**Error:** `Fetching http://yourdomain.com/.well-known/acme-challenge/XXX: Connection refused`

**Solution:**

```bash
# Verify port 80 is open
sudo ufw status | grep 80

# Check nginx is running
docker-compose -f docker-compose.prod.yml ps nginx

# Verify challenge directory exists
docker-compose -f docker-compose.prod.yml exec nginx ls -la /var/www/certbot

# Test manually
echo "test" > nginx/ssl/certbot/test.txt
curl http://yourdomain.com/.well-known/acme-challenge/test.txt
```

### Mixed Content Warnings

**Error:** Browser shows "not secure" despite HTTPS

**Solution:**

```bash
# Ensure all resources load via HTTPS
# Check frontend code for http:// URLs

# Add to nginx config
add_header Content-Security-Policy "upgrade-insecure-requests" always;
```

### HSTS Not Working

**Error:** HSTS header not sent

**Solution:**

```bash
# Verify header in response
curl -I https://yourdomain.com | grep Strict-Transport-Security

# Check nginx config syntax
docker-compose -f docker-compose.prod.yml exec nginx nginx -t

# Reload nginx
docker-compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

---

## Advanced Topics

### Certificate Pinning

For mobile apps or enhanced security:

```bash
# Generate pin
openssl x509 -in nginx/ssl/cert.pem -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  base64
```

### OCSP Stapling Verification

```bash
# Test OCSP stapling
openssl s_client -connect yourdomain.com:443 -status

# Should show:
# OCSP response:
# OCSP Response Status: successful (0x0)
```

### SNI (Server Name Indication)

For multiple domains:

```nginx
# Add additional server blocks in ssl.conf
server {
    listen 443 ssl http2;
    server_name anotherdomain.com;

    ssl_certificate /etc/nginx/ssl/anotherdomain.pem;
    ssl_certificate_key /etc/nginx/ssl/anotherdomain-key.pem;

    # ... rest of config
}
```

---

## Security Checklist

Before going to production:

- [ ] Using Let's Encrypt or valid CA certificate
- [ ] TLS 1.2 and 1.3 only (1.0/1.1 disabled)
- [ ] Strong cipher suites configured
- [ ] DH parameters generated (2048-bit minimum)
- [ ] HSTS header enabled
- [ ] OCSP stapling enabled
- [ ] Auto-renewal configured
- [ ] Expiration monitoring set up
- [ ] HTTP to HTTPS redirect working
- [ ] No mixed content warnings
- [ ] SSL Labs rating: A+
- [ ] Security Headers rating: A
- [ ] Certificate chain complete
- [ ] Private key permissions: 600
- [ ] Certificate backed up securely

---

## Quick Reference

### Commands

```bash
# Generate self-signed cert
./ssl-setup.sh self-signed

# Setup Let's Encrypt
./ssl-setup.sh letsencrypt

# Install corporate cert
./ssl-setup.sh corporate

# Test SSL configuration
./ssl-setup.sh test

# Renew certificate
docker-compose run --rm certbot renew

# Check expiration
openssl x509 -enddate -noout -in nginx/ssl/cert.pem

# Verify nginx config
docker-compose exec nginx nginx -t

# Reload nginx
docker-compose exec nginx nginx -s reload
```

### File Locations

```
nginx/ssl/
├── cert.pem              # Certificate
├── key.pem               # Private key
├── dhparam.pem           # DH parameters
└── letsencrypt/          # Let's Encrypt certificates
    └── live/
        └── yourdomain.com/
            ├── fullchain.pem
            ├── privkey.pem
            └── chain.pem
```

---

## Resources

- **Let's Encrypt:** https://letsencrypt.org/
- **SSL Labs:** https://www.ssllabs.com/ssltest/
- **Mozilla SSL Config:** https://ssl-config.mozilla.org/
- **Security Headers:** https://securityheaders.com/
- **Certbot Docs:** https://certbot.eff.org/docs/

---

**Version:** 1.0.0
**Last Updated:** December 2024

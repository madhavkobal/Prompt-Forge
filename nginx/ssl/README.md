# SSL/TLS Certificate Setup

This directory contains SSL/TLS certificates for HTTPS.

## Option 1: Let's Encrypt (Recommended for Production)

### Prerequisites
- A registered domain name
- Domain DNS pointing to your server's IP address
- Ports 80 and 443 open in your firewall

### Setup with Certbot

1. Install Certbot:
   ```bash
   # On Ubuntu/Debian
   sudo apt update
   sudo apt install certbot python3-certbot-nginx
   ```

2. Obtain certificates:
   ```bash
   sudo certbot certonly --webroot \
     -w /var/www/certbot \
     -d yourdomain.com \
     -d www.yourdomain.com \
     --email admin@yourdomain.com \
     --agree-tos \
     --no-eff-email
   ```

3. Copy certificates to nginx/ssl directory:
   ```bash
   sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ./nginx/ssl/
   sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ./nginx/ssl/
   ```

4. Set proper permissions:
   ```bash
   chmod 644 ./nginx/ssl/fullchain.pem
   chmod 600 ./nginx/ssl/privkey.pem
   ```

5. Enable HTTPS configuration in nginx:
   - Edit `nginx/conf.d/default.conf`
   - Uncomment the HTTPS server block
   - Update `server_name` with your domain
   - Restart nginx: `docker-compose -f docker-compose.prod.yml restart nginx`

### Auto-renewal

Let's Encrypt certificates expire after 90 days. Set up auto-renewal:

```bash
# Test renewal
sudo certbot renew --dry-run

# Add to crontab for automatic renewal
sudo crontab -e
```

Add this line to renew daily at 2 AM:
```
0 2 * * * certbot renew --quiet --deploy-hook "docker-compose -f /path/to/docker-compose.prod.yml restart nginx"
```

## Option 2: Docker Certbot Service

Add this to your `docker-compose.prod.yml`:

```yaml
services:
  certbot:
    image: certbot/certbot
    container_name: promptforge_certbot
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
```

Then run:
```bash
docker-compose -f docker-compose.prod.yml run --rm certbot certonly \
  --webroot \
  --webroot-path /var/www/certbot \
  -d yourdomain.com \
  -d www.yourdomain.com \
  --email admin@yourdomain.com \
  --agree-tos \
  --no-eff-email
```

## Option 3: Self-Signed Certificates (Development/Testing Only)

**WARNING**: Do not use in production. Self-signed certificates will show security warnings in browsers.

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ./nginx/ssl/privkey.pem \
  -out ./nginx/ssl/fullchain.pem \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
```

## Certificate Files

Place the following files in this directory:
- `fullchain.pem` - Full certificate chain
- `privkey.pem` - Private key

**IMPORTANT**:
- Never commit private keys to version control
- The `nginx/ssl/` directory is in `.gitignore`
- Keep backups of your certificates in a secure location

## Verification

After setting up SSL:

1. Test nginx configuration:
   ```bash
   docker-compose -f docker-compose.prod.yml exec nginx nginx -t
   ```

2. Check SSL certificate:
   ```bash
   openssl s_client -connect yourdomain.com:443 -servername yourdomain.com
   ```

3. Test with SSL Labs:
   https://www.ssllabs.com/ssltest/analyze.html?d=yourdomain.com

## Troubleshooting

### Certificate not found error
- Ensure certificates are in `nginx/ssl/` directory
- Check file permissions (644 for .pem, 600 for private key)
- Verify paths in nginx configuration

### Let's Encrypt rate limits
- Limit of 50 certificates per domain per week
- Use staging environment for testing: add `--staging` flag to certbot

### ACME challenge failed
- Ensure port 80 is accessible
- Check DNS records are correct
- Verify `/.well-known/acme-challenge/` location in nginx config

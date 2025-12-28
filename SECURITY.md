# Security Guide for PromptForge

This document outlines the security measures implemented in PromptForge and best practices for maintaining a secure deployment.

## Table of Contents

1. [Security Features](#security-features)
2. [Authentication & Authorization](#authentication--authorization)
3. [Data Protection](#data-protection)
4. [Network Security](#network-security)
5. [Input Validation & Sanitization](#input-validation--sanitization)
6. [Rate Limiting](#rate-limiting)
7. [Monitoring & Logging](#monitoring--logging)
8. [Vulnerability Management](#vulnerability-management)
9. [Deployment Security](#deployment-security)
10. [Security Best Practices](#security-best-practices)
11. [Incident Response](#incident-response)
12. [Reporting Security Issues](#reporting-security-issues)

---

## Security Features

PromptForge implements multiple layers of security to protect your application and data:

### Backend Security

- ✅ **Rate Limiting**: Token bucket algorithm prevents abuse (60 req/min default)
- ✅ **Request Size Limits**: Protects against DoS attacks (10MB default)
- ✅ **CSRF Protection**: Double-submit cookie pattern for state-changing operations
- ✅ **XSS Protection**: Security headers and input sanitization
- ✅ **SQL Injection Protection**: SQLAlchemy ORM with parameterized queries
- ✅ **Password Security**: Bcrypt hashing with 12 rounds, strength validation
- ✅ **HTTPS Enforcement**: Automatic redirect in production
- ✅ **Security Headers**: CSP, HSTS, X-Frame-Options, etc.
- ✅ **API Key Management**: Secure generation, hashing, and rotation
- ✅ **Input Sanitization**: XSS prevention with bleach library

### Frontend Security

- ✅ **Content Security Policy**: Prevents unauthorized script execution
- ✅ **XSS Prevention**: Input sanitization utilities
- ✅ **Secure URL Validation**: Blocks javascript: and data: URLs
- ✅ **CSRF Token Handling**: Automatic token management
- ✅ **Client-Side Rate Limiting**: Prevents rapid repeated actions
- ✅ **Password Strength Validation**: Real-time feedback

---

## Authentication & Authorization

### Password Requirements

PromptForge enforces strong password policies by default:

```python
MIN_PASSWORD_LENGTH = 8
REQUIRE_PASSWORD_UPPERCASE = True
REQUIRE_PASSWORD_LOWERCASE = True
REQUIRE_PASSWORD_DIGITS = True
REQUIRE_PASSWORD_SPECIAL = True
```

**Password must contain:**
- At least 8 characters
- At least one uppercase letter (A-Z)
- At least one lowercase letter (a-z)
- At least one digit (0-9)
- At least one special character (!@#$%^&*...)

### Password Hashing

Passwords are hashed using **bcrypt** with 12 rounds:

```python
# Strong work factor (12 rounds = ~300ms per hash)
pwd_context = CryptContext(schemes=["bcrypt"], bcrypt__rounds=12)
```

**Why bcrypt?**
- Adaptive work factor (can increase over time)
- Built-in salt generation
- Resistant to rainbow table attacks
- Industry-standard for password hashing

### JWT Tokens

Access tokens are signed using HS256 algorithm:

```python
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30  # Short-lived tokens
```

**Token Security Best Practices:**
1. Keep tokens short-lived (30 minutes default)
2. Store tokens in httpOnly cookies (recommended) or secure storage
3. Never log tokens or expose them in URLs
4. Implement token refresh mechanism for better UX

### Recommended: httpOnly Cookies for Token Storage

**Current Implementation:** Tokens stored in localStorage
**Recommended for Production:** httpOnly cookies

**To implement httpOnly cookies:**

1. Update backend auth endpoint to set cookie:
```python
@router.post("/login")
def login(response: Response, ...):
    access_token = create_access_token(...)

    # Set httpOnly cookie
    response.set_cookie(
        key="access_token",
        value=access_token,
        httponly=True,
        secure=True,  # HTTPS only
        samesite="lax",
        max_age=1800  # 30 minutes
    )
```

2. Update frontend to send credentials:
```typescript
fetch('/api/v1/auth/login', {
  credentials: 'include',  // Send cookies
  ...
})
```

**Benefits:**
- Immune to XSS attacks
- Cannot be accessed by JavaScript
- Automatically sent with requests

---

## Data Protection

### Database Security

#### Connection Encryption

Enable SSL/TLS for PostgreSQL connections:

```bash
# In production.env
DATABASE_URL=postgresql://user:pass@host:5432/db?sslmode=require
```

**SSL Modes:**
- `disable`: No SSL (⚠️ NOT for production)
- `require`: Require SSL connection
- `verify-ca`: Verify server certificate
- `verify-full`: Verify server certificate and hostname

**For AWS RDS:**
```bash
DATABASE_URL=postgresql://user:pass@host:5432/db?sslmode=verify-full&sslrootcert=/path/to/rds-ca-cert.pem
```

#### Data At Rest Encryption

1. **PostgreSQL**: Enable transparent data encryption (TDE)
   - For AWS RDS: Enable encryption when creating the instance
   - For self-hosted: Use encrypted volumes (LUKS, dm-crypt)

2. **File Storage**: Encrypt sensitive files before storage
   ```python
   # Use cryptography library for file encryption
   from cryptography.fernet import Fernet
   ```

### SQL Injection Protection

PromptForge uses SQLAlchemy ORM which provides automatic protection:

```python
# ✅ SAFE - SQLAlchemy uses parameterized queries
user = db.query(User).filter(User.username == username).first()

# ❌ DANGEROUS - Never use raw SQL with user input
# db.execute(f"SELECT * FROM users WHERE username = '{username}'")
```

**If you must use raw SQL:**
```python
# Use parameterized queries
db.execute(
    "SELECT * FROM users WHERE username = :username",
    {"username": username}
)
```

### Secrets Management

#### Development
Use `.env` files (never commit to git):
```bash
# Add to .gitignore
.env
.env.local
.env.production
```

#### Production (Recommended)

**Option 1: AWS Secrets Manager**
```python
import boto3
import json

def get_secret(secret_name):
    client = boto3.client('secretsmanager', region_name='us-east-1')
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])
```

**Option 2: HashiCorp Vault**
```python
import hvac

client = hvac.Client(url='https://vault.example.com')
client.token = 'your-vault-token'
secret = client.secrets.kv.v2.read_secret_version(path='promptforge')
```

**Option 3: Environment Variables (Kubernetes Secrets)**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: promptforge-secrets
type: Opaque
data:
  SECRET_KEY: <base64-encoded-value>
  DATABASE_URL: <base64-encoded-value>
```

---

## Network Security

### HTTPS Enforcement

PromptForge automatically redirects HTTP to HTTPS in production:

```python
# Automatic HTTPS redirect
app.add_middleware(HTTPSRedirectMiddleware)

# HSTS header
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

### CORS Configuration

Configure allowed origins in production:

```bash
# production.env
CORS_ORIGINS=["https://yourdomain.com","https://www.yourdomain.com"]
```

**Never use wildcard (*) in production!**

### Security Headers

All responses include security headers:

```http
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Content-Security-Policy: default-src 'self'; ...
Strict-Transport-Security: max-age=31536000; includeSubDomains
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), microphone=(), camera=()
```

### Content Security Policy (CSP)

Current CSP policy:

```
default-src 'self';
script-src 'self' 'unsafe-inline' 'unsafe-eval';
style-src 'self' 'unsafe-inline';
img-src 'self' data: https:;
connect-src 'self' https://generativelanguage.googleapis.com;
frame-ancestors 'none';
```

**⚠️ Note:** Remove `'unsafe-inline'` and `'unsafe-eval'` in production by:
1. Extracting inline scripts to separate files
2. Using nonces for necessary inline scripts
3. Avoiding `eval()` and similar functions

---

## Input Validation & Sanitization

### Backend Validation

All user inputs are validated and sanitized:

```python
from app.core.security import sanitize_input, validate_email

# Email validation
if not validate_email(user_data.email):
    raise HTTPException(400, "Invalid email format")

# XSS prevention
sanitized_username = sanitize_input(user_data.username)
```

**Sanitization Functions:**
- `sanitize_input()`: Removes HTML tags and dangerous content
- `validate_email()`: Validates email format
- `validate_password_strength()`: Enforces password policy
- `sanitize_sql_identifier()`: Validates SQL identifiers

### Frontend Validation

Use security utilities for client-side validation:

```typescript
import { sanitizeInput, sanitizeUrl, sanitizeHtml } from '@/utils/security';

// Sanitize user input before display
const safeContent = sanitizeInput(userContent);

// Validate URLs
const safeUrl = sanitizeUrl(userProvidedUrl);

// Escape HTML
const escaped = escapeHtml(userInput);
```

### XSS Prevention

**Backend:**
```python
# All user inputs are sanitized with bleach
import bleach
safe_text = bleach.clean(user_input, tags=[], strip=True)
```

**Frontend:**
```typescript
// Never use dangerouslySetInnerHTML
// Always sanitize before rendering
<div>{sanitizeInput(userContent)}</div>
```

---

## Rate Limiting

### Backend Rate Limiting

Token bucket algorithm with configurable limits:

```bash
# production.env
RATE_LIMIT_ENABLED=True
RATE_LIMIT_PER_MINUTE=60
RATE_LIMIT_BURST=10
```

**How it works:**
1. Each client gets a bucket with `RATE_LIMIT_BURST` tokens
2. Tokens refill at `RATE_LIMIT_PER_MINUTE / 60` per second
3. Each request consumes 1 token
4. No tokens = 429 Too Many Requests

**Rate limit headers in responses:**
```http
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1234567890
```

### Client-Side Rate Limiting

Prevent rapid repeated actions:

```typescript
import { rateLimiter } from '@/utils/security';

function handleSubmit() {
  // Allow max 3 submissions per 60 seconds
  if (!rateLimiter.checkLimit('form-submit', 3, 60000)) {
    alert('Too many submissions. Please wait.');
    return;
  }

  // Process submission
}
```

---

## Monitoring & Logging

### Security Event Logging

All security-relevant events are logged:

```python
logger.warning(
    "Failed login attempt",
    extra={
        "username": username,
        "ip_address": request.client.host,
        "user_agent": request.headers.get("user-agent")
    }
)
```

**Events to monitor:**
- Failed login attempts
- Rate limit violations
- CSRF token failures
- Suspicious input patterns
- API key usage

### Error Tracking

Configure Sentry for error tracking:

```bash
# production.env
SENTRY_DSN=https://your-key@sentry.io/project-id
SENTRY_ENVIRONMENT=production
SENTRY_TRACES_SAMPLE_RATE=0.1
```

**What gets tracked:**
- Unhandled exceptions
- Performance issues
- Security violations
- Custom security events

### CSP Violation Reporting

Monitor CSP violations in the browser:

```typescript
import { setupCSPReporting } from '@/utils/security';

// In your app initialization
setupCSPReporting();
```

Violations are logged to the console (configure to send to backend).

---

## Vulnerability Management

### Dependency Scanning

Automated security scans run daily via GitHub Actions:

**Backend (Python):**
- `safety`: Checks for known vulnerabilities in dependencies
- `bandit`: Scans code for security issues

**Frontend (npm):**
- `npm audit`: Checks for known vulnerabilities
- `dependabot`: Automated dependency updates

**CodeQL:**
- Advanced security analysis
- Scans for common vulnerabilities

### Manual Security Audits

Run security checks locally:

```bash
# Backend
cd backend
pip install safety bandit
safety check
bandit -r app/

# Frontend
cd frontend
npm audit
npm audit fix  # Auto-fix where possible
```

### Updating Dependencies

**Regular updates (monthly):**
```bash
# Backend
pip install --upgrade -r requirements.txt
pip freeze > requirements.txt

# Frontend
npm update
npm audit fix
```

**Security patches (immediately):**
```bash
# When vulnerability found
pip install --upgrade package-name==secure-version
npm install package-name@secure-version
```

---

## Deployment Security

### Environment Variables

**Never commit secrets to git!**

```bash
# ❌ NEVER DO THIS
SECRET_KEY=my-secret-key

# ✅ Use environment variables
export SECRET_KEY=$(openssl rand -base64 32)
```

### Docker Security

**Best practices for Docker:**

1. **Use non-root user:**
```dockerfile
USER nobody:nogroup
```

2. **Scan images:**
```bash
docker scan promptforge-backend:latest
```

3. **Minimal base images:**
```dockerfile
FROM python:3.11-slim  # Not python:3.11
```

4. **No secrets in images:**
```dockerfile
# Use BuildKit secrets
RUN --mount=type=secret,id=secret_key \
    SECRET_KEY=$(cat /run/secrets/secret_key) command
```

### Kubernetes Security

**Security context:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

**Network policies:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-network-policy
spec:
  podSelector:
    matchLabels:
      app: promptforge-backend
  ingress:
    - from:
      - podSelector:
          matchLabels:
            app: nginx-ingress
      ports:
        - port: 8000
```

### Reverse Proxy (Nginx)

**Security headers in Nginx:**
```nginx
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

---

## Security Best Practices

### Development

1. **Never commit secrets** to version control
2. **Use environment variables** for configuration
3. **Keep dependencies updated** regularly
4. **Run security scans** before committing
5. **Review code** for security issues

### Production

1. **Enable all security features** in production.env
2. **Use HTTPS** everywhere (no exceptions)
3. **Monitor logs** for suspicious activity
4. **Regular backups** with encryption
5. **Incident response plan** documented

### Code Reviews

Security checklist for code reviews:

- [ ] No hardcoded secrets or credentials
- [ ] User input is validated and sanitized
- [ ] SQL queries use parameterized queries
- [ ] Authentication/authorization properly implemented
- [ ] Error messages don't leak sensitive information
- [ ] Logging doesn't include sensitive data
- [ ] Dependencies are up-to-date and secure

---

## API Key Management

### Creating API Keys

```python
from app.core.api_keys import APIKeyManager

# Create API key for user
api_key, key_record = APIKeyManager.create_api_key(
    db=db,
    user_id=user.id,
    name="Production API Key",
    expires_in_days=90,  # Optional expiration
    scopes=["read:prompts", "write:prompts"]
)

# ⚠️ Display api_key to user ONCE - it's never shown again!
print(f"Your API key: {api_key}")
# User sees: sk_live_<random_token_here>
```

### Rotating API Keys

Regularly rotate API keys (recommended: every 90 days):

```python
# Rotate existing key
new_key, new_record = APIKeyManager.rotate_api_key(
    db=db,
    old_key_id=existing_key.id,
    user_id=user.id,
    expires_in_days=90
)

# Old key is automatically revoked
# Return new_key to user
```

### Using API Keys

**Authentication:**
```python
# In request header
Authorization: Bearer <your_api_key_here>
```

**Validation:**
```python
# Automatic validation in dependencies
api_key = APIKeyManager.validate_api_key(db, provided_key)
if not api_key:
    raise HTTPException(401, "Invalid API key")
```

---

## Incident Response

### Security Incident Procedure

1. **Detection**: Monitor logs, alerts, and reports
2. **Assessment**: Determine severity and scope
3. **Containment**: Isolate affected systems
4. **Eradication**: Remove threat
5. **Recovery**: Restore normal operations
6. **Post-Incident**: Document and learn

### Incident Checklist

When a security incident occurs:

- [ ] **Preserve evidence** (logs, snapshots)
- [ ] **Notify stakeholders** (according to severity)
- [ ] **Rotate compromised credentials** immediately
- [ ] **Block malicious IPs** in firewall
- [ ] **Review access logs** for other breaches
- [ ] **Update security measures** to prevent recurrence
- [ ] **Document incident** for future reference

### Common Incidents

**Compromised Credentials:**
```bash
# 1. Revoke all sessions
# 2. Force password reset
# 3. Rotate SECRET_KEY
# 4. Check access logs
# 5. Notify affected users
```

**DDoS Attack:**
```bash
# 1. Enable rate limiting
# 2. Use CDN/DDoS protection (Cloudflare)
# 3. Increase infrastructure capacity
# 4. Block malicious IPs
```

**SQL Injection Attempt:**
```bash
# 1. Review logs for attack pattern
# 2. Verify SQLAlchemy ORM is used (should prevent)
# 3. Add WAF rules if needed
# 4. Monitor for data exfiltration
```

---

## Reporting Security Issues

### Responsible Disclosure

If you discover a security vulnerability in PromptForge:

**DO:**
- ✅ Report it privately to the security team
- ✅ Provide detailed information to reproduce
- ✅ Allow reasonable time for a fix (90 days)
- ✅ Follow coordinated disclosure practices

**DON'T:**
- ❌ Publicly disclose before a fix is available
- ❌ Exploit the vulnerability
- ❌ Access data that doesn't belong to you

### Contact

**Email:** security@yourdomain.com

**PGP Key:** [Link to PGP public key]

### Bug Bounty

We appreciate security researchers who help keep PromptForge secure.
Rewards for valid vulnerabilities:

- **Critical**: $500 - $1000
- **High**: $250 - $500
- **Medium**: $100 - $250
- **Low**: Recognition in Hall of Fame

---

## Security Checklist for Production

Before deploying to production:

### Application Security
- [ ] All environment variables configured in production.env
- [ ] SECRET_KEY is cryptographically random (min 32 chars)
- [ ] CSRF_SECRET_KEY is set (separate from SECRET_KEY)
- [ ] Rate limiting enabled
- [ ] CORS origins set to specific domains (not *)
- [ ] Security headers enabled
- [ ] Password policy enforced

### Database Security
- [ ] PostgreSQL SSL/TLS enabled (sslmode=require)
- [ ] Database credentials stored securely (secrets manager)
- [ ] Regular backups configured
- [ ] Backup encryption enabled
- [ ] Connection pooling configured

### Network Security
- [ ] HTTPS enabled with valid SSL certificate
- [ ] HSTS header configured
- [ ] TLS 1.2+ only (disable older versions)
- [ ] Firewall rules configured
- [ ] Only necessary ports exposed

### Monitoring & Logging
- [ ] Sentry configured for error tracking
- [ ] Prometheus metrics enabled
- [ ] Log aggregation configured (ELK, CloudWatch, etc.)
- [ ] Security event alerts configured
- [ ] Regular log reviews scheduled

### Access Control
- [ ] Principle of least privilege applied
- [ ] Service accounts with minimal permissions
- [ ] SSH key-based authentication only
- [ ] MFA enabled for critical accounts
- [ ] Regular access reviews

### Maintenance
- [ ] Automated dependency updates (Dependabot)
- [ ] Security scanning in CI/CD
- [ ] Regular security audits scheduled
- [ ] Incident response plan documented
- [ ] Security training for team

---

## Additional Resources

### Security Tools

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Mozilla Observatory](https://observatory.mozilla.org/)
- [Security Headers](https://securityheaders.com/)
- [SSL Labs](https://www.ssllabs.com/ssltest/)

### Documentation

- [FastAPI Security](https://fastapi.tiangolo.com/tutorial/security/)
- [OWASP Cheat Sheets](https://cheatsheetseries.owasp.org/)
- [CWE Top 25](https://cwe.mitre.org/top25/)

### Compliance

- GDPR: Data protection and privacy
- SOC 2: Security controls for service providers
- PCI DSS: If handling payment cards
- HIPAA: If handling health information

---

**Last Updated:** 2024-12-28
**Version:** 1.0.0

For questions or concerns about security, please contact: security@yourdomain.com

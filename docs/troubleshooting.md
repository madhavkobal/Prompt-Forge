# Troubleshooting Guide

Common issues and solutions for PromptForge.

## Application Issues

### Service Won't Start

**Problem:** Backend won't start

**Symptoms:**
```
Error: [Errno 98] Address already in use
```

**Solution:**
```bash
# Find process using port 8000
lsof -ti:8000

# Kill the process
kill -9 $(lsof -ti:8000)

# Or use different port
uvicorn app.main:app --port 8001
```

---

**Problem:** Database connection failed

**Symptoms:**
```
sqlalchemy.exc.OperationalError: could not connect to server
```

**Solutions:**
1. Check if PostgreSQL is running:
```bash
pg_isready
systemctl status postgresql
```

2. Verify connection string:
```bash
# Check .env file
cat backend/.env | grep DATABASE_URL

# Test connection
psql postgresql://user:pass@localhost:5432/promptforge_prod
```

3. Check firewall:
```bash
sudo ufw status
sudo ufw allow 5432/tcp
```

---

### Authentication Issues

**Problem:** JWT token expired

**Symptoms:**
```
401 Unauthorized: Token has expired
```

**Solution:**
```javascript
// Frontend: Implement token refresh
if (error.response.status === 401) {
  // Clear token and redirect to login
  localStorage.removeItem('token');
  window.location.href = '/login';
}
```

---

**Problem:** Can't create account - password validation fails

**Symptoms:**
```
400 Bad Request: Password must contain at least one uppercase letter
```

**Solution:**
Ensure password meets requirements:
- ✅ Minimum 8 characters
- ✅ At least one uppercase (A-Z)
- ✅ At least one lowercase (a-z)
- ✅ At least one digit (0-9)
- ✅ At least one special character (!@#$%...)

**Valid examples:**
- `MySecure123!`
- `P@ssw0rd2024`

---

## Performance Issues

### Slow API Responses

**Problem:** API requests taking >5 seconds

**Diagnosis:**
```bash
# Check response times
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:8000/api/v1/prompts

# curl-format.txt:
time_namelookup:  %{time_namelookup}\n
time_connect:  %{time_connect}\n
time_total:  %{time_total}\n
```

**Solutions:**

1. **Database Query Optimization:**
```sql
-- Find slow queries
SELECT query, mean_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Add missing indexes
CREATE INDEX idx_prompts_owner ON prompts(owner_id);
CREATE INDEX idx_prompts_quality ON prompts(quality_score);
```

2. **Increase Workers:**
```bash
# gunicorn_config.py
workers = 4  # Increase based on CPU cores
```

3. **Enable Connection Pooling:**
```python
# config.py
DATABASE_POOL_SIZE = 20
DATABASE_MAX_OVERFLOW = 10
```

---

### High Memory Usage

**Problem:** Backend consuming excessive memory

**Diagnosis:**
```bash
# Monitor memory
docker stats
top -p $(pgrep -f uvicorn)
```

**Solutions:**

1. **Limit Worker Memory:**
```python
# gunicorn_config.py
worker_class = 'uvicorn.workers.UvicornWorker'
max_requests = 1000  # Restart workers after 1000 requests
max_requests_jitter = 50
```

2. **Database Connection Limits:**
```python
# Reduce pool size if needed
DATABASE_POOL_SIZE = 10
```

---

## Database Issues

### Database Locked (SQLite)

**Problem:** Database is locked

**Symptoms:**
```
sqlite3.OperationalError: database is locked
```

**Solutions:**

1. **Use PostgreSQL** (recommended for production)

2. **Or increase timeout:**
```python
# For SQLite in development only
engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False, "timeout": 30}
)
```

---

### Migration Failures

**Problem:** Alembic migration fails

**Symptoms:**
```
ERROR [alembic.util.messaging] Target database is not up to date.
```

**Solutions:**

1. **Check current version:**
```bash
alembic current
alembic history
```

2. **Force version:**
```bash
# Mark as current without running
alembic stamp head
```

3. **Rollback and retry:**
```bash
alembic downgrade -1
alembic upgrade head
```

4. **Manual SQL fix:**
```bash
# Generate SQL without applying
alembic upgrade head --sql > migration.sql
# Review and apply manually
psql promptforge_prod < migration.sql
```

---

## AI Integration Issues

### Gemini API Errors

**Problem:** Analysis fails with API error

**Symptoms:**
```
500 Internal Server Error: Gemini API request failed
```

**Solutions:**

1. **Check API Key:**
```bash
# Verify key is set
echo $GEMINI_API_KEY

# Test API directly
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"contents":[{"parts":[{"text":"test"}]}]}' \
  "https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent?key=YOUR_API_KEY"
```

2. **Check Rate Limits:**
```python
# Implement exponential backoff
import time
from tenacity import retry, wait_exponential, stop_after_attempt

@retry(wait=wait_exponential(multiplier=1, min=4, max=10), stop=stop_after_attempt(3))
def call_gemini_api():
    # API call here
    pass
```

3. **Handle API Errors Gracefully:**
```python
try:
    result = gemini_service.analyze(prompt)
except Exception as e:
    logger.error(f"Gemini API failed: {e}")
    return {"error": "AI service temporarily unavailable"}
```

---

## Docker Issues

### Container Won't Start

**Problem:** Docker container exits immediately

**Diagnosis:**
```bash
# View container logs
docker logs promptforge-backend

# Check container status
docker ps -a
```

**Solutions:**

1. **Check environment variables:**
```bash
docker inspect promptforge-backend | grep -A 20 "Env"
```

2. **Run interactively:**
```bash
docker run -it --entrypoint /bin/bash promptforge-backend
```

3. **Check disk space:**
```bash
df -h
docker system prune -a
```

---

### Port Already in Use

**Problem:** Can't bind to port

**Symptoms:**
```
Error: Bind for 0.0.0.0:8000 failed: port is already allocated
```

**Solution:**
```bash
# Find what's using the port
sudo lsof -i :8000

# Change port in docker-compose.yml
ports:
  - "8001:8000"
```

---

## Frontend Issues

### Build Failures

**Problem:** npm run build fails

**Symptoms:**
```
Error: Cannot find module '@/components/Button'
```

**Solutions:**

1. **Clear cache and reinstall:**
```bash
rm -rf node_modules package-lock.json
npm install
```

2. **Check TypeScript errors:**
```bash
npm run type-check
```

3. **Check for case sensitivity:**
```typescript
// Wrong (if file is button.tsx)
import Button from '@/components/Button'

// Correct
import Button from '@/components/button'
```

---

### API Connection Failed

**Problem:** Frontend can't connect to backend

**Symptoms:**
```
Network Error: Failed to fetch
```

**Solutions:**

1. **Check API URL:**
```javascript
// .env.local
VITE_API_URL=http://localhost:8000/api/v1
```

2. **Check CORS:**
```python
# backend config.py
CORS_ORIGINS = ["http://localhost:5173"]
```

3. **Verify backend is running:**
```bash
curl http://localhost:8000/health
```

---

## Production Issues

### High CPU Usage

**Problem:** CPU usage constantly >80%

**Diagnosis:**
```bash
# Top processes
top
htop

# Docker stats
docker stats

# Specific container
docker exec promptforge-backend top
```

**Solutions:**

1. **Scale horizontally:**
```bash
docker-compose up -d --scale backend=3
```

2. **Optimize code:**
```python
# Use async/await properly
# Add database indexes
# Cache frequently accessed data
```

3. **Limit concurrent requests:**
```python
# gunicorn_config.py
worker_connections = 1000
```

---

### Out of Disk Space

**Problem:** Disk full

**Diagnosis:**
```bash
df -h
du -sh /* | sort -h
```

**Solutions:**

1. **Clean Docker:**
```bash
docker system prune -a
docker volume prune
```

2. **Clean logs:**
```bash
find /var/log -name "*.log" -mtime +30 -delete
journalctl --vacuum-time=7d
```

3. **Archive old data:**
```sql
-- Archive old prompts
DELETE FROM prompts WHERE created_at < NOW() - INTERVAL '1 year';
```

---

## Getting Help

If you can't resolve the issue:

1. **Check Documentation:**
   - [User Guide](./user-guide.md)
   - [FAQ](./faq.md)
   - [Development Guide](./development.md)

2. **Search Issues:**
   - [GitHub Issues](https://github.com/madhavkobal/Prompt-Forge/issues)

3. **Create Issue:**
   - Provide error messages
   - Include steps to reproduce
   - Share relevant logs
   - Mention environment (OS, versions)

4. **Contact Support:**
   - Email: support@promptforge.io
   - GitHub Discussions

---

**Emergency Procedures:**

If production is down:
1. Check health endpoint: `curl https://api.promptforge.io/health`
2. Review error logs
3. Rollback to last known good version
4. Notify users via status page
5. Create incident report

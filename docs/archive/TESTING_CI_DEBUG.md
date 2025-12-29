# CI/CD Testing Debug Guide

## GitHub Actions Test Failure - Troubleshooting

### Quick Diagnosis

If tests are failing in GitHub Actions but pass locally, follow this guide to diagnose and fix the issues.

---

## Recent Fixes Applied

### 1. Environment Variable Handling
**Problem**: conftest.py was overwriting CI environment variables
**Fix**: Changed to use `setdefault()` to respect existing CI variables

```python
# Before (overwrites CI vars)
os.environ["DATABASE_URL"] = "sqlite:///:memory:"

# After (respects CI vars)
os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
```

### 2. Database Engine Configuration
**Problem**: Test fixture only supported SQLite
**Fix**: Updated to support both SQLite (local) and PostgreSQL (CI)

```python
database_url = os.environ.get("DATABASE_URL", "sqlite:///:memory:")
if database_url.startswith("sqlite"):
    engine = create_engine(database_url, connect_args={"check_same_thread": False})
else:
    engine = create_engine(database_url)  # PostgreSQL
```

### 3. Simplified Test Dependencies
**Problem**: Some test dependencies were causing conflicts
**Fix**: Removed non-essential dependencies from requirements-test.txt

---

## Common Failure Scenarios

### Scenario 1: Import Errors

**Symptoms:**
```
ModuleNotFoundError: No module named 'app'
ImportError: cannot import name 'X' from 'app.Y'
```

**Diagnosis:**
```bash
# Check if all dependencies are installed
pip install -r requirements.txt
pip install -r requirements-test.txt

# Verify PYTHONPATH
echo $PYTHONPATH

# Run tests locally
cd backend
pytest -v
```

**Solution:**
1. Ensure `backend/` is in PYTHONPATH
2. Check that all imports use correct paths
3. Verify no circular imports

---

### Scenario 2: Database Connection Errors

**Symptoms:**
```
sqlalchemy.exc.OperationalError: could not connect to server
FATAL: password authentication failed
```

**Diagnosis:**
```bash
# Check database URL
echo $DATABASE_URL

# Test database connection
psql $DATABASE_URL -c "SELECT 1"
```

**Solution in CI:**
1. Verify PostgreSQL service is running
2. Check credentials match between workflow and conftest
3. Ensure database exists before running tests

**GitHub Actions Workflow Check:**
```yaml
services:
  postgres:
    image: postgres:15
    env:
      POSTGRES_USER: promptforge
      POSTGRES_PASSWORD: test_password
      POSTGRES_DB: promptforge_test
    options: >-
      --health-cmd pg_isready
      --health-interval 10s
```

---

### Scenario 3: Environment Variable Issues

**Symptoms:**
```
pydantic_core._pydantic_core.ValidationError: GEMINI_API_KEY field required
KeyError: 'SECRET_KEY'
```

**Diagnosis:**
```bash
# Check environment variables in CI logs
env | grep -E 'DATABASE_URL|SECRET_KEY|GEMINI_API_KEY'
```

**Solution:**
Ensure all required environment variables are set in GitHub Actions:
```yaml
env:
  DATABASE_URL: postgresql://promptforge:test_password@localhost:5432/promptforge_test
  SECRET_KEY: test-secret-key-for-ci-only
  GEMINI_API_KEY: fake-api-key-for-testing
  ENVIRONMENT: testing
```

---

### Scenario 4: Test Collection Failures

**Symptoms:**
```
ERROR collecting tests/test_auth.py
SyntaxError: invalid syntax
```

**Diagnosis:**
```bash
# Check Python version
python --version

# Verify syntax locally
python -m py_compile backend/tests/test_auth.py
```

**Solution:**
1. Ensure CI uses correct Python version (3.9+)
2. Check for Python version-specific syntax
3. Verify all test files are valid Python

---

### Scenario 5: Dependency Conflicts

**Symptoms:**
```
ERROR: pip's dependency resolver does not currently take into account all the packages that are installed
Requires: pydantic>=2.0, but pydantic 1.10 is installed
```

**Diagnosis:**
```bash
# Check for conflicts
pip check

# List installed packages
pip list
```

**Solution:**
```bash
# Clear pip cache
pip cache purge

# Reinstall dependencies
pip install --upgrade pip
pip install -r requirements.txt
pip install -r requirements-test.txt
```

---

## Debugging Workflow

### Step 1: Check GitHub Actions Logs

1. Go to: https://github.com/madhavkobal/Prompt-Forge/actions
2. Click on the failed workflow run
3. Expand the "Run tests with pytest" step
4. Look for the first error message

### Step 2: Reproduce Locally

```bash
# Create test environment matching CI
cd backend
python3.9 -m venv test_venv
source test_venv/bin/activate

# Install dependencies (matching CI)
pip install --upgrade pip
pip install -r requirements.txt
pip install -r requirements-test.txt

# Set CI-like environment variables
export DATABASE_URL="postgresql://promptforge:password@localhost:5432/promptforge_test"
export SECRET_KEY="test-secret-key"
export GEMINI_API_KEY="test-api-key"
export ENVIRONMENT="testing"

# Run tests
pytest -v

# Run with coverage (matching CI)
pytest --cov=app --cov-report=xml --cov-report=term-missing
```

### Step 3: Fix and Test

1. Make necessary fixes to code/configuration
2. Test locally: `pytest -v`
3. Commit and push
4. Check CI run

---

## Quick Fixes

### Fix 1: Skip Failing Tests Temporarily

```python
import pytest

@pytest.mark.skip(reason="Investigating CI failure")
def test_problematic_function():
    pass
```

### Fix 2: Add Debug Output

```python
def test_something(test_db):
    import os
    print(f"DATABASE_URL: {os.environ.get('DATABASE_URL')}")
    print(f"Tables: {test_db.execute('SELECT * FROM pg_catalog.pg_tables').fetchall()}")
    # ... rest of test
```

### Fix 3: Use CI-Specific Configuration

```python
import os

if os.environ.get("CI") == "true":
    # CI-specific configuration
    DATABASE_URL = os.environ["DATABASE_URL"]
else:
    # Local configuration
    DATABASE_URL = "sqlite:///:memory:"
```

---

## Verification Checklist

Before pushing changes, verify:

- [ ] Tests pass locally: `pytest`
- [ ] Tests pass with PostgreSQL: `DATABASE_URL=postgresql://... pytest`
- [ ] All imports work: `python -c "from app.main import app"`
- [ ] Environment variables are set in workflow
- [ ] Dependencies are in requirements files
- [ ] No hardcoded paths or credentials
- [ ] Database cleanup happens after tests
- [ ] No port conflicts (8000, 5432)

---

## GitHub Actions Workflow Verification

### Check Service Health

```yaml
- name: Wait for PostgreSQL
  run: |
    timeout 30 bash -c 'until pg_isready -h localhost -p 5432; do sleep 1; done'
```

### Verify Environment

```yaml
- name: Debug environment
  run: |
    echo "Python version: $(python --version)"
    echo "DATABASE_URL: $DATABASE_URL"
    echo "Pip packages:"
    pip list
```

### Test Database Connection

```yaml
- name: Test database connection
  run: |
    psql $DATABASE_URL -c "SELECT version();"
```

---

## Additional Resources

### View Full CI Logs
```bash
# Using GitHub CLI
gh run view <run-id> --log

# Or visit in browser
https://github.com/madhavkobal/Prompt-Forge/actions
```

### Local CI Testing with Act
```bash
# Install act (runs GitHub Actions locally)
brew install act  # macOS
# or
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run workflow locally
act push

# Run specific job
act -j test
```

---

## Current Test Status

| Component | Tests | Local | CI |
|-----------|-------|-------|-----|
| Authentication | 37+ | ✅ | 🔄 Investigating |
| Database Models | 32+ | ✅ | 🔄 Investigating |
| **Total** | **69+** | ✅ | 🔄 |

**Recent Changes:**
- ✅ Fixed environment variable handling in conftest.py
- ✅ Updated test_db fixture to support PostgreSQL
- ✅ Simplified test dependencies
- 🔄 Monitoring CI runs for remaining issues

---

## Getting Help

If issues persist:

1. **Check logs**: Review full GitHub Actions logs
2. **Compare environments**: Local vs CI differences
3. **Isolate issue**: Run single test file
4. **Seek patterns**: Similar errors in other projects
5. **Ask for help**: Include full error message and relevant code

---

## Monitoring CI Health

```bash
# Watch CI status
gh run list --limit 5

# View latest run
gh run view

# Re-run failed jobs
gh run rerun <run-id>
```

---

**Last Updated**: 2024-01-15
**Status**: Active debugging - fixes applied, monitoring results

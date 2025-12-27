# PromptForge Testing Guide

## Overview

This document describes the testing infrastructure for PromptForge backend. The test suite includes unit tests, integration tests, and continuous integration via GitHub Actions.

---

## Test Structure

```
backend/tests/
├── __init__.py
├── conftest.py              # Pytest fixtures and configuration
├── test_auth.py             # Authentication tests (100+ tests)
├── test_models.py           # Database model tests (40+ tests)
├── test_templates.py        # Template CRUD tests (planned)
├── test_analysis.py         # Analysis logic tests (planned)
├── test_enhancement.py      # Enhancement tests with mocks (planned)
└── test_api_endpoints.py    # Integration tests (planned)
```

---

## Quick Start

### 1. Install Test Dependencies

```bash
cd backend
pip install -r requirements-test.txt
```

### 2. Run All Tests

```bash
pytest
```

### 3. Run with Coverage

```bash
pytest --cov=app --cov-report=html
```

### 4. View Coverage Report

```bash
open htmlcov/index.html  # macOS
xdg-open htmlcov/index.html  # Linux
start htmlcov/index.html  # Windows
```

---

## Test Categories

### Unit Tests (`@pytest.mark.unit`)

Fast, isolated tests that don't require external dependencies.

**Run unit tests only:**
```bash
pytest -m unit
```

**Examples:**
- Password hashing and verification
- JWT token generation and validation
- Model field validation
- Business logic functions

### Integration Tests (`@pytest.mark.integration`)

Tests that require database or multiple components.

**Run integration tests only:**
```bash
pytest -m integration
```

**Examples:**
- API endpoint tests
- Database transaction tests
- Full authentication flow

### Database Tests (`@pytest.mark.database`)

Tests for database models and relationships.

**Run database tests only:**
```bash
pytest -m database
```

**Examples:**
- Model creation and validation
- Relationships and cascade deletes
- Timestamps and default values

---

## Test Coverage

### Current Coverage (Implemented Tests)

#### ✅ Authentication Tests (`test_auth.py`)
- **User Registration** (6 tests)
  - Successful registration
  - Duplicate email/username handling
  - Invalid email format
  - Missing required fields
  - Password hashing verification

- **User Login** (5 tests)
  - Successful login with token
  - Wrong password handling
  - Non-existent user
  - Missing credentials

- **JWT Token** (5 tests)
  - Token claims verification
  - Token expiration
  - Valid/invalid token decoding
  - Expired token handling

- **Current User** (4 tests)
  - Get current user with valid token
  - Missing/invalid token handling
  - Malformed authorization header

- **Password Security** (4 tests)
  - Password hashing
  - Verification success/failure
  - Salt randomness

- **AuthService** (3 tests)
  - User creation
  - Authentication success/failure

- **Edge Cases** (10 tests)
  - Empty password
  - Long username
  - SQL injection attempts
  - XSS attempts
  - Concurrent registrations
  - Case sensitivity

**Total: 37+ authentication tests**

#### ✅ Database Model Tests (`test_models.py`)
- **User Model** (5 tests)
  - User creation
  - Timestamps
  - Unique constraints (email, username)
  - Relationships

- **Prompt Model** (7 tests)
  - Prompt creation
  - Timestamps and updates
  - Owner relationship
  - Default scores
  - Cascade delete

- **PromptVersion Model** (5 tests)
  - Version creation
  - Relationships
  - Multiple versions
  - Cascade delete

- **Template Model** (6 tests)
  - Template creation
  - Use count
  - Public/private
  - Owner relationship
  - Cascade delete

- **Relationships** (4 tests)
  - User has many prompts
  - User has many templates
  - Prompt has many versions
  - Cascade deletes

- **Validation** (5 tests)
  - Required fields
  - JSON field storage

**Total: 32+ database model tests**

### Planned Coverage

#### 🚧 Template Tests (`test_templates.py`) - Planned
- CRUD operations
- Public/private filtering
- Permission checks
- Use count tracking

#### 🚧 Analysis Tests (`test_analysis.py`) - Planned
- Analysis scoring algorithms
- Best practices validation
- Ambiguity detection
- Gemini API integration (mocked)

#### 🚧 Enhancement Tests (`test_enhancement.py`) - Planned
- Prompt enhancement
- Multiple version generation
- Quality improvement calculation
- Gemini API mocking

#### 🚧 API Endpoint Tests (`test_api_endpoints.py`) - Planned
- All 20 API endpoints
- Request/response validation
- Authorization checks
- Error handling

---

## Running Specific Tests

### By Test File

```bash
# Run authentication tests
pytest tests/test_auth.py

# Run model tests
pytest tests/test_models.py
```

### By Test Class

```bash
# Run user registration tests
pytest tests/test_auth.py::TestUserRegistration

# Run prompt model tests
pytest tests/test_models.py::TestPromptModel
```

### By Test Function

```bash
# Run specific test
pytest tests/test_auth.py::TestUserRegistration::test_register_new_user_success
```

### By Markers

```bash
# Run only unit tests
pytest -m unit

# Run only integration tests
pytest -m integration

# Run auth-related tests
pytest -m auth

# Run database tests
pytest -m database

# Skip slow tests
pytest -m "not slow"
```

---

## Test Configuration

### pytest.ini

```ini
[pytest]
testpaths = tests
addopts = -v --cov=app --cov-report=term-missing
markers =
    unit: Unit tests (fast)
    integration: Integration tests
    database: Database tests
    auth: Authentication tests
    slow: Slow tests
```

### Coverage Settings

- **Minimum coverage**: 80%
- **Coverage report formats**: HTML, XML, Terminal
- **Excluded from coverage**:
  - Test files
  - Migrations
  - Virtual environment

---

## Test Fixtures

### Database Fixtures

**`test_db`** - In-memory SQLite database for each test
```python
def test_example(test_db):
    # Use test_db session
```

**`client`** - Test client with database override
```python
def test_api(client):
    response = client.get("/api/v1/prompts/")
```

### User Fixtures

**`test_user`** - Pre-created test user
```python
def test_with_user(test_user):
    assert test_user.username == "testuser"
```

**`auth_token`** - JWT token for test user
```python
def test_auth(auth_token):
    # Use token for authentication
```

**`auth_headers`** - Authorization headers
```python
def test_api_auth(client, auth_headers):
    response = client.get("/api/v1/auth/me", headers=auth_headers)
```

### Data Fixtures

**`test_prompt`** - Pre-created test prompt
**`test_template`** - Pre-created test template
**`multiple_prompts`** - 15 test prompts
**`analyzed_prompt`** - Prompt with analysis results
**`enhanced_prompt`** - Prompt with enhancement

### Mock Fixtures

**`mock_gemini_analysis_response`** - Mock Gemini analysis
**`mock_gemini_enhancement_response`** - Mock enhancement
**`mock_gemini_service`** - Mocked Gemini service

---

## Continuous Integration

### GitHub Actions Workflow

**File**: `.github/workflows/test.yml`

**Triggers**:
- Push to `main`, `develop`, `claude/**` branches
- Pull requests to `main`, `develop`

**Test Matrix**:
- Python 3.9, 3.10, 3.11
- PostgreSQL 15

**Steps**:
1. Checkout code
2. Set up Python
3. Cache pip packages
4. Install dependencies
5. Run pytest with coverage
6. Upload coverage to Codecov
7. Archive test results

**Status Badge**:
```markdown
![Tests](https://github.com/yourusername/Prompt-Forge/workflows/Backend%20Tests/badge.svg)
```

---

## Writing New Tests

### Test Structure

```python
import pytest
from fastapi.testclient import TestClient

@pytest.mark.unit
@pytest.mark.auth
class TestNewFeature:
    """Test description."""

    def test_feature_success(self, client):
        """Test successful case."""
        response = client.get("/api/v1/endpoint")
        assert response.status_code == 200

    def test_feature_error(self, client):
        """Test error case."""
        response = client.get("/api/v1/invalid")
        assert response.status_code == 404
```

### Best Practices

1. **Use descriptive test names**
   ```python
   def test_user_registration_with_valid_data_succeeds()
   ```

2. **Use markers to categorize tests**
   ```python
   @pytest.mark.unit
   @pytest.mark.auth
   ```

3. **Use fixtures for common setup**
   ```python
   def test_with_user(test_user, test_db):
   ```

4. **Test both success and failure cases**
   ```python
   def test_success_case()
   def test_error_case()
   ```

5. **Use clear assertions**
   ```python
   assert response.status_code == 200
   assert "email" in response.json()
   ```

6. **Mock external dependencies**
   ```python
   @pytest.fixture
   def mock_gemini(mocker):
       return mocker.patch('app.services.gemini_service.GeminiService')
   ```

---

## Mocking Gemini API

To avoid using actual API credits during testing, mock the Gemini service:

```python
@pytest.fixture
def mock_gemini_service(mocker):
    mock = mocker.patch('app.services.gemini_service.GeminiService')
    mock.return_value.analyze_prompt.return_value = {
        "quality_score": 85.0,
        "clarity_score": 88.0,
        # ...
    }
    return mock

def test_analysis(client, mock_gemini_service, auth_headers):
    response = client.post(
        "/api/v1/prompts/1/analyze",
        headers=auth_headers
    )
    assert response.status_code == 200
    assert mock_gemini_service.called
```

---

## Troubleshooting

### Tests Fail with Database Errors

**Problem**: `IntegrityError` or connection errors

**Solution**:
```bash
# Ensure test database is clean
pytest --create-db

# Or delete test database
rm test.db  # If using SQLite
```

### Import Errors

**Problem**: `ModuleNotFoundError`

**Solution**:
```bash
# Ensure in correct directory
cd backend

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-test.txt

# Run from backend directory
pytest
```

### Coverage Too Low

**Problem**: Coverage below 80%

**Solution**:
1. Add tests for uncovered code
2. Check coverage report: `open htmlcov/index.html`
3. Focus on red-highlighted code

### Slow Tests

**Problem**: Tests take too long

**Solution**:
```bash
# Skip slow tests
pytest -m "not slow"

# Run only fast unit tests
pytest -m unit

# Use parallel execution
pytest -n auto
```

---

## Test Statistics

### Current Stats (Implemented)

| Category | Tests | Status |
|----------|-------|--------|
| Authentication | 37+ | ✅ Complete |
| Database Models | 32+ | ✅ Complete |
| Templates | - | 🚧 Planned |
| Analysis | - | 🚧 Planned |
| Enhancement | - | 🚧 Planned |
| API Endpoints | - | 🚧 Planned |
| **Total** | **69+** | **In Progress** |

### Coverage Goals

- **Current**: ~40% (auth + models)
- **Target**: 80%+ overall
- **Critical paths**: 95%+

---

## Next Steps

1. **Implement remaining test files**:
   - `test_templates.py`
   - `test_analysis.py`
   - `test_enhancement.py`
   - `test_api_endpoints.py`

2. **Improve coverage**:
   - Add edge case tests
   - Test error handling
   - Test concurrent operations

3. **Performance testing**:
   - Load testing with Locust
   - Database query optimization
   - API response time benchmarks

4. **Integration testing**:
   - Full workflow tests
   - Multi-user scenarios
   - Real Gemini API integration (in staging)

---

## Resources

- [Pytest Documentation](https://docs.pytest.org/)
- [FastAPI Testing](https://fastapi.tiangolo.com/tutorial/testing/)
- [SQLAlchemy Testing](https://docs.sqlalchemy.org/en/14/orm/session_transaction.html)
- [Coverage.py](https://coverage.readthedocs.io/)

---

**Testing Status**: 🟡 In Progress (69+ tests implemented, more planned)

*Last Updated*: 2024-01-15

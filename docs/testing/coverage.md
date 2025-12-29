# Test Coverage Guide

This document explains the test coverage setup and reporting for PromptForge.

---

## Coverage Overview

PromptForge maintains comprehensive test coverage for both backend and frontend:

- **Backend Coverage**: 63% (Goal: 80%)
- **Frontend Coverage**: TBD (Goal: 80%)

### Coverage Badges

Our README displays real-time coverage badges:
- ✅ Backend Tests Status
- ✅ Frontend Tests Status
- ✅ Codecov Integration
- 📊 Coverage Percentages

---

## Backend Coverage (pytest-cov)

### Configuration

Coverage is configured in `backend/pytest.ini`:

```ini
[pytest]
addopts =
    --cov=app
    --cov-report=html
    --cov-report=term-missing
    --cov-report=xml
    --cov-report=json-summary
    --cov-fail-under=60  # Current threshold

[coverage:run]
source = app
omit =
    */tests/*
    */migrations/*
    */__pycache__/*
```

### Running Coverage Locally

```bash
# Run tests with coverage
cd backend
pytest

# Generate HTML coverage report
pytest --cov=app --cov-report=html
open htmlcov/index.html  # View in browser

# Show coverage in terminal
pytest --cov=app --cov-report=term-missing

# Generate specific reports
pytest --cov=app --cov-report=xml  # For CI/CD
pytest --cov=app --cov-report=json-summary  # For badges
```

### Current Coverage Status

**Current: 63%** (61 tests passing, 4 tests skipped)

**Covered Modules:**
- ✅ Authentication (100%)
- ✅ Security (100%)
- ✅ Auth Service (100%)
- ✅ Database Models (100%)
- ✅ Core Config (100%)
- ✅ Schemas (97%)

**Needs Coverage:**
- ⚠️ Analysis API (45%)
- ⚠️ Prompts API (33%)
- ⚠️ Templates API (40%)
- ⚠️ Gemini Service (20%)

### Improving Coverage

To reach 80% coverage goal:

1. **Add Analysis Tests** (`tests/test_analysis.py`)
   - Test prompt analysis endpoint
   - Test quality score calculations
   - Mock Gemini API responses

2. **Add Enhancement Tests** (`tests/test_enhancement.py`)
   - Test prompt enhancement endpoint
   - Test enhancement strategies
   - Mock AI generation

3. **Add Template Tests** (`tests/test_templates.py`)
   - Test template CRUD operations
   - Test template validation
   - Test template usage tracking

4. **Add Prompts Tests** (`tests/test_prompts.py`)
   - Test prompt CRUD operations
   - Test version management
   - Test history tracking

---

## Frontend Coverage (Vitest)

### Configuration

Coverage is configured in `frontend/vitest.config.ts`:

```typescript
export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov', 'json-summary'],

      // Coverage thresholds
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 80,
        statements: 80,
      },

      // What to include
      include: ['src/**/*.{ts,tsx}'],

      // What to exclude
      exclude: [
        'src/**/*.d.ts',
        'src/main.tsx',
        'src/__tests__/**',
        'src/__mocks__/**',
      ],
    },
  },
});
```

### Running Coverage Locally

```bash
# Run tests with coverage
cd frontend
npm run test:coverage

# View HTML coverage report
open coverage/index.html  # macOS
xdg-open coverage/index.html  # Linux
start coverage/index.html  # Windows

# Run tests in watch mode
npm run test:watch

# Run tests with UI
npm run test:ui
```

### Current Test Files

**Implemented:**
- ✅ `AuthForm.test.tsx` (30+ tests)
- ✅ `api.test.ts` (23+ tests)

**Planned:**
- ⚠️ `PromptEditor.test.tsx`
- ⚠️ `AnalysisPanel.test.tsx`
- ⚠️ `EnhancementPanel.test.tsx`
- ⚠️ `TemplateCard.test.tsx`
- ⚠️ Integration tests
- ⚠️ E2E tests

---

## CI/CD Coverage Reporting

### GitHub Actions Workflows

**Backend Tests** (`.github/workflows/test.yml`):
- ✅ Runs on Python 3.9, 3.10, 3.11
- ✅ Uses PostgreSQL 15
- ✅ Uploads to Codecov
- ✅ Generates coverage summary in PR
- ✅ Archives HTML reports

**Frontend Tests** (`.github/workflows/frontend-test.yml`):
- ✅ Runs on Node 18.x, 20.x
- ✅ Runs type checking
- ✅ Uploads to Codecov
- ✅ Generates coverage summary in PR
- ✅ Archives HTML reports
- ✅ Comments coverage on PRs

### Codecov Integration

Both workflows upload coverage to Codecov:

```yaml
- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v4
  with:
    token: ${{ secrets.CODECOV_TOKEN }}
    flags: backend  # or frontend
    fail_ci_if_error: false
```

**Codecov Setup:**
1. Go to https://codecov.io
2. Connect GitHub repository
3. Get `CODECOV_TOKEN`
4. Add to GitHub repository secrets
5. Codecov will automatically comment on PRs with coverage changes

### Viewing Coverage Reports

**In GitHub Actions:**
- Check "Actions" tab
- View workflow run
- See coverage summary in job output
- Download artifacts for HTML reports

**In Codecov:**
- Visit https://codecov.io/gh/madhavkobal/Prompt-Forge
- View interactive coverage reports
- See file-by-file breakdown
- Track coverage trends over time

---

## Coverage Best Practices

### What to Test

**✅ DO Test:**
- Business logic
- API endpoints
- Data validation
- Error handling
- Edge cases
- Authentication/authorization
- Database operations
- Service layer logic

**❌ DON'T Test:**
- External libraries
- Framework code
- Configuration files
- Type definitions
- Mock implementations

### Writing Testable Code

1. **Keep functions small and focused**
   ```python
   # Good - testable
   def calculate_quality_score(clarity, specificity, structure):
       return (clarity + specificity + structure) / 3

   # Bad - hard to test
   def process_prompt(prompt):
       # Does 10 different things
   ```

2. **Use dependency injection**
   ```python
   # Good - can mock gemini_service
   def analyze(prompt: str, gemini_service: GeminiService):
       return gemini_service.analyze(prompt)

   # Bad - hard to mock
   def analyze(prompt: str):
       gemini = GeminiService()
       return gemini.analyze(prompt)
   ```

3. **Separate concerns**
   ```typescript
   // Good - business logic separate from UI
   const calculateScore = (metrics) => { ... };
   const ScoreDisplay = () => <div>{calculateScore(metrics)}</div>;

   // Bad - mixed concerns
   const ScoreDisplay = () => {
       const score = /* complex calculation */;
       return <div>{score}</div>;
   };
   ```

### Excluded Code

Use `# pragma: no cover` for code that shouldn't be tested:

```python
# Debugging code
def debug_print(msg):  # pragma: no cover
    print(msg)

# Platform-specific code
if sys.platform == 'win32':  # pragma: no cover
    # Windows-specific code
    pass

# Main guard
if __name__ == '__main__':  # pragma: no cover
    main()
```

---

## Coverage Thresholds

### Current Thresholds

**Backend:**
- Current: 60% (temporary)
- Goal: 80%
- Reason: Only auth/models tests implemented

**Frontend:**
- Current: 70% (configured)
- Goal: 80%
- Reason: Only basic tests implemented

### When to Adjust Thresholds

**Lower threshold if:**
- Starting new project
- Large refactoring in progress
- External dependencies changed

**Raise threshold when:**
- More tests are added
- Coverage improves consistently
- Project matures

**Never:**
- Lower threshold to pass CI without adding tests
- Aim for 100% coverage (diminishing returns)
- Test just to hit numbers (test meaningful code)

---

## Troubleshooting

### Backend Coverage Issues

**Problem:** Coverage report not generated
```bash
# Solution: Check pytest-cov is installed
pip install pytest-cov

# Verify pytest.ini configuration
pytest --version
```

**Problem:** Low coverage despite many tests
```bash
# Solution: Check which files are being covered
pytest --cov=app --cov-report=term-missing

# Look for untested files
pytest --cov=app --cov-report=html
```

### Frontend Coverage Issues

**Problem:** Vitest coverage not working
```bash
# Solution: Install coverage provider
npm install -D @vitest/coverage-v8

# Check vitest config
npx vitest --version
```

**Problem:** Coverage artifacts not uploaded
```bash
# Solution: Check coverage files exist
ls -la coverage/
cat coverage/coverage-summary.json
```

---

## Monitoring Coverage

### Local Development

1. **Run tests before committing:**
   ```bash
   # Backend
   cd backend && pytest

   # Frontend
   cd frontend && npm run test:coverage
   ```

2. **Review coverage reports:**
   - Check which files have low coverage
   - Add tests for uncovered code
   - Focus on critical paths first

3. **Set up pre-commit hooks:**
   ```bash
   # Example pre-commit config
   repos:
     - repo: local
       hooks:
         - id: pytest-coverage
           name: pytest coverage
           entry: pytest --cov-fail-under=60
   ```

### CI/CD

1. **Monitor GitHub Actions:**
   - Check "Actions" tab regularly
   - Review failed coverage checks
   - Track trends over time

2. **Review Codecov:**
   - Check coverage diff on PRs
   - Ensure new code is tested
   - Don't merge if coverage decreases

3. **Coverage in PRs:**
   - CI automatically comments coverage
   - Review before merging
   - Discuss coverage changes in reviews

---

## Goals and Roadmap

### Short-term (Next Sprint)

- [ ] Add analysis API tests → Increase backend to 70%
- [ ] Add component tests → Increase frontend to 50%
- [ ] Set up Codecov properly
- [ ] Add coverage checks to PR template

### Medium-term (Next Month)

- [ ] Reach 80% backend coverage
- [ ] Reach 70% frontend coverage
- [ ] Add E2E tests
- [ ] Improve test performance

### Long-term (Next Quarter)

- [ ] Maintain 80%+ coverage
- [ ] Add mutation testing
- [ ] Add visual regression testing
- [ ] Implement test quality metrics

---

## Resources

### Documentation
- [pytest-cov documentation](https://pytest-cov.readthedocs.io/)
- [Vitest coverage](https://vitest.dev/guide/coverage.html)
- [Codecov documentation](https://docs.codecov.com/)
- [Coverage.py](https://coverage.readthedocs.io/)

### Tools
- [Codecov](https://codecov.io) - Coverage visualization
- [Coveralls](https://coveralls.io) - Alternative coverage service
- [SonarQube](https://www.sonarqube.org) - Code quality platform

### Best Practices
- [Google Testing Blog](https://testing.googleblog.com/)
- [Martin Fowler - Test Coverage](https://martinfowler.com/bliki/TestCoverage.html)
- [Effective Testing Strategies](https://kentcdodds.com/blog/write-tests)

---

**Last Updated:** December 27, 2024
**Maintained By:** PromptForge Team

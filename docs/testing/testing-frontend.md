# PromptForge Frontend Testing Guide

## Overview

Comprehensive testing suite for the PromptForge frontend built with Vitest, React Testing Library, and Testing Library User Event.

---

## Test Structure

```
frontend/src/
├── __tests__/
│   ├── components/
│   │   ├── AuthForm.test.tsx          # Authentication forms
│   │   ├── PromptEditor.test.tsx      # Monaco editor (planned)
│   │   ├── AnalysisPanel.test.tsx     # Analysis visualization (planned)
│   │   └── EnhancementPanel.test.tsx  # Enhancement display (planned)
│   ├── services/
│   │   └── api.test.ts                # API integration tests
│   ├── testUtils.tsx                  # Test utilities and helpers
│   └── __mocks__/
│       └── fileMock.js                # Static asset mocks
├── setupTests.ts                      # Global test setup
└── jest.config.js                     # Test configuration
```

---

## Quick Start

### 1. Install Dependencies

```bash
cd frontend
npm install
```

### 2. Run Tests

```bash
# Run all tests once
npm test

# Run tests in watch mode
npm run test:watch

# Run with UI
npm run test:ui

# Run with coverage
npm run test:coverage

# Type check
npm run type-check
```

### 3. View Coverage Report

```bash
npm run test:coverage
open coverage/index.html
```

---

## Test Scripts

| Command | Description |
|---------|-------------|
| `npm test` | Run all tests once (CI mode) |
| `npm run test:watch` | Run tests in watch mode |
| `npm run test:ui` | Open Vitest UI for interactive testing |
| `npm run test:coverage` | Generate coverage report |
| `npm run type-check` | TypeScript type checking |

---

## Test Configuration

### vitest.config.ts

```typescript
export default {
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['<rootDir>/src/setupTests.ts'],
  coverage: {
    threshold: { lines: 70, functions: 70, branches: 70 }
  }
}
```

### Coverage Thresholds

- **Lines**: 70%
- **Functions**: 70%
- **Branches**: 70%
- **Statements**: 70%

---

## Test Categories

### Component Tests ✅

**Authentication Forms** (30+ tests)
- Login form validation
- Registration form validation
- Password strength checking
- Error handling
- Loading states
- Accessibility

### API Service Tests ✅

**Auth Service** (6 tests)
- User registration
- User login
- Current user fetch
- Error handling

**Prompt Service** (8 tests)
- CRUD operations
- Analysis requests
- Enhancement requests
- Version history

**Template Service** (4 tests)
- Template CRUD
- Public/private filtering

**Error Handling** (5 tests)
- Network errors
- HTTP status codes (401, 404, 422, 500)

---

## Test Utilities

### Custom Render

Wraps components with providers (Router, React Query):

```typescript
import { render } from '../testUtils';

render(<MyComponent />);
```

### Mock Data Factories

```typescript
import {
  createMockUser,
  createMockPrompt,
  createMockAnalysis,
  createMockEnhancement,
  createMockTemplate,
} from '../testUtils';

const user = createMockUser({ email: 'custom@example.com' });
const prompt = createMockPrompt({ title: 'Custom Title' });
```

### Mock API Responses

```typescript
import { mockApiResponses } from '../testUtils';

mockedAxios.post.mockResolvedValue({
  data: mockApiResponses.login
});
```

### Helper Functions

```typescript
import {
  waitForLoadingToFinish,
  mockClipboard,
  mockLocalStorage,
  createMockFile,
} from '../testUtils';

// Wait for async operations
await waitForLoadingToFinish();

// Mock clipboard API
mockClipboard();

// Mock file upload
const file = createMockFile('test.txt');
```

---

## Writing Tests

### Component Test Example

```typescript
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '../testUtils';
import userEvent from '@testing-library/user-event';
import MyComponent from '@/components/MyComponent';

describe('MyComponent', () => {
  it('renders correctly', () => {
    render(<MyComponent />);
    expect(screen.getByText('Hello')).toBeInTheDocument();
  });

  it('handles user interaction', async () => {
    const user = userEvent.setup();
    const onClick = vi.fn();

    render(<MyComponent onClick={onClick} />);

    await user.click(screen.getByRole('button'));
    expect(onClick).toHaveBeenCalled();
  });
});
```

### API Service Test Example

```typescript
import { describe, it, expect, vi } from 'vitest';
import { authService } from '@/services/authService';
import axios from 'axios';

vi.mock('axios');

describe('authService', () => {
  it('logs in successfully', async () => {
    vi.mocked(axios.post).mockResolvedValue({
      data: { access_token: 'token', token_type: 'bearer' }
    });

    const result = await authService.login('user', 'pass');
    expect(result.access_token).toBe('token');
  });
});
```

---

## Test Coverage

### Current Coverage

| Category | Tests | Status |
|----------|-------|--------|
| Auth Forms | 30+ | ✅ Complete |
| Auth Service | 6 | ✅ Complete |
| Prompt Service | 8 | ✅ Complete |
| Template Service | 4 | ✅ Complete |
| Error Handling | 5 | ✅ Complete |
| **Total** | **53+** | **In Progress** |

### Planned Coverage

| Component | Status |
|-----------|--------|
| PromptEditor | 🚧 Planned |
| AnalysisPanel | 🚧 Planned |
| EnhancementPanel | 🚧 Planned |
| ComparisonView | 🚧 Planned |
| TemplateCard | 🚧 Planned |

---

## Best Practices

### 1. Use React Testing Library Queries

```typescript
// ✅ Good - Accessible queries
screen.getByRole('button', { name: /submit/i });
screen.getByLabelText(/email/i);
screen.getByText(/welcome/i);

// ❌ Bad - Implementation details
screen.getByClassName('submit-btn');
screen.getById('email-input');
```

### 2. Use User Event for Interactions

```typescript
// ✅ Good - Simulates real user behavior
const user = userEvent.setup();
await user.click(button);
await user.type(input, 'text');

// ❌ Bad - Direct fire event
fireEvent.click(button);
```

### 3. Test Accessibility

```typescript
// Check for proper labels
expect(screen.getByLabelText(/username/i)).toBeInTheDocument();

// Check keyboard navigation
await user.tab();
expect(input).toHaveFocus();

// Check ARIA attributes
expect(button).toHaveAttribute('aria-label', 'Submit');
```

### 4. Mock External Dependencies

```typescript
// Mock API calls
vi.mock('@/services/api');

// Mock router
vi.mock('react-router-dom', () => ({
  useNavigate: () => mockNavigate,
}));

// Mock toast notifications
vi.mock('react-hot-toast');
```

### 5. Test Error States

```typescript
it('handles error', async () => {
  vi.mocked(api.post).mockRejectedValue({
    response: { data: { detail: 'Error message' } }
  });

  render(<Component />);
  await user.click(button);

  expect(screen.getByText('Error message')).toBeInTheDocument();
});
```

---

## Mocking Strategies

### Mock Axios

```typescript
import { vi } from 'vitest';
import axios from 'axios';

vi.mock('axios');
const mockedAxios = vi.mocked(axios);

mockedAxios.get.mockResolvedValue({ data: mockData });
mockedAxios.post.mockRejectedValue(error);
```

### Mock React Router

```typescript
const mockNavigate = vi.fn();

vi.mock('react-router-dom', () => ({
  ...vi.importActual('react-router-dom'),
  useNavigate: () => mockNavigate,
  useParams: () => ({ id: '1' }),
}));
```

### Mock Local Storage

```typescript
const mockStorage = mockLocalStorage();
global.localStorage = mockStorage;

mockStorage.getItem.mockReturnValue('token');
```

### Mock Environment Variables

```typescript
process.env.VITE_API_URL = 'http://test-api.com';
```

---

## Continuous Integration

Tests run automatically on:
- Push to main, develop branches
- Pull requests
- CI/CD pipeline via GitHub Actions

See `.github/workflows/test.yml` for backend tests.
Frontend CI configuration can be added similarly.

---

## Troubleshooting

### Tests Fail with "Cannot find module"

**Solution:**
```bash
# Clear cache and reinstall
rm -rf node_modules
npm install
```

### Monaco Editor Issues in Tests

**Solution:**
Mock Monaco Editor:
```typescript
vi.mock('@monaco-editor/react', () => ({
  default: ({ value, onChange }: any) => (
    <textarea
      value={value}
      onChange={(e) => onChange(e.target.value)}
    />
  ),
}));
```

### Recharts Rendering Issues

**Solution:**
Mock Recharts components:
```typescript
vi.mock('recharts', () => ({
  RadarChart: ({ children }: any) => <div>{children}</div>,
  BarChart: ({ children }: any) => <div>{children}</div>,
}));
```

### Async Test Timeouts

**Solution:**
```typescript
it('async test', async () => {
  // ...
}, { timeout: 10000 }); // 10 second timeout
```

---

## Code Coverage

### View Coverage Report

```bash
npm run test:coverage
```

Coverage report is generated in `coverage/` directory:
- `coverage/index.html` - HTML report
- `coverage/lcov.info` - LCOV format
- `coverage/coverage-summary.json` - JSON summary

### Coverage Badges

Add to README.md:
```markdown
![Coverage](https://img.shields.io/badge/coverage-70%25-yellow)
```

---

## Resources

- [Vitest Documentation](https://vitest.dev/)
- [React Testing Library](https://testing-library.com/react)
- [Testing Library User Event](https://testing-library.com/docs/user-event/intro)
- [Jest DOM Matchers](https://github.com/testing-library/jest-dom)

---

## Test Statistics

### Implemented Tests

- **Auth Forms**: 30+ tests
- **Auth Service**: 6 tests
- **Prompt Service**: 8 tests
- **Template Service**: 4 tests
- **Error Handling**: 5 tests
- **Total**: 53+ tests

### Target Coverage

- Overall: 70%+
- Critical paths: 90%+
- UI components: 80%+
- Services: 95%+

---

**Testing Status**: 🟡 In Progress (53+ tests, foundation complete)

*Last Updated*: 2024-01-15

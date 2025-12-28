# Contributing to PromptForge

Thank you for your interest in contributing to PromptForge! This guide will help you get started.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Process](#development-process)
4. [Pull Request Process](#pull-request-process)
5. [Coding Standards](#coding-standards)
6. [Testing Guidelines](#testing-guidelines)
7. [Documentation](#documentation)
8. [Community](#community)

---

## Code of Conduct

### Our Pledge

We pledge to make participation in our project a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity and expression, level of experience, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards

**Positive behavior includes:**
- Using welcoming and inclusive language
- Being respectful of differing viewpoints
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards others

**Unacceptable behavior includes:**
- Trolling, insulting/derogatory comments, and personal attacks
- Public or private harassment
- Publishing others' private information
- Other conduct which could reasonably be considered inappropriate

---

## Getting Started

### Prerequisites

- Python 3.11+
- Node.js 20+
- PostgreSQL 12+ or SQLite (for development)
- Git
- Docker (optional, for containerized development)

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork:
```bash
git clone https://github.com/YOUR_USERNAME/Prompt-Forge.git
cd Prompt-Forge
```

3. Add upstream remote:
```bash
git remote add upstream https://github.com/madhavkobal/Prompt-Forge.git
```

### Set Up Development Environment

See [Development Guide](./development.md) for detailed setup instructions.

---

## Development Process

### 1. Pick an Issue

- Browse [open issues](https://github.com/madhavkobal/Prompt-Forge/issues)
- Look for issues labeled `good first issue` or `help wanted`
- Comment on the issue to let others know you're working on it

### 2. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

**Branch naming conventions:**
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `refactor/` - Code refactoring
- `test/` - Test improvements

### 3. Make Changes

- Write clean, readable code
- Follow coding standards (see below)
- Add tests for new features
- Update documentation as needed

### 4. Commit Changes

```bash
git add .
git commit -m "feat: add prompt export feature"
```

**Commit message format:**
```
<type>: <subject>

<body> (optional)

<footer> (optional)
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style (formatting, no code change)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat: add prompt export to JSON
fix: resolve authentication token expiry issue
docs: update API documentation for /prompts endpoint
refactor: simplify GeminiService error handling
test: add integration tests for prompt enhancement
```

### 5. Push to Your Fork

```bash
git push origin feature/your-feature-name
```

### 6. Open Pull Request

1. Go to your fork on GitHub
2. Click "Compare & pull request"
3. Fill in the PR template
4. Submit the pull request

---

## Pull Request Process

### Before Submitting

✅ **Checklist:**
- [ ] Code follows project style guidelines
- [ ] Tests pass locally (`pytest` for backend, `npm test` for frontend)
- [ ] Added tests for new features
- [ ] Updated documentation
- [ ] No merge conflicts
- [ ] Commits are clean and well-described
- [ ] PR description explains what and why

### PR Title Format

```
[Type] Brief description

Examples:
[Feature] Add prompt export functionality
[Fix] Resolve token expiration bug
[Docs] Update API documentation
```

### PR Description Template

```markdown
## Description
Brief description of what this PR does.

## Related Issue
Closes #123

## Changes Made
- Added prompt export endpoint
- Updated API documentation
- Added integration tests

## Testing
- Tested locally with pytest
- Manual testing in browser
- All existing tests pass

## Screenshots (if applicable)
[Add screenshots for UI changes]

## Checklist
- [ ] Code follows style guidelines
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No breaking changes (or documented if yes)
```

### Review Process

1. **Automated Checks**: CI/CD runs tests and linting
2. **Code Review**: Maintainers review your code
3. **Feedback**: Address any requested changes
4. **Approval**: Once approved, PR will be merged
5. **Merge**: Squash and merge into main branch

### Addressing Feedback

```bash
# Make requested changes
git add .
git commit -m "address review feedback"
git push origin feature/your-feature-name
```

---

## Coding Standards

### Python (Backend)

**Style Guide:** PEP 8

**Tools:**
- `black` - Code formatting
- `isort` - Import sorting
- `flake8` - Linting
- `mypy` - Type checking

**Run before committing:**
```bash
cd backend
black app/
isort app/
flake8 app/
mypy app/
```

**Key Conventions:**
- Use type hints
- Maximum line length: 88 characters (black default)
- Use docstrings for functions and classes
- Follow snake_case for variables and functions
- Follow PascalCase for classes

**Example:**
```python
from typing import List, Optional

def analyze_prompt(
    prompt_id: int,
    detailed: bool = False
) -> Optional[dict]:
    """
    Analyze prompt quality using AI.

    Args:
        prompt_id: ID of the prompt to analyze
        detailed: Whether to include detailed analysis

    Returns:
        Analysis results dictionary or None if prompt not found
    """
    # Implementation
    pass
```

### TypeScript (Frontend)

**Style Guide:** Airbnb TypeScript Style Guide

**Tools:**
- `eslint` - Linting
- `prettier` - Code formatting

**Run before committing:**
```bash
cd frontend
npm run lint
npm run format
```

**Key Conventions:**
- Use TypeScript (not JavaScript)
- Use functional components with hooks
- Use type interfaces (not `any`)
- Use camelCase for variables and functions
- Use PascalCase for components and interfaces

**Example:**
```typescript
interface PromptAnalysis {
  quality_score: number;
  clarity_score: number;
  suggestions: string[];
}

const AnalyzePrompt: React.FC<{ promptId: number }> = ({ promptId }) => {
  const [analysis, setAnalysis] = useState<PromptAnalysis | null>(null);
  
  useEffect(() => {
    // Fetch analysis
  }, [promptId]);

  return <div>{/* Render analysis */}</div>;
};
```

---

## Testing Guidelines

### Backend Testing

**Framework:** pytest

**Test Types:**
- **Unit Tests**: Test individual functions
- **Integration Tests**: Test API endpoints
- **E2E Tests**: Test complete workflows

**Running Tests:**
```bash
cd backend
pytest                    # All tests
pytest tests/test_auth.py # Specific file
pytest -v                 # Verbose
pytest --cov              # With coverage
```

**Writing Tests:**
```python
def test_create_prompt(client, auth_headers):
    """Test prompt creation"""
    data = {
        "title": "Test Prompt",
        "content": "Test content",
        "target_llm": "ChatGPT"
    }
    response = client.post(
        "/api/v1/prompts",
        json=data,
        headers=auth_headers
    )
    assert response.status_code == 201
    assert response.json()["title"] == "Test Prompt"
```

**Coverage Requirements:**
- Maintain >60% code coverage
- New features must include tests
- Bug fixes should include regression tests

### Frontend Testing

**Framework:** Vitest + React Testing Library

**Running Tests:**
```bash
cd frontend
npm test              # All tests
npm test -- --watch   # Watch mode
npm run test:coverage # With coverage
```

---

## Documentation

### Code Documentation

**Python Docstrings:**
```python
def enhance_prompt(prompt_id: int, focus: str = "comprehensive") -> dict:
    """
    Enhance a prompt using AI.

    This function sends the prompt to the Gemini AI API for enhancement
    based on the specified focus area.

    Args:
        prompt_id: The ID of the prompt to enhance
        focus: Enhancement focus ('clarity', 'specificity', or 'comprehensive')

    Returns:
        dict: Enhancement results with improved prompt and quality metrics

    Raises:
        HTTPException: If prompt not found or AI API fails

    Example:
        >>> result = enhance_prompt(123, focus="clarity")
        >>> print(result["enhanced_content"])
    """
    pass
```

**TypeScript Comments:**
```typescript
/**
 * Analyze a prompt and return quality metrics
 * @param promptId - The ID of the prompt to analyze
 * @returns Promise resolving to analysis results
 * @throws Error if analysis fails
 */
async function analyzePrompt(promptId: number): Promise<PromptAnalysis> {
  // Implementation
}
```

### User Documentation

When adding features:
- Update user guide
- Update API reference (if API changes)
- Add examples
- Update FAQ if needed

---

## Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and ideas
- **Discord**: Real-time chat (coming soon)
- **Email**: support@promptforge.io

### Getting Help

If you're stuck:
1. Check existing documentation
2. Search closed issues
3. Ask in GitHub Discussions
4. Join Discord for real-time help

### Recognition

Contributors are recognized in:
- README.md contributors section
- Release notes
- Hall of Fame (planned)

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to PromptForge!** 🚀

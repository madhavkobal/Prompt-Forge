# Development Guide

Complete guide for setting up PromptForge for local development.

## Quick Start

```bash
# Clone repository
git clone https://github.com/madhavkobal/Prompt-Forge.git
cd Prompt-Forge

# Backend setup
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your configuration
python -m pytest  # Run tests
uvicorn app.main:app --reload  # Start server

# Frontend setup (in new terminal)
cd frontend
npm install
cp .env.example .env.local
# Edit .env.local with your configuration
npm run dev  # Start dev server
```

**Access Application:**
- Frontend: http://localhost:5173
- Backend API: http://localhost:8000
- API Docs: http://localhost:8000/docs

---

## Prerequisites

###Software Requirements

| Software | Version | Required | Notes |
|----------|---------|----------|-------|
| Python | 3.11+ | Yes | Backend runtime |
| Node.js | 20+ | Yes | Frontend build tool |
| PostgreSQL | 12+ | Recommended | Production database |
| SQLite | Any | No | Development database (included in Python) |
| Git | 2.0+ | Yes | Version control |
| Docker | 20+ | Optional | For containerized development |

### API Keys

**Gemini API Key** (Required):
1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create API key
3. Add to `.env`: `GEMINI_API_KEY=your-key-here`

---

## Backend Setup

### 1. Create Virtual Environment

```bash
cd backend
python3.11 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 2. Install Dependencies

```bash
pip install --upgrade pip
pip install -r requirements.txt
pip install -r requirements-test.txt  # Optional, for testing
```

### 3. Configure Environment

```bash
cp .env.example .env
```

Edit `.env`:
```bash
# Required
SECRET_KEY=your-secret-key-min-32-chars  # Generate with: openssl rand -base64 32
GEMINI_API_KEY=your-gemini-api-key
DATABASE_URL=sqlite:///./promptforge.db  # Or PostgreSQL URL

# Optional
CORS_ORIGINS=["http://localhost:5173"]
LOG_LEVEL=DEBUG
```

### 4. Initialize Database

**Option A: SQLite (Development)**
```bash
# Database file will be created automatically
alembic upgrade head
```

**Option B: PostgreSQL (Recommended)**
```bash
# Install PostgreSQL first, then:
createdb promptforge_dev
export DATABASE_URL=postgresql://user:password@localhost:5432/promptforge_dev
alembic upgrade head
```

### 5. Run Backend

```bash
# Development (with auto-reload)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Production-like
gunicorn app.main:app --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

### 6. Run Tests

```bash
# All tests
pytest

# With coverage
pytest --cov=app --cov-report=html

# Specific test file
pytest tests/test_auth.py

# Verbose output
pytest -v

# Stop on first failure
pytest -x
```

### 7. Code Quality Tools

```bash
# Format code
black app/

# Sort imports
isort app/

# Linting
flake8 app/

# Type checking
mypy app/
```

---

## Frontend Setup

### 1. Install Dependencies

```bash
cd frontend
npm install
```

### 2. Configure Environment

```bash
cp .env.example .env.local
```

Edit `.env.local`:
```bash
VITE_API_URL=http://localhost:8000/api/v1
VITE_APP_NAME=PromptForge
VITE_ENABLE_ANALYTICS=false
```

### 3. Run Development Server

```bash
npm run dev  # Start dev server on http://localhost:5173
```

### 4. Build for Production

```bash
npm run build  # Output to dist/
npm run preview  # Preview production build
```

### 5. Run Tests

```bash
npm test  # Run tests
npm run test:coverage  # With coverage
npm run test:ui  # Interactive UI
```

### 6. Code Quality

```bash
npm run lint  # ESLint
npm run format  # Prettier
npm run type-check  # TypeScript
```

---

## Docker Development

### Using Docker Compose

```bash
# Start all services
docker-compose up

# Build and start
docker-compose up --build

# Run in background
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Individual Containers

**Backend:**
```bash
docker build -t promptforge-backend ./backend
docker run -p 8000:8000 --env-file backend/.env promptforge-backend
```

**Frontend:**
```bash
docker build -t promptforge-frontend ./frontend
docker run -p 80:80 promptforge-frontend
```

---

## Database Migrations

### Create Migration

```bash
cd backend
alembic revision --autogenerate -m "Add new field to prompts"
```

### Apply Migration

```bash
alembic upgrade head
```

### Rollback Migration

```bash
alembic downgrade -1  # Rollback one migration
alembic downgrade base  # Rollback all
```

### View Migration History

```bash
alembic history
alembic current
```

---

## Development Workflow

### 1. Start Development Session

```bash
# Terminal 1: Backend
cd backend
source venv/bin/activate
uvicorn app.main:app --reload

# Terminal 2: Frontend
cd frontend
npm run dev

# Terminal 3: Database (if using PostgreSQL)
psql promptforge_dev
```

### 2. Make Changes

- Edit code in your IDE
- Changes auto-reload (backend and frontend)
- Check browser and API docs

### 3. Test Changes

```bash
# Backend tests
cd backend
pytest

# Frontend tests
cd frontend
npm test
```

### 4. Commit Changes

```bash
git add .
git commit -m "feat: add new feature"
git push origin feature/my-feature
```

---

## Debugging

### Backend Debugging

**VS Code launch.json:**
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "FastAPI",
      "type": "python",
      "request": "launch",
      "module": "uvicorn",
      "args": [
        "app.main:app",
        "--reload"
      ],
      "jinja": true,
      "justMyCode": false
    }
  ]
}
```

**PyCharm:**
1. Run → Edit Configurations
2. Add Python configuration
3. Module: `uvicorn`
4. Parameters: `app.main:app --reload`

### Frontend Debugging

**Browser DevTools:**
- Chrome DevTools (F12)
- React DevTools Extension
- Network tab for API calls

**VS Code:**
- Install Debugger for Chrome extension
- Set breakpoints in code
- Press F5 to start debugging

---

## Common Development Tasks

### Reset Database

```bash
# SQLite
rm backend/promptforge.db
alembic upgrade head

# PostgreSQL
dropdb promptforge_dev
createdb promptforge_dev
alembic upgrade head
```

### Add New Dependency

**Backend:**
```bash
pip install new-package
pip freeze > requirements.txt
```

**Frontend:**
```bash
npm install new-package
# package.json updated automatically
```

### Generate Test Data

```bash
cd backend
python scripts/seed_database.py  # If available
```

### Update API Documentation

API docs auto-generate from FastAPI routes. Access at:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

---

## Troubleshooting

### Port Already in Use

```bash
# Kill process on port 8000 (backend)
lsof -ti:8000 | xargs kill -9

# Kill process on port 5173 (frontend)
lsof -ti:5173 | xargs kill -9
```

### Database Connection Issues

```bash
# Check PostgreSQL is running
pg_isready

# Restart PostgreSQL
sudo systemctl restart postgresql  # Linux
brew services restart postgresql  # Mac
```

### Module Not Found

```bash
# Backend
source venv/bin/activate
pip install -r requirements.txt

# Frontend
rm -rf node_modules package-lock.json
npm install
```

---

## IDE Setup

### VS Code

**Recommended Extensions:**
- Python
- Pylance
- ESLint
- Prettier
- TypeScript and JavaScript Language Features
- Docker
- GitLens

**Settings (.vscode/settings.json):**
```json
{
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": false,
  "python.linting.flake8Enabled": true,
  "python.formatting.provider": "black",
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.organizeImports": true
  }
}
```

### PyCharm

1. Open backend folder as project
2. Configure Python interpreter (select venv)
3. Enable Django support (optional)
4. Configure code style (Black, 88 chars)

---

## Performance Optimization

### Backend

- Use database connection pooling
- Enable SQLAlchemy query caching
- Profile with `py-spy` or `cProfile`
- Monitor with Prometheus metrics

### Frontend

- Use React.memo for expensive components
- Lazy load routes with React.lazy
- Optimize bundle size with tree shaking
- Use Web Vitals for performance monitoring

---

**Need Help?** See [Contributing Guide](./contributing.md) or [FAQ](./faq.md)

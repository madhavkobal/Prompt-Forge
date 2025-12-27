# PromptForge

**AI-Powered Prompt Quality Analyzer and Enhancement Tool**

PromptForge helps you analyze, enhance, and optimize your AI prompts using Google Gemini API. Get detailed quality scores, actionable suggestions, and LLM-specific best practices for ChatGPT, Claude, Gemini, Grok, and DeepSeek.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Python](https://img.shields.io/badge/python-3.9+-blue.svg)
![Node](https://img.shields.io/badge/node-20+-green.svg)
![FastAPI](https://img.shields.io/badge/FastAPI-0.104+-green.svg)
![React](https://img.shields.io/badge/React-18+-blue.svg)

[![Backend Tests](https://github.com/madhavkobal/Prompt-Forge/actions/workflows/test.yml/badge.svg)](https://github.com/madhavkobal/Prompt-Forge/actions/workflows/test.yml)
[![Frontend Tests](https://github.com/madhavkobal/Prompt-Forge/actions/workflows/frontend-test.yml/badge.svg)](https://github.com/madhavkobal/Prompt-Forge/actions/workflows/frontend-test.yml)
[![codecov](https://codecov.io/gh/madhavkobal/Prompt-Forge/branch/main/graph/badge.svg)](https://codecov.io/gh/madhavkobal/Prompt-Forge)
[![Backend Coverage](https://img.shields.io/badge/Backend%20Coverage-63%25-yellow.svg)](https://github.com/madhavkobal/Prompt-Forge)
[![Frontend Coverage](https://img.shields.io/badge/Frontend%20Coverage-TBD-lightgrey.svg)](https://github.com/madhavkobal/Prompt-Forge)

---

## 🚀 Features

### Core Capabilities
- **Prompt Analysis Engine** - Get quality scores (0-100) across multiple dimensions:
  - Overall Quality Score
  - Clarity Assessment
  - Specificity Evaluation
  - Structure Analysis
  - Context Completeness
  - Ambiguity Detection

- **AI-Powered Enhancement** - Automatically improve your prompts using Gemini API
  - Generate enhanced versions with quality improvements
  - Get 2-3 different enhancement strategies
  - See specific improvements made
  - Compare original vs enhanced side-by-side

- **Multi-LLM Best Practices** - Tailored recommendations for different AI models:
  - ChatGPT (OpenAI)
  - Claude (Anthropic)
  - Gemini (Google)
  - Grok (xAI)
  - DeepSeek

- **Template Library** - Save and reuse effective prompts
  - Create reusable templates
  - Share public templates
  - Track usage statistics

- **Version Control** - Track prompt iterations and improvements
  - Automatic version tracking
  - View version history
  - Restore previous versions

- **Interactive Editor** - Modern code editor interface
  - Monaco Editor (VS Code editor)
  - Markdown syntax highlighting
  - Real-time analysis with debouncing
  - Auto-analyze mode

- **Data Visualization** - Beautiful charts and metrics
  - Radar charts for multi-dimensional quality
  - Bar charts for score breakdown
  - Quality improvement tracking

---

## 🛠️ Tech Stack

### Backend
- **FastAPI** - Modern, fast Python web framework
- **PostgreSQL** - Reliable relational database
- **SQLAlchemy** - Powerful ORM for database operations
- **Google Gemini API** - AI-powered analysis and enhancement
- **JWT** - Secure token-based authentication
- **Pydantic** - Data validation and settings management
- **Bcrypt** - Secure password hashing

### Frontend
- **React 18** - Modern UI library
- **TypeScript** - Type-safe JavaScript
- **Tailwind CSS** - Utility-first CSS framework
- **Vite** - Next-generation build tool
- **Zustand** - Lightweight state management
- **React Router v6** - Client-side routing
- **Axios** - Promise-based HTTP client
- **Monaco Editor** - VS Code editor for web
- **Recharts** - Composable charting library
- **React Hot Toast** - Beautiful notifications
- **Lucide React** - Icon library

---

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

### Required
- **Python 3.9+** - [Download Python](https://www.python.org/downloads/)
- **Node.js 20+** - [Download Node.js](https://nodejs.org/)
- **PostgreSQL 15+** - [Download PostgreSQL](https://www.postgresql.org/download/)
- **Git** - [Download Git](https://git-scm.com/downloads)

### Optional (Recommended)
- **Docker & Docker Compose** - [Download Docker](https://www.docker.com/products/docker-desktop/)
- **pgAdmin** - PostgreSQL GUI (optional)
- **Postman** - API testing (optional)

### API Keys
- **Google Gemini API Key** - **REQUIRED** for AI features
  - Get it from [Google AI Studio](https://makersuite.google.com/app/apikey)
  - Free tier: 60 requests per minute
  - Create an account and generate an API key

---

## 🚀 Quick Start

Choose one of the following installation methods:

### Option 1: Docker Compose (Recommended for Quick Setup)

This is the fastest way to get started - everything runs in containers.

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Prompt-Forge
   ```

2. **Set up environment variables**
   ```bash
   # Copy backend environment file
   cp backend/.env.example backend/.env

   # Copy frontend environment file
   cp frontend/.env.example frontend/.env
   ```

3. **Edit `backend/.env` and add your Gemini API key**
   ```bash
   # Use your favorite editor
   nano backend/.env
   # OR
   vim backend/.env
   ```

   Update these critical values:
   ```env
   GEMINI_API_KEY=your-actual-gemini-api-key-here
   SECRET_KEY=your-secure-random-secret-key-here
   ```

   Generate a secure SECRET_KEY:
   ```bash
   # On Linux/Mac:
   openssl rand -hex 32

   # On Windows (PowerShell):
   -join ((48..57) + (97..102) | Get-Random -Count 64 | % {[char]$_})
   ```

4. **Start the application**
   ```bash
   docker-compose up --build
   ```

   This will:
   - Build frontend and backend containers
   - Start PostgreSQL database
   - Run database migrations
   - Start all services

5. **Access the application**
   - **Frontend**: http://localhost:5173
   - **Backend API**: http://localhost:8000
   - **API Documentation**: http://localhost:8000/docs
   - **PostgreSQL**: localhost:5432

6. **Stop the application**
   ```bash
   docker-compose down
   ```

---

### Option 2: Manual Setup (For Development)

This method gives you more control and is better for active development.

#### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd Prompt-Forge
```

#### Step 2: Set Up PostgreSQL Database

**On macOS (with Homebrew):**
```bash
# Install PostgreSQL
brew install postgresql@15

# Start PostgreSQL service
brew services start postgresql@15

# Create database
createdb promptforge_db
```

**On Ubuntu/Debian:**
```bash
# Install PostgreSQL
sudo apt update
sudo apt install postgresql postgresql-contrib

# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create user and database
sudo -u postgres psql
postgres=# CREATE USER promptforge WITH PASSWORD 'promptforge_dev_password';
postgres=# CREATE DATABASE promptforge_db OWNER promptforge;
postgres=# GRANT ALL PRIVILEGES ON DATABASE promptforge_db TO promptforge;
postgres=# \q
```

**On Windows:**
1. Download PostgreSQL installer from [postgresql.org](https://www.postgresql.org/download/windows/)
2. Run installer and follow setup wizard
3. Use pgAdmin to create database `promptforge_db`

#### Step 3: Backend Setup

```bash
# Navigate to backend directory
cd backend

# Create Python virtual environment
python -m venv venv

# Activate virtual environment
# On macOS/Linux:
source venv/bin/activate
# On Windows:
venv\Scripts\activate

# Upgrade pip
pip install --upgrade pip

# Install dependencies
pip install -r requirements.txt

# Set up environment variables
cp .env.example .env

# Edit .env file with your configuration
# IMPORTANT: Set GEMINI_API_KEY and SECRET_KEY
nano .env
```

**Configure backend/.env:**
```env
# Database
DATABASE_URL=postgresql://promptforge:promptforge_dev_password@localhost:5432/promptforge_db

# Security - CHANGE THESE!
SECRET_KEY=your-secure-secret-key-generate-with-openssl-rand-hex-32
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080

# Google Gemini API - REQUIRED!
GEMINI_API_KEY=your-gemini-api-key-from-google-ai-studio

# CORS
CORS_ORIGINS=http://localhost:5173,http://localhost:3000

# Environment
ENVIRONMENT=development
```

**Generate a secure SECRET_KEY:**
```bash
# Method 1: Using OpenSSL
openssl rand -hex 32

# Method 2: Using Python
python -c "import secrets; print(secrets.token_hex(32))"
```

**Start the backend server:**
```bash
# With auto-reload (development)
uvicorn app.main:app --reload

# Or specify host and port
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Backend will be available at:
- **API**: http://localhost:8000
- **Docs**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

#### Step 4: Frontend Setup

Open a **new terminal** (keep backend running):

```bash
# Navigate to frontend directory
cd frontend

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env

# Edit .env file (optional - defaults work for local dev)
nano .env
```

**Configure frontend/.env (optional):**
```env
# Backend API URL (defaults to http://localhost:8000)
VITE_API_URL=http://localhost:8000
```

**Start the development server:**
```bash
npm run dev
```

Frontend will be available at:
- **App**: http://localhost:5173

#### Step 5: Verify Installation

1. Open http://localhost:5173 in your browser
2. You should see the PromptForge login page
3. Click "Register" and create an account
4. Login and start analyzing prompts!

---

## 📁 Project Structure

```
Prompt-Forge/
├── backend/                      # FastAPI backend
│   ├── app/
│   │   ├── main.py              # FastAPI application entry point
│   │   ├── api/                 # API route handlers
│   │   │   ├── auth.py          # Authentication endpoints
│   │   │   ├── prompts.py       # Prompt CRUD and analysis
│   │   │   ├── templates.py     # Template management
│   │   │   ├── analysis.py      # Advanced analysis endpoints
│   │   │   └── dependencies.py  # Shared dependencies
│   │   ├── models/              # SQLAlchemy ORM models
│   │   │   ├── user.py          # User model
│   │   │   └── prompt.py        # Prompt, Template, Version models
│   │   ├── schemas/             # Pydantic schemas
│   │   │   ├── user.py          # User request/response schemas
│   │   │   └── prompt.py        # Prompt request/response schemas
│   │   ├── services/            # Business logic layer
│   │   │   ├── auth_service.py  # Authentication logic
│   │   │   └── gemini_service.py# AI service integration
│   │   └── core/                # Core configuration
│   │       ├── config.py        # Settings management
│   │       ├── security.py      # JWT and password hashing
│   │       └── database.py      # Database connection
│   ├── requirements.txt         # Python dependencies
│   ├── Dockerfile              # Backend Docker configuration
│   └── .env.example            # Environment variables template
├── frontend/                    # React frontend
│   ├── src/
│   │   ├── components/          # Reusable React components
│   │   │   ├── Layout.tsx
│   │   │   ├── ScoreCard.tsx
│   │   │   ├── PromptEditor.tsx
│   │   │   ├── AnalysisPanel.tsx
│   │   │   ├── EnhancementPanel.tsx
│   │   │   └── ComparisonView.tsx
│   │   ├── pages/               # Page components
│   │   │   ├── Login.tsx
│   │   │   ├── Register.tsx
│   │   │   ├── AnalyzerEnhanced.tsx
│   │   │   ├── Prompts.tsx
│   │   │   └── Templates.tsx
│   │   ├── services/            # API service layer
│   │   │   ├── authService.ts
│   │   │   ├── promptService.ts
│   │   │   └── templateService.ts
│   │   ├── store/               # Zustand state management
│   │   │   └── authStore.ts
│   │   ├── hooks/               # Custom React hooks
│   │   │   └── useDebounce.ts
│   │   ├── types/               # TypeScript type definitions
│   │   │   └── index.ts
│   │   ├── utils/               # Utility functions
│   │   │   ├── api.ts           # Axios configuration
│   │   │   └── helpers.ts
│   │   ├── App.tsx              # Main App component
│   │   ├── main.tsx             # React entry point
│   │   └── index.css            # Global styles
│   ├── package.json             # Node.js dependencies
│   ├── tsconfig.json            # TypeScript configuration
│   ├── vite.config.ts           # Vite build configuration
│   ├── tailwind.config.js       # Tailwind CSS configuration
│   ├── Dockerfile               # Frontend Docker configuration
│   └── .env.example             # Frontend environment template
├── docker-compose.yml           # Docker Compose orchestration
├── .gitignore                   # Git ignore rules
├── README.md                    # This file
├── API_ENDPOINTS.md            # API documentation
├── BACKEND_COMPLETION_SUMMARY.md
├── ENHANCED_EDITOR_SUMMARY.md
└── SETUP_GUIDE.md              # Detailed setup instructions
```

---

## 📖 API Documentation

### Interactive Documentation

Once the backend is running, visit:
- **Swagger UI** (try endpoints directly): http://localhost:8000/docs
- **ReDoc** (pretty documentation): http://localhost:8000/redoc

### Key API Endpoints

#### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login and get JWT token
- `GET /api/v1/auth/me` - Get current user info

#### Prompts
- `POST /api/v1/prompts/` - Create new prompt
- `GET /api/v1/prompts/` - Get all user prompts
- `GET /api/v1/prompts/history` - Get prompt history (sorted by recent)
- `GET /api/v1/prompts/{id}` - Get specific prompt
- `PUT /api/v1/prompts/{id}` - Update prompt
- `DELETE /api/v1/prompts/{id}` - Delete prompt
- `POST /api/v1/prompts/{id}/analyze` - Analyze prompt quality
- `POST /api/v1/prompts/{id}/enhance` - Enhance prompt with AI
- `GET /api/v1/prompts/{id}/versions` - Get prompt version history

#### Templates
- `POST /api/v1/templates/` - Create template
- `GET /api/v1/templates/` - Get all templates
- `GET /api/v1/templates/{id}` - Get specific template
- `DELETE /api/v1/templates/{id}` - Delete template

#### Advanced Analysis
- `POST /api/v1/analysis/prompt/{id}/versions` - Generate multiple enhanced versions
- `POST /api/v1/analysis/prompt/{id}/ambiguities` - Detect ambiguities
- `GET /api/v1/analysis/prompt/{id}/best-practices` - Check LLM best practices
- `GET /api/v1/analysis/models` - List available Gemini models

For complete API documentation, see [API_ENDPOINTS.md](API_ENDPOINTS.md)

---

## 💻 Usage Guide

### 1. Register an Account
1. Navigate to http://localhost:5173/register
2. Enter your email, username, and password
3. Click "Register"

### 2. Login
1. Go to http://localhost:5173/login
2. Enter your credentials
3. You'll be redirected to the analyzer

### 3. Analyze a Prompt
1. Go to the **Analyzer** page
2. Enter your prompt in the Monaco Editor
3. Select target LLM (ChatGPT, Claude, Gemini, etc.)
4. Click **"Analyze"** to get quality scores

**Analysis Results Include:**
- Overall quality score (0-100)
- Clarity, Specificity, Structure scores
- Strengths and weaknesses
- Actionable suggestions
- Best practices compliance
- Ambiguity detection

### 4. Enhance Your Prompt
1. After analyzing, click **"Enhance"**
2. AI generates an improved version
3. See quality improvement percentage
4. Review specific improvements made
5. Click **"Use Enhanced Version"** to replace original

### 5. Compare Versions
1. Switch to **Comparison** tab
2. View original vs enhanced side-by-side
3. See character count differences
4. Compare quality improvements

### 6. Save as Template
1. Click **"Save"** to save your prompt
2. Access saved prompts in **Prompts** page
3. Create templates in **Templates** page
4. Reuse templates for similar tasks

### 7. View History
1. Go to **Prompts** page
2. View all your saved prompts
3. See quality scores at a glance
4. Click to edit or analyze again

---

## 🔧 Development

### Running Tests

```bash
# Backend tests (if configured)
cd backend
pytest

# Frontend tests (if configured)
cd frontend
npm test
```

### Code Quality

```bash
# Backend linting
cd backend
flake8 app/
black app/  # Code formatting

# Frontend linting
cd frontend
npm run lint
npm run type-check  # TypeScript checking
```

### Database Migrations

```bash
# Create migration
cd backend
alembic revision --autogenerate -m "description"

# Apply migrations
alembic upgrade head

# Rollback migration
alembic downgrade -1
```

### Building for Production

**Frontend:**
```bash
cd frontend
npm run build
# Output in dist/ directory
```

**Backend:**
```bash
cd backend
# Use production ASGI server
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker
```

---

## 🚀 Deployment

### Environment Variables Checklist

Before deploying to production:

**Backend (.env):**
- ✅ Change `SECRET_KEY` to strong random value
- ✅ Update `DATABASE_URL` to production database
- ✅ Verify `GEMINI_API_KEY` is valid
- ✅ Set `CORS_ORIGINS` to production frontend URL
- ✅ Set `ENVIRONMENT=production`
- ✅ Adjust `ACCESS_TOKEN_EXPIRE_MINUTES` for security

**Frontend (.env):**
- ✅ Set `VITE_API_URL` to production backend URL
- ✅ Enable HTTPS

### Production Deployment Options

#### Option 1: Docker on VPS
```bash
# Build and push to registry
docker build -t yourregistry/promptforge-backend:latest ./backend
docker build -t yourregistry/promptforge-frontend:latest ./frontend
docker push yourregistry/promptforge-backend:latest
docker push yourregistry/promptforge-frontend:latest

# On server, pull and run
docker-compose -f docker-compose.prod.yml up -d
```

#### Option 2: Platform as a Service

**Backend (Railway, Render, Fly.io):**
1. Connect your Git repository
2. Set environment variables
3. Deploy automatically on push

**Frontend (Vercel, Netlify, Cloudflare Pages):**
1. Connect Git repository
2. Set build command: `npm run build`
3. Set output directory: `dist`
4. Set `VITE_API_URL` environment variable

#### Option 3: Traditional VPS

**Backend:**
```bash
# Install dependencies
sudo apt update
sudo apt install python3-pip postgresql nginx

# Set up application
cd /var/www/promptforge/backend
pip install -r requirements.txt

# Use systemd for process management
sudo systemctl start promptforge-backend
sudo systemctl enable promptforge-backend
```

**Frontend:**
```bash
# Build frontend
npm run build

# Serve with nginx
sudo cp -r dist/* /var/www/promptforge/frontend/
```

### Database

**Production Database Options:**
- **AWS RDS** - PostgreSQL managed service
- **Google Cloud SQL** - Managed PostgreSQL
- **Supabase** - PostgreSQL with extras
- **Heroku Postgres** - Simple managed database
- **DigitalOcean Managed Databases**

**Backup Strategy:**
```bash
# Automated daily backups
pg_dump promptforge_db > backup_$(date +%Y%m%d).sql

# Restore from backup
psql promptforge_db < backup_20240115.sql
```

---

## 🔒 Security Considerations

### Best Practices

1. **API Keys**
   - Never commit `.env` files to Git
   - Use environment-specific secrets management
   - Rotate keys regularly
   - Monitor API usage

2. **Authentication**
   - Use HTTPS in production
   - Set appropriate token expiration
   - Implement rate limiting
   - Use strong password requirements

3. **Database**
   - Use strong passwords
   - Enable SSL connections
   - Regular backups
   - Limit network access

4. **CORS**
   - Only allow trusted origins
   - Don't use wildcard (*) in production
   - Verify origin headers

---

## 🐛 Troubleshooting

### Common Issues

#### Database Connection Errors
```
sqlalchemy.exc.OperationalError: could not connect to server
```
**Solution:**
- Ensure PostgreSQL is running: `brew services start postgresql@15` (macOS)
- Check DATABASE_URL in `.env`
- Verify database exists: `psql -l`
- Check credentials are correct

#### Gemini API Errors
```
google.api_core.exceptions.PermissionDenied: 403 API key not valid
```
**Solution:**
- Verify API key at https://makersuite.google.com
- Check GEMINI_API_KEY in backend/.env
- Ensure API is enabled in Google Cloud Console
- Check quota limits

#### CORS Errors in Browser
```
Access to fetch at 'http://localhost:8000' has been blocked by CORS policy
```
**Solution:**
- Add frontend URL to CORS_ORIGINS in backend/.env
- Restart backend server after changes
- Clear browser cache
- Check backend console for CORS logs

#### Frontend Won't Start
```
Error: Cannot find module '@monaco-editor/react'
```
**Solution:**
- Delete node_modules: `rm -rf node_modules`
- Clear npm cache: `npm cache clean --force`
- Reinstall dependencies: `npm install`
- Check Node.js version: `node --version` (should be 20+)

#### Port Already in Use
```
Error: Port 8000 is already in use
```
**Solution:**
```bash
# Find process using port
lsof -i :8000  # macOS/Linux
netstat -ano | findstr :8000  # Windows

# Kill process
kill -9 <PID>  # macOS/Linux
taskkill /PID <PID> /F  # Windows
```

---

## 📚 Additional Resources

### Documentation Files
- [API_ENDPOINTS.md](API_ENDPOINTS.md) - Complete API reference
- [BACKEND_COMPLETION_SUMMARY.md](BACKEND_COMPLETION_SUMMARY.md) - Backend implementation details
- [ENHANCED_EDITOR_SUMMARY.md](ENHANCED_EDITOR_SUMMARY.md) - Frontend editor features

### External Links
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [React Documentation](https://react.dev/)
- [Google Gemini API](https://ai.google.dev/docs)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Tailwind CSS](https://tailwindcss.com/docs)

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**
4. **Test thoroughly**
5. **Commit with clear messages**
   ```bash
   git commit -m "Add: Description of your feature"
   ```
6. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```
7. **Submit a Pull Request**

### Contribution Guidelines
- Follow existing code style
- Write clear commit messages
- Add tests for new features
- Update documentation
- Keep PRs focused and small

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Google Gemini API** for powerful AI capabilities
- **FastAPI** for excellent Python web framework
- **React** and **Vite** teams for modern frontend tools
- **Tailwind CSS** for beautiful styling
- **Monaco Editor** for code editing experience
- **Recharts** for data visualization
- All open-source contributors and maintainers

---

## 📞 Support

### Get Help
- **Issues**: [GitHub Issues](your-repo/issues)
- **Discussions**: [GitHub Discussions](your-repo/discussions)
- **Documentation**: http://localhost:8000/docs
- **Email**: support@promptforge.example

### Reporting Bugs
When reporting bugs, please include:
- Your environment (OS, Python version, Node version)
- Steps to reproduce
- Expected vs actual behavior
- Error messages and logs
- Screenshots if applicable

---

## 🗺️ Roadmap

### Planned Features
- [ ] Batch prompt analysis
- [ ] Collaborative workspaces
- [ ] Export to PDF/Markdown
- [ ] API rate limiting
- [ ] User profiles and avatars
- [ ] Prompt sharing and community library
- [ ] A/B testing for prompts
- [ ] Analytics dashboard
- [ ] Multi-language support
- [ ] Integration with LLM platforms
- [ ] CLI tool for prompt analysis
- [ ] VS Code extension

---

## 📊 Project Status

- ✅ **Backend API**: 100% Complete
- ✅ **Frontend UI**: 100% Complete
- ✅ **Authentication**: Fully Implemented
- ✅ **AI Integration**: Working with Gemini
- ✅ **Database**: PostgreSQL configured
- ✅ **Docker Support**: Available
- ✅ **Documentation**: Comprehensive
- 🚧 **Testing**: In Progress
- 🚧 **Deployment**: To be configured

---

**Built with ❤️ for better AI prompts**

*PromptForge - Because great AI starts with great prompts*

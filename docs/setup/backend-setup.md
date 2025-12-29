# PromptForge Backend Setup Guide

## ✅ Complete Backend Structure

All requested components have been created and are ready to use:

### 1. Database Models (`backend/app/models/`)

#### **User Model** (`user.py`)
```python
- id: Integer (Primary Key)
- email: String (Unique, Indexed)
- username: String (Unique, Indexed)
- hashed_password: String
- full_name: String (Optional)
- is_active: Boolean
- is_superuser: Boolean
- created_at: DateTime
- updated_at: DateTime
- Relationships: prompts, templates
```

#### **Prompt Model** (`prompt.py`)
```python
- id: Integer (Primary Key)
- title: String
- content: Text (Required)
- enhanced_content: Text
# Analysis Scores
- quality_score: Float
- clarity_score: Float
- specificity_score: Float
- structure_score: Float
# Analysis Details
- analysis_result: JSON
- suggestions: JSON
- best_practices: JSON
# Metadata
- target_llm: String (ChatGPT, Claude, Gemini, Grok, DeepSeek)
- category: String
- tags: JSON
- owner_id: Foreign Key → users
- created_at, updated_at: DateTime
```

#### **Template Model** (`prompt.py`)
```python
- id: Integer (Primary Key)
- name: String (Required)
- description: Text
- content: Text (Required)
- category: String
- tags: JSON
- is_public: Boolean
- use_count: Integer
- owner_id: Foreign Key → users
- created_at, updated_at: DateTime
```

#### **PromptVersion Model** (`prompt.py`)
```python
- id: Integer (Primary Key)
- prompt_id: Foreign Key → prompts
- version_number: Integer
- content: Text
- quality_score: Float
- change_summary: Text
- created_at: DateTime
```

### 2. Pydantic Schemas (`backend/app/schemas/`)

#### **User Schemas** (`user.py`)
- `UserBase` - Base user fields
- `UserCreate` - Registration (includes password)
- `UserLogin` - Login credentials
- `User` - Response schema
- `Token` - JWT token response
- `TokenData` - Token payload

#### **Prompt Schemas** (`prompt.py`)
- `PromptBase` - Base prompt fields
- `PromptCreate` - Create prompt request
- `PromptUpdate` - Update prompt request
- `Prompt` - Full prompt response
- `PromptAnalysis` - Analysis results
- `PromptEnhancement` - Enhancement results
- `PromptVersion` - Version data
- `TemplateBase`, `TemplateCreate`, `Template` - Template schemas

### 3. FastAPI Application (`backend/app/main.py`)

**Features:**
- ✅ CORS middleware configured
- ✅ Automatic database table creation
- ✅ OpenAPI documentation at `/docs`
- ✅ Router organization by feature
- ✅ Health check endpoint

### 4. Database Setup (`backend/app/core/`)

**Configuration** (`config.py`):
- Pydantic Settings for environment variables
- Database URL, Secret key, API settings
- CORS origins, Gemini API key

**Database Connection** (`database.py`):
- SQLAlchemy engine and session
- Dependency injection for DB sessions
- Connection pooling ready

**Security** (`security.py`):
- JWT token creation and validation
- Bcrypt password hashing
- Password verification

### 5. API Endpoints Structure

#### **Health & Root**
```
GET  /              → API info and welcome
GET  /health        → Health check status
```

#### **Authentication** (`/api/v1/auth`)
```
POST /api/v1/auth/register  → Register new user
POST /api/v1/auth/login     → Login, get JWT token
GET  /api/v1/auth/me        → Get current user info
```

#### **Prompts** (`/api/v1/prompts`)
```
POST   /api/v1/prompts/                → Create prompt
GET    /api/v1/prompts/                → List all user prompts
GET    /api/v1/prompts/{id}            → Get specific prompt
PUT    /api/v1/prompts/{id}            → Update prompt
DELETE /api/v1/prompts/{id}            → Delete prompt
POST   /api/v1/prompts/{id}/analyze    → Analyze quality ✨
POST   /api/v1/prompts/{id}/enhance    → AI enhancement ✨
GET    /api/v1/prompts/{id}/versions   → Version history
```

#### **Templates** (`/api/v1/templates`)
```
POST   /api/v1/templates/     → Create template
GET    /api/v1/templates/     → List templates (user + public)
GET    /api/v1/templates/{id} → Get specific template
DELETE /api/v1/templates/{id} → Delete template
```

### 6. Services Layer (`backend/app/services/`)

#### **AuthService** (`auth_service.py`)
- `create_user()` - User registration with validation
- `authenticate_user()` - Login validation

#### **GeminiService** (`gemini_service.py`)
- `analyze_prompt()` - AI-powered quality analysis
- `enhance_prompt()` - AI-powered prompt improvement
- `check_best_practices()` - LLM-specific recommendations
- Fallback mechanisms for API failures
- JSON response parsing

## 🚀 Quick Start

### Option 1: Using Docker (Recommended)

```bash
# From project root
docker-compose up --build

# Backend will be available at:
# - API: http://localhost:8000
# - Docs: http://localhost:8000/docs
# - Health: http://localhost:8000/health
```

### Option 2: Manual Setup

#### Step 1: Install Dependencies

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

#### Step 2: Configure Environment

```bash
cp .env.example .env
```

Edit `.env` and set:
```env
DATABASE_URL=postgresql://user:password@localhost:5432/promptforge_db
SECRET_KEY=your-super-secret-key-min-32-chars
GEMINI_API_KEY=your-gemini-api-key-here
```

#### Step 3: Setup Database

```bash
# Create PostgreSQL database
createdb promptforge_db

# Tables will be created automatically on first run
```

#### Step 4: Start Backend

```bash
uvicorn app.main:app --reload

# Server will start at http://localhost:8000
```

## 📚 API Documentation

Once running, visit:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## 🧪 Testing the Backend

### Test Health Endpoint
```bash
curl http://localhost:8000/health
```

### Test Register
```bash
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testuser",
    "password": "securepass123",
    "full_name": "Test User"
  }'
```

### Test Login
```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=testuser&password=securepass123"
```

### Test Analyze Endpoint (with token)
```bash
# First create a prompt, then analyze it
TOKEN="your-jwt-token-here"

curl -X POST http://localhost:8000/api/v1/prompts/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Prompt",
    "content": "Write a story about AI",
    "target_llm": "ChatGPT"
  }'

# Then analyze it (use the returned ID)
curl -X POST http://localhost:8000/api/v1/prompts/1/analyze \
  -H "Authorization: Bearer $TOKEN"
```

## 📁 Project Structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py                    # FastAPI app entry point
│   ├── api/                       # API routes
│   │   ├── __init__.py
│   │   ├── dependencies.py        # Auth dependencies
│   │   ├── auth.py               # Auth endpoints
│   │   ├── prompts.py            # Prompt endpoints
│   │   └── templates.py          # Template endpoints
│   ├── core/                      # Core configuration
│   │   ├── __init__.py
│   │   ├── config.py             # Settings & config
│   │   ├── database.py           # DB connection
│   │   └── security.py           # JWT & hashing
│   ├── models/                    # SQLAlchemy models
│   │   ├── __init__.py
│   │   ├── user.py               # User model
│   │   └── prompt.py             # Prompt, Template, Version models
│   ├── schemas/                   # Pydantic schemas
│   │   ├── __init__.py
│   │   ├── user.py               # User schemas
│   │   └── prompt.py             # Prompt schemas
│   └── services/                  # Business logic
│       ├── __init__.py
│       ├── auth_service.py       # Auth logic
│       └── gemini_service.py     # AI analysis logic
├── requirements.txt               # Python dependencies
├── Dockerfile                     # Docker image
└── .env.example                   # Environment template
```

## 🔑 Key Features

### Authentication & Security
- ✅ JWT token-based authentication
- ✅ Bcrypt password hashing
- ✅ Token expiration (30 min default)
- ✅ Protected endpoints with dependencies

### Database
- ✅ PostgreSQL with SQLAlchemy ORM
- ✅ Automatic table creation
- ✅ Relationship management
- ✅ Timestamp tracking (created_at, updated_at)

### AI Integration
- ✅ Google Gemini API for analysis
- ✅ Quality scoring (4 dimensions)
- ✅ Prompt enhancement
- ✅ Multi-LLM best practices
- ✅ Fallback handling

### API Design
- ✅ RESTful endpoints
- ✅ Request/response validation with Pydantic
- ✅ Automatic OpenAPI documentation
- ✅ CORS configured
- ✅ Error handling

## 🎯 Next Steps

1. **Get Gemini API Key**: https://makersuite.google.com/app/apikey
2. **Start the backend**: `docker-compose up` or manual setup
3. **Test endpoints**: Visit http://localhost:8000/docs
4. **Connect frontend**: Frontend will auto-connect to backend
5. **Start building**: All infrastructure is ready!

## ✅ Verification Checklist

- [x] Database models created (User, Prompt, Template, PromptVersion)
- [x] Pydantic schemas for validation
- [x] FastAPI application with CORS
- [x] Database connection setup
- [x] API endpoints:
  - [x] /api/health
  - [x] /api/v1/auth (register, login, me)
  - [x] /api/v1/prompts/{id}/analyze
  - [x] /api/v1/prompts/{id}/enhance
- [x] JWT authentication
- [x] Gemini API integration
- [x] Docker configuration
- [x] Environment setup

**Status: ✅ COMPLETE - All requested backend components are implemented!**

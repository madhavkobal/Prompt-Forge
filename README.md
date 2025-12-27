# PromptForge

**AI-Powered Prompt Quality Analyzer and Enhancement Tool**

PromptForge helps you analyze, enhance, and optimize your AI prompts using Google Gemini API. Get detailed quality scores, actionable suggestions, and LLM-specific best practices for ChatGPT, Claude, Gemini, Grok, and DeepSeek.

## Features

- **Prompt Analysis Engine** - Get quality scores (0-100) across multiple dimensions:
  - Overall Quality
  - Clarity
  - Specificity
  - Structure

- **AI-Powered Enhancement** - Automatically improve your prompts using Gemini API
- **Multi-LLM Best Practices** - Tailored recommendations for different AI models
- **Template Library** - Save and reuse effective prompts
- **Version Control** - Track prompt iterations and improvements
- **Side-by-Side Comparison** - Compare original vs enhanced prompts

## Tech Stack

### Backend
- **FastAPI** - Modern Python web framework
- **PostgreSQL** - Relational database
- **SQLAlchemy** - ORM for database operations
- **Google Gemini API** - AI-powered analysis and enhancement
- **JWT** - Secure authentication

### Frontend
- **React 18** - UI library
- **TypeScript** - Type-safe JavaScript
- **Tailwind CSS** - Utility-first CSS framework
- **Vite** - Fast build tool
- **Zustand** - State management
- **React Router** - Client-side routing
- **Axios** - HTTP client

## Project Structure

```
promptforge/
├── backend/
│   ├── app/
│   │   ├── main.py              # FastAPI application entry point
│   │   ├── api/                 # API routes
│   │   │   ├── auth.py          # Authentication endpoints
│   │   │   ├── prompts.py       # Prompt CRUD and analysis
│   │   │   ├── templates.py     # Template management
│   │   │   └── dependencies.py  # Auth dependencies
│   │   ├── models/              # SQLAlchemy models
│   │   │   ├── user.py
│   │   │   └── prompt.py
│   │   ├── schemas/             # Pydantic schemas
│   │   │   ├── user.py
│   │   │   └── prompt.py
│   │   ├── services/            # Business logic
│   │   │   ├── auth_service.py
│   │   │   └── gemini_service.py
│   │   └── core/                # Core configuration
│   │       ├── config.py
│   │       ├── security.py
│   │       └── database.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .env.example
├── frontend/
│   ├── src/
│   │   ├── components/          # React components
│   │   │   ├── Layout.tsx
│   │   │   └── ScoreCard.tsx
│   │   ├── pages/               # Page components
│   │   │   ├── Login.tsx
│   │   │   ├── Register.tsx
│   │   │   ├── Analyzer.tsx
│   │   │   ├── Prompts.tsx
│   │   │   └── Templates.tsx
│   │   ├── services/            # API services
│   │   │   ├── authService.ts
│   │   │   ├── promptService.ts
│   │   │   └── templateService.ts
│   │   ├── store/               # State management
│   │   │   └── authStore.ts
│   │   ├── types/               # TypeScript types
│   │   │   └── index.ts
│   │   ├── utils/               # Utilities
│   │   │   ├── api.ts
│   │   │   └── helpers.ts
│   │   ├── App.tsx
│   │   ├── main.tsx
│   │   └── index.css
│   ├── package.json
│   ├── tsconfig.json
│   ├── vite.config.ts
│   ├── tailwind.config.js
│   └── Dockerfile
├── docker-compose.yml
└── README.md
```

## Getting Started

### Prerequisites

- Docker and Docker Compose (recommended)
- OR:
  - Python 3.9+
  - Node.js 20+
  - PostgreSQL 15+

- **Google Gemini API Key** (Get it from [Google AI Studio](https://makersuite.google.com/app/apikey))

### Quick Start with Docker

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd promptforge
   ```

2. **Set up environment variables**
   ```bash
   cp backend/.env.example backend/.env
   ```

3. **Edit `backend/.env` and add your Gemini API key**
   ```env
   GEMINI_API_KEY=your-actual-api-key-here
   SECRET_KEY=your-secure-secret-key-change-this
   ```

4. **Start the application**
   ```bash
   docker-compose up --build
   ```

5. **Access the application**
   - Frontend: http://localhost:5173
   - Backend API: http://localhost:8000
   - API Documentation: http://localhost:8000/docs

### Manual Setup (Without Docker)

#### Backend Setup

1. **Navigate to backend directory**
   ```bash
   cd backend
   ```

2. **Create virtual environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your database URL and Gemini API key
   ```

5. **Start the backend server**
   ```bash
   uvicorn app.main:app --reload
   ```

#### Frontend Setup

1. **Navigate to frontend directory**
   ```bash
   cd frontend
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Start the development server**
   ```bash
   npm run dev
   ```

#### PostgreSQL Setup

1. **Create database**
   ```bash
   createdb promptforge_db
   ```

2. **Update DATABASE_URL in backend/.env**
   ```env
   DATABASE_URL=postgresql://username:password@localhost:5432/promptforge_db
   ```

## API Documentation

Once the backend is running, visit:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

### Key Endpoints

#### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login and get JWT token
- `GET /api/v1/auth/me` - Get current user info

#### Prompts
- `POST /api/v1/prompts/` - Create new prompt
- `GET /api/v1/prompts/` - Get all user prompts
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

## Usage Guide

### 1. Register an Account
Navigate to http://localhost:5173/register and create an account.

### 2. Analyze a Prompt
1. Go to the Analyzer page
2. Enter your prompt
3. Select target LLM (ChatGPT, Claude, Gemini, etc.)
4. Click "Analyze" to get quality scores and suggestions

### 3. Enhance Your Prompt
After analyzing, click "Enhance" to get an AI-improved version of your prompt.

### 4. Save as Template
Save frequently used prompts as templates for quick reuse.

## Environment Variables

### Backend (.env)

```env
# Database
DATABASE_URL=postgresql://promptforge:password@postgres:5432/promptforge_db

# Security
SECRET_KEY=your-super-secret-key-change-this-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Google Gemini API
GEMINI_API_KEY=your-gemini-api-key-here

# CORS
CORS_ORIGINS=http://localhost:5173,http://localhost:3000

# Environment
ENVIRONMENT=development
```

### Frontend

Create a `.env` file in the frontend directory (optional):

```env
VITE_API_URL=http://localhost:8000
```

## Development

### Running Tests

```bash
# Backend tests
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

# Frontend linting
cd frontend
npm run lint
```

## Deployment

### Production Considerations

1. **Security**
   - Change `SECRET_KEY` to a strong random value
   - Use environment-specific secrets management
   - Enable HTTPS
   - Configure proper CORS origins

2. **Database**
   - Use managed PostgreSQL service
   - Set up regular backups
   - Configure connection pooling

3. **API Keys**
   - Secure Gemini API key storage
   - Implement rate limiting
   - Monitor API usage

4. **Frontend**
   ```bash
   cd frontend
   npm run build
   # Deploy dist/ directory to your hosting service
   ```

5. **Backend**
   ```bash
   cd backend
   # Use production ASGI server
   gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker
   ```

## Troubleshooting

### Database Connection Issues
- Ensure PostgreSQL is running
- Verify DATABASE_URL is correct
- Check database credentials

### Gemini API Errors
- Verify API key is valid
- Check API quota limits
- Ensure network connectivity to Google AI services

### Frontend Build Errors
- Clear node_modules and reinstall: `rm -rf node_modules && npm install`
- Check Node.js version compatibility

### CORS Errors
- Add your frontend URL to CORS_ORIGINS in backend/.env
- Restart backend server after changes

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - See LICENSE file for details

## Support

For issues and questions:
- Open an issue on GitHub
- Check existing documentation
- Review API docs at /docs endpoint

## Acknowledgments

- Google Gemini API for AI capabilities
- FastAPI and React communities
- All contributors

---

Built with ❤️ for better AI prompts

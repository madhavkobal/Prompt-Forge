# PromptForge Architecture

System architecture and design documentation for PromptForge v1.0.

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Component Architecture](#component-architecture)
4. [Data Flow](#data-flow)
5. [Database Schema](#database-schema)
6. [API Architecture](#api-architecture)
7. [Security Architecture](#security-architecture)
8. [Deployment Architecture](#deployment-architecture)

---

## System Overview

PromptForge is a full-stack web application built with modern technologies, designed for scalability, security, and maintainability.

### Technology Stack

**Backend:**
- **Framework**: FastAPI (Python 3.11)
- **Database**: PostgreSQL 12+
- **ORM**: SQLAlchemy 2.0
- **Authentication**: JWT (JSON Web Tokens)
- **AI Integration**: Google Gemini AI API
- **Validation**: Pydantic v2

**Frontend:**
- **Framework**: React 18 with TypeScript
- **Build Tool**: Vite
- **Styling**: TailwindCSS
- **Routing**: React Router v6
- **State Management**: React Hooks + Context API

**Infrastructure:**
- **Containerization**: Docker
- **Orchestration**: Kubernetes-ready
- **Monitoring**: Prometheus + Grafana
- **Logging**: Structured JSON logging
- **Error Tracking**: Sentry

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Client Layer                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Web Browser │  │  Mobile App  │  │  API Client  │      │
│  │   (React)    │  │  (Planned)   │  │  (External)  │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
└─────────┼──────────────────┼──────────────────┼─────────────┘
          │                  │                  │
          └──────────────────┴──────────────────┘
                             │
                    HTTPS (TLS 1.2+)
                             │
┌─────────────────────────────┴────────────────────────────────┐
│                     Load Balancer / CDN                       │
│                  (nginx / Cloudflare)                         │
└─────────────────────────────┬────────────────────────────────┘
                             │
          ┌──────────────────┴──────────────────┐
          │                                     │
┌─────────▼─────────┐               ┌──────────▼──────────┐
│  Static Assets    │               │  Backend API        │
│  (Frontend Build) │               │  (FastAPI)          │
│  - React App      │               │                     │
│  - CSS, JS, Images│               │  ┌───────────────┐  │
└───────────────────┘               │  │ Rate Limiting │  │
                                    │  │  Middleware   │  │
                                    │  └───────┬───────┘  │
                                    │          │          │
                                    │  ┌───────▼───────┐  │
                                    │  │   Security    │  │
                                    │  │  Middleware   │  │
                                    │  │ (CSRF, XSS)   │  │
                                    │  └───────┬───────┘  │
                                    │          │          │
                                    │  ┌───────▼───────┐  │
                                    │  │ Auth Handlers │  │
                                    │  │    (JWT)      │  │
                                    │  └───────┬───────┘  │
                                    │          │          │
                                    │  ┌───────▼───────┐  │
                                    │  │  API Routes   │  │
                                    │  │ /auth /prompts│  │
                                    │  │  /analysis    │  │
                                    │  └───────┬───────┘  │
                                    │          │          │
                                    │  ┌───────▼───────┐  │
                                    │  │ Business Logic│  │
                                    │  │   Services    │  │
                                    │  └───────┬───────┘  │
                                    └──────────┼──────────┘
                                               │
                         ┌─────────────────────┼─────────────────────┐
                         │                     │                     │
               ┌─────────▼────────┐  ┌────────▼────────┐  ┌────────▼────────┐
               │   PostgreSQL     │  │   Gemini AI     │  │  Monitoring     │
               │    Database      │  │      API        │  │  (Prometheus)   │
               │  - User data     │  │  - Analysis     │  │  - Metrics      │
               │  - Prompts       │  │  - Enhancement  │  │  - Health       │
               │  - Templates     │  │                 │  │                 │
               └──────────────────┘  └─────────────────┘  └─────────────────┘
```

---

## Component Architecture

### Backend Components

**1. API Layer (FastAPI)**
- **Routes/Endpoints**: Handle HTTP requests
- **Middleware**: Security, rate limiting, logging
- **Request Validation**: Pydantic models
- **Response Serialization**: JSON responses

**2. Service Layer**
- **AuthService**: User authentication and authorization
- **GeminiService**: AI integration for analysis and enhancement
- **PromptService**: Prompt CRUD operations (if separated)
- **TemplateService**: Template management (if separated)

**3. Data Access Layer**
- **Models**: SQLAlchemy ORM models
- **Schemas**: Pydantic schemas for validation
- **Database Session**: Connection management

**4. Security Layer**
- **Password Hashing**: bcrypt (12 rounds)
- **JWT Tokens**: Authentication tokens
- **Input Sanitization**: XSS prevention
- **CSRF Protection**: Double-submit cookie

**5. Monitoring Layer**
- **Prometheus Metrics**: Application metrics
- **Structured Logging**: JSON logs
- **Health Checks**: Liveness/readiness probes
- **Error Tracking**: Sentry integration

### Frontend Components

**1. Presentation Layer**
- **Pages**: Dashboard, Prompts, Templates, Analysis
- **Components**: Reusable UI components
- **Layouts**: Page layouts and structure

**2. State Management**
- **Context API**: Global state (auth, user)
- **React Hooks**: Local component state
- **Custom Hooks**: Reusable stateful logic

**3. API Integration**
- **API Client**: axios/fetch wrapper
- **Authentication**: Token management
- **Error Handling**: Centralized error handling

**4. Routing**
- **React Router**: Client-side routing
- **Protected Routes**: Authentication guards
- **Navigation**: Route-based navigation

**5. Utilities**
- **Security**: XSS prevention, sanitization
- **Performance**: Web Vitals tracking
- **Formatting**: Date, number formatting

---

## Data Flow

### User Registration Flow

```
User → Frontend → API → AuthService → Database
  │       │        │        │            │
  │       │        │        ├─ Validate email
  │       │        │        ├─ Check password strength
  │       │        │        ├─ Sanitize inputs
  │       │        │        ├─ Hash password (bcrypt)
  │       │        │        └─ Create user record
  │       │        │                       │
  │       │        └─── Return user data ──┘
  │       └──── Show success message
  └── User logged in (JWT token received)
```

### Prompt Analysis Flow

```
User → Frontend → API → PromptService → GeminiService → Gemini AI
  │       │        │         │               │             │
  │       │        │         └─ Get prompt ──┘             │
  │       │        │                                       │
  │       │        │              ┌─ Send to Gemini API ──┘
  │       │        │              │
  │       │        │              ├─ Parse AI response
  │       │        │              ├─ Extract scores
  │       │        │              ├─ Format suggestions
  │       │        │              │
  │       │        │         ┌────▼─ Update prompt with analysis
  │       │        │         │         (quality_score, suggestions)
  │       │        │         │
  │       │        └─────────┴── Return analysis results
  │       │
  │       └── Display analysis report
  │
  └── View scores, strengths, weaknesses, suggestions
```

### Prompt Enhancement Flow

```
User → Frontend → API → PromptService → GeminiService → Gemini AI
  │       │        │         │               │             │
  │       │        │         └─ Get prompt ──┘             │
  │       │        │                                       │
  │       │        │              ┌─ Send to Gemini API ──┘
  │       │        │              │  (with enhancement instructions)
  │       │        │              │
  │       │        │              ├─ Parse enhanced prompt
  │       │        │              ├─ Calculate improvements
  │       │        │              │
  │       │        │         ┌────▼─ Create new version
  │       │        │         │         with enhanced content
  │       │        │         │
  │       │        └─────────┴── Return enhancement results
  │       │
  │       └── Display enhanced version
  │           (side-by-side comparison)
  │
  └── Choose to save or edit enhancement
```

---

## Database Schema

### Users Table
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_username (username),
    INDEX idx_email (email)
);
```

### Prompts Table
```sql
CREATE TABLE prompts (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    target_llm VARCHAR(50),
    category VARCHAR(50),
    tags TEXT[],
    quality_score FLOAT,
    clarity_score FLOAT,
    specificity_score FLOAT,
    structure_score FLOAT,
    suggestions TEXT[],
    best_practices JSONB,
    enhanced_content TEXT,
    owner_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_owner (owner_id),
    INDEX idx_category (category),
    INDEX idx_quality (quality_score)
);
```

### Templates Table
```sql
CREATE TABLE templates (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    content TEXT NOT NULL,
    category VARCHAR(50),
    tags TEXT[],
    is_public BOOLEAN DEFAULT FALSE,
    owner_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_owner (owner_id),
    INDEX idx_public (is_public),
    INDEX idx_category (category)
);
```

### Prompt Versions Table
```sql
CREATE TABLE prompt_versions (
    id SERIAL PRIMARY KEY,
    prompt_id INTEGER REFERENCES prompts(id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (prompt_id, version_number),
    INDEX idx_prompt (prompt_id)
);
```

### Entity Relationships

```
users 1──────* prompts
users 1──────* templates
prompts 1────* prompt_versions
```

---

## API Architecture

### RESTful Design Principles

**Resource-Based URLs:**
```
/api/v1/auth/register       # POST - Create user
/api/v1/auth/login          # POST - Login
/api/v1/prompts             # GET - List prompts
/api/v1/prompts             # POST - Create prompt
/api/v1/prompts/{id}        # GET - Get prompt
/api/v1/prompts/{id}        # PUT - Update prompt
/api/v1/prompts/{id}        # DELETE - Delete prompt
```

**HTTP Methods:**
- GET: Retrieve resources
- POST: Create resources
- PUT: Update resources
- DELETE: Delete resources

**Status Codes:**
- 200: OK
- 201: Created
- 204: No Content
- 400: Bad Request
- 401: Unauthorized
- 403: Forbidden
- 404: Not Found
- 422: Validation Error
- 429: Rate Limited
- 500: Server Error

### API Versioning

Current: `/api/v1/*`

Future versions will use `/api/v2/*` for backwards compatibility.

---

## Security Architecture

### Defense in Depth

**Layer 1: Network Security**
- HTTPS/TLS 1.2+
- HSTS headers
- CORS configuration
- Rate limiting (60 req/min)

**Layer 2: Application Security**
- JWT authentication
- Password hashing (bcrypt, 12 rounds)
- Input validation (Pydantic)
- Input sanitization (bleach)
- CSRF protection
- XSS protection headers

**Layer 3: Data Security**
- Database connection encryption (SSL)
- Secrets management (environment variables)
- No hardcoded credentials
- Prepared statements (SQL injection prevention)

**Layer 4: Monitoring & Response**
- Error tracking (Sentry)
- Audit logging
- Security event monitoring
- Incident response plan

### Authentication Flow

```
1. User submits credentials
   └─> POST /api/v1/auth/login
       
2. Server validates credentials
   ├─> Lookup user by username
   ├─> Verify password (bcrypt.verify)
   └─> Generate JWT token (30min expiry)
       
3. Client stores token
   └─> In memory (or httpOnly cookie)
       
4. Client includes token in requests
   └─> Authorization: Bearer <token>
       
5. Server validates token
   ├─> Decode JWT
   ├─> Verify signature
   ├─> Check expiration
   └─> Extract user info
       
6. If valid: Process request
   If invalid: Return 401 Unauthorized
```

---

## Deployment Architecture

### Container Architecture

**Backend Container:**
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Frontend Container:**
```dockerfile
FROM node:20-alpine as build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
```

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: promptforge-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: promptforge-backend
  template:
    metadata:
      labels:
        app: promptforge-backend
    spec:
      containers:
      - name: backend
        image: promptforge/backend:latest
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: promptforge-secrets
              key: database-url
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Scalability Considerations

**Horizontal Scaling:**
- Stateless application design
- Load balancer distribution
- Session token-based auth (no server state)
- Database connection pooling

**Vertical Scaling:**
- Increased CPU/memory for containers
- Database server upgrades
- Cache layer (Redis - planned)

**Database Scaling:**
- Read replicas for read-heavy workloads
- Connection pooling
- Query optimization
- Indexing strategy

---

**Version:** 1.0.0
**Last Updated:** December 2024

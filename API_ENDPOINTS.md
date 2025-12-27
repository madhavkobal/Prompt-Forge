# PromptForge API Endpoints Documentation

## Base URL
```
http://localhost:8000
```

## API Version
```
/api/v1
```

---

## Authentication Endpoints

### 1. Register New User
**POST** `/api/v1/auth/register`

Create a new user account.

**Request Body:**
```json
{
  "email": "user@example.com",
  "username": "johndoe",
  "password": "securepassword",
  "full_name": "John Doe" // optional
}
```

**Response:** `201 Created`
```json
{
  "id": 1,
  "email": "user@example.com",
  "username": "johndoe",
  "full_name": "John Doe",
  "is_active": true,
  "created_at": "2024-01-15T10:30:00"
}
```

**Errors:**
- `400 Bad Request` - Email or username already exists
- `422 Unprocessable Entity` - Validation error

---

### 2. Login
**POST** `/api/v1/auth/login`

Authenticate user and receive access token.

**Request Body:** `multipart/form-data`
```
username: johndoe
password: securepassword
```

**Response:** `200 OK`
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

**Errors:**
- `401 Unauthorized` - Invalid credentials

**Usage:**
Include the access token in subsequent requests:
```
Authorization: Bearer <access_token>
```

---

### 3. Get Current User
**GET** `/api/v1/auth/me`

Get information about the authenticated user.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:** `200 OK`
```json
{
  "id": 1,
  "email": "user@example.com",
  "username": "johndoe",
  "full_name": "John Doe",
  "is_active": true,
  "created_at": "2024-01-15T10:30:00"
}
```

**Errors:**
- `401 Unauthorized` - Invalid or missing token

---

## Prompt Endpoints

All prompt endpoints require authentication.

### 1. Create Prompt
**POST** `/api/v1/prompts/`

Create a new prompt.

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "title": "SEO Article Writer",
  "content": "Write a comprehensive SEO-optimized article about...",
  "target_llm": "ChatGPT",
  "category": "writing",
  "tags": ["seo", "content", "marketing"]
}
```

**Response:** `201 Created`
```json
{
  "id": 1,
  "title": "SEO Article Writer",
  "content": "Write a comprehensive SEO-optimized article about...",
  "target_llm": "ChatGPT",
  "category": "writing",
  "tags": ["seo", "content", "marketing"],
  "owner_id": 1,
  "quality_score": null,
  "clarity_score": null,
  "specificity_score": null,
  "structure_score": null,
  "created_at": "2024-01-15T10:30:00",
  "updated_at": "2024-01-15T10:30:00"
}
```

---

### 2. Get All Prompts
**GET** `/api/v1/prompts/`

Get all prompts for the authenticated user.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `skip` (int, default: 0) - Number of records to skip
- `limit` (int, default: 100) - Maximum number of records to return

**Response:** `200 OK`
```json
[
  {
    "id": 1,
    "title": "SEO Article Writer",
    "content": "Write a comprehensive...",
    "target_llm": "ChatGPT",
    "quality_score": 87.5,
    "created_at": "2024-01-15T10:30:00",
    "updated_at": "2024-01-15T10:30:00"
  }
]
```

---

### 3. Get Prompt History
**GET** `/api/v1/prompts/history`

Get user's prompt history sorted by most recent.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `skip` (int, default: 0) - Number of records to skip
- `limit` (int, default: 100) - Maximum number of records to return

**Response:** `200 OK`
```json
[
  {
    "id": 3,
    "title": "Latest Prompt",
    "content": "...",
    "updated_at": "2024-01-15T15:00:00"
  },
  {
    "id": 1,
    "title": "Older Prompt",
    "content": "...",
    "updated_at": "2024-01-15T10:30:00"
  }
]
```

---

### 4. Get Single Prompt
**GET** `/api/v1/prompts/{prompt_id}`

Get a specific prompt by ID.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:** `200 OK`
```json
{
  "id": 1,
  "title": "SEO Article Writer",
  "content": "Write a comprehensive SEO-optimized article about...",
  "target_llm": "ChatGPT",
  "quality_score": 87.5,
  "clarity_score": 90.0,
  "specificity_score": 85.0,
  "structure_score": 88.0,
  "suggestions": ["Add more context", "Specify output format"],
  "best_practices": {...},
  "created_at": "2024-01-15T10:30:00",
  "updated_at": "2024-01-15T10:30:00"
}
```

**Errors:**
- `404 Not Found` - Prompt doesn't exist or doesn't belong to user

---

### 5. Update Prompt
**PUT** `/api/v1/prompts/{prompt_id}`

Update an existing prompt.

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body:** (all fields optional)
```json
{
  "title": "Updated Title",
  "content": "Updated content...",
  "target_llm": "Claude",
  "category": "analysis",
  "tags": ["updated", "tags"]
}
```

**Response:** `200 OK`
```json
{
  "id": 1,
  "title": "Updated Title",
  "content": "Updated content...",
  "updated_at": "2024-01-15T11:00:00"
}
```

**Note:** Updating content creates a new version automatically.

**Errors:**
- `404 Not Found` - Prompt doesn't exist or doesn't belong to user

---

### 6. Delete Prompt
**DELETE** `/api/v1/prompts/{prompt_id}`

Delete a prompt.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:** `204 No Content`

**Errors:**
- `404 Not Found` - Prompt doesn't exist or doesn't belong to user

---

### 7. Analyze Prompt
**POST** `/api/v1/prompts/{prompt_id}/analyze`

Analyze prompt quality using AI.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:** `200 OK`
```json
{
  "quality_score": 87.5,
  "clarity_score": 90.0,
  "specificity_score": 85.0,
  "structure_score": 88.0,
  "strengths": [
    "Clear objective stated",
    "Specific requirements listed",
    "Well-structured format"
  ],
  "weaknesses": [
    "Could add more context about target audience",
    "Output format not specified"
  ],
  "suggestions": [
    "Add expected output format",
    "Include tone and style preferences",
    "Specify word count or length"
  ],
  "best_practices": {
    "has_clear_instruction": "excellent",
    "has_context": "good",
    "has_constraints": "fair",
    "has_examples": "poor",
    "ambiguities": [
      "Target audience is not specified"
    ]
  }
}
```

**Processing:**
- Uses Google Gemini API for analysis
- Updates prompt record with scores
- Evaluates: clarity, specificity, structure, context completeness
- Detects ambiguities and suggests improvements

**Errors:**
- `404 Not Found` - Prompt doesn't exist
- `500 Internal Server Error` - AI service error

---

### 8. Enhance Prompt
**POST** `/api/v1/prompts/{prompt_id}/enhance`

Generate an enhanced version of the prompt using AI.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:** `200 OK`
```json
{
  "original_content": "Write an article about AI...",
  "enhanced_content": "Write a comprehensive, SEO-optimized article about AI developments in 2024. Target audience: tech-savvy professionals. Tone: informative yet engaging. Include: 1) Latest AI breakthroughs, 2) Industry impact analysis, 3) Future predictions. Format: 1500-2000 words with subheadings. Include real-world examples and cite recent sources.",
  "quality_improvement": 15.5,
  "improvements": [
    "Added clear target audience specification",
    "Defined tone and style expectations",
    "Structured content requirements with numbered list",
    "Specified word count and formatting",
    "Added requirement for examples and citations"
  ]
}
```

**Processing:**
- Uses Google Gemini API for enhancement
- Generates improved version with better structure
- Stores enhanced content in prompt record
- Returns both original and enhanced versions

**Errors:**
- `404 Not Found` - Prompt doesn't exist
- `500 Internal Server Error` - AI service error

---

### 9. Get Prompt Versions
**GET** `/api/v1/prompts/{prompt_id}/versions`

Get all versions of a prompt (version history).

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:** `200 OK`
```json
[
  {
    "id": 3,
    "prompt_id": 1,
    "version_number": 3,
    "content": "Most recent version...",
    "created_at": "2024-01-15T12:00:00"
  },
  {
    "id": 2,
    "prompt_id": 1,
    "version_number": 2,
    "content": "Second version...",
    "created_at": "2024-01-15T11:00:00"
  },
  {
    "id": 1,
    "prompt_id": 1,
    "version_number": 1,
    "content": "Original version...",
    "created_at": "2024-01-15T10:30:00"
  }
]
```

**Note:** Versions are returned in descending order (most recent first).

**Errors:**
- `404 Not Found` - Prompt doesn't exist

---

## Template Endpoints

All template endpoints require authentication.

### 1. Create Template
**POST** `/api/v1/templates/`

Create a new template.

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "name": "Blog Post Template",
  "description": "SEO-optimized blog post structure",
  "content": "Write a blog post about {topic}. Include: introduction, 3 main points, conclusion. Target audience: {audience}. Tone: {tone}.",
  "category": "content",
  "tags": ["blog", "seo", "content"],
  "is_public": true
}
```

**Response:** `201 Created`
```json
{
  "id": 1,
  "name": "Blog Post Template",
  "description": "SEO-optimized blog post structure",
  "content": "Write a blog post about {topic}...",
  "category": "content",
  "tags": ["blog", "seo", "content"],
  "is_public": true,
  "owner_id": 1,
  "use_count": 0,
  "created_at": "2024-01-15T10:30:00"
}
```

---

### 2. Get All Templates
**GET** `/api/v1/templates/`

Get templates (user's own + public templates).

**Headers:**
```
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `skip` (int, default: 0) - Number of records to skip
- `limit` (int, default: 100) - Maximum number of records to return
- `include_public` (bool, default: true) - Include public templates

**Response:** `200 OK`
```json
[
  {
    "id": 1,
    "name": "Blog Post Template",
    "description": "SEO-optimized blog post structure",
    "content": "Write a blog post about {topic}...",
    "is_public": true,
    "use_count": 42,
    "created_at": "2024-01-15T10:30:00"
  }
]
```

---

### 3. Get Single Template
**GET** `/api/v1/templates/{template_id}`

Get a specific template by ID.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:** `200 OK`
```json
{
  "id": 1,
  "name": "Blog Post Template",
  "description": "SEO-optimized blog post structure",
  "content": "Write a blog post about {topic}...",
  "category": "content",
  "tags": ["blog", "seo", "content"],
  "is_public": true,
  "use_count": 43,
  "created_at": "2024-01-15T10:30:00"
}
```

**Note:** Automatically increments use_count when accessed.

**Errors:**
- `404 Not Found` - Template doesn't exist
- `403 Forbidden` - Template is private and doesn't belong to user

---

### 4. Delete Template
**DELETE** `/api/v1/templates/{template_id}`

Delete a template (only your own templates).

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:** `204 No Content`

**Errors:**
- `404 Not Found` - Template doesn't exist or doesn't belong to user

---

## Advanced Analysis Endpoints

### 1. Generate Multiple Enhanced Versions
**POST** `/api/v1/analysis/prompt/{prompt_id}/versions`

Generate 2-3 different enhanced versions of a prompt.

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "num_versions": 3
}
```

**Response:** `200 OK`
```json
{
  "versions": [
    {
      "version_number": 1,
      "content": "Enhanced version 1...",
      "focus": "Clarity and structure",
      "quality_improvement": 12.5
    },
    {
      "version_number": 2,
      "content": "Enhanced version 2...",
      "focus": "Specificity and context",
      "quality_improvement": 15.0
    },
    {
      "version_number": 3,
      "content": "Enhanced version 3...",
      "focus": "Comprehensive improvement",
      "quality_improvement": 18.5
    }
  ]
}
```

---

### 2. Detect Ambiguities
**POST** `/api/v1/analysis/prompt/{prompt_id}/ambiguities`

Detect ambiguous parts in a prompt.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:** `200 OK`
```json
{
  "ambiguities": [
    {
      "text": "Write something interesting",
      "issue": "'Interesting' is subjective and unclear",
      "suggestion": "Specify what makes content interesting for your use case"
    },
    {
      "text": "Make it good",
      "issue": "Vague quality criteria",
      "suggestion": "Define specific quality metrics or criteria"
    }
  ],
  "count": 2,
  "severity": "medium"
}
```

---

### 3. Check Best Practices
**GET** `/api/v1/analysis/prompt/{prompt_id}/best-practices`

Check prompt against LLM-specific best practices.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:** `200 OK`
```json
{
  "target_llm": "ChatGPT",
  "checks": {
    "has_clear_instruction": {
      "status": "pass",
      "rating": "excellent",
      "description": "Prompt has clear, actionable instruction"
    },
    "has_context": {
      "status": "pass",
      "rating": "good",
      "description": "Sufficient context provided"
    },
    "has_constraints": {
      "status": "warning",
      "rating": "fair",
      "description": "Some constraints defined but could be more specific"
    },
    "has_examples": {
      "status": "fail",
      "rating": "poor",
      "description": "No examples provided for reference"
    },
    "appropriate_length": {
      "status": "pass",
      "rating": "good",
      "description": "Prompt length is appropriate for complexity"
    }
  },
  "overall_compliance": 72,
  "recommendations": [
    "Add 1-2 examples of expected output",
    "Specify more detailed constraints (word count, format, style)",
    "Consider adding edge cases to handle"
  ]
}
```

---

### 4. List Available Models
**GET** `/api/v1/analysis/models`

Get list of available Gemini models for analysis.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:** `200 OK`
```json
{
  "models": [
    {
      "id": "gemini-pro",
      "name": "Gemini Pro",
      "description": "Standard model for analysis and enhancement",
      "capabilities": ["analysis", "enhancement", "best-practices"]
    },
    {
      "id": "gemini-1.5-pro",
      "name": "Gemini 1.5 Pro",
      "description": "Advanced model with longer context",
      "capabilities": ["analysis", "enhancement", "best-practices", "complex-reasoning"]
    },
    {
      "id": "gemini-1.5-flash",
      "name": "Gemini 1.5 Flash",
      "description": "Fast model for quick analysis",
      "capabilities": ["analysis", "enhancement"]
    }
  ]
}
```

---

## Health Check

### Health Check
**GET** `/health`

Check if the API is running.

**Response:** `200 OK`
```json
{
  "status": "healthy"
}
```

---

## Error Responses

All endpoints may return the following error responses:

### 400 Bad Request
```json
{
  "detail": "Invalid request parameters"
}
```

### 401 Unauthorized
```json
{
  "detail": "Could not validate credentials"
}
```

### 403 Forbidden
```json
{
  "detail": "Access denied"
}
```

### 404 Not Found
```json
{
  "detail": "Resource not found"
}
```

### 422 Unprocessable Entity
```json
{
  "detail": [
    {
      "loc": ["body", "email"],
      "msg": "invalid email format",
      "type": "value_error.email"
    }
  ]
}
```

### 500 Internal Server Error
```json
{
  "detail": "Internal server error"
}
```

---

## Rate Limiting

Currently, there is no rate limiting implemented. This will be added in future versions.

## CORS Configuration

The API allows requests from configured origins specified in the `.env` file.

Default development origin: `http://localhost:5173`

---

## Interactive API Documentation

FastAPI provides interactive API documentation:

- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

---

## Data Models

### LLM Types
Supported target LLM types:
- `ChatGPT`
- `Claude`
- `Gemini`
- `Grok`
- `DeepSeek`

### Categories
Common categories:
- `writing`
- `coding`
- `analysis`
- `creative`
- `business`
- `education`

---

## Authentication Flow

1. **Register**: Create account with `POST /auth/register`
2. **Login**: Get access token with `POST /auth/login`
3. **Use Token**: Include in all requests: `Authorization: Bearer <token>`
4. **Verify**: Check token with `GET /auth/me`

Token expires after 7 days (configurable in settings).

---

## Example Workflow

### Complete Prompt Analysis & Enhancement Flow

```bash
# 1. Register
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "username": "johndoe",
    "password": "securepass"
  }'

# 2. Login
curl -X POST http://localhost:8000/api/v1/auth/login \
  -F "username=johndoe" \
  -F "password=securepass"

# Response: {"access_token": "...", "token_type": "bearer"}

# 3. Create Prompt
curl -X POST http://localhost:8000/api/v1/prompts/ \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My Prompt",
    "content": "Write an article about AI",
    "target_llm": "ChatGPT"
  }'

# Response: {"id": 1, ...}

# 4. Analyze Prompt
curl -X POST http://localhost:8000/api/v1/prompts/1/analyze \
  -H "Authorization: Bearer <token>"

# 5. Enhance Prompt
curl -X POST http://localhost:8000/api/v1/prompts/1/enhance \
  -H "Authorization: Bearer <token>"

# 6. Get History
curl -X GET http://localhost:8000/api/v1/prompts/history \
  -H "Authorization: Bearer <token>"
```

---

## Notes

- All timestamps are in ISO 8601 format (UTC)
- All IDs are integers
- Tags are arrays of strings
- Scores are floats between 0 and 100
- Authentication is required for all endpoints except `/health`, `/auth/register`, and `/auth/login`

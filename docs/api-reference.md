# PromptForge API Reference

Complete REST API documentation for PromptForge v1.0.

## Base URL

```
http://localhost:8000/api/v1  # Development
https://api.promptforge.io/api/v1  # Production
```

## Authentication

PromptForge uses JWT (JSON Web Token) for authentication.

### Get Access Token

**Endpoint:** `POST /api/v1/auth/login`

**Request Body:**
```json
{
  "username": "string",
  "password": "string"
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

**Using the Token:**
```
Authorization: Bearer <access_token>
```

Token expires after 30 minutes.

---

## Authentication Endpoints

### Register User

Create a new user account.

**Endpoint:** `POST /api/v1/auth/register`

**Request Body:**
```json
{
  "email": "user@example.com",
  "username": "myusername",
  "password": "SecurePass123!",
  "full_name": "John Doe"  // optional
}
```

**Response (201 Created):**
```json
{
  "id": 1,
  "email": "user@example.com",
  "username": "myusername",
  "full_name": "John Doe",
  "created_at": "2024-12-28T10:00:00Z"
}
```

**Error Responses:**
- `400 Bad Request`: Invalid input, weak password, or duplicate username/email
- `422 Unprocessable Entity`: Validation error

### Login

Authenticate and receive access token.

**Endpoint:** `POST /api/v1/auth/login`

**Request Body (Form Data):**
```
username=myusername&password=SecurePass123!
```

**Response (200 OK):**
```json
{
  "access_token": "eyJ...",
  "token_type": "bearer"
}
```

**Error Responses:**
- `401 Unauthorized`: Invalid credentials
- `429 Too Many Requests`: Rate limit exceeded

### Get Current User

Get authenticated user information.

**Endpoint:** `GET /api/v1/auth/me`

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "id": 1,
  "email": "user@example.com",
  "username": "myusername",
  "full_name": "John Doe",
  "created_at": "2024-12-28T10:00:00Z"
}
```

**Error Responses:**
- `401 Unauthorized`: Invalid or expired token

---

## Prompt Endpoints

### List Prompts

Get all prompts for authenticated user.

**Endpoint:** `GET /api/v1/prompts`

**Query Parameters:**
- `skip` (integer, default=0): Pagination offset
- `limit` (integer, default=20, max=100): Number of results
- `category` (string): Filter by category
- `target_llm` (string): Filter by target LLM
- `sort_by` (string): Sort field (created_at, quality_score, title)
- `order` (string): asc or desc

**Example:**
```
GET /api/v1/prompts?skip=0&limit=10&category=content&sort_by=quality_score&order=desc
```

**Response (200 OK):**
```json
{
  "items": [
    {
      "id": 1,
      "title": "Blog Post Generator",
      "content": "Write a blog post about...",
      "target_llm": "ChatGPT",
      "category": "content",
      "tags": ["blog", "writing"],
      "quality_score": 85.5,
      "clarity_score": 88.0,
      "specificity_score": 82.0,
      "structure_score": 87.0,
      "created_at": "2024-12-28T10:00:00Z",
      "updated_at": "2024-12-28T10:30:00Z"
    }
  ],
  "total": 42,
  "skip": 0,
  "limit": 10
}
```

### Create Prompt

Create a new prompt.

**Endpoint:** `POST /api/v1/prompts`

**Request Body:**
```json
{
  "title": "Blog Post Generator",
  "content": "Write a comprehensive blog post about {topic}...",
  "target_llm": "ChatGPT",
  "category": "content",
  "tags": ["blog", "writing"]
}
```

**Response (201 Created):**
```json
{
  "id": 1,
  "title": "Blog Post Generator",
  "content": "Write a comprehensive blog post about {topic}...",
  "target_llm": "ChatGPT",
  "category": "content",
  "tags": ["blog", "writing"],
  "owner_id": 1,
  "created_at": "2024-12-28T10:00:00Z",
  "updated_at": "2024-12-28T10:00:00Z"
}
```

### Get Prompt

Get a specific prompt by ID.

**Endpoint:** `GET /api/v1/prompts/{prompt_id}`

**Response (200 OK):**
```json
{
  "id": 1,
  "title": "Blog Post Generator",
  "content": "Write a comprehensive blog post about...",
  "target_llm": "ChatGPT",
  "category": "content",
  "tags": ["blog", "writing"],
  "quality_score": 85.5,
  "clarity_score": 88.0,
  "specificity_score": 82.0,
  "structure_score": 87.0,
  "suggestions": ["Add more examples", "Specify tone"],
  "best_practices": {
    "has_clear_instruction": "excellent",
    "has_context": "good"
  },
  "owner_id": 1,
  "created_at": "2024-12-28T10:00:00Z",
  "updated_at": "2024-12-28T10:30:00Z"
}
```

**Error Responses:**
- `404 Not Found`: Prompt doesn't exist
- `403 Forbidden`: Not authorized to view this prompt

### Update Prompt

Update an existing prompt.

**Endpoint:** `PUT /api/v1/prompts/{prompt_id}`

**Request Body:**
```json
{
  "title": "Updated Blog Post Generator",
  "content": "Write a comprehensive blog post...",
  "category": "content",
  "tags": ["blog", "writing", "SEO"]
}
```

**Response (200 OK):**
Returns updated prompt object.

### Delete Prompt

Delete a prompt.

**Endpoint:** `DELETE /api/v1/prompts/{prompt_id}`

**Response (204 No Content)**

---

## Analysis Endpoints

### Analyze Prompt

Analyze prompt quality using AI.

**Endpoint:** `POST /api/v1/analysis/analyze/{prompt_id}`

**Response (200 OK):**
```json
{
  "prompt_id": 1,
  "quality_score": 85.5,
  "clarity_score": 88.0,
  "specificity_score": 82.0,
  "structure_score": 87.0,
  "strengths": [
    "Clear objective stated",
    "Specific topic defined",
    "Well-structured request"
  ],
  "weaknesses": [
    "Could add more context about target audience",
    "Output format not specified"
  ],
  "suggestions": [
    "Add expected article length",
    "Specify tone and style",
    "Include target audience details"
  ],
  "best_practices": {
    "has_clear_instruction": "excellent",
    "has_context": "good",
    "has_constraints": "fair",
    "has_examples": "poor"
  }
}
```

### Enhance Prompt

Enhance prompt using AI.

**Endpoint:** `POST /api/v1/analysis/enhance/{prompt_id}`

**Response (200 OK):**
```json
{
  "prompt_id": 1,
  "original_content": "Write a blog post about AI.",
  "enhanced_content": "Write a comprehensive, well-structured blog post about AI...",
  "quality_improvement": 15.5,
  "improvements": [
    "Added clear target audience specification",
    "Defined tone and style expectations",
    "Structured content requirements with numbered list"
  ]
}
```

### Generate Multiple Versions

Generate multiple enhanced versions.

**Endpoint:** `POST /api/v1/analysis/versions/{prompt_id}`

**Query Parameters:**
- `count` (integer, default=3): Number of versions to generate

**Response (200 OK):**
```json
{
  "versions": [
    {
      "version_number": 1,
      "content": "Enhanced version 1 focusing on clarity...",
      "focus": "Clarity and structure",
      "quality_improvement": 12.5
    },
    {
      "version_number": 2,
      "content": "Enhanced version 2 focusing on specificity...",
      "focus": "Specificity and detail",
      "quality_improvement": 15.0
    }
  ]
}
```

---

## Template Endpoints

### List Templates

Get templates (user's + public).

**Endpoint:** `GET /api/v1/templates`

**Query Parameters:**
- `skip`, `limit`: Pagination
- `category`: Filter by category
- `is_public`: Filter by visibility (true/false)

**Response (200 OK):**
```json
{
  "items": [
    {
      "id": 1,
      "name": "Blog Post Template",
      "description": "Template for creating blog posts",
      "content": "Write a blog post about {topic}...",
      "category": "content",
      "tags": ["blog", "content"],
      "is_public": true,
      "owner_id": 1,
      "created_at": "2024-12-28T10:00:00Z"
    }
  ],
  "total": 15,
  "skip": 0,
  "limit": 20
}
```

### Create Template

Create a new template.

**Endpoint:** `POST /api/v1/templates`

**Request Body:**
```json
{
  "name": "Blog Post Template",
  "description": "Template for creating blog posts",
  "content": "Write a {format} about {topic} for {audience}...",
  "category": "content",
  "tags": ["blog", "content"],
  "is_public": true
}
```

### Use Template

Create prompt from template.

**Endpoint:** `POST /api/v1/templates/{template_id}/use`

**Request Body:**
```json
{
  "variables": {
    "topic": "AI in Healthcare",
    "format": "blog post",
    "audience": "healthcare professionals"
  }
}
```

**Response (201 Created):**
Returns newly created prompt object.

---

## Health Check Endpoints

### Basic Health

**Endpoint:** `GET /health`

**Response (200 OK):**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "environment": "production"
}
```

### Detailed Health

**Endpoint:** `GET /health/detailed`

**Response (200 OK):**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "checks": {
    "database": {
      "status": "healthy",
      "latency_ms": 5.2
    },
    "gemini_api": {
      "status": "healthy",
      "latency_ms": 150.3
    }
  }
}
```

### Metrics

**Endpoint:** `GET /metrics`

Returns Prometheus-formatted metrics.

---

## Error Responses

### Standard Error Format

```json
{
  "detail": "Error message describing what went wrong"
}
```

### Common HTTP Status Codes

- `200 OK`: Success
- `201 Created`: Resource created successfully
- `204 No Content`: Success with no response body
- `400 Bad Request`: Invalid request data
- `401 Unauthorized`: Missing or invalid authentication
- `403 Forbidden`: Authenticated but not authorized
- `404 Not Found`: Resource not found
- `422 Unprocessable Entity`: Validation error
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error
- `503 Service Unavailable`: Service temporarily unavailable

---

## Rate Limiting

- **Limit**: 60 requests per minute per user/IP
- **Headers in Response**:
  - `X-RateLimit-Limit`: 60
  - `X-RateLimit-Remaining`: 45
  - `X-RateLimit-Reset`: 1234567890

When rate limited:
```json
{
  "detail": "Rate limit exceeded. Please try again later.",
  "retry_after": 30
}
```

---

## Example Code

### Python

```python
import requests

BASE_URL = "http://localhost:8000/api/v1"

# Login
response = requests.post(
    f"{BASE_URL}/auth/login",
    data={"username": "myuser", "password": "MyPass123!"}
)
token = response.json()["access_token"]

# Create headers
headers = {"Authorization": f"Bearer {token}"}

# Create prompt
prompt_data = {
    "title": "Test Prompt",
    "content": "Write a blog post about AI",
    "target_llm": "ChatGPT",
    "category": "content",
    "tags": ["test"]
}
response = requests.post(
    f"{BASE_URL}/prompts",
    json=prompt_data,
    headers=headers
)
prompt_id = response.json()["id"]

# Analyze prompt
response = requests.post(
    f"{BASE_URL}/analysis/analyze/{prompt_id}",
    headers=headers
)
analysis = response.json()
print(f"Quality Score: {analysis['quality_score']}")
```

### JavaScript

```javascript
const BASE_URL = 'http://localhost:8000/api/v1';

// Login
const loginResponse = await fetch(`${BASE_URL}/auth/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: 'username=myuser&password=MyPass123!'
});
const { access_token } = await loginResponse.json();

// Create prompt
const promptData = {
  title: 'Test Prompt',
  content: 'Write a blog post about AI',
  target_llm: 'ChatGPT',
  category: 'content',
  tags: ['test']
};

const response = await fetch(`${BASE_URL}/prompts`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${access_token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify(promptData)
});

const prompt = await response.json();
console.log('Created prompt:', prompt.id);
```

---

**Version:** 1.0.0
**Last Updated:** December 2024

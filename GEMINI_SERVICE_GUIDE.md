# Google Gemini API Integration Guide

## Overview

The enhanced Gemini service provides comprehensive prompt analysis and enhancement capabilities with retry logic, multiple model support, and advanced features.

## Features Implemented ✅

### 1. Multi-Dimensional Analysis
- **Clarity Score (0-100)**: Evaluates how clear and understandable the prompt is
- **Specificity Score (0-100)**: Measures detail and requirement specificity
- **Structure Score (0-100)**: Assesses organization and formatting
- **Context Completeness**: Evaluates if sufficient background is provided
- **Ambiguity Detection**: Identifies unclear or confusing parts

### 2. Prompt Enhancement
- **Single Best Version**: Generates one optimized prompt
- **Multiple Versions (2-3)**: Creates different approaches:
  - Version 1: Focus on clarity and structure
  - Version 2: Focus on specificity and detail
  - Version 3: Focus on context and examples

### 3. Error Handling & Retry Logic
- **Exponential Backoff**: Automatic retry with 1s, 2s, 4s delays
- **Smart Error Detection**: Doesn't retry authentication errors
- **Fallback Responses**: Provides reasonable defaults if API fails
- **Graceful Degradation**: Service continues functioning during outages

### 4. Multi-Model Support
- **gemini-pro**: Standard model (default)
- **gemini-1.5-pro**: Latest with improved capabilities
- **gemini-1.5-flash**: Faster alternative

## Service Class: `GeminiService`

### Initialization

```python
from app.services.gemini_service import GeminiService

# Default initialization (gemini-pro, 3 retries)
service = GeminiService()

# Custom model and retry settings
service = GeminiService(model_name='gemini-1.5-pro', max_retries=5)
```

### Available Models

```python
GeminiService.SUPPORTED_MODELS = {
    'gemini-pro': 'gemini-pro',
    'gemini-1.5-pro': 'gemini-1.5-pro-latest',
    'gemini-1.5-flash': 'gemini-1.5-flash-latest',
}
```

## API Methods

### 1. `analyze_prompt()` - Comprehensive Analysis

**Purpose**: Evaluate prompt quality across multiple dimensions

**Parameters**:
- `content` (str): The prompt to analyze
- `target_llm` (Optional[str]): Target LLM (ChatGPT, Claude, Gemini, etc.)

**Returns**: `PromptAnalysis` object with:
```python
{
    "quality_score": 85.0,
    "clarity_score": 90.0,
    "specificity_score": 80.0,
    "structure_score": 85.0,
    "strengths": [
        "Clear role definition",
        "Well-structured with examples"
    ],
    "weaknesses": [
        "Could be more specific about output format",
        "Missing context about constraints"
    ],
    "suggestions": [
        "Add explicit output format requirements",
        "Include success criteria"
    ],
    "best_practices": {
        "context": "good",
        "role_definition": "excellent",
        "output_format": "fair",
        "constraints": "poor",
        "ambiguities": ["what kind of report"]
    }
}
```

**Example Usage**:
```python
service = GeminiService()
analysis = service.analyze_prompt(
    content="Write a report about climate change",
    target_llm="ChatGPT"
)

print(f"Quality Score: {analysis.quality_score}")
print(f"Suggestions: {analysis.suggestions}")
```

### 2. `enhance_prompt()` - Single Best Enhancement

**Purpose**: Generate one optimized version of the prompt

**Parameters**:
- `content` (str): Original prompt
- `target_llm` (Optional[str]): Target LLM for optimization

**Returns**: `PromptEnhancement` object with:
```python
{
    "original_content": "Write a report about climate change",
    "enhanced_content": "You are an environmental science expert. Write a comprehensive report about climate change that includes:\n\n1. Current scientific consensus\n2. Major contributing factors\n3. Observed impacts globally\n4. Mitigation strategies\n\nFormat: 1500-2000 words, with citations\nAudience: Policy makers with basic scientific knowledge",
    "improvements": [
        "Added clear role definition",
        "Structured requirements as numbered list",
        "Specified output format and length",
        "Defined target audience"
    ],
    "quality_improvement": 45.5
}
```

**Example Usage**:
```python
enhancement = service.enhance_prompt(
    content="Write a report about climate change",
    target_llm="Claude"
)

print(f"Enhanced: {enhancement.enhanced_content}")
print(f"Improvement: +{enhancement.quality_improvement}%")
```

### 3. `generate_prompt_versions()` - Multiple Versions

**Purpose**: Create 2-3 different enhanced versions with different focuses

**Parameters**:
- `content` (str): Original prompt
- `target_llm` (Optional[str]): Target LLM
- `num_versions` (int): Number of versions (default: 3)

**Returns**: List of version dictionaries:
```python
[
    {
        "version_number": 1,
        "title": "Clear & Structured",
        "enhanced_content": "...",
        "improvements": ["...", "..."],
        "focus": "clarity and structure"
    },
    {
        "version_number": 2,
        "title": "Specific & Detailed",
        "enhanced_content": "...",
        "improvements": ["...", "..."],
        "focus": "specificity and detail"
    },
    {
        "version_number": 3,
        "title": "Context-Rich",
        "enhanced_content": "...",
        "improvements": ["...", "..."],
        "focus": "context and examples"
    }
]
```

**Example Usage**:
```python
versions = service.generate_prompt_versions(
    content="Explain quantum computing",
    target_llm="Gemini",
    num_versions=3
)

for version in versions:
    print(f"\n{version['title']}:")
    print(version['enhanced_content'])
```

### 4. `detect_ambiguities()` - Ambiguity Detection

**Purpose**: Identify unclear or ambiguous parts of a prompt

**Parameters**:
- `content` (str): Prompt to analyze

**Returns**: List of ambiguities:
```python
[
    {
        "phrase": "write something good",
        "reason": "Subjective term 'good' without clear criteria",
        "suggestion": "Define specific quality metrics (e.g., 'write a 500-word article with 3 cited sources')"
    },
    {
        "phrase": "as soon as possible",
        "reason": "Unclear timeframe",
        "suggestion": "Specify exact deadline or timeframe"
    }
]
```

**Example Usage**:
```python
ambiguities = service.detect_ambiguities(
    "Write something good about AI as soon as possible"
)

for amb in ambiguities:
    print(f"⚠️ Ambiguous: {amb['phrase']}")
    print(f"   Why: {amb['reason']}")
    print(f"   Fix: {amb['suggestion']}")
```

### 5. `check_best_practices()` - LLM-Specific Guidelines

**Purpose**: Check compliance with LLM-specific best practices

**Parameters**:
- `content` (str): Prompt to check
- `target_llm` (str): Target LLM

**Returns**: Compliance report:
```python
{
    "target_llm": "ChatGPT",
    "best_practices": [
        "Use clear role definitions",
        "Provide context and background",
        "Specify output format",
        "Break complex tasks into steps",
        "Include examples when helpful"
    ],
    "compliance_score": 65.0,
    "recommendations": [
        "Add more context and details",
        "Use clear role definitions",
        "Provide context and background"
    ]
}
```

## API Endpoints

### Analysis Endpoints (`/api/v1/analysis/`)

#### 1. Generate Multiple Versions
```
POST /api/v1/analysis/prompt/{prompt_id}/versions?num_versions=3
```

**Response**:
```json
{
    "original_prompt": "...",
    "target_llm": "ChatGPT",
    "versions": [...],
    "count": 3
}
```

#### 2. Detect Ambiguities
```
POST /api/v1/analysis/prompt/{prompt_id}/ambiguities
```

**Response**:
```json
{
    "prompt_id": 123,
    "ambiguities": [...],
    "count": 2,
    "has_ambiguities": true
}
```

#### 3. Check Best Practices
```
GET /api/v1/analysis/prompt/{prompt_id}/best-practices
```

**Response**:
```json
{
    "target_llm": "Claude",
    "best_practices": [...],
    "compliance_score": 75.0,
    "recommendations": [...]
}
```

#### 4. Get Available Models
```
GET /api/v1/analysis/models
```

**Response**:
```json
{
    "models": [
        {
            "name": "gemini-pro",
            "id": "gemini-pro",
            "description": "Standard Gemini Pro model",
            "recommended": true
        }
    ],
    "default": "gemini-pro"
}
```

## Retry Logic

The service implements intelligent retry logic with exponential backoff:

### Retry Behavior
- **Attempt 1**: Immediate
- **Attempt 2**: Wait 1 second (2^0)
- **Attempt 3**: Wait 2 seconds (2^1)
- **Attempt 4**: Wait 4 seconds (2^2)

### Non-Retryable Errors
The service won't retry on:
- Authentication errors
- API key errors
- Invalid configuration

### Example
```python
try:
    # This will retry up to 3 times with exponential backoff
    analysis = service.analyze_prompt(content)
except Exception as e:
    # All retries failed
    print(f"Failed after 3 attempts: {e}")
```

## Error Handling

### Fallback Responses

If the API fails, the service provides reasonable defaults:

**Analysis Fallback**:
```python
{
    "quality_score": 60.0,
    "clarity_score": 65.0,
    "specificity_score": 55.0,
    "structure_score": 60.0,
    "strengths": ["Prompt provided"],
    "weaknesses": ["Analysis service temporarily unavailable"],
    "suggestions": ["Try again later"]
}
```

**Enhancement Fallback**:
```python
{
    "original_content": "...",
    "enhanced_content": "...",  # Returns original
    "improvements": ["Service temporarily unavailable"],
    "quality_improvement": 0.0
}
```

## Best Practices by LLM

### ChatGPT
- Use clear role definitions (e.g., "You are an expert...")
- Provide context and background information
- Specify desired output format explicitly
- Break complex tasks into numbered steps
- Include examples when helpful

### Claude
- Structure with XML tags for complex prompts
- Be explicit about constraints and requirements
- Use chain-of-thought prompting for reasoning
- Provide clear success criteria
- Leverage Claude's analytical and writing strengths

### Gemini
- Leverage multimodal capabilities when applicable
- Use structured output formats (JSON, tables)
- Provide clear context upfront
- Specify reasoning and thinking requirements
- Use iterative refinement approach

### Grok
- Be direct and specific in requests
- Leverage real-time knowledge when needed
- Use clear formatting and structure
- Provide explicit, actionable instructions

### DeepSeek
- Focus on reasoning and analytical tasks
- Provide step-by-step guidance for complex problems
- Use clear problem structure and definitions
- Leverage mathematical and logical capabilities

## Testing the Service

### Example Test Script

```python
from app.services.gemini_service import GeminiService

# Initialize service
service = GeminiService(model_name='gemini-pro')

# Test prompt
test_prompt = "Write a tutorial about Python"

# 1. Analyze
print("=== ANALYSIS ===")
analysis = service.analyze_prompt(test_prompt, "ChatGPT")
print(f"Quality: {analysis.quality_score}/100")
print(f"Clarity: {analysis.clarity_score}/100")

# 2. Enhance
print("\n=== ENHANCEMENT ===")
enhancement = service.enhance_prompt(test_prompt, "ChatGPT")
print(f"Original: {enhancement.original_content}")
print(f"Enhanced: {enhancement.enhanced_content}")

# 3. Multiple versions
print("\n=== VERSIONS ===")
versions = service.generate_prompt_versions(test_prompt, num_versions=2)
for v in versions:
    print(f"\n{v['title']}: {v['enhanced_content'][:100]}...")

# 4. Detect ambiguities
print("\n=== AMBIGUITIES ===")
ambiguities = service.detect_ambiguities(test_prompt)
print(f"Found {len(ambiguities)} ambiguities")

# 5. Check best practices
print("\n=== BEST PRACTICES ===")
practices = service.check_best_practices(test_prompt, "ChatGPT")
print(f"Compliance: {practices['compliance_score']}/100")
```

## Configuration

### Environment Variables

Required in `.env`:
```bash
GEMINI_API_KEY=your-api-key-here
```

### Model Selection

Change default model in service initialization:
```python
# Use faster flash model
service = GeminiService(model_name='gemini-1.5-flash')

# Use latest pro model
service = GeminiService(model_name='gemini-1.5-pro')
```

### Retry Configuration

Adjust retry attempts:
```python
# More aggressive retries
service = GeminiService(max_retries=5)

# No retries
service = GeminiService(max_retries=1)
```

## Performance Considerations

### API Call Costs
- Each analysis: 1 API call
- Each enhancement: 1 API call
- Multiple versions: 1 API call (all versions in one request)
- Ambiguity detection: 1 API call

### Response Times
- **gemini-pro**: ~2-5 seconds per request
- **gemini-1.5-flash**: ~1-3 seconds per request
- **gemini-1.5-pro**: ~3-7 seconds per request

*Times include retry logic and network latency*

### Rate Limiting
- Gemini API has rate limits (check Google AI Studio)
- Implement caching for frequently analyzed prompts
- Use batch processing for multiple prompts

## Troubleshooting

### Common Issues

**1. Authentication Error**
```
Error: API_KEY_INVALID
```
**Solution**: Check your `GEMINI_API_KEY` in `.env`

**2. JSON Parsing Error**
```
Error: JSON parsing error
```
**Solution**: Service will use fallback response automatically

**3. Rate Limit Exceeded**
```
Error: Resource exhausted
```
**Solution**: Wait and retry, or upgrade API quota

### Debug Mode

Enable detailed logging:
```python
import logging
logging.basicConfig(level=logging.DEBUG)

service = GeminiService()
# Now all API calls and responses will be logged
```

## Summary

The enhanced Gemini service provides:

✅ **Comprehensive Analysis** - 4 scoring dimensions + context evaluation
✅ **Multiple Enhancement Options** - 2-3 versions with different focuses
✅ **Ambiguity Detection** - Identify unclear parts automatically
✅ **Retry Logic** - Exponential backoff for reliability
✅ **Multi-Model Support** - Choose optimal model for your needs
✅ **Error Handling** - Graceful fallbacks ensure service continuity
✅ **LLM-Specific Best Practices** - Tailored recommendations

The service is production-ready and handles edge cases gracefully!

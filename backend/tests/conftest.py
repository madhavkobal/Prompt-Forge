"""
Pytest configuration and fixtures for PromptForge backend tests.

This module provides:
- Test database setup and teardown
- Test client for API requests
- Mock data factories
- Common fixtures for authentication, users, prompts, etc.
"""

import os
import pytest
from typing import Generator, Dict, Any
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool

# Set test environment (only if not already set by CI/CD)
os.environ.setdefault("ENVIRONMENT", "testing")
os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("SECRET_KEY", "test-secret-key-for-testing-only-not-secure")
os.environ.setdefault("GEMINI_API_KEY", "test-gemini-api-key")
# CORS_ORIGINS has a default value in config.py, no need to set it here

from app.main import app
from app.core.database import Base, get_db
from app.core.security import create_access_token
from app.models.user import User
from app.models.prompt import Prompt as PromptModel, Template, PromptVersion
from app.schemas.user import UserCreate
from app.services.auth_service import AuthService


# =============================================================================
# Database Fixtures
# =============================================================================

@pytest.fixture(scope="function")
def test_db() -> Generator[Session, None, None]:
    """
    Create a test database for each test function.
    Uses DATABASE_URL from environment (SQLite for local, PostgreSQL for CI).
    """
    # Get database URL from environment
    database_url = os.environ.get("DATABASE_URL", "sqlite:///:memory:")

    # Create test database engine
    if database_url.startswith("sqlite"):
        engine = create_engine(
            database_url,
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
    else:
        # PostgreSQL or other databases
        engine = create_engine(database_url)

    # Create all tables
    Base.metadata.create_all(bind=engine)

    # Create session
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()

    try:
        yield db
    finally:
        db.close()
        # Clean up tables after each test
        db.rollback()
        Base.metadata.drop_all(bind=engine)
        engine.dispose()


@pytest.fixture(scope="function")
def client(test_db: Session) -> Generator[TestClient, None, None]:
    """
    Create a test client with test database dependency override.
    """
    def override_get_db():
        try:
            yield test_db
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()


# =============================================================================
# User Fixtures
# =============================================================================

@pytest.fixture
def test_user_data() -> Dict[str, str]:
    """Test user registration data."""
    return {
        "email": "test@example.com",
        "username": "testuser",
        "password": "TestPassword123!",  # Strong password with uppercase, lowercase, digits, and special char
        "full_name": "Test User"
    }


@pytest.fixture
def test_user(test_db: Session, test_user_data: Dict[str, str]) -> User:
    """Create a test user in the database."""
    user_create = UserCreate(**test_user_data)
    user = AuthService.create_user(test_db, user_create)
    return user


@pytest.fixture
def test_user2_data() -> Dict[str, str]:
    """Second test user data for multi-user tests."""
    return {
        "email": "test2@example.com",
        "username": "testuser2",
        "password": "TestPassword456!",  # Strong password with uppercase, lowercase, digits, and special char
        "full_name": "Test User Two"
    }


@pytest.fixture
def test_user2(test_db: Session, test_user2_data: Dict[str, str]) -> User:
    """Create a second test user."""
    user_create = UserCreate(**test_user2_data)
    user = AuthService.create_user(test_db, user_create)
    return user


@pytest.fixture
def auth_token(test_user: User) -> str:
    """Generate authentication token for test user."""
    return create_access_token(data={"sub": test_user.username})


@pytest.fixture
def auth_headers(auth_token: str) -> Dict[str, str]:
    """Create authorization headers with test token."""
    return {"Authorization": f"Bearer {auth_token}"}


# =============================================================================
# Prompt Fixtures
# =============================================================================

@pytest.fixture
def test_prompt_data() -> Dict[str, Any]:
    """Test prompt creation data."""
    return {
        "title": "Test Prompt",
        "content": "Write a comprehensive article about AI testing best practices.",
        "target_llm": "ChatGPT",
        "category": "testing",
        "tags": ["ai", "testing", "quality"]
    }


@pytest.fixture
def test_prompt(test_db: Session, test_user: User, test_prompt_data: Dict[str, Any]) -> PromptModel:
    """Create a test prompt in the database."""
    prompt = PromptModel(
        **test_prompt_data,
        owner_id=test_user.id
    )
    test_db.add(prompt)
    test_db.commit()
    test_db.refresh(prompt)

    # Create initial version
    version = PromptVersion(
        prompt_id=prompt.id,
        version_number=1,
        content=prompt.content
    )
    test_db.add(version)
    test_db.commit()

    return prompt


@pytest.fixture
def analyzed_prompt(test_db: Session, test_prompt: PromptModel) -> PromptModel:
    """Create a prompt with analysis results."""
    test_prompt.quality_score = 85.0
    test_prompt.clarity_score = 88.0
    test_prompt.specificity_score = 82.0
    test_prompt.structure_score = 87.0
    test_prompt.suggestions = ["Add more context", "Specify output format"]
    test_prompt.best_practices = {"has_clear_instruction": "excellent"}
    test_db.commit()
    test_db.refresh(test_prompt)
    return test_prompt


@pytest.fixture
def enhanced_prompt(test_db: Session, analyzed_prompt: PromptModel) -> PromptModel:
    """Create a prompt with enhancement results."""
    analyzed_prompt.enhanced_content = "Write a comprehensive, well-structured article about AI testing best practices. Include: 1) Testing strategies, 2) Tools and frameworks, 3) Real-world examples."
    test_db.commit()
    test_db.refresh(analyzed_prompt)
    return analyzed_prompt


# =============================================================================
# Template Fixtures
# =============================================================================

@pytest.fixture
def test_template_data() -> Dict[str, Any]:
    """Test template creation data."""
    return {
        "name": "Blog Post Template",
        "description": "Template for creating blog posts",
        "content": "Write a blog post about {topic}. Target audience: {audience}.",
        "category": "content",
        "tags": ["blog", "content"],
        "is_public": True
    }


@pytest.fixture
def test_template(test_db: Session, test_user: User, test_template_data: Dict[str, Any]) -> Template:
    """Create a test template in the database."""
    template = Template(
        **test_template_data,
        owner_id=test_user.id
    )
    test_db.add(template)
    test_db.commit()
    test_db.refresh(template)
    return template


@pytest.fixture
def private_template(test_db: Session, test_user: User) -> Template:
    """Create a private template."""
    template = Template(
        name="Private Template",
        description="Private test template",
        content="Private content",
        category="test",
        tags=["private"],
        is_public=False,
        owner_id=test_user.id
    )
    test_db.add(template)
    test_db.commit()
    test_db.refresh(template)
    return template


# =============================================================================
# Mock Data Fixtures
# =============================================================================

@pytest.fixture
def mock_gemini_analysis_response() -> Dict[str, Any]:
    """Mock response from Gemini API for analysis."""
    return {
        "quality_score": 85.0,
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


@pytest.fixture
def mock_gemini_enhancement_response() -> Dict[str, Any]:
    """Mock response from Gemini API for enhancement."""
    return {
        "original_content": "Write a comprehensive article about AI testing best practices.",
        "enhanced_content": "Write a comprehensive, well-structured article about AI testing best practices. Target audience: software developers and QA engineers. Tone: technical yet accessible. Include: 1) Overview of AI testing challenges, 2) Testing strategies and methodologies, 3) Popular tools and frameworks, 4) Real-world case studies, 5) Best practices and recommendations. Format: 1500-2000 words with subheadings.",
        "quality_improvement": 15.5,
        "improvements": [
            "Added clear target audience specification",
            "Defined tone and style expectations",
            "Structured content requirements with numbered list",
            "Specified word count and formatting requirements",
            "Added requirement for case studies and examples"
        ]
    }


@pytest.fixture
def mock_gemini_versions_response() -> Dict[str, Any]:
    """Mock response for multiple enhanced versions."""
    return {
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
            },
            {
                "version_number": 3,
                "content": "Enhanced version 3 with comprehensive improvements...",
                "focus": "Comprehensive enhancement",
                "quality_improvement": 18.5
            }
        ]
    }


# =============================================================================
# Utility Fixtures
# =============================================================================

@pytest.fixture
def multiple_prompts(test_db: Session, test_user: User) -> list[PromptModel]:
    """Create multiple test prompts for pagination testing."""
    prompts = []
    for i in range(15):
        prompt = PromptModel(
            title=f"Test Prompt {i+1}",
            content=f"Content for test prompt {i+1}",
            target_llm="ChatGPT",
            category="test",
            tags=["test"],
            owner_id=test_user.id,
            quality_score=80.0 + i
        )
        test_db.add(prompt)
        prompts.append(prompt)

    test_db.commit()
    for prompt in prompts:
        test_db.refresh(prompt)

    return prompts


@pytest.fixture
def multiple_templates(test_db: Session, test_user: User) -> list[Template]:
    """Create multiple test templates."""
    templates = []
    for i in range(10):
        template = Template(
            name=f"Template {i+1}",
            description=f"Description for template {i+1}",
            content=f"Content for template {i+1}",
            category="test",
            tags=["test"],
            is_public=i % 2 == 0,  # Every other template is public
            owner_id=test_user.id
        )
        test_db.add(template)
        templates.append(template)

    test_db.commit()
    for template in templates:
        test_db.refresh(template)

    return templates


# =============================================================================
# Cleanup Fixtures
# =============================================================================

@pytest.fixture(autouse=True)
def reset_database(test_db: Session):
    """
    Reset database state after each test.
    This is automatically used for all tests.
    """
    yield
    # Cleanup is handled by test_db fixture


# =============================================================================
# Mock Service Fixtures
# =============================================================================

@pytest.fixture
def mock_gemini_service(mocker, mock_gemini_analysis_response, mock_gemini_enhancement_response):
    """
    Mock GeminiService to avoid actual API calls during testing.
    """
    mock_service = mocker.patch('app.services.gemini_service.GeminiService')

    # Mock analyze_prompt method
    mock_service.return_value.analyze_prompt.return_value = type('obj', (object,), mock_gemini_analysis_response)

    # Mock enhance_prompt method
    mock_service.return_value.enhance_prompt.return_value = type('obj', (object,), mock_gemini_enhancement_response)

    return mock_service

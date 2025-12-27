"""
Quick test script to verify backend setup
Run this after starting the backend server
"""
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

print("=" * 60)
print("PROMPTFORGE BACKEND VERIFICATION")
print("=" * 60)

# Test 1: Import core modules
print("\n✓ Testing imports...")
try:
    from app.core.config import settings
    from app.core.database import Base, engine
    from app.core.security import get_password_hash, verify_password
    print("  ✓ Core modules imported successfully")
except Exception as e:
    print(f"  ✗ Core import failed: {e}")
    sys.exit(1)

# Test 2: Check models
print("\n✓ Testing models...")
try:
    from app.models.user import User
    from app.models.prompt import Prompt, Template, PromptVersion
    print("  ✓ All models imported successfully")
    print(f"    - User: {User.__tablename__}")
    print(f"    - Prompt: {Prompt.__tablename__}")
    print(f"    - Template: {Template.__tablename__}")
    print(f"    - PromptVersion: {PromptVersion.__tablename__}")
except Exception as e:
    print(f"  ✗ Model import failed: {e}")
    sys.exit(1)

# Test 3: Check schemas
print("\n✓ Testing schemas...")
try:
    from app.schemas.user import User as UserSchema, UserCreate, Token
    from app.schemas.prompt import (
        Prompt as PromptSchema,
        PromptAnalysis,
        PromptEnhancement,
        Template as TemplateSchema,
    )
    print("  ✓ All schemas imported successfully")
except Exception as e:
    print(f"  ✗ Schema import failed: {e}")
    sys.exit(1)

# Test 4: Check services
print("\n✓ Testing services...")
try:
    from app.services.auth_service import AuthService
    from app.services.gemini_service import GeminiService
    print("  ✓ All services imported successfully")
except Exception as e:
    print(f"  ✗ Service import failed: {e}")
    sys.exit(1)

# Test 5: Check API routes
print("\n✓ Testing API routes...")
try:
    from app.api import auth, prompts, templates
    print("  ✓ All API routes imported successfully")
except Exception as e:
    print(f"  ✗ API route import failed: {e}")
    sys.exit(1)

# Test 6: Check FastAPI app
print("\n✓ Testing FastAPI application...")
try:
    from app.main import app
    print("  ✓ FastAPI app created successfully")
    print(f"    - Title: {app.title}")
    print(f"    - Version: {app.version}")
    routes = [route.path for route in app.routes]
    print(f"    - Routes registered: {len(routes)}")
except Exception as e:
    print(f"  ✗ FastAPI app failed: {e}")
    sys.exit(1)

# Test 7: Password hashing
print("\n✓ Testing security functions...")
try:
    test_password = "test123"
    hashed = get_password_hash(test_password)
    assert verify_password(test_password, hashed)
    assert not verify_password("wrong", hashed)
    print("  ✓ Password hashing works correctly")
except Exception as e:
    print(f"  ✗ Security test failed: {e}")
    sys.exit(1)

# Test 8: Configuration
print("\n✓ Testing configuration...")
try:
    print(f"  - Project Name: {settings.PROJECT_NAME}")
    print(f"  - Version: {settings.VERSION}")
    print(f"  - API Prefix: {settings.API_V1_STR}")
    print(f"  - Environment: {settings.ENVIRONMENT}")
    print(f"  - Database URL: {settings.DATABASE_URL[:30]}...")
    print(f"  - CORS Origins: {len(settings.CORS_ORIGINS)} configured")
    print("  ✓ Configuration loaded successfully")
except Exception as e:
    print(f"  ✗ Configuration test failed: {e}")
    sys.exit(1)

print("\n" + "=" * 60)
print("✓ ALL TESTS PASSED - Backend is properly configured!")
print("=" * 60)
print("\nNext steps:")
print("1. Start the backend: uvicorn app.main:app --reload")
print("2. Visit http://localhost:8000/docs for API documentation")
print("3. Visit http://localhost:8000/health for health check")
print("=" * 60)

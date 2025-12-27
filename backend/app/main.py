import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.database import Base
from app.api import auth, prompts, templates, analysis

# Create database tables for non-test environments
# Test fixtures handle table creation during tests
if os.environ.get("ENVIRONMENT") != "testing":
    try:
        from app.core.database import engine
        Base.metadata.create_all(bind=engine)
    except Exception:
        # Fail gracefully if database is not yet configured
        pass

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="AI-powered prompt quality analyzer and enhancement tool",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth", tags=["Authentication"])
app.include_router(prompts.router, prefix=f"{settings.API_V1_STR}/prompts", tags=["Prompts"])
app.include_router(templates.router, prefix=f"{settings.API_V1_STR}/templates", tags=["Templates"])
app.include_router(analysis.router, prefix=f"{settings.API_V1_STR}/analysis", tags=["Advanced Analysis"])


@app.get("/")
def root():
    """Root endpoint"""
    return {
        "message": "Welcome to PromptForge API",
        "version": settings.VERSION,
        "docs": "/docs",
    }


@app.get("/health")
def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}

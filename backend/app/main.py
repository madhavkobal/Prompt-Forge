import os
import time
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from app.core.config import settings
from app.core.database import Base, engine as db_engine
from app.api import auth, prompts, templates, analysis
import logging

# Configure logging
log_level = getattr(settings, 'LOG_LEVEL', 'INFO')
logging.basicConfig(
    level=getattr(logging, log_level, logging.INFO),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create database tables for non-test environments
# Test fixtures handle table creation during tests
if os.environ.get("ENVIRONMENT") != "testing":
    try:
        Base.metadata.create_all(bind=db_engine)
        logger.info("Database tables created successfully")
    except Exception as e:
        # Fail gracefully if database is not yet configured
        logger.warning(f"Could not create database tables: {e}")

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="AI-powered prompt quality analyzer and enhancement tool",
    docs_url="/docs" if not settings.ENVIRONMENT == "production" else None,
    redoc_url="/redoc" if not settings.ENVIRONMENT == "production" else None,
)

# Security Middleware
# Trust only specific hosts in production
if settings.ENVIRONMENT == "production":
    allowed_hosts = settings.ALLOWED_HOSTS if hasattr(settings, 'ALLOWED_HOSTS') else ["*"]
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=allowed_hosts)

# Gzip compression for responses
app.add_middleware(GZipMiddleware, minimum_size=1000)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request timing and logging middleware
@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    """Add processing time header and log requests"""
    start_time = time.time()

    # Add security headers
    response = await call_next(request)
    process_time = time.time() - start_time

    response.headers["X-Process-Time"] = str(process_time)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"

    # Log request
    logger.info(
        f"{request.method} {request.url.path} - Status: {response.status_code} - "
        f"Time: {process_time:.3f}s"
    )

    return response

# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Handle uncaught exceptions"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error" if settings.ENVIRONMENT == "production" else str(exc)},
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
async def health_check():
    """
    Comprehensive health check endpoint
    Checks database connectivity and returns service status
    """
    health_status = {
        "status": "healthy",
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT,
    }

    # Check database connection
    try:
        from sqlalchemy import text
        with db_engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        health_status["database"] = "connected"
    except Exception as e:
        health_status["status"] = "unhealthy"
        health_status["database"] = "disconnected"
        health_status["error"] = str(e) if settings.ENVIRONMENT != "production" else "Database connection failed"
        logger.error(f"Health check failed: {e}")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=health_status
        )

    return health_status

@app.get("/metrics")
async def metrics():
    """
    Basic metrics endpoint for monitoring
    Can be extended with Prometheus metrics
    """
    enable_metrics = getattr(settings, 'ENABLE_METRICS', True)
    if settings.ENVIRONMENT == "production" and not enable_metrics:
        return JSONResponse(
            status_code=status.HTTP_404_NOT_FOUND,
            content={"detail": "Metrics endpoint is disabled"}
        )

    # TODO: Add Prometheus metrics or custom metrics
    return {
        "uptime": "Available via monitoring tools",
        "requests_total": "Available via monitoring tools",
        "active_connections": "Available via monitoring tools",
    }

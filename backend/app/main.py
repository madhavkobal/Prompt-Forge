import os
import time
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZIPMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager

from app.core.config import settings
from app.core.database import Base, engine as db_engine
from app.api import auth, prompts, templates, analysis

# Optional: Import monitoring modules if available
try:
    from app.core.logging_config import setup_logging, get_logger
    LOGGING_AVAILABLE = True
except ImportError:
    LOGGING_AVAILABLE = False
    import logging
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)
    logger.warning("Structured logging not available - using basic logging")

try:
    from app.core.metrics import MetricsMiddleware, get_metrics, track_exception
    METRICS_AVAILABLE = True
except ImportError:
    METRICS_AVAILABLE = False
    if LOGGING_AVAILABLE:
        logger.warning("Prometheus metrics not available")

try:
    from app.core.health import (
        detailed_health_check,
        basic_health_check,
        readiness_probe,
        liveness_probe,
        get_system_metrics
    )
    HEALTH_CHECKS_AVAILABLE = True
except ImportError:
    HEALTH_CHECKS_AVAILABLE = False
    if LOGGING_AVAILABLE:
        logger.warning("Enhanced health checks not available")

try:
    import sentry_sdk
    from sentry_sdk.integrations.fastapi import FastApiIntegration
    from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration
    SENTRY_AVAILABLE = True
except ImportError:
    SENTRY_AVAILABLE = False
    if LOGGING_AVAILABLE:
        logger.warning("Sentry error tracking not available")

# Initialize structured logging if available
if LOGGING_AVAILABLE:
    setup_logging()
    logger = get_logger(__name__)

# Initialize Sentry if configured and available
if SENTRY_AVAILABLE and settings.SENTRY_DSN:
    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        environment=getattr(settings, 'SENTRY_ENVIRONMENT', None) or settings.ENVIRONMENT,
        traces_sample_rate=getattr(settings, 'SENTRY_TRACES_SAMPLE_RATE', 0.1),
        integrations=[
            FastApiIntegration(),
            SqlalchemyIntegration(),
        ],
        before_send=lambda event, hint: event if settings.ENVIRONMENT != "testing" else None,
    )
    logger.info("Sentry error tracking initialized")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events"""
    # Startup
    logger.info(f"Starting {settings.PROJECT_NAME} v{settings.VERSION}")
    logger.info(f"Environment: {settings.ENVIRONMENT}")

    # Create database tables for non-test environments
    if os.environ.get("ENVIRONMENT") != "testing":
        try:
            Base.metadata.create_all(bind=db_engine)
            logger.info("Database tables created successfully")
        except Exception as e:
            logger.warning(f"Could not create database tables: {e}")

    yield

    # Shutdown
    logger.info(f"Shutting down {settings.PROJECT_NAME}")


# Create FastAPI app
app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="AI-powered prompt quality analyzer and enhancement tool",
    docs_url="/docs" if settings.ENVIRONMENT != "production" else None,
    redoc_url="/redoc" if settings.ENVIRONMENT != "production" else None,
    lifespan=lifespan,
)

# Add Prometheus metrics middleware
if METRICS_AVAILABLE and settings.ENABLE_METRICS:
    app.add_middleware(MetricsMiddleware)
    logger.info("Prometheus metrics middleware enabled")

# Security Middleware - Trust only specific hosts in production
if settings.ENVIRONMENT == "production":
    allowed_hosts = getattr(settings, 'ALLOWED_HOSTS', ["*"])
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=allowed_hosts)
    logger.info(f"Trusted hosts middleware enabled: {allowed_hosts}")

# Gzip compression for responses
app.add_middleware(GZIPMiddleware, minimum_size=1000)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
logger.info(f"CORS enabled for origins: {settings.CORS_ORIGINS}")


# Request timing and logging middleware
@app.middleware("http")
async def add_security_headers_and_logging(request: Request, call_next):
    """Add security headers and log requests"""
    start_time = time.time()

    # Process request
    response = await call_next(request)

    # Calculate processing time
    process_time = time.time() - start_time

    # Add custom headers
    response.headers["X-Process-Time"] = str(process_time)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"

    if settings.ENVIRONMENT == "production":
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"

    # Log request with structured logging
    logger.info(
        "HTTP request processed",
        extra={
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "process_time_seconds": round(process_time, 3),
            "client_ip": request.client.host if request.client else None,
        }
    )

    # Warn on slow requests
    if settings.ENABLE_REQUEST_TIMING and process_time > settings.SLOW_REQUEST_THRESHOLD:
        logger.warning(
            f"Slow request detected: {request.method} {request.url.path}",
            extra={
                "process_time_seconds": round(process_time, 3),
                "threshold_seconds": settings.SLOW_REQUEST_THRESHOLD,
            }
        )

    return response


# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Handle uncaught exceptions with logging and metrics"""
    # Get exception type
    exception_type = type(exc).__name__

    # Track exception in metrics
    if METRICS_AVAILABLE and settings.ENABLE_METRICS:
        endpoint = request.url.path
        track_exception(exception_type, endpoint)

    # Log exception with context
    logger.error(
        f"Unhandled exception: {exception_type}",
        exc_info=True,
        extra={
            "exception_type": exception_type,
            "endpoint": request.url.path,
            "method": request.method,
            "client_ip": request.client.host if request.client else None,
        }
    )

    # Capture in Sentry (if configured)
    if SENTRY_AVAILABLE and settings.SENTRY_DSN:
        sentry_sdk.capture_exception(exc)

    # Return error response
    error_detail = str(exc) if settings.ENVIRONMENT != "production" else "Internal server error"

    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": error_detail},
    )


# Include API routers
app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth", tags=["Authentication"])
app.include_router(prompts.router, prefix=f"{settings.API_V1_STR}/prompts", tags=["Prompts"])
app.include_router(templates.router, prefix=f"{settings.API_V1_STR}/templates", tags=["Templates"])
app.include_router(analysis.router, prefix=f"{settings.API_V1_STR}/analysis", tags=["Advanced Analysis"])


# Root endpoint
@app.get("/", tags=["Root"])
def root():
    """API root endpoint"""
    return {
        "message": "Welcome to PromptForge API",
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT,
        "docs": "/docs" if settings.ENVIRONMENT != "production" else None,
    }


# Health check endpoints
@app.get("/health", tags=["Health"])
async def health_check():
    """
    Basic health check endpoint
    Returns simple health status for uptime monitoring
    """
    if HEALTH_CHECKS_AVAILABLE:
        return await basic_health_check()

    # Fallback basic health check
    return {
        "status": "healthy",
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT
    }


@app.get("/health/detailed", tags=["Health"])
async def detailed_health():
    """
    Detailed health check with all dependencies
    Checks database, Gemini API, and other services
    """
    if HEALTH_CHECKS_AVAILABLE:
        return await detailed_health_check()

    # Fallback to basic check
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content={"detail": "Detailed health checks not available"}
    )


@app.get("/health/ready", tags=["Health"])
async def readiness():
    """
    Kubernetes readiness probe
    Indicates if the service is ready to accept traffic
    """
    if HEALTH_CHECKS_AVAILABLE:
        return await readiness_probe()

    # Fallback readiness check
    return {"ready": True, "timestamp": time.time()}


@app.get("/health/live", tags=["Health"])
async def liveness():
    """
    Kubernetes liveness probe
    Indicates if the service is alive and should not be restarted
    """
    if HEALTH_CHECKS_AVAILABLE:
        return await liveness_probe()

    # Fallback liveness check
    return {"alive": True, "timestamp": time.time()}


# Metrics endpoint
@app.get("/metrics", tags=["Monitoring"])
async def metrics():
    """
    Prometheus metrics endpoint
    Exposes application metrics for monitoring
    """
    if not METRICS_AVAILABLE:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"detail": "Metrics module not available"}
        )

    if not settings.ENABLE_METRICS:
        return JSONResponse(
            status_code=status.HTTP_404_NOT_FOUND,
            content={"detail": "Metrics endpoint is disabled"}
        )

    return get_metrics()


# System metrics endpoint (for debugging)
@app.get("/system/metrics", tags=["Monitoring"])
async def system_metrics():
    """
    System-level metrics
    Provides CPU, memory, and process information
    """
    if not HEALTH_CHECKS_AVAILABLE:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"detail": "System metrics not available"}
        )

    if settings.ENVIRONMENT == "production":
        return JSONResponse(
            status_code=status.HTTP_404_NOT_FOUND,
            content={"detail": "System metrics not available in production"}
        )

    return await get_system_metrics()

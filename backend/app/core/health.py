"""
Health check endpoints for PromptForge
Provides detailed health, readiness, and liveness probes for monitoring and orchestration
"""
import time
from typing import Dict, Any
from fastapi import status
from fastapi.responses import JSONResponse
from sqlalchemy import text
from app.core.database import engine as db_engine
from app.core.config import settings
import google.generativeai as genai


# Track application startup time
APP_START_TIME = time.time()


async def basic_health_check() -> Dict[str, Any]:
    """
    Basic health check - just returns OK
    Suitable for simple uptime monitoring
    """
    return {
        "status": "healthy",
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT
    }


async def detailed_health_check() -> JSONResponse:
    """
    Detailed health check with all dependencies
    Checks database, Gemini API, and other critical services
    """
    health_status = {
        "status": "healthy",
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT,
        "timestamp": time.time(),
        "uptime_seconds": time.time() - APP_START_TIME,
        "checks": {}
    }

    overall_healthy = True

    # Database check
    db_health = await check_database()
    health_status["checks"]["database"] = db_health
    if db_health["status"] != "healthy":
        overall_healthy = False

    # Gemini API check (only if enabled in detailed checks)
    if settings.ENABLE_DETAILED_HEALTH_CHECK:
        gemini_health = await check_gemini_api()
        health_status["checks"]["gemini_api"] = gemini_health
        # Gemini API is not critical - don't mark overall as unhealthy
        # if gemini_health["status"] != "healthy":
        #     overall_healthy = False

    # Update overall status
    if not overall_healthy:
        health_status["status"] = "unhealthy"
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=health_status
        )

    return JSONResponse(
        status_code=status.HTTP_200_OK,
        content=health_status
    )


async def readiness_probe() -> JSONResponse:
    """
    Kubernetes readiness probe
    Checks if the application is ready to accept traffic
    Fails if critical dependencies (database) are not available
    """
    ready = True
    checks = {}

    # Check database
    db_health = await check_database()
    checks["database"] = db_health
    if db_health["status"] != "healthy":
        ready = False

    status_code = status.HTTP_200_OK if ready else status.HTTP_503_SERVICE_UNAVAILABLE

    return JSONResponse(
        status_code=status_code,
        content={
            "ready": ready,
            "checks": checks,
            "timestamp": time.time()
        }
    )


async def liveness_probe() -> JSONResponse:
    """
    Kubernetes liveness probe
    Simple check to see if the application is alive
    Should respond quickly and not check external dependencies
    """
    return JSONResponse(
        status_code=status.HTTP_200_OK,
        content={
            "alive": True,
            "timestamp": time.time(),
            "uptime_seconds": time.time() - APP_START_TIME
        }
    )


async def check_database() -> Dict[str, Any]:
    """Check database connectivity"""
    start_time = time.time()

    try:
        with db_engine.connect() as connection:
            result = connection.execute(text("SELECT 1"))
            result.fetchone()

        duration = time.time() - start_time

        return {
            "status": "healthy",
            "response_time_ms": round(duration * 1000, 2),
            "message": "Database connection successful"
        }

    except Exception as e:
        duration = time.time() - start_time

        error_message = str(e) if settings.ENVIRONMENT != "production" else "Database connection failed"

        return {
            "status": "unhealthy",
            "response_time_ms": round(duration * 1000, 2),
            "error": error_message
        }


async def check_gemini_api() -> Dict[str, Any]:
    """Check Gemini API connectivity (lightweight test)"""
    start_time = time.time()

    try:
        # Configure Gemini
        genai.configure(api_key=settings.GEMINI_API_KEY)

        # List models as a lightweight check
        # Don't actually generate anything to keep it fast
        models = genai.list_models()

        # Just verify we can access the API
        model_count = len(list(models))

        duration = time.time() - start_time

        return {
            "status": "healthy",
            "response_time_ms": round(duration * 1000, 2),
            "message": f"Gemini API accessible ({model_count} models available)"
        }

    except Exception as e:
        duration = time.time() - start_time

        error_message = str(e) if settings.ENVIRONMENT != "production" else "Gemini API connection failed"

        return {
            "status": "unhealthy",
            "response_time_ms": round(duration * 1000, 2),
            "error": error_message
        }


async def get_system_metrics() -> Dict[str, Any]:
    """
    Get system-level metrics
    Useful for debugging and monitoring
    """
    import psutil
    import os

    process = psutil.Process(os.getpid())

    return {
        "system": {
            "cpu_percent": process.cpu_percent(interval=0.1),
            "memory_mb": round(process.memory_info().rss / 1024 / 1024, 2),
            "threads": process.num_threads(),
            "open_files": len(process.open_files()),
        },
        "application": {
            "uptime_seconds": time.time() - APP_START_TIME,
            "version": settings.VERSION,
            "environment": settings.ENVIRONMENT,
        }
    }

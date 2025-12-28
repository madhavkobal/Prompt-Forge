"""
Prometheus metrics for PromptForge
Tracks API requests, Gemini API usage, user activity, and performance
"""
from prometheus_client import Counter, Histogram, Gauge, Info, generate_latest, CONTENT_TYPE_LATEST
from fastapi import Request, Response
from typing import Callable
import time
from app.core.config import settings


# Application info
app_info = Info('promptforge_app', 'Application information')
app_info.info({
    'version': settings.VERSION,
    'environment': settings.ENVIRONMENT,
    'project_name': settings.PROJECT_NAME
})

# HTTP Request Metrics
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status_code']
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency in seconds',
    ['method', 'endpoint'],
    buckets=(0.01, 0.05, 0.1, 0.5, 1.0, 2.5, 5.0, 10.0)
)

http_requests_in_progress = Gauge(
    'http_requests_in_progress',
    'Number of HTTP requests in progress',
    ['method', 'endpoint']
)

# Gemini API Metrics
gemini_api_requests_total = Counter(
    'gemini_api_requests_total',
    'Total Gemini API requests',
    ['endpoint', 'status']
)

gemini_api_duration_seconds = Histogram(
    'gemini_api_duration_seconds',
    'Gemini API request latency in seconds',
    ['endpoint'],
    buckets=(0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0)
)

gemini_api_errors_total = Counter(
    'gemini_api_errors_total',
    'Total Gemini API errors',
    ['endpoint', 'error_type']
)

# Database Metrics
database_queries_total = Counter(
    'database_queries_total',
    'Total database queries',
    ['query_type']
)

database_query_duration_seconds = Histogram(
    'database_query_duration_seconds',
    'Database query latency in seconds',
    ['query_type'],
    buckets=(0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 5.0)
)

database_connections_active = Gauge(
    'database_connections_active',
    'Number of active database connections'
)

# User Activity Metrics
user_registrations_total = Counter(
    'user_registrations_total',
    'Total user registrations'
)

user_logins_total = Counter(
    'user_logins_total',
    'Total user logins',
    ['status']
)

active_users = Gauge(
    'active_users',
    'Number of active users in the last 24 hours'
)

# Prompt Analysis Metrics
prompts_analyzed_total = Counter(
    'prompts_analyzed_total',
    'Total prompts analyzed'
)

prompts_enhanced_total = Counter(
    'prompts_enhanced_total',
    'Total prompts enhanced'
)

prompt_quality_score = Histogram(
    'prompt_quality_score',
    'Distribution of prompt quality scores',
    buckets=(0.0, 0.2, 0.4, 0.6, 0.7, 0.8, 0.85, 0.9, 0.95, 1.0)
)

# Template Metrics
templates_created_total = Counter(
    'templates_created_total',
    'Total templates created'
)

templates_used_total = Counter(
    'templates_used_total',
    'Total template uses'
)

# System Metrics
exceptions_total = Counter(
    'exceptions_total',
    'Total unhandled exceptions',
    ['exception_type', 'endpoint']
)

slow_requests_total = Counter(
    'slow_requests_total',
    'Total slow requests (exceeding threshold)',
    ['endpoint']
)


class MetricsMiddleware:
    """Middleware for collecting HTTP request metrics"""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)

        # Extract request info
        method = scope["method"]
        path = scope["path"]

        # Skip metrics endpoint to avoid self-reference
        if path == "/metrics":
            return await self.app(scope, receive, send)

        # Normalize path (remove IDs)
        endpoint = self._normalize_path(path)

        # Track request in progress
        http_requests_in_progress.labels(method=method, endpoint=endpoint).inc()

        # Start timer
        start_time = time.time()

        # Process request
        status_code = 500
        try:
            async def send_wrapper(message):
                nonlocal status_code
                if message["type"] == "http.response.start":
                    status_code = message["status"]
                await send(message)

            await self.app(scope, receive, send_wrapper)

        finally:
            # Calculate duration
            duration = time.time() - start_time

            # Record metrics
            http_requests_total.labels(
                method=method,
                endpoint=endpoint,
                status_code=status_code
            ).inc()

            http_request_duration_seconds.labels(
                method=method,
                endpoint=endpoint
            ).observe(duration)

            http_requests_in_progress.labels(
                method=method,
                endpoint=endpoint
            ).dec()

            # Track slow requests
            if duration > settings.SLOW_REQUEST_THRESHOLD:
                slow_requests_total.labels(endpoint=endpoint).inc()

    @staticmethod
    def _normalize_path(path: str) -> str:
        """Normalize path by removing IDs to reduce cardinality"""
        parts = path.split('/')
        normalized_parts = []

        for part in parts:
            # Replace numeric IDs
            if part.isdigit():
                normalized_parts.append('{id}')
            # Replace UUIDs
            elif len(part) == 36 and part.count('-') == 4:
                normalized_parts.append('{uuid}')
            else:
                normalized_parts.append(part)

        return '/'.join(normalized_parts)


def get_metrics() -> Response:
    """
    Generate Prometheus metrics in text format

    Returns:
        Response with Prometheus metrics
    """
    metrics_data = generate_latest()
    return Response(
        content=metrics_data,
        media_type=CONTENT_TYPE_LATEST
    )


# Helper functions for tracking specific metrics

def track_gemini_request(endpoint: str, duration: float, status: str = "success", error_type: str = None):
    """Track Gemini API request"""
    gemini_api_requests_total.labels(endpoint=endpoint, status=status).inc()
    gemini_api_duration_seconds.labels(endpoint=endpoint).observe(duration)

    if error_type:
        gemini_api_errors_total.labels(endpoint=endpoint, error_type=error_type).inc()


def track_database_query(query_type: str, duration: float):
    """Track database query"""
    database_queries_total.labels(query_type=query_type).inc()
    database_query_duration_seconds.labels(query_type=query_type).observe(duration)


def track_user_registration():
    """Track user registration"""
    user_registrations_total.inc()


def track_user_login(success: bool):
    """Track user login"""
    status = "success" if success else "failure"
    user_logins_total.labels(status=status).inc()


def track_prompt_analysis(quality_score: float):
    """Track prompt analysis"""
    prompts_analyzed_total.inc()
    prompt_quality_score.observe(quality_score)


def track_prompt_enhancement():
    """Track prompt enhancement"""
    prompts_enhanced_total.inc()


def track_template_creation():
    """Track template creation"""
    templates_created_total.inc()


def track_template_usage():
    """Track template usage"""
    templates_used_total.inc()


def track_exception(exception_type: str, endpoint: str):
    """Track unhandled exception"""
    exceptions_total.labels(exception_type=exception_type, endpoint=endpoint).inc()

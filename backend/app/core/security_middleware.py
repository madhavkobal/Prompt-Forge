"""
Security middleware for rate limiting, request size limits, and security headers
"""
from typing import Callable, Optional
from fastapi import Request, HTTPException, status, Response
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.datastructures import Headers
import time
import hashlib
import secrets
from collections import defaultdict
from datetime import datetime, timedelta

from app.core.config import settings


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    Rate limiting middleware using token bucket algorithm
    Tracks requests per IP address and per user (if authenticated)
    """

    def __init__(self, app):
        super().__init__(app)
        self.rate_limits = defaultdict(lambda: {"tokens": settings.RATE_LIMIT_BURST, "last_update": time.time()})
        self.cleanup_interval = 3600  # Cleanup old entries every hour
        self.last_cleanup = time.time()

    def _get_client_identifier(self, request: Request) -> str:
        """Get unique identifier for client (IP + optional user)"""
        client_ip = request.client.host if request.client else "unknown"

        # Try to get user from token if authenticated
        user_id = None
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            # Extract user from token (we'll just use a hash of the token for simplicity)
            token = auth_header.split(" ")[1]
            user_id = hashlib.sha256(token.encode()).hexdigest()[:16]

        return f"{client_ip}:{user_id}" if user_id else client_ip

    def _refill_tokens(self, client_id: str) -> None:
        """Refill tokens based on time elapsed"""
        current_time = time.time()
        client_data = self.rate_limits[client_id]
        time_elapsed = current_time - client_data["last_update"]

        # Add tokens based on time elapsed (1 token per 60/RATE_LIMIT_PER_MINUTE seconds)
        tokens_to_add = time_elapsed * (settings.RATE_LIMIT_PER_MINUTE / 60)
        client_data["tokens"] = min(
            settings.RATE_LIMIT_BURST,
            client_data["tokens"] + tokens_to_add
        )
        client_data["last_update"] = current_time

    def _cleanup_old_entries(self) -> None:
        """Remove old rate limit entries to prevent memory bloat"""
        current_time = time.time()
        if current_time - self.last_cleanup > self.cleanup_interval:
            # Remove entries older than 1 hour
            cutoff_time = current_time - 3600
            to_remove = [
                client_id for client_id, data in self.rate_limits.items()
                if data["last_update"] < cutoff_time
            ]
            for client_id in to_remove:
                del self.rate_limits[client_id]
            self.last_cleanup = current_time

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Process request with rate limiting"""
        if not settings.RATE_LIMIT_ENABLED:
            return await call_next(request)

        # Skip rate limiting for health check endpoints
        if request.url.path.startswith("/health"):
            return await call_next(request)

        client_id = self._get_client_identifier(request)

        # Refill tokens
        self._refill_tokens(client_id)

        # Check if client has tokens available
        if self.rate_limits[client_id]["tokens"] >= 1:
            self.rate_limits[client_id]["tokens"] -= 1
            response = await call_next(request)

            # Add rate limit headers
            response.headers["X-RateLimit-Limit"] = str(settings.RATE_LIMIT_PER_MINUTE)
            response.headers["X-RateLimit-Remaining"] = str(int(self.rate_limits[client_id]["tokens"]))
            response.headers["X-RateLimit-Reset"] = str(int(self.rate_limits[client_id]["last_update"] + 60))

            return response
        else:
            # Rate limit exceeded
            retry_after = int(60 - (time.time() - self.rate_limits[client_id]["last_update"]))
            return JSONResponse(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                content={
                    "detail": "Rate limit exceeded. Please try again later.",
                    "retry_after": retry_after
                },
                headers={"Retry-After": str(retry_after)}
            )

        # Periodic cleanup
        self._cleanup_old_entries()


class RequestSizeLimitMiddleware(BaseHTTPMiddleware):
    """
    Middleware to limit request body size to prevent DoS attacks
    """

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Check request size before processing"""
        if request.method in ["POST", "PUT", "PATCH"]:
            content_length = request.headers.get("content-length")
            if content_length and int(content_length) > settings.MAX_REQUEST_SIZE:
                return JSONResponse(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    content={
                        "detail": f"Request body too large. Maximum size is {settings.MAX_REQUEST_SIZE} bytes."
                    }
                )

        return await call_next(request)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """
    Middleware to add security headers to all responses
    Includes strict CSP with nonce support (no unsafe-inline/unsafe-eval)
    """

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Add security headers to response"""
        # Generate nonce for this request (for inline scripts/styles)
        nonce = secrets.token_urlsafe(16)
        request.state.csp_nonce = nonce  # Store in request state for use in templates

        response = await call_next(request)

        if settings.ENABLE_SECURITY_HEADERS:
            # XSS Protection
            response.headers["X-Content-Type-Options"] = "nosniff"
            response.headers["X-Frame-Options"] = "DENY"
            response.headers["X-XSS-Protection"] = "1; mode=block"

            # Strict Content Security Policy (no unsafe-inline/unsafe-eval)
            # Development: More permissive for Vite/React hot reload
            # Production: Strict policy with nonces
            if settings.ENVIRONMENT == "production":
                csp_policy = (
                    "default-src 'self'; "
                    f"script-src 'self' 'nonce-{nonce}'; "  # Nonce-based inline scripts
                    f"style-src 'self' 'nonce-{nonce}' https://fonts.googleapis.com; "  # Nonce-based inline styles
                    "img-src 'self' data: https:; "
                    "font-src 'self' data: https://fonts.gstatic.com; "
                    "connect-src 'self' https://generativelanguage.googleapis.com; "
                    "frame-ancestors 'none'; "
                    "base-uri 'self'; "
                    "form-action 'self'; "
                    "upgrade-insecure-requests"  # Upgrade HTTP to HTTPS
                )
            else:
                # Development: Allow Vite hot reload and dev tools
                csp_policy = (
                    "default-src 'self'; "
                    f"script-src 'self' 'nonce-{nonce}' 'unsafe-eval' ws: wss:; "  # unsafe-eval needed for Vite HMR
                    f"style-src 'self' 'nonce-{nonce}' 'unsafe-inline' https://fonts.googleapis.com; "  # unsafe-inline for dev
                    "img-src 'self' data: https: blob:; "
                    "font-src 'self' data: https://fonts.gstatic.com; "
                    "connect-src 'self' ws: wss: https://generativelanguage.googleapis.com; "  # ws for Vite HMR
                    "frame-ancestors 'none'; "
                    "base-uri 'self'; "
                    "form-action 'self'"
                )

            response.headers["Content-Security-Policy"] = csp_policy

            # Report CSP violations (optional, for monitoring)
            if settings.ENVIRONMENT == "production" and hasattr(settings, 'CSP_REPORT_URI'):
                response.headers["Content-Security-Policy-Report-Only"] = (
                    csp_policy + f"; report-uri {settings.CSP_REPORT_URI}"
                )

            # HSTS (HTTP Strict Transport Security) - Production only
            if settings.ENVIRONMENT == "production":
                # max-age=31536000 (1 year), include subdomains, preload
                response.headers["Strict-Transport-Security"] = (
                    "max-age=31536000; includeSubDomains; preload"
                )

            # Referrer Policy
            response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

            # Permissions Policy (formerly Feature-Policy)
            response.headers["Permissions-Policy"] = (
                "geolocation=(), microphone=(), camera=(), payment=(), usb=(), "
                "magnetometer=(), gyroscope=(), speaker=(self)"
            )

        return response


class CSRFProtectionMiddleware(BaseHTTPMiddleware):
    """
    CSRF protection middleware for state-changing operations
    Uses double-submit cookie pattern
    """

    def __init__(self, app):
        super().__init__(app)
        self.csrf_secret = settings.CSRF_SECRET_KEY or settings.SECRET_KEY
        self.safe_methods = ["GET", "HEAD", "OPTIONS", "TRACE"]

    def _generate_csrf_token(self) -> str:
        """Generate a new CSRF token"""
        return secrets.token_urlsafe(32)

    def _verify_csrf_token(self, token: str, cookie_token: str) -> bool:
        """Verify CSRF token matches cookie"""
        return secrets.compare_digest(token, cookie_token)

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Verify CSRF token for state-changing requests"""
        if not settings.ENABLE_CSRF_PROTECTION:
            return await call_next(request)

        # Skip CSRF for safe methods
        if request.method in self.safe_methods:
            response = await call_next(request)
            # Set CSRF cookie for future requests
            if "csrf_token" not in request.cookies:
                csrf_token = self._generate_csrf_token()
                response.set_cookie(
                    key="csrf_token",
                    value=csrf_token,
                    httponly=True,
                    secure=settings.ENVIRONMENT == "production",
                    samesite="lax"
                )
            return response

        # Skip CSRF for auth endpoints (they use different protection)
        if request.url.path.startswith("/api/v1/auth/"):
            return await call_next(request)

        # Verify CSRF token for state-changing requests
        csrf_cookie = request.cookies.get("csrf_token")
        csrf_header = request.headers.get("X-CSRF-Token")

        if not csrf_cookie or not csrf_header:
            return JSONResponse(
                status_code=status.HTTP_403_FORBIDDEN,
                content={"detail": "CSRF token missing"}
            )

        if not self._verify_csrf_token(csrf_header, csrf_cookie):
            return JSONResponse(
                status_code=status.HTTP_403_FORBIDDEN,
                content={"detail": "CSRF token invalid"}
            )

        return await call_next(request)


class HTTPSRedirectMiddleware(BaseHTTPMiddleware):
    """
    Middleware to redirect HTTP to HTTPS in production
    """

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Redirect HTTP to HTTPS if in production"""
        if settings.ENVIRONMENT == "production":
            # Check if request is HTTP (not HTTPS)
            if request.url.scheme == "http":
                # Build HTTPS URL
                https_url = request.url.replace(scheme="https")
                return JSONResponse(
                    status_code=status.HTTP_301_MOVED_PERMANENTLY,
                    headers={"Location": str(https_url)}
                )

        return await call_next(request)

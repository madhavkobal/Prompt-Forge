"""
Per-endpoint rate limiting for API endpoints

Provides fine-grained rate limiting that can be applied to specific endpoints,
particularly useful for expensive AI operations.
"""
from typing import Dict, Optional
from fastapi import Request, HTTPException, status
from collections import defaultdict
import time
import hashlib


class EndpointRateLimiter:
    """
    Per-endpoint rate limiter using token bucket algorithm

    Allows different rate limits for different endpoints.
    More restrictive than global middleware rate limiting.
    """

    def __init__(self):
        # Structure: {client_id: {endpoint: {"tokens": float, "last_update": float}}}
        self.rate_limits: Dict[str, Dict[str, Dict[str, float]]] = defaultdict(lambda: defaultdict(dict))
        self.cleanup_interval = 3600  # Cleanup every hour
        self.last_cleanup = time.time()

    def _get_client_identifier(self, request: Request) -> str:
        """Get unique identifier for client"""
        client_ip = request.client.host if request.client else "unknown"

        # Try to get user from cookie or Authorization header
        token = request.cookies.get("access_token")
        if not token:
            auth_header = request.headers.get("Authorization", "")
            if auth_header.startswith("Bearer "):
                token = auth_header.split(" ")[1]

        if token:
            user_id = hashlib.sha256(token.encode()).hexdigest()[:16]
            return f"{client_ip}:{user_id}"

        return client_ip

    def _refill_tokens(
        self,
        client_id: str,
        endpoint: str,
        rate_per_minute: int,
        burst: int
    ) -> None:
        """Refill tokens based on time elapsed"""
        current_time = time.time()

        if endpoint not in self.rate_limits[client_id]:
            self.rate_limits[client_id][endpoint] = {
                "tokens": float(burst),
                "last_update": current_time
            }
            return

        client_data = self.rate_limits[client_id][endpoint]
        time_elapsed = current_time - client_data["last_update"]

        # Add tokens based on time elapsed
        tokens_to_add = time_elapsed * (rate_per_minute / 60)
        client_data["tokens"] = min(
            float(burst),
            client_data["tokens"] + tokens_to_add
        )
        client_data["last_update"] = current_time

    def _cleanup_old_entries(self) -> None:
        """Remove old rate limit entries to prevent memory bloat"""
        current_time = time.time()
        if current_time - self.last_cleanup > self.cleanup_interval:
            cutoff_time = current_time - 3600

            # Remove old entries
            for client_id in list(self.rate_limits.keys()):
                for endpoint in list(self.rate_limits[client_id].keys()):
                    if self.rate_limits[client_id][endpoint]["last_update"] < cutoff_time:
                        del self.rate_limits[client_id][endpoint]

                # Remove client if no endpoints left
                if not self.rate_limits[client_id]:
                    del self.rate_limits[client_id]

            self.last_cleanup = current_time

    def check_rate_limit(
        self,
        request: Request,
        endpoint: str,
        rate_per_minute: int = 10,
        burst: int = 15
    ) -> None:
        """
        Check if request exceeds rate limit

        Args:
            request: FastAPI request object
            endpoint: Endpoint identifier (e.g., "analyze_prompt")
            rate_per_minute: Number of requests allowed per minute
            burst: Maximum burst capacity

        Raises:
            HTTPException: If rate limit exceeded
        """
        client_id = self._get_client_identifier(request)

        # Refill tokens
        self._refill_tokens(client_id, endpoint, rate_per_minute, burst)

        # Check if client has tokens available
        if self.rate_limits[client_id][endpoint]["tokens"] >= 1:
            self.rate_limits[client_id][endpoint]["tokens"] -= 1
        else:
            # Rate limit exceeded
            retry_after = int(60 - (time.time() - self.rate_limits[client_id][endpoint]["last_update"]))
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "error": "rate_limit_exceeded",
                    "message": f"Rate limit exceeded for {endpoint}. Please try again later.",
                    "retry_after": retry_after,
                    "limit": rate_per_minute,
                    "window": "per minute"
                },
                headers={"Retry-After": str(retry_after)}
            )

        # Periodic cleanup
        self._cleanup_old_entries()


# Global rate limiter instance
rate_limiter = EndpointRateLimiter()


# Dependency functions for common rate limits
def ai_endpoint_rate_limit(request: Request) -> None:
    """
    Stricter rate limit for AI endpoints (analyze, enhance)

    Limit: 10 requests per minute (vs global 60/min)
    Rationale: AI endpoints are expensive and resource-intensive
    """
    rate_limiter.check_rate_limit(
        request,
        endpoint="ai_operation",
        rate_per_minute=10,
        burst=15
    )


def heavy_compute_rate_limit(request: Request) -> None:
    """
    Rate limit for computationally expensive endpoints

    Limit: 5 requests per minute
    """
    rate_limiter.check_rate_limit(
        request,
        endpoint="heavy_compute",
        rate_per_minute=5,
        burst=10
    )


def strict_rate_limit(request: Request) -> None:
    """
    Very strict rate limit for highly sensitive operations

    Limit: 3 requests per minute
    """
    rate_limiter.check_rate_limit(
        request,
        endpoint="strict",
        rate_per_minute=3,
        burst=5
    )

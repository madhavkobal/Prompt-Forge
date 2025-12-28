from pydantic_settings import BaseSettings
from typing import List, Optional


class Settings(BaseSettings):
    # API Settings
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "PromptForge"
    VERSION: str = "1.0.0"

    # Security
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    # Rate Limiting
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_PER_MINUTE: int = 60
    RATE_LIMIT_BURST: int = 10

    # Request Security
    MAX_REQUEST_SIZE: int = 10 * 1024 * 1024  # 10MB
    ENABLE_CSRF_PROTECTION: bool = True
    CSRF_SECRET_KEY: Optional[str] = None

    # Security Headers
    ENABLE_SECURITY_HEADERS: bool = True
    ALLOWED_HOSTS: List[str] = ["*"]

    # Password Policy
    MIN_PASSWORD_LENGTH: int = 8
    REQUIRE_PASSWORD_UPPERCASE: bool = True
    REQUIRE_PASSWORD_LOWERCASE: bool = True
    REQUIRE_PASSWORD_DIGITS: bool = True
    REQUIRE_PASSWORD_SPECIAL: bool = True

    # Database
    DATABASE_URL: str

    # CORS
    # Note: In .env file, CORS_ORIGINS must be a JSON array: ["url1","url2"]
    CORS_ORIGINS: List[str] = ["http://localhost:5173", "http://localhost:3000"]

    # Google Gemini
    GEMINI_API_KEY: str

    # Environment
    ENVIRONMENT: str = "development"

    # Logging
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "json"  # json or text

    # Monitoring & Observability
    ENABLE_METRICS: bool = True
    SENTRY_DSN: Optional[str] = None
    SENTRY_ENVIRONMENT: Optional[str] = None
    SENTRY_TRACES_SAMPLE_RATE: float = 0.1  # 10% of transactions

    # Performance Monitoring
    ENABLE_REQUEST_TIMING: bool = True
    SLOW_REQUEST_THRESHOLD: float = 1.0  # seconds

    # Health Checks
    ENABLE_DETAILED_HEALTH_CHECK: bool = True
    HEALTH_CHECK_TIMEOUT: int = 5  # seconds

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()

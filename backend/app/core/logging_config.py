"""
Structured logging configuration for PromptForge
Supports both JSON and text formats for different environments
Includes sensitive data redaction to prevent credential leaks
"""
import logging
import sys
import re
from typing import Any, Dict
from pythonjsonlogger import jsonlogger
from app.core.config import settings


class SensitiveDataFilter(logging.Filter):
    """
    Logging filter that redacts sensitive information from log messages

    Redacts:
    - Passwords (password, passwd, pwd fields)
    - Tokens (token, access_token, refresh_token, api_key, secret)
    - Credit cards, SSNs, emails (pattern-based)
    """

    # Sensitive field names to redact
    SENSITIVE_FIELDS = {
        'password', 'passwd', 'pwd', 'secret', 'token', 'access_token',
        'refresh_token', 'api_key', 'apikey', 'api_secret', 'private_key',
        'authorization', 'auth', 'gemini_api_key', 'openai_api_key'
    }

    # Patterns for sensitive data
    PATTERNS = {
        'credit_card': re.compile(r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b'),
        'ssn': re.compile(r'\b\d{3}-\d{2}-\d{4}\b'),
        'email': re.compile(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
        'bearer_token': re.compile(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', re.IGNORECASE),
        'jwt': re.compile(r'eyJ[A-Za-z0-9\-._~+/]+=*'),
    }

    REDACTED = '[REDACTED]'

    def filter(self, record: logging.LogRecord) -> bool:
        """
        Filter method called for each log record

        Args:
            record: Log record to filter

        Returns:
            True (always allow the record, just modify it)
        """
        # Redact message
        if hasattr(record, 'msg') and isinstance(record.msg, str):
            record.msg = self._redact_string(record.msg)

        # Redact arguments
        if hasattr(record, 'args') and record.args:
            if isinstance(record.args, dict):
                record.args = self._redact_dict(record.args)
            elif isinstance(record.args, (list, tuple)):
                record.args = tuple(self._redact_value(arg) for arg in record.args)

        # Redact extra fields (for structured logging)
        for attr in dir(record):
            if not attr.startswith('_') and attr.lower() in self.SENSITIVE_FIELDS:
                setattr(record, attr, self.REDACTED)

        return True

    def _redact_string(self, text: str) -> str:
        """Redact sensitive patterns from a string"""
        for pattern_name, pattern in self.PATTERNS.items():
            text = pattern.sub(self.REDACTED, text)
        return text

    def _redact_dict(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Redact sensitive fields from a dictionary"""
        redacted = {}
        for key, value in data.items():
            if key.lower() in self.SENSITIVE_FIELDS:
                redacted[key] = self.REDACTED
            elif isinstance(value, dict):
                redacted[key] = self._redact_dict(value)
            elif isinstance(value, str):
                redacted[key] = self._redact_string(value)
            else:
                redacted[key] = value
        return redacted

    def _redact_value(self, value: Any) -> Any:
        """Redact a single value"""
        if isinstance(value, str):
            return self._redact_string(value)
        elif isinstance(value, dict):
            return self._redact_dict(value)
        return value


class CustomJsonFormatter(jsonlogger.JsonFormatter):
    """Custom JSON formatter with additional fields"""

    def add_fields(self, log_record: Dict[str, Any], record: logging.LogRecord, message_dict: Dict[str, Any]) -> None:
        super().add_fields(log_record, record, message_dict)

        # Add custom fields
        log_record['environment'] = settings.ENVIRONMENT
        log_record['service'] = settings.PROJECT_NAME
        log_record['version'] = settings.VERSION

        # Add level name
        if 'level' not in log_record:
            log_record['level'] = record.levelname

        # Add timestamp if not present
        if 'timestamp' not in log_record:
            log_record['timestamp'] = self.formatTime(record, self.datefmt)


def setup_logging() -> logging.Logger:
    """
    Configure structured logging based on environment settings
    Returns the root logger
    """
    # Get log level from settings
    log_level = getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO)

    # Create root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)

    # Remove existing handlers
    root_logger.handlers = []

    # Create console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(log_level)

    # Set formatter based on LOG_FORMAT setting
    if settings.LOG_FORMAT.lower() == 'json':
        # JSON formatter for production (easier for log aggregation)
        formatter = CustomJsonFormatter(
            '%(timestamp)s %(levelname)s %(name)s %(message)s'
        )
    else:
        # Text formatter for development
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )

    console_handler.setFormatter(formatter)

    # Add sensitive data redaction filter
    sensitive_filter = SensitiveDataFilter()
    console_handler.addFilter(sensitive_filter)

    root_logger.addHandler(console_handler)

    # Reduce noise from third-party libraries
    logging.getLogger('uvicorn.access').setLevel(logging.WARNING)
    logging.getLogger('uvicorn.error').setLevel(logging.INFO)
    logging.getLogger('sqlalchemy.engine').setLevel(logging.WARNING)

    return root_logger


def get_logger(name: str) -> logging.Logger:
    """
    Get a logger instance with the given name

    Args:
        name: Logger name (typically __name__ of the module)

    Returns:
        Configured logger instance
    """
    return logging.getLogger(name)


# Context manager for adding extra fields to logs
class LogContext:
    """Context manager for adding extra context to log messages"""

    def __init__(self, logger: logging.Logger, **extra_fields):
        self.logger = logger
        self.extra_fields = extra_fields
        self.old_factory = logging.getLogRecordFactory()

    def __enter__(self):
        def record_factory(*args, **kwargs):
            record = self.old_factory(*args, **kwargs)
            for key, value in self.extra_fields.items():
                setattr(record, key, value)
            return record

        logging.setLogRecordFactory(record_factory)
        return self.logger

    def __exit__(self, exc_type, exc_val, exc_tb):
        logging.setLogRecordFactory(self.old_factory)

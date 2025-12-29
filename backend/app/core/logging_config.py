"""
Structured logging configuration for PromptForge
Supports both JSON and text formats for different environments
"""
import logging
import sys
from typing import Any, Dict
from pythonjsonlogger import jsonlogger
from app.core.config import settings


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

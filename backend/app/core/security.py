from datetime import datetime, timedelta
from typing import Optional
import re
from jose import JWTError, jwt
from passlib.context import CryptContext
from app.core.config import settings

# Use bcrypt with strong work factor (12 rounds is default, secure)
# Bcrypt automatically salts passwords and is resistant to rainbow table attacks
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto", bcrypt__rounds=12)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create JWT access token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash"""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Hash a password"""
    return pwd_context.hash(password)


def decode_access_token(token: str) -> Optional[dict]:
    """Decode JWT token"""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload
    except JWTError:
        return None


def validate_password_strength(password: str) -> tuple[bool, Optional[str]]:
    """
    Validate password meets security requirements
    Returns (is_valid, error_message)
    """
    if len(password) < settings.MIN_PASSWORD_LENGTH:
        return False, f"Password must be at least {settings.MIN_PASSWORD_LENGTH} characters long"

    if settings.REQUIRE_PASSWORD_UPPERCASE and not re.search(r"[A-Z]", password):
        return False, "Password must contain at least one uppercase letter"

    if settings.REQUIRE_PASSWORD_LOWERCASE and not re.search(r"[a-z]", password):
        return False, "Password must contain at least one lowercase letter"

    if settings.REQUIRE_PASSWORD_DIGITS and not re.search(r"\d", password):
        return False, "Password must contain at least one digit"

    if settings.REQUIRE_PASSWORD_SPECIAL and not re.search(r"[!@#$%^&*(),.?\":{}|<>]", password):
        return False, "Password must contain at least one special character"

    # Check for common weak passwords
    common_passwords = ["password", "12345678", "qwerty", "abc123", "password123"]
    if password.lower() in common_passwords:
        return False, "Password is too common. Please choose a stronger password"

    return True, None


def sanitize_input(text: str, allow_html: bool = False) -> str:
    """
    Sanitize user input to prevent XSS attacks

    Args:
        text: Input text to sanitize
        allow_html: If True, allows safe HTML tags (using bleach)

    Returns:
        Sanitized text safe for storage and display
    """
    if not text:
        return text

    try:
        import bleach

        if allow_html:
            # Allow only safe HTML tags
            allowed_tags = ['p', 'br', 'strong', 'em', 'u', 'ol', 'ul', 'li', 'a', 'code', 'pre']
            allowed_attributes = {'a': ['href', 'title']}
            return bleach.clean(text, tags=allowed_tags, attributes=allowed_attributes, strip=True)
        else:
            # Strip all HTML tags
            return bleach.clean(text, tags=[], strip=True)
    except ImportError:
        # Fallback if bleach not available - basic HTML escape
        return (text
                .replace('&', '&amp;')
                .replace('<', '&lt;')
                .replace('>', '&gt;')
                .replace('"', '&quot;')
                .replace("'", '&#x27;'))


def sanitize_sql_identifier(identifier: str) -> str:
    """
    Sanitize SQL identifiers (table/column names) to prevent SQL injection
    Note: SQLAlchemy ORM already protects against SQL injection in queries,
    but this is useful for dynamic table/column names if ever needed

    Args:
        identifier: SQL identifier (table or column name)

    Returns:
        Sanitized identifier safe for SQL queries
    """
    # Only allow alphanumeric characters and underscores
    if not re.match(r"^[a-zA-Z_][a-zA-Z0-9_]*$", identifier):
        raise ValueError(f"Invalid SQL identifier: {identifier}")
    return identifier


def validate_email(email: str) -> bool:
    """
    Validate email format

    Args:
        email: Email address to validate

    Returns:
        True if valid email format
    """
    email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(email_pattern, email))


def generate_secure_token(length: int = 32) -> str:
    """
    Generate a cryptographically secure random token
    Useful for API keys, reset tokens, etc.

    Args:
        length: Length of the token (default 32 bytes = 256 bits)

    Returns:
        URL-safe token string
    """
    import secrets
    return secrets.token_urlsafe(length)


def create_refresh_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """
    Create JWT refresh token (longer-lived than access tokens)

    Refresh tokens are used to obtain new access tokens without re-authentication.
    They should be stored securely (httpOnly cookie) and have longer expiration.

    Args:
        data: Data to encode in the token (typically user identifier)
        expires_delta: Custom expiration time (default: REFRESH_TOKEN_EXPIRE_DAYS from settings)

    Returns:
        Encoded JWT refresh token
    """
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        # Default: 7 days (configurable in settings)
        expire = datetime.utcnow() + timedelta(days=getattr(settings, 'REFRESH_TOKEN_EXPIRE_DAYS', 7))

    to_encode.update({
        "exp": expire,
        "type": "refresh"  # Mark as refresh token
    })
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def decode_refresh_token(token: str) -> Optional[dict]:
    """
    Decode and validate refresh token

    Args:
        token: JWT refresh token to decode

    Returns:
        Decoded payload if valid, None otherwise
    """
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])

        # Verify it's a refresh token
        if payload.get("type") != "refresh":
            return None

        return payload
    except JWTError:
        return None


def hash_token(token: str) -> str:
    """
    Hash a token for secure storage in database

    Tokens should never be stored in plain text. This creates a SHA-256 hash
    that can be safely stored and compared.

    Args:
        token: Token to hash

    Returns:
        Hexadecimal hash of the token
    """
    import hashlib
    return hashlib.sha256(token.encode()).hexdigest()

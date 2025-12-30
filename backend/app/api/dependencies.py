from fastapi import Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from typing import Optional
from app.core.database import get_db
from app.core.security import decode_access_token
from app.models.user import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login", auto_error=False)

# Cookie name for httpOnly authentication
COOKIE_NAME = "access_token"


def get_token_from_request(
    request: Request,
    token_from_header: Optional[str] = Depends(oauth2_scheme)
) -> Optional[str]:
    """
    Extract token from either httpOnly cookie or Authorization header

    Priority:
    1. httpOnly cookie (more secure, preferred)
    2. Authorization header (for backward compatibility and mobile apps)
    """
    # Try to get token from httpOnly cookie first (more secure)
    token = request.cookies.get(COOKIE_NAME)
    if token:
        return token

    # Fallback to Authorization header for backward compatibility
    if token_from_header:
        return token_from_header

    return None


def get_current_user(
    token: Optional[str] = Depends(get_token_from_request),
    db: Session = Depends(get_db)
) -> User:
    """
    Get current authenticated user

    Supports authentication via:
    - httpOnly cookie (preferred, XSS protection)
    - Authorization header (backward compatibility)
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if token is None:
        raise credentials_exception

    payload = decode_access_token(token)
    if payload is None:
        raise credentials_exception

    username: str = payload.get("sub")
    if username is None:
        raise credentials_exception

    user = db.query(User).filter(User.username == username).first()
    if user is None:
        raise credentials_exception

    return user


def get_current_active_user(current_user: User = Depends(get_current_user)) -> User:
    """Get current active user"""
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

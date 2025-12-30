from fastapi import APIRouter, Depends, HTTPException, status, Response, Request
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta, datetime

from app.core.database import get_db
from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    hash_token
)
from app.schemas.user import UserCreate, User, Token
from app.services.auth_service import AuthService
from app.api.dependencies import get_current_active_user
from app.models.refresh_token import RefreshToken
from app.models.user import User as UserModel

router = APIRouter()

# Cookie settings for httpOnly authentication
COOKIE_NAME = "access_token"
COOKIE_MAX_AGE = settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60  # Convert to seconds
REFRESH_COOKIE_NAME = "refresh_token"
REFRESH_COOKIE_MAX_AGE = getattr(settings, 'REFRESH_TOKEN_EXPIRE_DAYS', 7) * 24 * 60 * 60  # Convert days to seconds


@router.post("/register", response_model=User, status_code=status.HTTP_201_CREATED)
def register(user_data: UserCreate, db: Session = Depends(get_db)):
    """Register a new user"""
    return AuthService.create_user(db, user_data)


@router.post("/login", response_model=Token)
def login(
    response: Response,
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    """
    Login and get access token with refresh token

    Security Enhancements:
    - Access token set as httpOnly cookie (XSS protection)
    - Refresh token issued for seamless token renewal (7-day expiry)
    - Refresh token stored hashed in database for revocation support
    - Tokens also returned in response for backward compatibility
    """
    user = AuthService.authenticate_user(db, form_data.username, form_data.password)

    # Create access token (short-lived: 30 minutes)
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )

    # Create refresh token (long-lived: 7 days)
    refresh_token_expires = timedelta(days=getattr(settings, 'REFRESH_TOKEN_EXPIRE_DAYS', 7))
    refresh_token = create_refresh_token(
        data={"sub": user.username}, expires_delta=refresh_token_expires
    )

    # Store hashed refresh token in database for revocation support
    hashed_refresh_token = hash_token(refresh_token)
    db_refresh_token = RefreshToken(
        user_id=user.id,
        token=hashed_refresh_token,
        expires_at=datetime.utcnow() + refresh_token_expires
    )
    db.add(db_refresh_token)
    db.commit()

    # Set httpOnly cookies (XSS protection)
    response.set_cookie(
        key=COOKIE_NAME,
        value=access_token,
        httponly=True,  # Prevents JavaScript access (XSS protection)
        secure=settings.ENVIRONMENT == "production",  # HTTPS only in production
        samesite="lax",  # CSRF protection
        max_age=COOKIE_MAX_AGE,
        path="/",
    )

    response.set_cookie(
        key=REFRESH_COOKIE_NAME,
        value=refresh_token,
        httponly=True,  # Prevents JavaScript access
        secure=settings.ENVIRONMENT == "production",
        samesite="lax",
        max_age=REFRESH_COOKIE_MAX_AGE,
        path="/",
    )

    # Also return tokens for backward compatibility and mobile apps
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "refresh_token": refresh_token
    }


@router.post("/logout")
def logout(
    request: Request,
    response: Response,
    db: Session = Depends(get_db)
):
    """
    Logout user by clearing httpOnly cookies and revoking refresh token

    Security: Revokes refresh token in database to prevent reuse
    """
    # Revoke refresh token in database if present
    refresh_token = request.cookies.get(REFRESH_COOKIE_NAME)
    if refresh_token:
        hashed_token = hash_token(refresh_token)
        db_token = db.query(RefreshToken).filter(
            RefreshToken.token == hashed_token,
            RefreshToken.revoked == False
        ).first()
        if db_token:
            db_token.revoked = True
            db.commit()

    # Clear both access and refresh token cookies
    response.delete_cookie(
        key=COOKIE_NAME,
        path="/",
        httponly=True,
        secure=settings.ENVIRONMENT == "production",
        samesite="lax",
    )
    response.delete_cookie(
        key=REFRESH_COOKIE_NAME,
        path="/",
        httponly=True,
        secure=settings.ENVIRONMENT == "production",
        samesite="lax",
    )
    return {"message": "Successfully logged out"}


@router.post("/refresh", response_model=Token)
def refresh_access_token(
    request: Request,
    response: Response,
    db: Session = Depends(get_db)
):
    """
    Refresh access token using refresh token

    Allows users to get a new access token without re-authenticating.
    The refresh token must be valid, not expired, and not revoked.

    Security:
    - Validates refresh token from httpOnly cookie
    - Checks token is not revoked in database
    - Issues new access token (does not rotate refresh token)
    - Optional: Implement refresh token rotation for enhanced security
    """
    # Get refresh token from cookie (or header for backward compatibility)
    refresh_token = request.cookies.get(REFRESH_COOKIE_NAME)
    if not refresh_token:
        # Fallback to header for mobile apps
        auth_header = request.headers.get("X-Refresh-Token")
        if auth_header:
            refresh_token = auth_header

    if not refresh_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token missing"
        )

    # Decode and validate refresh token
    payload = decode_refresh_token(refresh_token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token"
        )

    username: str = payload.get("sub")
    if username is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token payload"
        )

    # Verify refresh token exists in database and is not revoked
    hashed_token = hash_token(refresh_token)
    db_token = db.query(RefreshToken).filter(
        RefreshToken.token == hashed_token,
        RefreshToken.revoked == False
    ).first()

    if not db_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token revoked or invalid"
        )

    # Check if refresh token is expired
    if db_token.expires_at < datetime.utcnow():
        db_token.revoked = True
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token expired"
        )

    # Get user from database
    user = db.query(UserModel).filter(UserModel.username == username).first()
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive"
        )

    # Create new access token
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )

    # Set new access token cookie
    response.set_cookie(
        key=COOKIE_NAME,
        value=access_token,
        httponly=True,
        secure=settings.ENVIRONMENT == "production",
        samesite="lax",
        max_age=COOKIE_MAX_AGE,
        path="/",
    )

    # Return new access token
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }


@router.post("/revoke")
def revoke_refresh_token(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """
    Manually revoke a refresh token

    Useful for:
    - Logging out from all devices
    - Security incident response
    - User-initiated token revocation
    """
    refresh_token = request.cookies.get(REFRESH_COOKIE_NAME)
    if not refresh_token:
        # Fallback to header
        auth_header = request.headers.get("X-Refresh-Token")
        if auth_header:
            refresh_token = auth_header

    if not refresh_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No refresh token provided"
        )

    # Revoke the token
    hashed_token = hash_token(refresh_token)
    db_token = db.query(RefreshToken).filter(
        RefreshToken.token == hashed_token,
        RefreshToken.user_id == current_user.id
    ).first()

    if db_token:
        db_token.revoked = True
        db.commit()
        return {"message": "Refresh token revoked successfully"}
    else:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Refresh token not found"
        )


@router.get("/me", response_model=User)
def get_current_user_info(
    current_user: User = Depends(get_current_active_user)
):
    """Get current user information"""
    return current_user

from fastapi import APIRouter, Depends, HTTPException, status, Response
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta

from app.core.database import get_db
from app.core.config import settings
from app.core.security import create_access_token
from app.schemas.user import UserCreate, User, Token
from app.services.auth_service import AuthService
from app.api.dependencies import get_current_active_user

router = APIRouter()

# Cookie settings for httpOnly authentication
COOKIE_NAME = "access_token"
COOKIE_MAX_AGE = settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60  # Convert to seconds


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
    Login and get access token

    Security Enhancement: Token is set as httpOnly cookie to prevent XSS attacks.
    The token is also returned in response body for backward compatibility.
    """
    user = AuthService.authenticate_user(db, form_data.username, form_data.password)

    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )

    # Set httpOnly cookie (XSS protection)
    response.set_cookie(
        key=COOKIE_NAME,
        value=access_token,
        httponly=True,  # Prevents JavaScript access (XSS protection)
        secure=settings.ENVIRONMENT == "production",  # HTTPS only in production
        samesite="lax",  # CSRF protection
        max_age=COOKIE_MAX_AGE,
        path="/",
    )

    # Also return token for backward compatibility and mobile apps
    return {"access_token": access_token, "token_type": "bearer"}


@router.post("/logout")
def logout(response: Response):
    """
    Logout user by clearing the httpOnly cookie
    """
    response.delete_cookie(
        key=COOKIE_NAME,
        path="/",
        httponly=True,
        secure=settings.ENVIRONMENT == "production",
        samesite="lax",
    )
    return {"message": "Successfully logged out"}


@router.get("/me", response_model=User)
def get_current_user_info(
    current_user: User = Depends(get_current_active_user)
):
    """Get current user information"""
    return current_user

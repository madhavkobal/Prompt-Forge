from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.user import User
from app.schemas.user import UserCreate
from app.core.security import (
    get_password_hash,
    verify_password,
    validate_password_strength,
    sanitize_input,
    validate_email
)


class AuthService:
    @staticmethod
    def create_user(db: Session, user_data: UserCreate) -> User:
        """Create a new user with security validations"""
        # Validate email format
        if not validate_email(user_data.email):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid email format",
            )

        # Validate password strength
        is_valid, error_message = validate_password_strength(user_data.password)
        if not is_valid:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=error_message,
            )

        # Sanitize input fields to prevent XSS
        sanitized_username = sanitize_input(user_data.username)
        sanitized_email = sanitize_input(user_data.email)
        sanitized_full_name = sanitize_input(user_data.full_name) if user_data.full_name else None

        # Check if user exists
        existing_user = (
            db.query(User)
            .filter(
                (User.email == sanitized_email) | (User.username == sanitized_username)
            )
            .first()
        )

        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email or username already registered",
            )

        # Create new user with sanitized data
        hashed_password = get_password_hash(user_data.password)
        db_user = User(
            email=sanitized_email,
            username=sanitized_username,
            full_name=sanitized_full_name,
            hashed_password=hashed_password,
        )

        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        return db_user

    @staticmethod
    def authenticate_user(db: Session, username: str, password: str) -> User:
        """Authenticate a user"""
        user = db.query(User).filter(User.username == username).first()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect username or password",
            )

        if not verify_password(password, user.hashed_password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect username or password",
            )

        return user

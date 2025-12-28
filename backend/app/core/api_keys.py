"""
API Key Management and Rotation System

This module provides secure API key generation, validation, and rotation
capabilities for external API access.
"""
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
import hashlib
import secrets
from sqlalchemy import Column, Integer, String, DateTime, Boolean
from sqlalchemy.orm import Session
from app.core.database import Base


class APIKey(Base):
    """
    API Key model for secure API access
    Stores hashed API keys (never plain text) with rotation support
    """
    __tablename__ = "api_keys"

    id = Column(Integer, primary_key=True, index=True)
    key_hash = Column(String, unique=True, nullable=False, index=True)
    key_prefix = Column(String(8), nullable=False)  # First 8 chars for identification
    name = Column(String, nullable=False)  # Descriptive name for the key
    user_id = Column(Integer, nullable=False, index=True)  # Owner of the key
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=True)  # Optional expiration
    last_used_at = Column(DateTime, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    scopes = Column(String, nullable=True)  # JSON string of permissions


class APIKeyManager:
    """
    Manager for API key operations including creation, validation, and rotation
    """

    @staticmethod
    def generate_api_key() -> str:
        """
        Generate a cryptographically secure API key

        Returns:
            A 64-character API key in format: sk_live_<random_token>
        """
        token = secrets.token_urlsafe(32)
        return f"sk_live_{token}"

    @staticmethod
    def hash_api_key(api_key: str) -> str:
        """
        Hash an API key for secure storage

        Args:
            api_key: The plain text API key

        Returns:
            SHA-256 hash of the API key
        """
        return hashlib.sha256(api_key.encode()).hexdigest()

    @staticmethod
    def create_api_key(
        db: Session,
        user_id: int,
        name: str,
        expires_in_days: Optional[int] = None,
        scopes: Optional[list] = None
    ) -> tuple[str, APIKey]:
        """
        Create a new API key for a user

        Args:
            db: Database session
            user_id: ID of the user who owns this key
            name: Descriptive name for the key
            expires_in_days: Optional expiration in days
            scopes: Optional list of permission scopes

        Returns:
            Tuple of (plain_api_key, api_key_record)
            IMPORTANT: plain_api_key is only shown once!
        """
        # Generate new API key
        plain_key = APIKeyManager.generate_api_key()
        key_hash = APIKeyManager.hash_api_key(plain_key)
        key_prefix = plain_key[:8]

        # Calculate expiration
        expires_at = None
        if expires_in_days:
            expires_at = datetime.utcnow() + timedelta(days=expires_in_days)

        # Create database record
        api_key_record = APIKey(
            key_hash=key_hash,
            key_prefix=key_prefix,
            name=name,
            user_id=user_id,
            expires_at=expires_at,
            scopes=','.join(scopes) if scopes else None
        )

        db.add(api_key_record)
        db.commit()
        db.refresh(api_key_record)

        return plain_key, api_key_record

    @staticmethod
    def validate_api_key(db: Session, api_key: str) -> Optional[APIKey]:
        """
        Validate an API key and update last_used_at

        Args:
            db: Database session
            api_key: The plain text API key to validate

        Returns:
            APIKey record if valid, None otherwise
        """
        # Hash the provided key
        key_hash = APIKeyManager.hash_api_key(api_key)

        # Find matching key in database
        api_key_record = db.query(APIKey).filter(
            APIKey.key_hash == key_hash,
            APIKey.is_active == True
        ).first()

        if not api_key_record:
            return None

        # Check expiration
        if api_key_record.expires_at and api_key_record.expires_at < datetime.utcnow():
            return None

        # Update last used timestamp
        api_key_record.last_used_at = datetime.utcnow()
        db.commit()

        return api_key_record

    @staticmethod
    def revoke_api_key(db: Session, key_id: int, user_id: int) -> bool:
        """
        Revoke (deactivate) an API key

        Args:
            db: Database session
            key_id: ID of the key to revoke
            user_id: ID of the user (for authorization)

        Returns:
            True if revoked successfully, False otherwise
        """
        api_key = db.query(APIKey).filter(
            APIKey.id == key_id,
            APIKey.user_id == user_id
        ).first()

        if not api_key:
            return False

        api_key.is_active = False
        db.commit()
        return True

    @staticmethod
    def rotate_api_key(
        db: Session,
        old_key_id: int,
        user_id: int,
        name: Optional[str] = None,
        expires_in_days: Optional[int] = None
    ) -> tuple[str, APIKey]:
        """
        Rotate an API key (create new, revoke old)

        Args:
            db: Database session
            old_key_id: ID of the key to rotate
            user_id: ID of the user (for authorization)
            name: Optional new name (defaults to old name)
            expires_in_days: Optional expiration for new key

        Returns:
            Tuple of (new_plain_key, new_api_key_record)
        """
        # Get old key
        old_key = db.query(APIKey).filter(
            APIKey.id == old_key_id,
            APIKey.user_id == user_id
        ).first()

        if not old_key:
            raise ValueError("API key not found or unauthorized")

        # Create new key
        key_name = name or old_key.name
        scopes = old_key.scopes.split(',') if old_key.scopes else None

        new_plain_key, new_key_record = APIKeyManager.create_api_key(
            db=db,
            user_id=user_id,
            name=key_name,
            expires_in_days=expires_in_days,
            scopes=scopes
        )

        # Revoke old key
        old_key.is_active = False
        db.commit()

        return new_plain_key, new_key_record

    @staticmethod
    def list_user_api_keys(db: Session, user_id: int) -> list[Dict[str, Any]]:
        """
        List all API keys for a user (returns safe info only)

        Args:
            db: Database session
            user_id: ID of the user

        Returns:
            List of API key info dictionaries (no secrets)
        """
        keys = db.query(APIKey).filter(APIKey.user_id == user_id).all()

        return [
            {
                "id": key.id,
                "name": key.name,
                "key_prefix": key.key_prefix,
                "created_at": key.created_at.isoformat(),
                "expires_at": key.expires_at.isoformat() if key.expires_at else None,
                "last_used_at": key.last_used_at.isoformat() if key.last_used_at else None,
                "is_active": key.is_active,
                "scopes": key.scopes.split(',') if key.scopes else []
            }
            for key in keys
        ]

    @staticmethod
    def cleanup_expired_keys(db: Session) -> int:
        """
        Cleanup expired API keys (deactivate them)
        Should be run periodically as a background task

        Args:
            db: Database session

        Returns:
            Number of keys deactivated
        """
        expired_keys = db.query(APIKey).filter(
            APIKey.expires_at < datetime.utcnow(),
            APIKey.is_active == True
        ).all()

        count = 0
        for key in expired_keys:
            key.is_active = False
            count += 1

        db.commit()
        return count

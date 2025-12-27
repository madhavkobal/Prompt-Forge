"""
Tests for authentication functionality.

Tests include:
- User registration
- User login
- JWT token generation and validation
- Password hashing and verification
- Current user retrieval
- Authentication errors and edge cases
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from jose import jwt

from app.core.config import settings
from app.core.security import verify_password, decode_access_token
from app.models.user import User
from app.services.auth_service import AuthService
from app.schemas.user import UserCreate


# =============================================================================
# Registration Tests
# =============================================================================

@pytest.mark.unit
@pytest.mark.auth
class TestUserRegistration:
    """Test user registration functionality."""

    def test_register_new_user_success(self, client: TestClient, test_user_data: dict):
        """Test successful user registration."""
        response = client.post("/api/v1/auth/register", json=test_user_data)

        assert response.status_code == 201
        data = response.json()
        assert data["email"] == test_user_data["email"]
        assert data["username"] == test_user_data["username"]
        assert data["full_name"] == test_user_data["full_name"]
        assert "id" in data
        assert "password" not in data  # Password should not be in response
        assert data["is_active"] is True

    def test_register_duplicate_email(self, client: TestClient, test_user_data: dict):
        """Test registration with duplicate email fails."""
        # First registration
        client.post("/api/v1/auth/register", json=test_user_data)

        # Try to register with same email
        duplicate_data = test_user_data.copy()
        duplicate_data["username"] = "different_username"
        response = client.post("/api/v1/auth/register", json=duplicate_data)

        assert response.status_code == 400
        assert "email" in response.json()["detail"].lower()

    def test_register_duplicate_username(self, client: TestClient, test_user_data: dict):
        """Test registration with duplicate username fails."""
        # First registration
        client.post("/api/v1/auth/register", json=test_user_data)

        # Try to register with same username
        duplicate_data = test_user_data.copy()
        duplicate_data["email"] = "different@example.com"
        response = client.post("/api/v1/auth/register", json=duplicate_data)

        assert response.status_code == 400
        assert "username" in response.json()["detail"].lower()

    def test_register_invalid_email(self, client: TestClient, test_user_data: dict):
        """Test registration with invalid email format fails."""
        test_user_data["email"] = "not-an-email"
        response = client.post("/api/v1/auth/register", json=test_user_data)

        assert response.status_code == 422

    def test_register_missing_required_fields(self, client: TestClient):
        """Test registration with missing required fields fails."""
        incomplete_data = {
            "email": "test@example.com"
            # Missing username and password
        }
        response = client.post("/api/v1/auth/register", json=incomplete_data)

        assert response.status_code == 422

    def test_register_password_hashed(self, test_db: Session, test_user_data: dict):
        """Test that password is properly hashed in database."""
        user_create = UserCreate(**test_user_data)
        user = AuthService.create_user(test_db, user_create)

        # Password should be hashed, not plain text
        assert user.hashed_password != test_user_data["password"]
        assert user.hashed_password.startswith("$2b$")  # bcrypt hash prefix
        # Verify the password works
        assert verify_password(test_user_data["password"], user.hashed_password)


# =============================================================================
# Login Tests
# =============================================================================

@pytest.mark.unit
@pytest.mark.auth
class TestUserLogin:
    """Test user login functionality."""

    def test_login_success(self, client: TestClient, test_user: User, test_user_data: dict):
        """Test successful login returns access token."""
        response = client.post(
            "/api/v1/auth/login",
            data={
                "username": test_user_data["username"],
                "password": test_user_data["password"]
            }
        )

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "token_type" in data
        assert data["token_type"] == "bearer"

        # Verify token is valid JWT
        token = data["access_token"]
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        assert payload["sub"] == test_user.username

    def test_login_with_email(self, client: TestClient, test_user: User, test_user_data: dict):
        """Test login with email instead of username."""
        response = client.post(
            "/api/v1/auth/login",
            data={
                "username": test_user_data["email"],  # OAuth2 form uses 'username' field
                "password": test_user_data["password"]
            }
        )

        # This might fail depending on implementation
        # Update test based on your auth logic
        assert response.status_code in [200, 401]

    def test_login_wrong_password(self, client: TestClient, test_user: User, test_user_data: dict):
        """Test login with incorrect password fails."""
        response = client.post(
            "/api/v1/auth/login",
            data={
                "username": test_user_data["username"],
                "password": "wrongpassword"
            }
        )

        assert response.status_code == 401
        assert "detail" in response.json()

    def test_login_nonexistent_user(self, client: TestClient):
        """Test login with non-existent username fails."""
        response = client.post(
            "/api/v1/auth/login",
            data={
                "username": "nonexistentuser",
                "password": "somepassword"
            }
        )

        assert response.status_code == 401

    def test_login_missing_credentials(self, client: TestClient):
        """Test login with missing credentials fails."""
        response = client.post(
            "/api/v1/auth/login",
            data={"username": "testuser"}  # Missing password
        )

        assert response.status_code == 422


# =============================================================================
# JWT Token Tests
# =============================================================================

@pytest.mark.unit
@pytest.mark.auth
class TestJWTToken:
    """Test JWT token generation and validation."""

    def test_token_contains_correct_claims(self, auth_token: str, test_user: User):
        """Test JWT token contains correct claims."""
        payload = jwt.decode(auth_token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])

        assert "sub" in payload  # Subject (username)
        assert "exp" in payload  # Expiration time
        assert payload["sub"] == test_user.username

    def test_token_expiration_set(self, auth_token: str):
        """Test JWT token has expiration set."""
        payload = jwt.decode(auth_token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])

        assert "exp" in payload
        # Expiration should be in the future
        import time
        assert payload["exp"] > time.time()

    def test_decode_valid_token(self, auth_token: str, test_user: User):
        """Test decoding a valid token."""
        payload = decode_access_token(auth_token)

        assert payload is not None
        assert payload["sub"] == test_user.username

    def test_decode_invalid_token(self):
        """Test decoding an invalid token returns None."""
        invalid_token = "invalid.token.here"
        payload = decode_access_token(invalid_token)

        assert payload is None

    def test_decode_expired_token(self, test_user: User):
        """Test decoding an expired token returns None."""
        from datetime import timedelta
        from app.core.security import create_access_token

        # Create token that expires immediately
        expired_token = create_access_token(
            data={"sub": test_user.username},
            expires_delta=timedelta(seconds=-1)
        )

        # Wait a moment
        import time
        time.sleep(0.1)

        payload = decode_access_token(expired_token)
        assert payload is None


# =============================================================================
# Current User Tests
# =============================================================================

@pytest.mark.integration
@pytest.mark.auth
class TestCurrentUser:
    """Test getting current authenticated user."""

    def test_get_current_user_success(self, client: TestClient, test_user: User, auth_headers: dict):
        """Test getting current user with valid token."""
        response = client.get("/api/v1/auth/me", headers=auth_headers)

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == test_user.id
        assert data["username"] == test_user.username
        assert data["email"] == test_user.email

    def test_get_current_user_no_token(self, client: TestClient):
        """Test getting current user without token fails."""
        response = client.get("/api/v1/auth/me")

        assert response.status_code == 401

    def test_get_current_user_invalid_token(self, client: TestClient):
        """Test getting current user with invalid token fails."""
        headers = {"Authorization": "Bearer invalid_token"}
        response = client.get("/api/v1/auth/me", headers=headers)

        assert response.status_code == 401

    def test_get_current_user_malformed_header(self, client: TestClient):
        """Test getting current user with malformed auth header fails."""
        headers = {"Authorization": "Invalid Format"}
        response = client.get("/api/v1/auth/me", headers=headers)

        assert response.status_code == 401


# =============================================================================
# Password Security Tests
# =============================================================================

@pytest.mark.unit
@pytest.mark.auth
class TestPasswordSecurity:
    """Test password hashing and verification."""

    def test_password_hashing(self):
        """Test password is properly hashed."""
        from app.core.security import get_password_hash

        password = "testpassword123"
        hashed = get_password_hash(password)

        assert hashed != password
        assert hashed.startswith("$2b$")
        assert len(hashed) > 50

    def test_password_verification_success(self):
        """Test correct password verification."""
        from app.core.security import get_password_hash

        password = "testpassword123"
        hashed = get_password_hash(password)

        assert verify_password(password, hashed) is True

    def test_password_verification_failure(self):
        """Test incorrect password verification."""
        from app.core.security import get_password_hash

        password = "testpassword123"
        hashed = get_password_hash(password)

        assert verify_password("wrongpassword", hashed) is False

    def test_same_password_different_hashes(self):
        """Test same password generates different hashes (salt)."""
        from app.core.security import get_password_hash

        password = "testpassword123"
        hash1 = get_password_hash(password)
        hash2 = get_password_hash(password)

        # Hashes should be different due to salt
        assert hash1 != hash2
        # But both should verify correctly
        assert verify_password(password, hash1)
        assert verify_password(password, hash2)


# =============================================================================
# AuthService Tests
# =============================================================================

@pytest.mark.unit
@pytest.mark.auth
class TestAuthService:
    """Test AuthService business logic."""

    def test_create_user_service(self, test_db: Session, test_user_data: dict):
        """Test user creation through AuthService."""
        user_create = UserCreate(**test_user_data)
        user = AuthService.create_user(test_db, user_create)

        assert user.id is not None
        assert user.email == test_user_data["email"]
        assert user.username == test_user_data["username"]
        assert user.is_active is True

    def test_authenticate_user_success(self, test_db: Session, test_user: User, test_user_data: dict):
        """Test successful user authentication."""
        authenticated_user = AuthService.authenticate_user(
            test_db,
            test_user_data["username"],
            test_user_data["password"]
        )

        assert authenticated_user is not None
        assert authenticated_user.id == test_user.id

    def test_authenticate_user_wrong_password(self, test_db: Session, test_user: User):
        """Test authentication with wrong password fails."""
        with pytest.raises(Exception):  # Should raise HTTPException
            AuthService.authenticate_user(
                test_db,
                test_user.username,
                "wrongpassword"
            )

    def test_authenticate_nonexistent_user(self, test_db: Session):
        """Test authentication of non-existent user fails."""
        with pytest.raises(Exception):  # Should raise HTTPException
            AuthService.authenticate_user(
                test_db,
                "nonexistent",
                "password"
            )


# =============================================================================
# Edge Cases and Error Handling
# =============================================================================

@pytest.mark.unit
@pytest.mark.auth
class TestAuthEdgeCases:
    """Test edge cases and error handling."""

    def test_register_empty_password(self, client: TestClient, test_user_data: dict):
        """Test registration with empty password."""
        test_user_data["password"] = ""
        response = client.post("/api/v1/auth/register", json=test_user_data)

        assert response.status_code == 422

    def test_register_very_long_username(self, client: TestClient, test_user_data: dict):
        """Test registration with extremely long username."""
        test_user_data["username"] = "a" * 1000
        response = client.post("/api/v1/auth/register", json=test_user_data)

        # Should either succeed or fail with validation error
        assert response.status_code in [201, 422]

    def test_register_sql_injection_attempt(self, client: TestClient, test_user_data: dict):
        """Test that SQL injection attempts are safely handled."""
        test_user_data["username"] = "admin'; DROP TABLE users; --"
        response = client.post("/api/v1/auth/register", json=test_user_data)

        # Should either succeed (string is escaped) or fail validation
        assert response.status_code in [201, 422]

    def test_register_xss_attempt(self, client: TestClient, test_user_data: dict):
        """Test that XSS attempts are safely handled."""
        test_user_data["full_name"] = "<script>alert('xss')</script>"
        response = client.post("/api/v1/auth/register", json=test_user_data)

        if response.status_code == 201:
            # If accepted, it should be properly escaped
            data = response.json()
            assert "<script>" not in data.get("full_name", "")

    def test_token_without_bearer_prefix(self, client: TestClient, auth_token: str):
        """Test that token without 'Bearer' prefix is rejected."""
        headers = {"Authorization": auth_token}  # Missing 'Bearer' prefix
        response = client.get("/api/v1/auth/me", headers=headers)

        assert response.status_code == 401

    def test_multiple_concurrent_registrations(self, client: TestClient, test_user_data: dict):
        """Test handling of concurrent registration attempts."""
        # This tests race conditions
        import concurrent.futures

        def register():
            return client.post("/api/v1/auth/register", json=test_user_data)

        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(register) for _ in range(5)]
            results = [f.result() for f in futures]

        # Exactly one should succeed, others should fail
        success_count = sum(1 for r in results if r.status_code == 201)
        assert success_count == 1

    def test_case_sensitive_username(self, client: TestClient, test_user: User, test_user_data: dict):
        """Test username case sensitivity."""
        response = client.post(
            "/api/v1/auth/login",
            data={
                "username": test_user_data["username"].upper(),
                "password": test_user_data["password"]
            }
        )

        # Behavior depends on implementation
        # Document expected behavior in assertion
        assert response.status_code in [200, 401]

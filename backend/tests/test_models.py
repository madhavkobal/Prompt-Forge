"""
Tests for database models.

Tests include:
- Model creation and field validation
- Relationships between models
- Cascade deletes
- Default values
- Timestamps
"""

import pytest
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from app.models.user import User
from app.models.prompt import Prompt as PromptModel, Template, PromptVersion


# =============================================================================
# User Model Tests
# =============================================================================

@pytest.mark.unit
@pytest.mark.database
class TestUserModel:
    """Test User model."""

    def test_create_user(self, test_db: Session):
        """Test creating a user."""
        user = User(
            email="test@example.com",
            username="testuser",
            hashed_password="hashed_password_here",
            full_name="Test User"
        )
        test_db.add(user)
        test_db.commit()
        test_db.refresh(user)

        assert user.id is not None
        assert user.email == "test@example.com"
        assert user.username == "testuser"
        assert user.is_active is True  # Default value

    def test_user_timestamps(self, test_db: Session):
        """Test user created_at and updated_at timestamps."""
        user = User(
            email="test@example.com",
            username="testuser",
            hashed_password="hashed"
        )
        test_db.add(user)
        test_db.commit()
        test_db.refresh(user)

        assert user.created_at is not None
        assert user.updated_at is not None
        assert isinstance(user.created_at, datetime)
        assert isinstance(user.updated_at, datetime)

    def test_user_unique_email(self, test_db: Session):
        """Test email uniqueness constraint."""
        user1 = User(
            email="test@example.com",
            username="user1",
            hashed_password="hashed"
        )
        test_db.add(user1)
        test_db.commit()

        user2 = User(
            email="test@example.com",  # Duplicate email
            username="user2",
            hashed_password="hashed"
        )
        test_db.add(user2)

        with pytest.raises(IntegrityError):
            test_db.commit()

    def test_user_unique_username(self, test_db: Session):
        """Test username uniqueness constraint."""
        user1 = User(
            email="test1@example.com",
            username="testuser",
            hashed_password="hashed"
        )
        test_db.add(user1)
        test_db.commit()

        user2 = User(
            email="test2@example.com",
            username="testuser",  # Duplicate username
            hashed_password="hashed"
        )
        test_db.add(user2)

        with pytest.raises(IntegrityError):
            test_db.commit()

    def test_user_relationships(self, test_db: Session, test_user: User, test_prompt: PromptModel):
        """Test user relationships with prompts and templates."""
        assert len(test_user.prompts) == 1
        assert test_user.prompts[0].id == test_prompt.id


# =============================================================================
# Prompt Model Tests
# =============================================================================

@pytest.mark.unit
@pytest.mark.database
class TestPromptModel:
    """Test Prompt model."""

    def test_create_prompt(self, test_db: Session, test_user: User):
        """Test creating a prompt."""
        prompt = PromptModel(
            title="Test Prompt",
            content="Test content",
            target_llm="ChatGPT",
            category="test",
            tags=["tag1", "tag2"],
            owner_id=test_user.id
        )
        test_db.add(prompt)
        test_db.commit()
        test_db.refresh(prompt)

        assert prompt.id is not None
        assert prompt.title == "Test Prompt"
        assert prompt.content == "Test content"
        assert prompt.target_llm == "ChatGPT"
        assert prompt.owner_id == test_user.id

    def test_prompt_timestamps(self, test_db: Session, test_user: User):
        """Test prompt timestamps."""
        prompt = PromptModel(
            title="Test",
            content="Content",
            target_llm="ChatGPT",
            owner_id=test_user.id
        )
        test_db.add(prompt)
        test_db.commit()
        test_db.refresh(prompt)

        assert prompt.created_at is not None
        assert prompt.updated_at is not None

        # Test updated_at changes
        old_updated_at = prompt.updated_at
        import time
        time.sleep(0.1)
        prompt.content = "Updated content"
        test_db.commit()
        test_db.refresh(prompt)

        assert prompt.updated_at > old_updated_at

    def test_prompt_owner_relationship(self, test_db: Session, test_user: User):
        """Test prompt-user relationship."""
        prompt = PromptModel(
            title="Test",
            content="Content",
            target_llm="ChatGPT",
            owner_id=test_user.id
        )
        test_db.add(prompt)
        test_db.commit()
        test_db.refresh(prompt)

        assert prompt.owner.id == test_user.id
        assert prompt.owner.username == test_user.username

    def test_prompt_default_scores_null(self, test_db: Session, test_user: User):
        """Test prompt scores default to None."""
        prompt = PromptModel(
            title="Test",
            content="Content",
            target_llm="ChatGPT",
            owner_id=test_user.id
        )
        test_db.add(prompt)
        test_db.commit()
        test_db.refresh(prompt)

        assert prompt.quality_score is None
        assert prompt.clarity_score is None
        assert prompt.specificity_score is None
        assert prompt.structure_score is None

    def test_prompt_with_scores(self, test_db: Session, test_user: User):
        """Test prompt with analysis scores."""
        prompt = PromptModel(
            title="Test",
            content="Content",
            target_llm="ChatGPT",
            owner_id=test_user.id,
            quality_score=85.5,
            clarity_score=90.0,
            specificity_score=80.0,
            structure_score=87.5
        )
        test_db.add(prompt)
        test_db.commit()
        test_db.refresh(prompt)

        assert prompt.quality_score == 85.5
        assert prompt.clarity_score == 90.0

    def test_prompt_cascade_delete(self, test_db: Session, test_user: User):
        """Test cascade delete when user is deleted."""
        prompt = PromptModel(
            title="Test",
            content="Content",
            target_llm="ChatGPT",
            owner_id=test_user.id
        )
        test_db.add(prompt)
        test_db.commit()
        prompt_id = prompt.id

        # Delete user
        test_db.delete(test_user)
        test_db.commit()

        # Prompt should be deleted too
        deleted_prompt = test_db.query(PromptModel).filter(PromptModel.id == prompt_id).first()
        assert deleted_prompt is None


# =============================================================================
# PromptVersion Model Tests
# =============================================================================

@pytest.mark.unit
@pytest.mark.database
class TestPromptVersionModel:
    """Test PromptVersion model."""

    def test_create_version(self, test_db: Session, test_prompt: PromptModel):
        """Test creating a prompt version."""
        version = PromptVersion(
            prompt_id=test_prompt.id,
            version_number=2,
            content="Updated content version 2"
        )
        test_db.add(version)
        test_db.commit()
        test_db.refresh(version)

        assert version.id is not None
        assert version.prompt_id == test_prompt.id
        assert version.version_number == 2

    def test_version_relationship_to_prompt(self, test_db: Session, test_prompt: PromptModel):
        """Test version-prompt relationship."""
        version = PromptVersion(
            prompt_id=test_prompt.id,
            version_number=2,
            content="Version 2"
        )
        test_db.add(version)
        test_db.commit()
        test_db.refresh(version)

        assert version.prompt.id == test_prompt.id

    def test_multiple_versions(self, test_db: Session, test_prompt: PromptModel):
        """Test creating multiple versions for a prompt."""
        for i in range(2, 5):
            version = PromptVersion(
                prompt_id=test_prompt.id,
                version_number=i,
                content=f"Version {i}"
            )
            test_db.add(version)

        test_db.commit()

        # Query all versions
        versions = test_db.query(PromptVersion).filter(
            PromptVersion.prompt_id == test_prompt.id
        ).all()

        assert len(versions) == 4  # 1 from fixture + 3 new

    def test_version_cascade_delete(self, test_db: Session, test_prompt: PromptModel):
        """Test versions are deleted when prompt is deleted."""
        version = PromptVersion(
            prompt_id=test_prompt.id,
            version_number=2,
            content="Version 2"
        )
        test_db.add(version)
        test_db.commit()
        version_id = version.id

        # Delete prompt
        test_db.delete(test_prompt)
        test_db.commit()

        # Version should be deleted
        deleted_version = test_db.query(PromptVersion).filter(
            PromptVersion.id == version_id
        ).first()
        assert deleted_version is None


# =============================================================================
# Template Model Tests
# =============================================================================

@pytest.mark.unit
@pytest.mark.database
class TestTemplateModel:
    """Test Template model."""

    def test_create_template(self, test_db: Session, test_user: User):
        """Test creating a template."""
        template = Template(
            name="Test Template",
            description="Test description",
            content="Template content with {placeholder}",
            category="test",
            tags=["tag1"],
            is_public=True,
            owner_id=test_user.id
        )
        test_db.add(template)
        test_db.commit()
        test_db.refresh(template)

        assert template.id is not None
        assert template.name == "Test Template"
        assert template.is_public is True

    def test_template_use_count_default(self, test_db: Session, test_user: User):
        """Test template use_count defaults to 0."""
        template = Template(
            name="Test",
            content="Content",
            category="test",
            owner_id=test_user.id
        )
        test_db.add(template)
        test_db.commit()
        test_db.refresh(template)

        assert template.use_count == 0

    def test_template_increment_use_count(self, test_db: Session, test_template: Template):
        """Test incrementing template use count."""
        initial_count = test_template.use_count
        test_template.use_count += 1
        test_db.commit()
        test_db.refresh(test_template)

        assert test_template.use_count == initial_count + 1

    def test_template_is_public_default(self, test_db: Session, test_user: User):
        """Test is_public defaults to False."""
        template = Template(
            name="Test",
            content="Content",
            category="test",
            owner_id=test_user.id
        )
        test_db.add(template)
        test_db.commit()
        test_db.refresh(template)

        assert template.is_public is False

    def test_template_owner_relationship(self, test_db: Session, test_user: User):
        """Test template-user relationship."""
        template = Template(
            name="Test",
            content="Content",
            category="test",
            owner_id=test_user.id
        )
        test_db.add(template)
        test_db.commit()
        test_db.refresh(template)

        assert template.owner.id == test_user.id

    def test_template_cascade_delete(self, test_db: Session, test_user: User):
        """Test template deletion when user is deleted."""
        template = Template(
            name="Test",
            content="Content",
            category="test",
            owner_id=test_user.id
        )
        test_db.add(template)
        test_db.commit()
        template_id = template.id

        # Delete user
        test_db.delete(test_user)
        test_db.commit()

        # Template should be deleted
        deleted_template = test_db.query(Template).filter(
            Template.id == template_id
        ).first()
        assert deleted_template is None


# =============================================================================
# Model Relationships Tests
# =============================================================================

@pytest.mark.unit
@pytest.mark.database
class TestModelRelationships:
    """Test relationships between models."""

    def test_user_has_many_prompts(self, test_db: Session, test_user: User):
        """Test user can have multiple prompts."""
        for i in range(5):
            prompt = PromptModel(
                title=f"Prompt {i}",
                content=f"Content {i}",
                target_llm="ChatGPT",
                owner_id=test_user.id
            )
            test_db.add(prompt)

        test_db.commit()
        test_db.refresh(test_user)

        assert len(test_user.prompts) == 5

    def test_user_has_many_templates(self, test_db: Session, test_user: User):
        """Test user can have multiple templates."""
        for i in range(3):
            template = Template(
                name=f"Template {i}",
                content=f"Content {i}",
                category="test",
                owner_id=test_user.id
            )
            test_db.add(template)

        test_db.commit()
        test_db.refresh(test_user)

        assert len(test_user.templates) == 3

    def test_prompt_has_many_versions(self, test_db: Session, test_prompt: PromptModel):
        """Test prompt can have multiple versions."""
        for i in range(2, 6):
            version = PromptVersion(
                prompt_id=test_prompt.id,
                version_number=i,
                content=f"Version {i}"
            )
            test_db.add(version)

        test_db.commit()
        test_db.refresh(test_prompt)

        assert len(test_prompt.versions) == 5  # 1 from fixture + 4 new

    def test_delete_user_deletes_all_related(self, test_db: Session, test_user: User):
        """Test deleting user cascades to all related models."""
        # Create multiple related objects
        prompt = PromptModel(
            title="Test",
            content="Content",
            target_llm="ChatGPT",
            owner_id=test_user.id
        )
        test_db.add(prompt)
        test_db.commit()

        version = PromptVersion(
            prompt_id=prompt.id,
            version_number=2,
            content="Version 2"
        )
        test_db.add(version)
        test_db.commit()

        template = Template(
            name="Test",
            content="Content",
            category="test",
            owner_id=test_user.id
        )
        test_db.add(template)
        test_db.commit()

        # Get IDs
        prompt_id = prompt.id
        version_id = version.id
        template_id = template.id

        # Delete user
        test_db.delete(test_user)
        test_db.commit()

        # All should be deleted
        assert test_db.query(PromptModel).filter(PromptModel.id == prompt_id).first() is None
        assert test_db.query(PromptVersion).filter(PromptVersion.id == version_id).first() is None
        assert test_db.query(Template).filter(Template.id == template_id).first() is None


# =============================================================================
# Model Validation Tests
# =============================================================================

@pytest.mark.unit
@pytest.mark.database
class TestModelValidation:
    """Test model field validation."""

    def test_user_requires_email(self, test_db: Session):
        """Test user requires email field."""
        user = User(
            username="testuser",
            hashed_password="hashed"
            # Missing email
        )
        test_db.add(user)

        with pytest.raises(IntegrityError):
            test_db.commit()

    def test_prompt_requires_content(self, test_db: Session, test_user: User):
        """Test prompt requires content field."""
        prompt = PromptModel(
            title="Test",
            target_llm="ChatGPT",
            owner_id=test_user.id
            # Missing content
        )
        test_db.add(prompt)

        with pytest.raises(IntegrityError):
            test_db.commit()

    def test_template_requires_name(self, test_db: Session, test_user: User):
        """Test template requires name field."""
        template = Template(
            content="Content",
            category="test",
            owner_id=test_user.id
            # Missing name
        )
        test_db.add(template)

        with pytest.raises(IntegrityError):
            test_db.commit()

    def test_json_field_stores_dict(self, test_db: Session, test_user: User):
        """Test JSON fields properly store dictionaries."""
        prompt = PromptModel(
            title="Test",
            content="Content",
            target_llm="ChatGPT",
            owner_id=test_user.id,
            best_practices={"key": "value", "nested": {"data": "here"}}
        )
        test_db.add(prompt)
        test_db.commit()
        test_db.refresh(prompt)

        assert isinstance(prompt.best_practices, dict)
        assert prompt.best_practices["key"] == "value"
        assert prompt.best_practices["nested"]["data"] == "here"

    def test_json_field_stores_list(self, test_db: Session, test_user: User):
        """Test JSON fields properly store lists."""
        prompt = PromptModel(
            title="Test",
            content="Content",
            target_llm="ChatGPT",
            owner_id=test_user.id,
            suggestions=["suggestion1", "suggestion2", "suggestion3"]
        )
        test_db.add(prompt)
        test_db.commit()
        test_db.refresh(prompt)

        assert isinstance(prompt.suggestions, list)
        assert len(prompt.suggestions) == 3
        assert "suggestion1" in prompt.suggestions

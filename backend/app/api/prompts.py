from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.core.database import get_db
from app.core.exceptions import AnalysisUnavailableException, EnhancementUnavailableException
from app.api.dependencies import get_current_active_user
from app.models.user import User
from app.models.prompt import Prompt as PromptModel, PromptVersion as PromptVersionModel
from app.schemas.prompt import (
    Prompt,
    PromptCreate,
    PromptUpdate,
    PromptAnalysis,
    PromptEnhancement,
    PromptVersion,
)
from app.services.gemini_service import GeminiService
from app.config.system_prompts import PROMPTS_VERSION

router = APIRouter()
gemini_service = GeminiService()


@router.post("/", response_model=Prompt, status_code=status.HTTP_201_CREATED)
def create_prompt(
    prompt_data: PromptCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Create a new prompt"""
    db_prompt = PromptModel(
        title=prompt_data.title,
        content=prompt_data.content,
        target_llm=prompt_data.target_llm,
        category=prompt_data.category,
        tags=prompt_data.tags,
        owner_id=current_user.id,
    )

    db.add(db_prompt)
    db.commit()
    db.refresh(db_prompt)

    # Create initial version
    version = PromptVersionModel(
        prompt_id=db_prompt.id,
        version_number=1,
        content=prompt_data.content,
    )
    db.add(version)
    db.commit()

    return db_prompt


@router.get("/", response_model=List[Prompt])
def get_prompts(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Get all prompts for current user"""
    prompts = (
        db.query(PromptModel)
        .filter(PromptModel.owner_id == current_user.id)
        .offset(skip)
        .limit(limit)
        .all()
    )
    return prompts


@router.get("/history", response_model=List[Prompt])
def get_prompt_history(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Get user's prompt history sorted by most recent"""
    prompts = (
        db.query(PromptModel)
        .filter(PromptModel.owner_id == current_user.id)
        .order_by(PromptModel.updated_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return prompts


@router.get("/{prompt_id}", response_model=Prompt)
def get_prompt(
    prompt_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Get a specific prompt"""
    prompt = (
        db.query(PromptModel)
        .filter(
            PromptModel.id == prompt_id, PromptModel.owner_id == current_user.id
        )
        .first()
    )

    if not prompt:
        raise HTTPException(status_code=404, detail="Prompt not found")

    return prompt


@router.put("/{prompt_id}", response_model=Prompt)
def update_prompt(
    prompt_id: int,
    prompt_data: PromptUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Update a prompt"""
    prompt = (
        db.query(PromptModel)
        .filter(
            PromptModel.id == prompt_id, PromptModel.owner_id == current_user.id
        )
        .first()
    )

    if not prompt:
        raise HTTPException(status_code=404, detail="Prompt not found")

    # Update fields using explicit field mapping for security
    # This prevents accidental overwrites of internal fields (id, owner_id, etc.)
    # if the schema ever evolves or allows extra fields
    if prompt_data.title is not None:
        prompt.title = prompt_data.title
    if prompt_data.content is not None:
        prompt.content = prompt_data.content
    if prompt_data.target_llm is not None:
        prompt.target_llm = prompt_data.target_llm
    if prompt_data.category is not None:
        prompt.category = prompt_data.category
    if prompt_data.tags is not None:
        prompt.tags = prompt_data.tags

    # Create new version if content changed
    if prompt_data.content:
        latest_version = (
            db.query(PromptVersionModel)
            .filter(PromptVersionModel.prompt_id == prompt_id)
            .order_by(PromptVersionModel.version_number.desc())
            .first()
        )

        new_version_number = (latest_version.version_number + 1) if latest_version else 1

        version = PromptVersionModel(
            prompt_id=prompt_id,
            version_number=new_version_number,
            content=prompt_data.content,
        )
        db.add(version)

    db.commit()
    db.refresh(prompt)
    return prompt


@router.delete("/{prompt_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_prompt(
    prompt_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Delete a prompt"""
    prompt = (
        db.query(PromptModel)
        .filter(
            PromptModel.id == prompt_id, PromptModel.owner_id == current_user.id
        )
        .first()
    )

    if not prompt:
        raise HTTPException(status_code=404, detail="Prompt not found")

    db.delete(prompt)
    db.commit()
    return None


@router.post("/{prompt_id}/analyze", response_model=PromptAnalysis)
def analyze_prompt(
    prompt_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Analyze prompt quality"""
    prompt = (
        db.query(PromptModel)
        .filter(
            PromptModel.id == prompt_id, PromptModel.owner_id == current_user.id
        )
        .first()
    )

    if not prompt:
        raise HTTPException(status_code=404, detail="Prompt not found")

    # Analyze with Gemini
    try:
        analysis = gemini_service.analyze_prompt(prompt.content, prompt.target_llm)

        # Update prompt with analysis results and track which version of meta-prompts was used
        prompt.quality_score = analysis.quality_score
        prompt.clarity_score = analysis.clarity_score
        prompt.specificity_score = analysis.specificity_score
        prompt.structure_score = analysis.structure_score
        prompt.suggestions = analysis.suggestions
        prompt.best_practices = analysis.best_practices
        prompt.system_prompts_version = PROMPTS_VERSION  # Track meta-prompt version for A/B testing

        db.commit()

        return analysis
    except AnalysisUnavailableException as e:
        raise HTTPException(
            status_code=503,
            detail={
                "error": "service_unavailable",
                "message": e.message,
                "details": e.details
            }
        )


@router.post("/{prompt_id}/enhance", response_model=PromptEnhancement)
def enhance_prompt(
    prompt_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Enhance prompt with AI"""
    prompt = (
        db.query(PromptModel)
        .filter(
            PromptModel.id == prompt_id, PromptModel.owner_id == current_user.id
        )
        .first()
    )

    if not prompt:
        raise HTTPException(status_code=404, detail="Prompt not found")

    # Enhance with Gemini
    try:
        enhancement = gemini_service.enhance_prompt(prompt.content, prompt.target_llm)

        # Update prompt with enhanced content
        prompt.enhanced_content = enhancement.enhanced_content

        db.commit()

        return enhancement
    except EnhancementUnavailableException as e:
        raise HTTPException(
            status_code=503,
            detail={
                "error": "service_unavailable",
                "message": e.message,
                "details": e.details
            }
        )


@router.get("/{prompt_id}/versions", response_model=List[PromptVersion])
def get_prompt_versions(
    prompt_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Get all versions of a prompt"""
    prompt = (
        db.query(PromptModel)
        .filter(
            PromptModel.id == prompt_id, PromptModel.owner_id == current_user.id
        )
        .first()
    )

    if not prompt:
        raise HTTPException(status_code=404, detail="Prompt not found")

    versions = (
        db.query(PromptVersionModel)
        .filter(PromptVersionModel.prompt_id == prompt_id)
        .order_by(PromptVersionModel.version_number.desc())
        .all()
    )

    return versions

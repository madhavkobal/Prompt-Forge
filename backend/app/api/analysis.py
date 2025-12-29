"""
Advanced analysis endpoints for prompt evaluation
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Dict, Any

from app.core.database import get_db
from app.core.exceptions import AnalysisUnavailableException, EnhancementUnavailableException
from app.api.dependencies import get_current_active_user
from app.models.user import User
from app.models.prompt import Prompt as PromptModel
from app.services.gemini_service import GeminiService

router = APIRouter()


@router.post("/prompt/{prompt_id}/versions")
def generate_enhanced_versions(
    prompt_id: int,
    num_versions: int = 3,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> Dict[str, Any]:
    """
    Generate multiple enhanced versions of a prompt

    Returns 2-3 different improved versions, each focusing on different aspects:
    - Version 1: Clarity and structure
    - Version 2: Specificity and detail
    - Version 3: Context and examples
    """
    # Fetch prompt
    prompt = (
        db.query(PromptModel)
        .filter(
            PromptModel.id == prompt_id,
            PromptModel.owner_id == current_user.id
        )
        .first()
    )

    if not prompt:
        raise HTTPException(status_code=404, detail="Prompt not found")

    # Generate versions
    try:
        gemini_service = GeminiService()
        versions = gemini_service.generate_prompt_versions(
            prompt.content,
            prompt.target_llm,
            num_versions
        )

        return {
            "original_prompt": prompt.content,
            "target_llm": prompt.target_llm,
            "versions": versions,
            "count": len(versions)
        }
    except EnhancementUnavailableException as e:
        raise HTTPException(
            status_code=503,
            detail={
                "error": "service_unavailable",
                "message": e.message,
                "details": e.details
            }
        )


@router.post("/prompt/{prompt_id}/ambiguities")
def detect_ambiguities(
    prompt_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> Dict[str, Any]:
    """
    Detect ambiguous or unclear parts in a prompt

    Returns list of ambiguities with:
    - The ambiguous phrase
    - Why it's ambiguous
    - How to clarify it
    """
    # Fetch prompt
    prompt = (
        db.query(PromptModel)
        .filter(
            PromptModel.id == prompt_id,
            PromptModel.owner_id == current_user.id
        )
        .first()
    )

    if not prompt:
        raise HTTPException(status_code=404, detail="Prompt not found")

    # Detect ambiguities
    try:
        gemini_service = GeminiService()
        ambiguities = gemini_service.detect_ambiguities(prompt.content)

        return {
            "prompt_id": prompt_id,
            "ambiguities": ambiguities,
            "count": len(ambiguities),
            "has_ambiguities": len(ambiguities) > 0
        }
    except AnalysisUnavailableException as e:
        raise HTTPException(
            status_code=503,
            detail={
                "error": "service_unavailable",
                "message": e.message,
                "details": e.details
            }
        )


@router.get("/prompt/{prompt_id}/best-practices")
def check_best_practices(
    prompt_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> Dict[str, Any]:
    """
    Check prompt against LLM-specific best practices

    Returns compliance score and recommendations
    """
    # Fetch prompt
    prompt = (
        db.query(PromptModel)
        .filter(
            PromptModel.id == prompt_id,
            PromptModel.owner_id == current_user.id
        )
        .first()
    )

    if not prompt:
        raise HTTPException(status_code=404, detail="Prompt not found")

    if not prompt.target_llm:
        raise HTTPException(
            status_code=400,
            detail="Prompt must have a target LLM specified"
        )

    # Check best practices
    gemini_service = GeminiService()
    result = gemini_service.check_best_practices(prompt.content, prompt.target_llm)

    return result


@router.get("/models")
def get_available_models() -> Dict[str, Any]:
    """Get list of supported Gemini models"""
    return {
        "models": [
            {
                "name": "gemini-pro",
                "id": "gemini-pro",
                "description": "Standard Gemini Pro model for text generation",
                "recommended": True
            },
            {
                "name": "gemini-1.5-pro",
                "id": "gemini-1.5-pro-latest",
                "description": "Latest Gemini 1.5 Pro with improved capabilities",
                "recommended": False
            },
            {
                "name": "gemini-1.5-flash",
                "id": "gemini-1.5-flash-latest",
                "description": "Faster Gemini 1.5 Flash model",
                "recommended": False
            }
        ],
        "default": "gemini-pro"
    }

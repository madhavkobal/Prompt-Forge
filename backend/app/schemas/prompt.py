from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime


class PromptBase(BaseModel):
    title: Optional[str] = None
    content: str
    target_llm: Optional[str] = None
    category: Optional[str] = None
    tags: Optional[List[str]] = None


class PromptCreate(PromptBase):
    pass


class PromptUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    target_llm: Optional[str] = None
    category: Optional[str] = None
    tags: Optional[List[str]] = None


class Prompt(PromptBase):
    id: int
    enhanced_content: Optional[str] = None
    quality_score: Optional[float] = None
    clarity_score: Optional[float] = None
    specificity_score: Optional[float] = None
    structure_score: Optional[float] = None
    analysis_result: Optional[Dict[str, Any]] = None
    suggestions: Optional[List[str]] = None
    best_practices: Optional[Dict[str, Any]] = None
    system_prompts_version: Optional[str] = None
    owner_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class PromptAnalysis(BaseModel):
    quality_score: float
    clarity_score: float
    specificity_score: float
    structure_score: float
    strengths: List[str]
    weaknesses: List[str]
    suggestions: List[str]
    best_practices: Dict[str, Any]


class PromptEnhancement(BaseModel):
    original_content: str
    enhanced_content: str
    improvements: List[str]
    quality_improvement: float


class PromptVersionBase(BaseModel):
    content: str
    version_number: int
    change_summary: Optional[str] = None


class PromptVersion(PromptVersionBase):
    id: int
    prompt_id: int
    quality_score: Optional[float] = None
    created_at: datetime

    class Config:
        from_attributes = True


class TemplateBase(BaseModel):
    name: str
    description: Optional[str] = None
    content: str
    category: Optional[str] = None
    tags: Optional[List[str]] = None
    is_public: bool = False


class TemplateCreate(TemplateBase):
    pass


class Template(TemplateBase):
    id: int
    owner_id: int
    use_count: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

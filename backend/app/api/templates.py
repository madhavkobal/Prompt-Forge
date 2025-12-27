from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.core.database import get_db
from app.api.dependencies import get_current_active_user
from app.models.user import User
from app.models.prompt import Template as TemplateModel
from app.schemas.prompt import Template, TemplateCreate

router = APIRouter()


@router.post("/", response_model=Template, status_code=status.HTTP_201_CREATED)
def create_template(
    template_data: TemplateCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Create a new template"""
    db_template = TemplateModel(
        name=template_data.name,
        description=template_data.description,
        content=template_data.content,
        category=template_data.category,
        tags=template_data.tags,
        is_public=template_data.is_public,
        owner_id=current_user.id,
    )

    db.add(db_template)
    db.commit()
    db.refresh(db_template)
    return db_template


@router.get("/", response_model=List[Template])
def get_templates(
    skip: int = 0,
    limit: int = 100,
    include_public: bool = True,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Get templates (user's own + public templates)"""
    query = db.query(TemplateModel)

    if include_public:
        query = query.filter(
            (TemplateModel.owner_id == current_user.id) | (TemplateModel.is_public == True)
        )
    else:
        query = query.filter(TemplateModel.owner_id == current_user.id)

    templates = query.offset(skip).limit(limit).all()
    return templates


@router.get("/{template_id}", response_model=Template)
def get_template(
    template_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Get a specific template"""
    template = db.query(TemplateModel).filter(TemplateModel.id == template_id).first()

    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    # Check access permissions
    if template.owner_id != current_user.id and not template.is_public:
        raise HTTPException(status_code=403, detail="Access denied")

    # Increment use count
    template.use_count += 1
    db.commit()

    return template


@router.delete("/{template_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_template(
    template_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Delete a template"""
    template = (
        db.query(TemplateModel)
        .filter(
            TemplateModel.id == template_id,
            TemplateModel.owner_id == current_user.id,
        )
        .first()
    )

    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    db.delete(template)
    db.commit()
    return None

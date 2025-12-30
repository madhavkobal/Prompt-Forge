"""Add system_prompts_version to prompts table

Revision ID: 7eb6e0d09fb7
Revises: 5289f4272a78
Create Date: 2025-12-30 08:05:00.975716

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7eb6e0d09fb7'
down_revision: Union[str, None] = '5289f4272a78'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add system_prompts_version column to prompts table
    op.add_column('prompts', sa.Column('system_prompts_version', sa.String(), nullable=True))


def downgrade() -> None:
    # Remove system_prompts_version column from prompts table
    op.drop_column('prompts', 'system_prompts_version')

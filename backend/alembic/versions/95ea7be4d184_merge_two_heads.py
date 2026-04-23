"""merge_two_heads

Revision ID: 95ea7be4d184
Revises: a1b2c3d4e5f6, 5a6b7c8d9e0f
Create Date: 2026-04-20 17:38:30.953497

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '95ea7be4d184'
down_revision: Union[str, Sequence[str], None] = ('a1b2c3d4e5f6', '5a6b7c8d9e0f')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass

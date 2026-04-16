"""add_property_id_to_chat_conversations

Revision ID: a3f8c2b1d704
Revises: cb799e57102f
Create Date: 2026-04-13 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a3f8c2b1d704'
down_revision: Union[str, Sequence[str], None] = 'cb799e57102f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        'chat_conversations',
        sa.Column('property_id', sa.UUID(), sa.ForeignKey('properties.id', ondelete='SET NULL'), nullable=True, index=True),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('chat_conversations', 'property_id')

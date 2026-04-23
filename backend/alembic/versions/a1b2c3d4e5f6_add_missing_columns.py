"""add_missing_columns_to_financial_transactions

Revision ID: a1b2c3d4e5f6
Revises: e8d9f0a1b2c3
Create Date: 2026-04-20

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, Sequence[str], None] = 'e8d9f0a1b2c3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add missing columns and enum values."""

    # 1. Add ai_confidence to financial_transactions
    op.add_column('financial_transactions', sa.Column('ai_confidence', sa.Float(), nullable=True))

    # 2. Create operationcategory enum and add category to building_operations_log
    op.execute("CREATE TYPE operationcategory AS ENUM ('cleaning', 'repair', 'maintenance', 'inspection', 'other')")
    op.add_column('building_operations_log', sa.Column('category', sa.Enum('cleaning', 'repair', 'maintenance', 'inspection', 'other', name='operationcategory'), nullable=True))


def downgrade() -> None:
    """Revert changes."""
    op.drop_column('building_operations_log', 'category')
    op.execute("DROP TYPE operationcategory")
    op.drop_column('financial_transactions', 'ai_confidence')
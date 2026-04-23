"""fix_enum_and_column_sync

Revision ID: e8d9f0a1b2c3
Revises: 2026_04_16_001_enable_rls_multitenancy
Create Date: 2026-04-20

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e8d9f0a1b2c3'
down_revision: Union[str, Sequence[str], None] = 'rls_multitenancy_001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Sync PostgreSQL enums and add missing columns to match Python models."""

    # 1. Add missing values to unitstatus enum (vacant, occupied already exist)
    op.execute("ALTER TYPE unitstatus ADD VALUE IF NOT EXISTS 'rented'")
    op.execute("ALTER TYPE unitstatus ADD VALUE IF NOT EXISTS 'maintenance'")

    # 2. Add missing values to propertytype enum (building, single already exist)
    op.execute("ALTER TYPE propertytype ADD VALUE IF NOT EXISTS 'apartment_complex'")
    op.execute("ALTER TYPE propertytype ADD VALUE IF NOT EXISTS 'standalone_house'")
    op.execute("ALTER TYPE propertytype ADD VALUE IF NOT EXISTS 'land'")
    op.execute("ALTER TYPE propertytype ADD VALUE IF NOT EXISTS 'commercial'")

    # 3. Add custom_category column to financial_transactions (only if not exists)
    op.execute("""
        ALTER TABLE financial_transactions
        ADD COLUMN IF NOT EXISTS custom_category VARCHAR
    """)


def downgrade() -> None:
    """Revert changes."""
    op.drop_column('financial_transactions', 'custom_category')
    # Note: Cannot easily remove enum values in PostgreSQL without dropping the type entirely
    # This is a one-way sync for forward compatibility
"""add custom_category to financial_transactions

Revision ID: 4f5e6a7b8c9d
Revises: cc4d776d6197
Create Date: 2026-04-16

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '4f5e6a7b8c9d'
down_revision: Union[str, Sequence[str], None] = 'cc4d776d6197'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('financial_transactions', sa.Column('custom_category', sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column('financial_transactions', 'custom_category')

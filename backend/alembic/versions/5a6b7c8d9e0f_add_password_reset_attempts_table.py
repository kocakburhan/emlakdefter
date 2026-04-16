"""add password_reset_attempts table

Revision ID: 5a6b7c8d9e0f
Revises: 4f5e6a7b8c9d
Create Date: 2026-04-16

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '5a6b7c8d9e0f'
down_revision: Union[str, Sequence[str], None] = '4f5e6a7b8c9d'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'password_reset_attempts',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default='0'),
        sa.Column('deleted_at', sa.DateTime(), nullable=True),
        sa.Column('phone_number', sa.String(), nullable=False),
        sa.Column('attempted_at', sa.DateTime(), nullable=False),
        sa.Column('ip_address', sa.String(), nullable=True),
    )
    op.create_index('ix_password_reset_attempts_phone_number', 'password_reset_attempts', ['phone_number'])


def downgrade() -> None:
    op.drop_index('ix_password_reset_attempts_phone_number', 'password_reset_attempts')
    op.drop_table('password_reset_attempts')

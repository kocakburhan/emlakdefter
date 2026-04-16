"""add_firebase_uid_to_users

Revision ID: f0a1b2c3d4e5
Revises: a3f8c2b1d704
Create Date: 2026-04-14

"""
from alembic import op
import sqlalchemy as sa

revision = 'f0a1b2c3d4e5'
down_revision = 'a3f8c2b1d704'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'users',
        sa.Column('firebase_uid', sa.String(), nullable=True, unique=True, index=True)
    )
    # Mevcut kullanıcılar icin phone_number Firebase UID olarak gecici atama (test icin)
    # Gercek deploy'da bu satir comment veya kaldirilir
    # op.execute("UPDATE users SET firebase_uid = phone_number WHERE firebase_uid IS NULL")


def downgrade() -> None:
    op.drop_column('users', 'firebase_uid')

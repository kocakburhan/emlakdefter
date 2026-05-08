"""Add listing_type to properties and property_units

Revision ID: add_listing_type
Revises:
Create Date: 2026-05-09
"""
from alembic import op
import sqlalchemy as sa

revision = 'add_listing_type_001'
down_revision = '95ea7be4d184'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('properties', sa.Column('listing_type', sa.String(20), nullable=True))
    op.add_column('property_units', sa.Column('listing_type', sa.String(20), nullable=True))


def downgrade() -> None:
    op.drop_column('property_units', 'listing_type')
    op.drop_column('properties', 'listing_type')
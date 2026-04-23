"""Force Row Level Security for all RLS tables

Revision ID: force_rls_001
Revises: b1c2d3e4f5g6
Create Date: 2026-04-20

CRITICAL FIX: PostgreSQL'de tablo sahibi (owner), FORCE ROW LEVEL SECURITY
olmadan RLS'yi bypass eder. Bu migration, tüm RLS tablolarında
FORCE ROW LEVEL SECURITY'ı etkinleştirir.

Ayrıca PostgreSQL'de set_config() ile yapılan session ayarları,
psycopg2'nin autocommit=False modunda transaction içinde kaybolabilir.
Bu nedenle testlerde ve uygulamada SET komutu kullanılmalıdır:
    SET app.current_agency_id = 'uuid';
    RESET app.current_agency_id;

set_config() yerine SET komutu kullanılmalıdır çünkü:
1. SET komutu her zaman session seviyesinde çalışır
2. psycopg2 autocommit=False ile daha güvenilirdir
3. Transaction bağımsızdır
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers
revision = 'force_rls_001'
down_revision = 'b1c2d3e4f5g6'
branch_labels = None
depends_on = None


def upgrade() -> None:
    tables = [
        'agency_staff',
        'invitations',
        'properties',
        'property_units',
        'landlords_units',
        'tenants',
        'financial_transactions',
        'payment_schedules',
        'support_tickets',
        'building_operations_log',
        'chat_conversations',
        'user_device_tokens',
        'ticket_messages',
        'chat_messages',
    ]

    for table_name in tables:
        # FORCE ROW LEVEL SECURITY: Tablo sahibi dahil tüm kullanıcılar
        # için RLS'yi zorunlu kılar
        op.execute(f"ALTER TABLE {table_name} FORCE ROW LEVEL SECURITY;")


def downgrade() -> None:
    tables = [
        'agency_staff',
        'invitations',
        'properties',
        'property_units',
        'landlords_units',
        'tenants',
        'financial_transactions',
        'payment_schedules',
        'support_tickets',
        'building_operations_log',
        'chat_conversations',
        'user_device_tokens',
        'ticket_messages',
        'chat_messages',
    ]

    for table_name in tables:
        op.execute(f"ALTER TABLE {table_name} NO FORCE ROW LEVEL SECURITY;")

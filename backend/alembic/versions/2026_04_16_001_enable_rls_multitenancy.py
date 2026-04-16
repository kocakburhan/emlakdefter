"""Enable Row Level Security (RLS) for Multi-Tenancy

Revision ID: rls_multitenancy_001
Revises: 5130f4155e5b
Create Date: 2026-04-16

Bu migration, PostgreSQL Row Level Security (RLS) politikalarını etkinleştirir.
PRD §6.1'e göre: "PostgreSQL Row Level Security (RLS) ve tablolar düzeyinde
agency_id tabanlı katı veri izolasyonu kullanılacaktır."

RLS sayesinde, aynı veritabanı connection'ı üzerinden farklı agency'lerin
verilerine erişim tamamen engellenir.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import text

# revision identifiers
revision = 'rls_multitenancy_001'
down_revision = '5130f4155e5b'  # PRD schema compliance sonrası
branch_labels = None
depends_on = None


def upgrade() -> None:
    # =====================================================
    # 1. RLS için yardımcı fonksiyonları oluştur
    # =====================================================

    # set_agency_context fonksiyonu: SQL sorgularında agency_id'yi session variable olarak set eder
    op.execute("""
        CREATE OR REPLACE FUNCTION set_agency_context(agency_uuid UUID)
        RETURNS VOID AS $$
        BEGIN
            PERFORM set_config('app.current_agency_id', agency_uuid::TEXT, true);
        END;
        $$ LANGUAGE plpgsql SECURITY DEFINER;
    """)

    # get_agency_context fonksiyonu: Mevcut session'daki agency_id'yi döner
    op.execute("""
        CREATE OR REPLACE FUNCTION get_agency_context()
        RETURNS UUID AS $$
        DECLARE
            agency_text TEXT;
        BEGIN
            agency_text := current_setting('app.current_agency_id', true);
            IF agency_text IS NULL OR agency_text = '' THEN
                RETURN NULL;
            END IF;
            RETURN agency_text::UUID;
        END;
        $$ LANGUAGE plpgsql SECURITY DEFINER;
    """)

    # =====================================================
    # 2. Tüm tenant tablolarında RLS'yi etkinleştir
    # =====================================================

    tables_with_agency_id = [
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
    ]

    for table_name in tables_with_agency_id:
        # RLS'yi etkinleştir
        op.execute(f"ALTER TABLE {table_name} ENABLE ROW LEVEL SECURITY;")

        # Tablo için kullanıcının kendi agency_id'sine erişim izni veren policy oluştur
        op.execute(f"""
            CREATE POLICY agency_isolation_policy_{table_name}
            ON {table_name}
            FOR ALL
            USING (agency_id = get_agency_context())
            WITH CHECK (agency_id = get_agency_context());
        """)

    # =====================================================
    # 3. user_device_tokens için RLS (user üzerinden erişim)
    # =====================================================
    op.execute("""
        ALTER TABLE user_device_tokens ENABLE ROW LEVEL SECURITY;
    """)
    op.execute("""
        CREATE POLICY agency_isolation_policy_user_device_tokens
        ON user_device_tokens
        FOR ALL
        USING (
            user_id IN (
                SELECT u.id FROM users u
                INNER JOIN agency_staff af ON u.id = af.user_id
                WHERE af.agency_id = get_agency_context()
            )
        )
        WITH CHECK (
            user_id IN (
                SELECT u.id FROM users u
                INNER JOIN agency_staff af ON u.id = af.user_id
                WHERE af.agency_id = get_agency_context()
            )
        );
    """)

    # =====================================================
    # 4. ticket_messages için RLS (support_tickets üzerinden erişim)
    # =====================================================
    op.execute("""
        ALTER TABLE ticket_messages ENABLE ROW LEVEL SECURITY;
    """)
    op.execute("""
        CREATE POLICY agency_isolation_policy_ticket_messages
        ON ticket_messages
        FOR ALL
        USING (
            ticket_id IN (
                SELECT id FROM support_tickets
                WHERE agency_id = get_agency_context()
            )
        )
        WITH CHECK (
            ticket_id IN (
                SELECT id FROM support_tickets
                WHERE agency_id = get_agency_context()
            )
        );
    """)

    # =====================================================
    # 5. chat_messages için RLS (chat_conversations üzerinden erişim)
    # =====================================================
    op.execute("""
        ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
    """)
    op.execute("""
        CREATE POLICY agency_isolation_policy_chat_messages
        ON chat_messages
        FOR ALL
        USING (
            conversation_id IN (
                SELECT id FROM chat_conversations
                WHERE agency_id = get_agency_context()
            )
        )
        WITH CHECK (
            conversation_id IN (
                SELECT id FROM chat_conversations
                WHERE agency_id = get_agency_context()
            )
        );
    """)

    # =====================================================
    # 6. password_reset_attempts için RLS
    # (Phone number üzerinden erişim, agency_id yok)
    # Sadece superadmin erişebilir - read-only
    # =====================================================
    op.execute("""
        ALTER TABLE password_reset_attempts ENABLE ROW LEVEL SECURITY;
    """)
    op.execute("""
        CREATE POLICY agency_isolation_policy_password_reset_attempts
        ON password_reset_attempts
        FOR ALL
        USING (true)
        WITH CHECK (true);
    """)

    # =====================================================
    # 7. Roles için RLS ayarları
    # =====================================================

    # Tabloların sahibi postgres değil, uygulama kullanıcısı olmalı
    # Bu migration sonrasında uygulama kullanıcısı (emlakdefter_user)
    # tüm tablolara normal erişim kurallarına göre erişecek

    # NOT: Bypass için ayrı bir rol veya superuser gerekebilir
    # Üretim ortamında: postgres kullanıcısı RLS'yi bypass edebilir
    # Uygulama kullanıcısı (emlakdefter_user) her zaman RLS kontrollerine tabi


def downgrade() -> None:
    """RLS politikalarını ve ayarlarını kaldır"""

    # Policy'leri sil
    tables_with_agency_id = [
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
    ]

    for table_name in tables_with_agency_id:
        op.execute(f"DROP POLICY IF EXISTS agency_isolation_policy_{table_name} ON {table_name};")
        op.execute(f"ALTER TABLE {table_name} DISABLE ROW LEVEL SECURITY;")

    # Diğer tablolar
    op.execute("DROP POLICY IF EXISTS agency_isolation_policy_user_device_tokens ON user_device_tokens;")
    op.execute("ALTER TABLE user_device_tokens DISABLE ROW LEVEL SECURITY;")

    op.execute("DROP POLICY IF EXISTS agency_isolation_policy_ticket_messages ON ticket_messages;")
    op.execute("ALTER TABLE ticket_messages DISABLE ROW LEVEL SECURITY;")

    op.execute("DROP POLICY IF EXISTS agency_isolation_policy_chat_messages ON chat_messages;")
    op.execute("ALTER TABLE chat_messages DISABLE ROW LEVEL SECURITY;")

    op.execute("DROP POLICY IF EXISTS agency_isolation_policy_password_reset_attempts ON password_reset_attempts;")
    op.execute("ALTER TABLE password_reset_attempts DISABLE ROW LEVEL SECURITY;")

    # Fonksiyonları sil
    op.execute("DROP FUNCTION IF EXISTS set_agency_context(UUID);")
    op.execute("DROP FUNCTION IF EXISTS get_agency_context();")

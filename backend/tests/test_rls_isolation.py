"""
RLS (Row Level Security) İzolasyon Testi

Bu test, PostgreSQL Row Level Security politikalarının doğru çalıştığını doğrular.
Farklı agency_id'ye sahip ofislerin birbirlerinin verilerine erişemediğini test eder.

ÖNEMLI: PostgreSQL'de tablo sahibi (owner), FORCE ROW LEVEL SECURITY olmadan
RLS'yi bypass eder. Testlerin çalışması için tüm RLS tablolarında
FORCE ROW LEVEL SECURITY etkinleştirilmiş olmalıdır.

Test Senaryosu:
1. Agency A ve Agency B + mülkleri oluşturulur
2. RLS context'i Agency A olarak set edilir → sadece A'nın verisi görünür
3. RLS context'i Agency B olarak set edilir → sadece B'nin verisi görünür
4. RLS context'i temizlenir → veri görünmemeli (RLS aktif)
"""

import uuid
import pytest
import psycopg2
from psycopg2.extras import RealDictCursor


# Test DB config (Docker port mapping: 5433 external → 5432 internal)
DB_CONFIG = {
    "host": "127.0.0.1",
    "port": 5433,
    "database": "emlakdefter",
    "user": "emlakdefter_user",
    "password": "emlakdefter_password",
}

# Test agency IDs
AGENCY_A_ID = "11111111-1111-1111-1111-111111111111"
AGENCY_B_ID = "22222222-2222-2222-2222-222222222222"


def get_connection(autocommit=True):
    """Direct DB connection for RLS testing."""
    conn = psycopg2.connect(**DB_CONFIG)
    conn.set_session(autocommit=autocommit)
    return conn


def enable_force_rls(conn):
    """Enable FORCE ROW LEVEL SECURITY on all RLS tables."""
    tables = [
        'properties', 'property_units', 'tenants', 'financial_transactions',
        'payment_schedules', 'support_tickets', 'building_operations_log',
        'chat_conversations', 'chat_messages', 'agency_staff', 'invitations',
        'user_device_tokens', 'landlords_units'
    ]
    with conn.cursor() as cur:
        for table in tables:
            cur.execute(f"ALTER TABLE {table} FORCE ROW LEVEL SECURITY")


def disable_force_rls(conn):
    """Disable FORCE ROW LEVEL SECURITY on all RLS tables (for setup/cleanup)."""
    tables = [
        'properties', 'property_units', 'tenants', 'financial_transactions',
        'payment_schedules', 'support_tickets', 'building_operations_log',
        'chat_conversations', 'chat_messages', 'agency_staff', 'invitations',
        'user_device_tokens', 'landlords_units'
    ]
    with conn.cursor() as cur:
        for table in tables:
            cur.execute(f"ALTER TABLE {table} NO FORCE ROW LEVEL SECURITY")


def setup_test_data(conn):
    """Create test agencies and properties with RLS bypassed."""
    # Setup data WITH RLS bypassed (FORCE ROW LEVEL SECURITY disabled)
    disable_force_rls(conn)

    with conn.cursor() as cur:
        # Create Agency A
        cur.execute("""
            INSERT INTO agencies (id, name, subscription_status, created_at, updated_at, is_deleted)
            VALUES (%s, %s, 'active', NOW(), NOW(), false)
            ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name
        """, (AGENCY_A_ID, "Test Agency A - RLS Test"))

        # Create Agency B
        cur.execute("""
            INSERT INTO agencies (id, name, subscription_status, created_at, updated_at, is_deleted)
            VALUES (%s, %s, 'active', NOW(), NOW(), false)
            ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name
        """, (AGENCY_B_ID, "Test Agency B - RLS Test"))

        # Create property for Agency A (new UUID each time)
        prop_a_id = str(uuid.uuid4())
        cur.execute("""
            INSERT INTO properties (id, agency_id, name, type, address, total_units, created_at, updated_at, is_deleted)
            VALUES (%s, %s, %s, 'building', 'İstanbul A', 10, NOW(), NOW(), false)
            ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name
        """, (prop_a_id, AGENCY_A_ID, "Agency A Mülkü - RLS TEST"))

        # Create property for Agency B (new UUID each time)
        prop_b_id = str(uuid.uuid4())
        cur.execute("""
            INSERT INTO properties (id, agency_id, name, type, address, total_units, created_at, updated_at, is_deleted)
            VALUES (%s, %s, %s, 'building', 'Ankara B', 5, NOW(), NOW(), false)
            ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name
        """, (prop_b_id, AGENCY_B_ID, "Agency B Mülkü - RLS TEST"))

    # Re-enable FORCE ROW LEVEL SECURITY for tests
    enable_force_rls(conn)


def cleanup_test_data(conn):
    """Remove test agencies and their data (with RLS bypassed)."""
    disable_force_rls(conn)
    with conn.cursor() as cur:
        cur.execute("DELETE FROM properties WHERE agency_id = %s", (AGENCY_A_ID,))
        cur.execute("DELETE FROM properties WHERE agency_id = %s", (AGENCY_B_ID,))
        cur.execute("DELETE FROM agencies WHERE id = %s", (AGENCY_A_ID,))
        cur.execute("DELETE FROM agencies WHERE id = %s", (AGENCY_B_ID,))
    enable_force_rls(conn)


class TestRLSIsolation:
    """PostgreSQL RLS İzolasyon Testleri."""

    @pytest.fixture(autouse=True)
    def setup_and_teardown(self):
        """Her test öncesi veri oluştur, sonrası temizle."""
        conn = get_connection(autocommit=False)  # Normal mode for tests
        try:
            setup_test_data(conn)
            yield conn
        finally:
            cleanup_test_data(conn)
            conn.close()

    def test_rls_policy_exists(self, setup_and_teardown):
        """RLS politikalarının veritabanında tanımlı olduğunu doğrula."""
        conn = setup_and_teardown
        disable_force_rls(conn)  # Need RLS bypass to query pg_policies
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT tablename, policyname
                FROM pg_policies
                WHERE schemaname = 'public'
                  AND policyname LIKE 'agency_isolation%'
            """)
            policies = cur.fetchall()
        enable_force_rls(conn)

        policy_tables = {p["tablename"] for p in policies}
        expected_tables = {
            "agency_staff", "invitations",
            "properties", "property_units",
            "tenants", "financial_transactions",
            "payment_schedules", "support_tickets",
            "chat_conversations", "chat_messages",
            "building_operations_log", "user_device_tokens",
            "landlords_units"
        }

        missing = expected_tables - policy_tables
        assert not missing, f"RLS policy eksik tablolar: {missing}"
        print(f"✓ Tüm {len(policies)} RLS politikası mevcut")

    def test_rls_functions_exist(self, setup_and_teardown):
        """RLS context fonksiyonlarının veritabanında olduğunu doğrula."""
        conn = setup_and_teardown
        disable_force_rls(conn)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT proname, pronargs
                FROM pg_proc
                WHERE proname IN ('set_agency_context', 'get_agency_context')
            """)
            funcs = {r["proname"]: r["pronargs"] for r in cur.fetchall()}
        enable_force_rls(conn)

        assert "set_agency_context" in funcs
        assert "get_agency_context" in funcs
        print(f"✓ RLS fonksiyonları mevcut: {list(funcs.keys())}")

    def test_agency_a_isolation(self, setup_and_teardown):
        """Agency A context'inde iken sadece A'nın verileri görünür."""
        conn = setup_and_teardown
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Use SET for context (more reliable than set_config in transactions)
            cur.execute("SET app.current_agency_id = %s", (AGENCY_A_ID,))
            cur.execute("SELECT id, agency_id, name FROM properties")
            properties = cur.fetchall()

        agency_ids = {str(p["agency_id"]) for p in properties}
        assert AGENCY_A_ID in agency_ids, "Agency A verisi görünür olmalı"
        assert AGENCY_B_ID not in agency_ids, "Agency B verisi GÖRÜNÜR OLMAMALI (RLS ihlali!)"
        assert len(properties) >= 1, "Agency A'nın en az 1 mülkü olmalı"
        print(f"✓ Agency A izolasyonu doğru: {len(properties)} mülk görünür, Agency B'ninki yok")

    def test_agency_b_isolation(self, setup_and_teardown):
        """Agency B context'inde iken sadece B'nin verileri görünür."""
        conn = setup_and_teardown
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SET app.current_agency_id = %s", (AGENCY_B_ID,))
            cur.execute("SELECT id, agency_id, name FROM properties")
            properties = cur.fetchall()

        agency_ids = {str(p["agency_id"]) for p in properties}
        assert AGENCY_B_ID in agency_ids, "Agency B verisi görünür olmalı"
        assert AGENCY_A_ID not in agency_ids, "Agency A verisi GÖRÜNÜR OLMAMALI (RLS ihlali!)"
        assert len(properties) >= 1, "Agency B'nin en az 1 mülkü olmalı"
        print(f"✓ Agency B izolasyonu doğru: {len(properties)} mülk görünür, Agency A'nınki yok")

    def test_no_context_sees_nothing(self, setup_and_teardown):
        """RLS context set edilmeden sorgulama yapıldığında hiçbir şey görünmemeli."""
        conn = setup_and_teardown
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("RESET app.current_agency_id")
            cur.execute("SELECT id, agency_id, name FROM properties")
            properties = cur.fetchall()

        assert len(properties) == 0, \
            f"Context olmadan {len(properties)} mülk göründü — RLS çalışmıyor! Bu ciddi bir güvenlik açığı."
        print("✓ Context olmadan sorgu: 0 sonuç (RLS aktif)")

    def test_get_agency_context_returns_correct_value(self, setup_and_teardown):
        """get_agency_context() doğru agency_id döndürüyor."""
        conn = setup_and_teardown
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Set context to Agency A
            cur.execute("SET app.current_agency_id = %s", (AGENCY_A_ID,))
            cur.execute("SELECT get_agency_context() as ctx")
            result = cur.fetchone()
            assert result["ctx"] == AGENCY_A_ID

            # Change to Agency B
            cur.execute("SET app.current_agency_id = %s", (AGENCY_B_ID,))
            cur.execute("SELECT get_agency_context() as ctx")
            result = cur.fetchone()
            assert result["ctx"] == AGENCY_B_ID

            # Clear
            cur.execute("RESET app.current_agency_id")
            cur.execute("SELECT get_agency_context() as ctx")
            result = cur.fetchone()
            assert result["ctx"] is None

        print("✓ get_agency_context() doğru değerler döndürüyor")

    def test_rls_policy_covers_properties_table(self, setup_and_teardown):
        """properties tablosundaki RLS policy'si cross-agency görünümü engelliyor."""
        conn = setup_and_teardown
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Context A → should see 1 RLS TEST property (only Agency A's)
            cur.execute("SET app.current_agency_id = %s", (AGENCY_A_ID,))
            cur.execute("SELECT COUNT(*) as cnt FROM properties WHERE name LIKE '%RLS TEST'")
            count = cur.fetchone()["cnt"]
            assert count == 1, f"1 RLS TEST mülkü bekleniyordu (sadece Agency A), {count} bulundu"

            # Context B → should see 1 RLS TEST property (only Agency B's)
            cur.execute("SET app.current_agency_id = %s", (AGENCY_B_ID,))
            cur.execute("SELECT COUNT(*) as cnt FROM properties WHERE name LIKE '%RLS TEST'")
            count_b = cur.fetchone()["cnt"]
            assert count_b == 1, f"1 RLS TEST mülkü bekleniyordu (sadece Agency B), {count_b} bulundu"

            # Context B trying to see Agency A's property — should be 0
            cur.execute("SET app.current_agency_id = %s", (AGENCY_B_ID,))
            cur.execute("SELECT COUNT(*) as cnt FROM properties WHERE name LIKE '%Agency A%'")
            cross_count = cur.fetchone()["cnt"]
            assert cross_count == 0, \
                f"Agency B, Agency A'nın mülklerini görebiliyor! RLS ÇALIŞMIYOR! ({cross_count} mülk görünür)"

        print("✓ properties tablosu RLS ile tam izole — cross-agency görünüm engellendi")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])

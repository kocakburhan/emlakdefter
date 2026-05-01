"""Verify RLS isolation end-to-end."""
import psycopg2

conn = psycopg2.connect(
    host='127.0.0.1', port=5433, database='emlakdefter',
    user='emlakdefter_user', password='emlakdefter_password'
)
conn.autocommit = True
cur = conn.cursor()

AGENCY_A = '11111111-1111-1111-1111-111111111111'
AGENCY_B = '22222222-2222-2222-2222-222222222222'

# Phase 1: Verify role attributes
cur.execute('SELECT rolname, rolsuper, rolbypassrls FROM pg_roles WHERE rolname = current_user')
role = cur.fetchone()
print(f'Role: {role}')
assert role[2] == False, 'BYPASSRLS still True!'
assert role[1] == False, 'Still SUPERUSER!'

# Phase 2: Verify RLS isolation works — no context → 0 results
cur.execute('RESET app.current_agency_id')
cur.execute('SELECT count(*) FROM properties')
no_ctx = cur.fetchone()[0]
assert no_ctx == 0, f'No-context should return 0, got {no_ctx}'
print(f'[OK] No context: {no_ctx} rows')

# Context A → only Agency A data visible
cur.execute("SET app.current_agency_id = %s", (AGENCY_A,))
cur.execute("SELECT count(*) FROM properties WHERE agency_id::text = current_setting('app.current_agency_id', true)")
ctx_a = cur.fetchone()[0]
print(f'[OK] Context A: {ctx_a} rows visible')

# Context A → Agency B must be 0
cur.execute("SELECT count(*) FROM properties WHERE agency_id = %s", (AGENCY_B,))
cross = cur.fetchone()[0]
assert cross == 0, f'Agency B visible in A context! {cross} rows'
print(f'[OK] Cross-agency isolation: {cross} rows (must be 0)')

# Phase 3: Run the full RLS test suite
import subprocess, sys
result = subprocess.run([sys.executable, '-m', 'pytest', 'tests/test_rls_isolation.py', '-v', '-q'], capture_output=True, text=True)
print(f'RLS test suite: {result.stdout.split(chr(10))[-3]}')
assert result.returncode == 0, f'RLS tests failed: {result.stderr[-200:]}'

print('[PASS] RLS isolation verified end-to-end')
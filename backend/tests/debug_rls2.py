"""Test RLS with transaction control."""
import psycopg2

conn = psycopg2.connect(
    host='127.0.0.1', port=5433, database='emlakdefter',
    user='emlakdefter_user', password='emlakdefter_password'
)
conn.autocommit = True
cur = conn.cursor()

# Test 1: See ALL properties without any SET
cur.execute("RESET app.current_agency_id")
cur.execute("SELECT count(*) FROM properties")
print(f"All properties (no context): {cur.fetchone()[0]}")

# Test 2: With context A
cur.execute("SET app.current_agency_id = '11111111-1111-1111-1111-111111111111'")
cur.execute("SELECT count(*) FROM properties")
print(f"After SET to A: {cur.fetchone()[0]}")

# Test 3: Use current_setting directly in SQL
cur.execute("SET app.current_agency_id = '11111111-1111-1111-1111-111111111111'")
cur.execute("SELECT current_setting('app.current_agency_id', true)")
print(f"current_setting result: {cur.fetchone()[0]}")

# Test 4: Using search_path to see if app schema is relevant
cur.execute("SHOW search_path")
print(f"search_path: {cur.fetchone()[0]}")

# Test 5: Does a simple comparison work?
cur.execute("SET app.current_agency_id = '11111111-1111-1111-1111-111111111111'")
cur.execute("SELECT id FROM properties WHERE agency_id::text = current_setting('app.current_agency_id', true) LIMIT 3")
print(f"Direct comparison query: {cur.fetchall()}")

# Test 6: What does the RLS check actually see?
cur.execute("SET app.current_agency_id = '11111111-1111-1111-1111-111111111111'")
cur.execute("SELECT agency_id, get_agency_context() as ctx FROM properties LIMIT 3")
for r in cur.fetchall():
    print(f"agency_id={r[0]}, ctx={r[1]}, equal={r[0]==str(r[1])}")
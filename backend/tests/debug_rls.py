"""Test RLS isolation directly."""
import psycopg2

conn = psycopg2.connect(
    host='127.0.0.1', port=5433, database='emlakdefter',
    user='emlakdefter_user', password='emlakdefter_password'
)
conn.autocommit = True
cur = conn.cursor()

# Check RLS enforcement on the connection
cur.execute("SET app.current_agency_id = '11111111-1111-1111-1111-111111111111'")
cur.execute("SELECT id, agency_id FROM properties LIMIT 5")
rows = cur.fetchall()
print("After SET to Agency A:")
for r in rows:
    print(f"  id={r[0]}, agency_id={r[1]}")

agency_ids = {str(r[1]) for r in rows}
print(f"Agency IDs seen: {agency_ids}")
print(f"11111111 present: {'11111111-1111-1111-1111-111111111111' in agency_ids}")
print(f"22222222 present: {'22222222-2222-2222-2222-222222222222' in agency_ids}")
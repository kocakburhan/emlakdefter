# Database Migration & Backend Fix Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Get emlakdefter backend fully operational — fix database, migrations, and CORS configuration.

**Architecture:** Docker-based local dev stack with PostgreSQL 15, Redis 7, and FastAPI backend. Database initialized via docker-compose volumes and alembic migrations.

**Tech Stack:** Docker Compose, PostgreSQL 15, Alembic, FastAPI, Python 3.12

---

## Step 1: Clean up stale containers

**Files:**
- Modify: `docker-compose.dev.yml` (db-init.sh mount path)

- [ ] **Remove any existing emlakdefter containers and volumes**

```bash
docker-compose -f deploy/docker-compose.dev.yml down -v 2>/dev/null
docker container prune -f
```

- [ ] **Verify no emlakdefter containers remain**

```bash
docker ps -a --filter "name=emlakdefter"
```
Expected: Empty output

---

## Step 2: Fix db-init.sh script

**Problem:** Script tries to DROP role while connected as that role, and tries to create database from wrong user.

**Files:**
- Modify: `deploy/db-init.sh`

- [ ] **Step: Rewrite db-init.sh correctly**

The script should:
1. Connect as `postgres` (the default superuser in PostgreSQL docker image)
2. Create `emlakdefter_user` role first
3. Create `emlakdefter` database owned by `emlakdefter_user`
4. Grant privileges

```bash
cat > deploy/db-init.sh << 'EOF'
#!/bin/bash
set -e

echo "db-init: Starting emlakdefter database setup..."

# Connect as postgres default user to set up our user and database
psql -v ON_ERROR_STOP=1 -U postgres <<'EOSQL'
-- Create emlakdefter_user role
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'emlakdefter_user') THEN
        CREATE ROLE emlakdefter_user WITH LOGIN PASSWORD 'emlakdefter_password' NOSUPERUSER NOCREATEROLE NOCREATEDB;
        RAISE NOTICE 'emlakdefter_user created';
    ELSE
        RAISE NOTICE 'emlakdefter_user already exists';
    END IF;
END
$$;

-- Create emlakdefter database owned by emlakdefter_user
SELECT 'Creating emlakdefter database' AS status;
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'emlakdefter') THEN
        CREATE DATABASE emlakdefter OWNER emlakdefter_user;
        RAISE NOTICE 'emlakdefter database created';
    ELSE
        RAISE NOTICE 'emlakdefter database already exists';
    END IF;
END
$$;
EOSQL

echo "db-init: Database and user created successfully!"
EOF
```

- [ ] **Apply execute permission**

```bash
chmod +x deploy/db-init.sh
```

---

## Step 3: Start database container

- [ ] **Start db and redis containers**

```bash
docker-compose -f deploy/docker-compose.dev.yml up -d db redis
```

- [ ] **Wait for db to be healthy**

```bash
docker inspect emlakdefter_db --format '{{.State.Health.Status}}' 2>/dev/null || echo "No health check"
```
Expected: "healthy" after ~10s

---

## Step 4: Check migration state

- [ ] **Start backend container (will fail due to missing migrations, but we can exec into it)**

```bash
docker-compose -f deploy/docker-compose.dev.yml up -d backend
sleep 5
```

- [ ] **Check current database schema state**

```bash
docker exec emlakdefter_backend python -c "
import asyncio
from app.database import engine
import sqlalchemy as sa

async def check():
    async with engine.begin() as conn:
        # Check if users table exists and its role column type
        try:
            result = await conn.execute(sa.text(\"\"\"
                SELECT column_name, data_type, domain_name
                FROM information_schema.columns
                WHERE table_name = 'users' AND column_name = 'role'
            \"\"\"))
            row = result.fetchone()
            if row:
                print(f'users.role: {row}')
            else:
                print('users.role column not found')
        except Exception as e:
            print(f'Error: {e}')

        # Check enum types
        result = await conn.execute(sa.text(\"SELECT typname FROM pg_type WHERE typname IN ('userrole', 'globaluserrole')\"))
        print('Enum types:', [r[0] for r in result.fetchall()])

asyncio.run(check())
"
```

---

## Step 5: Determine migration status

**Files:**
- Check: `backend/alembic/versions/0b685e2d74a2_auto_fix_schema.py`

- [ ] **Check which migration is the current head**

```bash
docker exec emlakdefter_backend alembic heads 2>/dev/null || echo "Alembic not available"
```

- [ ] **Check if 0b685e2d74a2 migration is applied**

```bash
docker exec emlakdefter_backend alembic show 0b685e2d74a2 2>/dev/null || echo "Not applied"
```

---

## Step 6: Handle migration conflicts

**Problem:** The `0b685e2d74a2_auto_fix_schema.py` migration tries to:
1. `CREATE TYPE userrole` — this will FAIL if globaluserrole enum already exists
2. `ALTER TABLE users ALTER COLUMN role TYPE userrole USING role::text::userrole` — this will FAIL if column is currently `globaluserrole`

**Files:**
- Modify: `backend/alembic/versions/0b685e2d74a2_auto_fix_schema.py`

- [ ] **Fix migration script — handle enum properly**

The migration at line 85-86 needs to first DROP the old enum type if it exists, then create the new one:

```python
# Replace lines 85-86 with:
op.execute("DROP TYPE IF EXISTS userrole;")
op.execute("CREATE TYPE userrole AS ENUM ('superadmin', 'boss', 'employee', 'tenant', 'landlord');")
op.execute("ALTER TABLE users ALTER COLUMN role TYPE userrole USING role::text::userrole;")
```

---

## Step 7: Fix CORS Configuration

**Problem:** `allow_origins=["*"]` with `allow_credentials=True` is invalid.

**Files:**
- Modify: `backend/app/main.py:26-32`

- [ ] **Fix CORS to use explicit origins instead of wildcard when credentials are enabled**

```python
# Replace current CORS config:
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:5000",
        "http://localhost:8000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5000",
        "http://127.0.0.1:8000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

For development, if truly all origins needed:
```python
# If credentials not needed, can use wildcard:
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
# But for production with credentials, must list specific origins
```

---

## Step 8: Apply migrations

- [ ] **Run alembic upgrade**

```bash
docker exec emlakdefter_backend alembic upgrade head
```

- [ ] **Verify migrations applied**

```bash
docker exec emlakdefter_backend alembic current
```

---

## Step 9: Test backend

- [ ] **Test health endpoint**

```bash
curl -s http://127.0.0.1:8000/health
```

- [ ] **Test login endpoint**

```bash
curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email_or_phone": "test@test.com"}' \
  -w "\nHTTP_CODE:%{http_code}"
```

---

## Verification Checklist

- [ ] Docker containers running: `emlakdefter_db`, `emlakdefter_redis`, `emlakdefter_backend`
- [ ] Database schema matches models (check via SQL)
- [ ] All required tables exist: `users`, `agencies`, `properties`, `property_units`, `tenants`, `financial_transactions`, `payment_schedules`, `expenses`, `email_verification_codes`
- [ ] Backend health endpoint returns 200
- [ ] Login endpoint responds (even if user not found, should return proper JSON error, not 500)
- [ ] CORS headers present in OPTIONS response

---

## Files Summary

| File | Action |
|---|---|
| `deploy/db-init.sh` | Rewrite completely |
| `backend/app/main.py` | Fix CORS config |
| `backend/alembic/versions/0b685e2d74a2_auto_fix_schema.py` | Fix enum handling |
| `deploy/docker-compose.dev.yml` | No changes needed |
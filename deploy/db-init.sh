#!/bin/bash
# PostgreSQL initialization script
# Creates emlakdefter_user with correct (non-superuser, non-bypassrls) privileges
# and creates the emlakdefter database.
# Mount at /docker-entrypoint-initdb.d/ for automatic execution on first DB init.

set -e

echo "db-init: Starting emlakdefter database setup..."

psql -v ON_ERROR_STOP=1 -U postgres <<'EOSQL'
-- Create the emlakdefter database
SELECT 'Creating emlakdefter database' AS status;
CREATE DATABASE emlakdefter;
EOSQL

echo "db-init: Database created."

psql -v ON_ERROR_STOP=1 -U postgres -d emlakdefter <<'EOSQL'
-- Create emlakdefter_user WITHOUT superuser/bypassrls
SELECT 'Creating emlakdefter_user' AS status;
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'emlakdefter_user') THEN
        CREATE ROLE emlakdefter_user WITH LOGIN PASSWORD 'emlakdefter_password' NOSUPERUSER NOCREATEROLE NOCREATEDB;
        RAISE NOTICE 'emlakdefter_user created with correct attributes (NOSUPERUSER, NOBYPASSRLS)';
    ELSE
        ALTER ROLE emlakdefter_user NOSUPERUSER NOBYPASSRLS NOLOGIN;
        DROP ROLE emlakdefter_user;
        CREATE ROLE emlakdefter_user WITH LOGIN PASSWORD 'emlakdefter_password' NOSUPERUSER NOCREATEROLE NOCREATEDB;
        RAISE NOTICE 'emlakdefter_user recreated with correct attributes';
    END IF;
END
$$;

-- Grant database privileges
GRANT ALL PRIVILEGES ON DATABASE emlakdefter TO emlakdefter_user;

-- Grant schema privileges
GRANT ALL PRIVILEGES ON SCHEMA public TO emlakdefter_user;

-- Grant table/sequence privileges for existing objects
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO emlakdefter_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO emlakdefter_user;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO emlakdefter_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO emlakdefter_user;

-- Verify
SELECT rolname, rolsuper, rolbypassrls FROM pg_roles WHERE rolname = 'emlakdefter_user';
EOSQL

echo "db-init: emlakdefter_user configured successfully!"
echo "db-init: Done."

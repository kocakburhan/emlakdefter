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
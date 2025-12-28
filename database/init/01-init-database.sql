--------------------------------------------------------------------------------
-- PromptForge PostgreSQL Initialization Script
--------------------------------------------------------------------------------
--
-- This script initializes the PromptForge database with:
--   - Database creation
--   - User roles and permissions
--   - Extensions
--   - Performance optimizations
--
-- Usage:
--   psql -U postgres -f 01-init-database.sql
--
--------------------------------------------------------------------------------

-- Set client encoding
SET client_encoding = 'UTF8';

--------------------------------------------------------------------------------
-- Database Creation
--------------------------------------------------------------------------------

-- Create database if not exists
SELECT 'CREATE DATABASE promptforge_prod'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'promptforge_prod')\gexec

-- Connect to database
\c promptforge_prod

--------------------------------------------------------------------------------
-- Extensions
--------------------------------------------------------------------------------

-- UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Case-insensitive text matching
CREATE EXTENSION IF NOT EXISTS citext;

-- Cryptographic functions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Full-text search with language support
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Statistics and monitoring
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Additional useful extensions
CREATE EXTENSION IF NOT EXISTS btree_gin;
CREATE EXTENSION IF NOT EXISTS btree_gist;

\echo 'Extensions created successfully'

--------------------------------------------------------------------------------
-- User Roles
--------------------------------------------------------------------------------

-- Create application user
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'promptforge_app') THEN
        CREATE USER promptforge_app WITH PASSWORD 'CHANGE_THIS_PASSWORD';
    END IF;
END
$$;

-- Create read-only user for analytics/reporting
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'promptforge_readonly') THEN
        CREATE USER promptforge_readonly WITH PASSWORD 'CHANGE_THIS_READONLY_PASSWORD';
    END IF;
END
$$;

-- Create backup user
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'promptforge_backup') THEN
        CREATE USER promptforge_backup WITH PASSWORD 'CHANGE_THIS_BACKUP_PASSWORD';
    END IF;
END
$$;

\echo 'Users created successfully'

--------------------------------------------------------------------------------
-- Permissions
--------------------------------------------------------------------------------

-- Grant database privileges to application user
GRANT CONNECT ON DATABASE promptforge_prod TO promptforge_app;
GRANT USAGE ON SCHEMA public TO promptforge_app;
GRANT CREATE ON SCHEMA public TO promptforge_app;

-- Grant all privileges on all tables (current and future)
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO promptforge_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO promptforge_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO promptforge_app;

-- Read-only user permissions
GRANT CONNECT ON DATABASE promptforge_prod TO promptforge_readonly;
GRANT USAGE ON SCHEMA public TO promptforge_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO promptforge_readonly;

-- Backup user permissions
GRANT CONNECT ON DATABASE promptforge_prod TO promptforge_backup;
GRANT USAGE ON SCHEMA public TO promptforge_backup;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO promptforge_backup;

\echo 'Permissions configured successfully'

--------------------------------------------------------------------------------
-- Performance Configuration
--------------------------------------------------------------------------------

-- Set application name for connection tracking
ALTER DATABASE promptforge_prod SET application_name = 'promptforge';

-- Set statement timeout (30 seconds) to prevent long-running queries
ALTER DATABASE promptforge_prod SET statement_timeout = '30s';

-- Set idle in transaction timeout
ALTER DATABASE promptforge_prod SET idle_in_transaction_session_timeout = '60s';

-- Enable auto-explain for slow queries (adjust threshold as needed)
ALTER DATABASE promptforge_prod SET auto_explain.log_min_duration = '1000';
ALTER DATABASE promptforge_prod SET auto_explain.log_analyze = 'on';

-- Set default statistics target (affects query planning)
ALTER DATABASE promptforge_prod SET default_statistics_target = 100;

-- Set random page cost (adjust for SSD vs HDD)
-- SSD: 1.1, HDD: 4.0
ALTER DATABASE promptforge_prod SET random_page_cost = 1.1;

\echo 'Performance settings configured'

--------------------------------------------------------------------------------
-- Maintenance Configuration
--------------------------------------------------------------------------------

-- Configure autovacuum for better performance
ALTER DATABASE promptforge_prod SET autovacuum_vacuum_scale_factor = 0.1;
ALTER DATABASE promptforge_prod SET autovacuum_analyze_scale_factor = 0.05;

\echo 'Maintenance settings configured'

--------------------------------------------------------------------------------
-- Create Schemas for Organization
--------------------------------------------------------------------------------

-- Create schema for application data
CREATE SCHEMA IF NOT EXISTS app;
GRANT USAGE ON SCHEMA app TO promptforge_app;
GRANT CREATE ON SCHEMA app TO promptforge_app;
GRANT USAGE ON SCHEMA app TO promptforge_readonly;

-- Create schema for audit logs
CREATE SCHEMA IF NOT EXISTS audit;
GRANT USAGE ON SCHEMA audit TO promptforge_app;
GRANT CREATE ON SCHEMA audit TO promptforge_app;
GRANT USAGE ON SCHEMA audit TO promptforge_readonly;

\echo 'Schemas created successfully'

--------------------------------------------------------------------------------
-- Audit Logging Tables
--------------------------------------------------------------------------------

-- Create audit log table for tracking changes
CREATE TABLE IF NOT EXISTS audit.change_log (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id VARCHAR(100) NOT NULL,
    action VARCHAR(10) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data JSONB,
    new_data JSONB,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ip_address INET
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_change_log_table_name ON audit.change_log(table_name);
CREATE INDEX IF NOT EXISTS idx_change_log_record_id ON audit.change_log(record_id);
CREATE INDEX IF NOT EXISTS idx_change_log_changed_at ON audit.change_log(changed_at);

-- Create audit trigger function
CREATE OR REPLACE FUNCTION audit.log_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit.change_log (table_name, record_id, action, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.id::TEXT, 'INSERT', row_to_json(NEW), current_user);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit.change_log (table_name, record_id, action, old_data, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.id::TEXT, 'UPDATE', row_to_json(OLD), row_to_json(NEW), current_user);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit.change_log (table_name, record_id, action, old_data, changed_by)
        VALUES (TG_TABLE_NAME, OLD.id::TEXT, 'DELETE', row_to_json(OLD), current_user);
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

\echo 'Audit logging configured'

--------------------------------------------------------------------------------
-- Statistics and Monitoring
--------------------------------------------------------------------------------

-- Create view for monitoring table sizes
CREATE OR REPLACE VIEW audit.table_sizes AS
SELECT
    schemaname AS schema_name,
    tablename AS table_name,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS index_size,
    pg_total_relation_size(schemaname||'.'||tablename) AS total_bytes
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY total_bytes DESC;

-- Grant access to monitoring views
GRANT SELECT ON audit.table_sizes TO promptforge_app, promptforge_readonly;

\echo 'Monitoring views created'

--------------------------------------------------------------------------------
-- Connection Pool Configuration Table
--------------------------------------------------------------------------------

-- Create table to store connection pool settings
CREATE TABLE IF NOT EXISTS public.connection_pool_config (
    id SERIAL PRIMARY KEY,
    setting_name VARCHAR(100) UNIQUE NOT NULL,
    setting_value VARCHAR(255) NOT NULL,
    description TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Insert default connection pool settings
INSERT INTO public.connection_pool_config (setting_name, setting_value, description) VALUES
    ('min_pool_size', '5', 'Minimum number of connections in pool'),
    ('max_pool_size', '20', 'Maximum number of connections in pool'),
    ('pool_timeout', '30', 'Seconds to wait for connection from pool'),
    ('pool_recycle', '3600', 'Seconds before connection is recycled'),
    ('pool_pre_ping', 'true', 'Test connections before using')
ON CONFLICT (setting_name) DO NOTHING;

\echo 'Connection pool configuration created'

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

-- Function to get database size
CREATE OR REPLACE FUNCTION public.get_database_size()
RETURNS TEXT AS $$
BEGIN
    RETURN pg_size_pretty(pg_database_size(current_database()));
END;
$$ LANGUAGE plpgsql;

-- Function to get active connections count
CREATE OR REPLACE FUNCTION public.get_active_connections()
RETURNS TABLE(
    database_name TEXT,
    total_connections BIGINT,
    active_connections BIGINT,
    idle_connections BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        datname::TEXT,
        COUNT(*)::BIGINT AS total,
        COUNT(*) FILTER (WHERE state = 'active')::BIGINT AS active,
        COUNT(*) FILTER (WHERE state = 'idle')::BIGINT AS idle
    FROM pg_stat_activity
    WHERE datname = current_database()
    GROUP BY datname;
END;
$$ LANGUAGE plpgsql;

-- Function to terminate idle connections
CREATE OR REPLACE FUNCTION public.terminate_idle_connections(idle_minutes INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    terminated_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO terminated_count
    FROM pg_stat_activity
    WHERE datname = current_database()
        AND state = 'idle'
        AND state_change < NOW() - (idle_minutes || ' minutes')::INTERVAL
        AND pid <> pg_backend_pid();

    PERFORM pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname = current_database()
        AND state = 'idle'
        AND state_change < NOW() - (idle_minutes || ' minutes')::INTERVAL
        AND pid <> pg_backend_pid();

    RETURN terminated_count;
END;
$$ LANGUAGE plpgsql;

\echo 'Utility functions created'

--------------------------------------------------------------------------------
-- Security Hardening
--------------------------------------------------------------------------------

-- Revoke unnecessary permissions from public schema
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- Ensure proper ownership
ALTER DATABASE promptforge_prod OWNER TO postgres;
ALTER SCHEMA public OWNER TO postgres;
ALTER SCHEMA app OWNER TO postgres;
ALTER SCHEMA audit OWNER TO postgres;

\echo 'Security hardening applied'

--------------------------------------------------------------------------------
-- Completion
--------------------------------------------------------------------------------

\echo ''
\echo '=========================================='
\echo '  Database Initialization Complete!'
\echo '=========================================='
\echo ''
\echo 'Database: promptforge_prod'
\echo 'Users created:'
\echo '  - promptforge_app (application user)'
\echo '  - promptforge_readonly (read-only user)'
\echo '  - promptforge_backup (backup user)'
\echo ''
\echo 'IMPORTANT: Change default passwords!'
\echo '  ALTER USER promptforge_app WITH PASSWORD ''new_password'';'
\echo '  ALTER USER promptforge_readonly WITH PASSWORD ''new_password'';'
\echo '  ALTER USER promptforge_backup WITH PASSWORD ''new_password'';'
\echo ''
\echo 'Next steps:'
\echo '  1. Update passwords for all users'
\echo '  2. Configure pg_hba.conf for access control'
\echo '  3. Update postgresql.conf with optimizations'
\echo '  4. Run Alembic migrations'
\echo '  5. Configure backups'
\echo ''

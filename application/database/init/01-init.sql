-- DevOps Dashboard Database Initialization
-- This script sets up the initial database structure and basic data

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Create schemas for better organization
CREATE SCHEMA IF NOT EXISTS dashboard;
CREATE SCHEMA IF NOT EXISTS monitoring;

-- Grant permissions to application user
GRANT USAGE ON SCHEMA dashboard TO devops_user;
GRANT USAGE ON SCHEMA monitoring TO devops_user;
GRANT CREATE ON SCHEMA dashboard TO devops_user;
GRANT CREATE ON SCHEMA monitoring TO devops_user;

-- Set default search path
ALTER USER devops_user SET search_path = dashboard, monitoring, public;

-- Create a health check table for monitoring
CREATE TABLE IF NOT EXISTS monitoring.health_status (
    id SERIAL PRIMARY KEY,
    service_name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'unknown',
    last_check TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    details JSONB,
    UNIQUE(service_name)
);

-- Insert initial health check records
INSERT INTO monitoring.health_status (service_name, status, details) VALUES
    ('database', 'healthy', '{"message": "Database initialization completed"}'),
    ('api', 'starting', '{"message": "API service starting"}'),
    ('frontend', 'starting', '{"message": "Frontend service starting"}')
ON CONFLICT (service_name) DO NOTHING;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_health_status_service ON monitoring.health_status(service_name);
CREATE INDEX IF NOT EXISTS idx_health_status_check_time ON monitoring.health_status(last_check);

-- Log initialization
DO $$
BEGIN
    RAISE NOTICE 'DevOps Dashboard database initialized successfully';
    RAISE NOTICE 'Database: %', current_database();
    RAISE NOTICE 'User: %', current_user;
    RAISE NOTICE 'Timestamp: %', now();
END $$; 
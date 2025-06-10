-- PostgreSQL RDS Initialization Script for Notes App
-- Run this script on your PostgreSQL RDS instance using DBeaver or psql client

-- Create database (if not already created during RDS setup)
-- Note: If you need to create the database, connect as the master user first
-- CREATE DATABASE notes_db;

-- Connect to the notes_db database
\c notes_db;

-- Create notes table
CREATE TABLE IF NOT EXISTS notes (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    database_type VARCHAR(50) DEFAULT 'postgres'
);

-- Create update trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop existing trigger if it exists and create new one
DROP TRIGGER IF EXISTS update_notes_updated_at ON notes;
CREATE TRIGGER update_notes_updated_at 
    BEFORE UPDATE ON notes 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_notes_created_at ON notes(created_at);
CREATE INDEX IF NOT EXISTS idx_notes_database_type ON notes(database_type);

-- Insert sample data for demonstration
INSERT INTO notes (title, content, database_type) VALUES
('Welcome to PostgreSQL RDS', 'This is your first note stored in PostgreSQL RDS! Advanced relational database features are now available in the cloud.', 'postgres'),
('PostgreSQL RDS Features', 'AWS RDS PostgreSQL provides advanced features like JSON support, full-text search, and ACID compliance.', 'postgres'),
('High Availability', 'This PostgreSQL RDS instance can be configured with Multi-AZ deployments for high availability and automatic failover.', 'postgres'),
('Performance Insights', 'AWS RDS Performance Insights helps you monitor and optimize your PostgreSQL database performance.', 'postgres'),
('Scalability', 'PostgreSQL RDS supports read replicas and can scale both vertically and horizontally as needed.', 'postgres'),
('BI Integration', 'This database is ready for integration with Business Intelligence tools like Metabase or Redash.', 'postgres');

-- Show table structure
\d notes;

-- Show inserted data
SELECT 
    id,
    title,
    SUBSTRING(content, 1, 50) as content_preview,
    database_type,
    created_at
FROM notes 
ORDER BY created_at DESC;

-- Show count
SELECT COUNT(*) as total_postgres_notes FROM notes;

-- Success message
SELECT 'PostgreSQL RDS database initialized successfully for Notes App!' as status;

-- Show database information
SELECT 
    current_database() as database_name,
    current_user as current_user,
    version() as postgres_version;

-- Optional: Create additional user for application (if not using master credentials)
-- CREATE USER notes_user WITH PASSWORD 'your-secure-password';
-- GRANT CONNECT ON DATABASE notes_db TO notes_user;
-- GRANT USAGE ON SCHEMA public TO notes_user;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO notes_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO notes_user; 
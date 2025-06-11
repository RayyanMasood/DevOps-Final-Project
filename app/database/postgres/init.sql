-- PostgreSQL Initialization Script for Notes App

-- Create database (this will be handled by Docker environment variables)
-- The database creation is managed by the postgres Docker image

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

-- Insert sample data
INSERT INTO notes (title, content, database_type) VALUES
('Welcome to PostgreSQL', 'This is your first note stored in PostgreSQL! Advanced relational database features available.', 'postgres'),
('PostgreSQL Sample Note', 'This note demonstrates PostgreSQL storage capabilities with ACID compliance.', 'postgres'),
('Database Comparison', 'You can compare how the same app works with both MySQL and PostgreSQL backends!', 'postgres');

-- Show inserted data
SELECT COUNT(*) as total_notes FROM notes;

-- Success message
SELECT 'PostgreSQL database initialized successfully!' as message; 
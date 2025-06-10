-- MySQL Initialization Script for Notes App

-- Create database if it doesn't exist
CREATE DATABASE IF NOT EXISTS notes_db;
USE notes_db;

-- Create notes table
CREATE TABLE IF NOT EXISTS notes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    database_type VARCHAR(50) DEFAULT 'mysql'
);

-- Create index for better performance
CREATE INDEX idx_notes_created_at ON notes(created_at);
CREATE INDEX idx_notes_database_type ON notes(database_type);

-- Insert sample data
INSERT INTO notes (title, content, database_type) VALUES
('Welcome to Notes App', 'This is your first note stored in MySQL! You can create, edit, and delete notes.', 'mysql'),
('MySQL Sample Note', 'This note demonstrates MySQL storage capabilities. Feel free to edit or delete it.', 'mysql'),
('Getting Started', 'Use the form on the left to create new notes. Choose which database to save to!', 'mysql');

-- Show table structure
DESCRIBE notes;

-- Show inserted data
SELECT COUNT(*) as total_notes FROM notes;

-- Success message
SELECT 'MySQL database initialized successfully!' as message; 
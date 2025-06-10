-- MySQL RDS Initialization Script for Notes App
-- Run this script on your MySQL RDS instance using DBeaver or mysql client

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

-- Create indexes for better performance
CREATE INDEX idx_notes_created_at ON notes(created_at);
CREATE INDEX idx_notes_database_type ON notes(database_type);

-- Insert sample data for demonstration
INSERT INTO notes (title, content, database_type) VALUES
('Welcome to Notes App - MySQL RDS', 'This is your first note stored in MySQL RDS! The application is now connected to AWS managed databases.', 'mysql'),
('MySQL RDS Performance', 'AWS RDS provides automated backups, high availability, and scalable performance for MySQL databases.', 'mysql'),
('Production Ready', 'This note demonstrates that your application is successfully connected to production RDS infrastructure.', 'mysql'),
('Database Management', 'You can manage this RDS instance through AWS Console, DBeaver, or MySQL Workbench via SSH tunnel.', 'mysql'),
('Auto Scaling Ready', 'Your application is now ready to be deployed across multiple EC2 instances with Auto Scaling.', 'mysql');

-- Show table structure
DESCRIBE notes;

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
SELECT COUNT(*) as total_mysql_notes FROM notes;

-- Success message
SELECT 'MySQL RDS database initialized successfully for Notes App!' as status;

-- Optional: Create additional user for application (if not using master credentials)
-- CREATE USER 'notes_user'@'%' IDENTIFIED BY 'your-secure-password';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON notes_db.* TO 'notes_user'@'%';
-- FLUSH PRIVILEGES; 
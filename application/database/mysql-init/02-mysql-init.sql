-- MySQL Database Initialization Script for DevOps Dashboard
-- This script creates the necessary database structure and sample data

-- Create database (already done by Docker environment variables)
-- CREATE DATABASE IF NOT EXISTS devops_dashboard CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE devops_dashboard;

-- Enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

-- Create sample users table for testing
CREATE TABLE IF NOT EXISTS users_mysql (
    id VARCHAR(255) PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    role ENUM('ADMIN', 'USER', 'VIEWER') DEFAULT 'USER',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create sample metrics table for testing
CREATE TABLE IF NOT EXISTS metrics_mysql (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    value DECIMAL(10,2) NOT NULL,
    unit VARCHAR(50),
    category ENUM('SYSTEM', 'APPLICATION', 'BUSINESS') DEFAULT 'SYSTEM',
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata JSON
);

-- Create notes table for testing
CREATE TABLE IF NOT EXISTS notes_mysql (
    id VARCHAR(255) PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    tags JSON,
    is_public BOOLEAN DEFAULT FALSE,
    user_id VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_notes_mysql_user_id (user_id),
    INDEX idx_notes_mysql_created_at (created_at)
);

-- Insert sample data
INSERT IGNORE INTO users_mysql (id, email, username, password, first_name, last_name, role) VALUES
('mysql-1', 'admin@devops.local', 'admin_mysql', 'hashed_password_here', 'MySQL', 'Admin', 'ADMIN'),
('mysql-2', 'user@devops.local', 'user_mysql', 'hashed_password_here', 'MySQL', 'User', 'USER'),
('mysql-3', 'viewer@devops.local', 'viewer_mysql', 'hashed_password_here', 'MySQL', 'Viewer', 'VIEWER');

-- Insert sample metrics
INSERT IGNORE INTO metrics_mysql (id, name, value, unit, category, metadata) VALUES
('metric-mysql-1', 'CPU Usage', 75.5, '%', 'SYSTEM', '{"server": "mysql-server-1"}'),
('metric-mysql-2', 'Memory Usage', 82.3, '%', 'SYSTEM', '{"server": "mysql-server-1"}'),
('metric-mysql-3', 'Active Connections', 45, 'count', 'APPLICATION', '{"database": "mysql"}'),
('metric-mysql-4', 'Query Response Time', 123.45, 'ms', 'APPLICATION', '{"database": "mysql"}');

-- Insert sample notes
INSERT IGNORE INTO notes_mysql (id, title, content, tags, is_public, user_id) VALUES
('note-mysql-1', 'Welcome to MySQL Notes', 'This is a sample note stored in MySQL database. You can create, edit, and delete notes from here.', '["mysql", "database", "notes"]', TRUE, 'mysql-1'),
('note-mysql-2', 'Database Performance Tips', 'Tips for optimizing MySQL performance:\n1. Use proper indexing\n2. Optimize queries\n3. Monitor slow queries', '["mysql", "performance", "tips"]', TRUE, 'mysql-1'),
('note-mysql-3', 'Private Note', 'This is a private note visible only to the owner.', '["private", "personal"]', FALSE, 'mysql-2');

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_mysql_email ON users_mysql(email);
CREATE INDEX IF NOT EXISTS idx_users_mysql_username ON users_mysql(username);
CREATE INDEX IF NOT EXISTS idx_metrics_mysql_name ON metrics_mysql(name);
CREATE INDEX IF NOT EXISTS idx_metrics_mysql_timestamp ON metrics_mysql(timestamp);

-- Display initialization status
SELECT 'MySQL DevOps Dashboard database initialized successfully!' as status;
SELECT 'Database: devops_dashboard' as database_info;
SELECT 'User: devops_user' as user_info;
SELECT NOW() as timestamp; 
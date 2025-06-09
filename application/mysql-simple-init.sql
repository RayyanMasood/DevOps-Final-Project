-- Simple MySQL initialization for notes demo

-- Create users table
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

-- Create notes table
CREATE TABLE IF NOT EXISTS notes_mysql (
    id VARCHAR(255) PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    tags JSON,
    is_public BOOLEAN DEFAULT FALSE,
    user_id VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Insert sample users
INSERT IGNORE INTO users_mysql (id, email, username, password, first_name, last_name, role) VALUES
('mysql-1', 'admin@mysql.local', 'admin_mysql', 'hashed_password_here', 'MySQL', 'Admin', 'ADMIN'),
('mysql-2', 'user@mysql.local', 'user_mysql', 'hashed_password_here', 'MySQL', 'User', 'USER');

-- Insert sample notes
INSERT IGNORE INTO notes_mysql (id, title, content, tags, is_public, user_id) VALUES
('note-mysql-1', 'Welcome to MySQL Notes', 'This is a sample note stored in MySQL database. You can create, edit, and delete notes from here.', '[\"mysql\", \"database\", \"notes\"]', TRUE, 'mysql-1'),
('note-mysql-2', 'MySQL Performance Tips', 'Tips for optimizing MySQL performance: Use proper indexing, Optimize queries, Monitor slow queries', '[\"mysql\", \"performance\", \"tips\"]', TRUE, 'mysql-1');

-- Show tables
SHOW TABLES; 
-- MySQL Database Initialization Script
-- Creates tables for the main application data

USE devops_app;

-- Users table
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_created_at (created_at),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Products table
CREATE TABLE products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    category VARCHAR(100),
    sku VARCHAR(100) UNIQUE,
    stock_quantity INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_name (name),
    INDEX idx_category (category),
    INDEX idx_sku (sku),
    INDEX idx_is_active (is_active),
    INDEX idx_price (price),
    INDEX idx_stock_quantity (stock_quantity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Orders table
CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled') DEFAULT 'pending',
    total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    shipping_address TEXT,
    billing_address TEXT,
    payment_method VARCHAR(50),
    payment_status ENUM('pending', 'completed', 'failed', 'refunded') DEFAULT 'pending',
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    shipped_date TIMESTAMP NULL,
    delivered_date TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_order_number (order_number),
    INDEX idx_status (status),
    INDEX idx_payment_status (payment_status),
    INDEX idx_order_date (order_date),
    INDEX idx_total_amount (total_amount)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Order Items table
CREATE TABLE order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    unit_price DECIMAL(10, 2) NOT NULL,
    total_price DECIMAL(10, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    INDEX idx_order_id (order_id),
    INDEX idx_product_id (product_id),
    UNIQUE KEY unique_order_product (order_id, product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- User Sessions table (for authentication)
CREATE TABLE user_sessions (
    id VARCHAR(128) PRIMARY KEY,
    user_id INT,
    session_data JSON,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- User Activity Log table
CREATE TABLE user_activity_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id INT,
    details JSON,
    ip_address INET6,
    user_agent TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_action (action),
    INDEX idx_entity (entity_type, entity_id),
    INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Inventory Movements table
CREATE TABLE inventory_movements (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    movement_type ENUM('in', 'out', 'adjustment') NOT NULL,
    quantity INT NOT NULL,
    reference_type VARCHAR(50), -- 'order', 'return', 'adjustment', etc.
    reference_id INT,
    notes TEXT,
    user_id INT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_product_id (product_id),
    INDEX idx_movement_type (movement_type),
    INDEX idx_reference (reference_type, reference_id),
    INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Customer Reviews table
CREATE TABLE customer_reviews (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    order_id INT,
    rating TINYINT CHECK (rating >= 1 AND rating <= 5),
    title VARCHAR(200),
    review_text TEXT,
    is_verified BOOLEAN DEFAULT false,
    helpful_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_product_id (product_id),
    INDEX idx_rating (rating),
    INDEX idx_created_at (created_at),
    UNIQUE KEY unique_user_product_order (user_id, product_id, order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- System Configuration table
CREATE TABLE system_config (
    id INT AUTO_INCREMENT PRIMARY KEY,
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value JSON,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_config_key (config_key),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create database views for common queries
CREATE VIEW order_summary AS
SELECT 
    o.id,
    o.order_number,
    o.status,
    o.total_amount,
    o.order_date,
    u.username,
    u.email,
    COUNT(oi.id) as item_count
FROM orders o
LEFT JOIN users u ON o.user_id = u.id
LEFT JOIN order_items oi ON o.id = oi.order_id
GROUP BY o.id;

CREATE VIEW product_summary AS
SELECT 
    p.id,
    p.name,
    p.category,
    p.price,
    p.stock_quantity,
    p.is_active,
    COUNT(oi.id) as order_count,
    SUM(oi.quantity) as total_sold,
    AVG(cr.rating) as avg_rating,
    COUNT(cr.id) as review_count
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
LEFT JOIN customer_reviews cr ON p.id = cr.product_id
GROUP BY p.id;

CREATE VIEW user_summary AS
SELECT 
    u.id,
    u.username,
    u.email,
    u.is_active,
    u.created_at,
    u.last_login,
    COUNT(DISTINCT o.id) as order_count,
    SUM(o.total_amount) as total_spent,
    COUNT(DISTINCT cr.id) as review_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
LEFT JOIN customer_reviews cr ON u.id = cr.user_id
GROUP BY u.id;

-- Create stored procedures for common operations
DELIMITER //

CREATE PROCEDURE UpdateProductStock(
    IN p_product_id INT,
    IN p_quantity_change INT,
    IN p_movement_type ENUM('in', 'out', 'adjustment'),
    IN p_reference_type VARCHAR(50),
    IN p_reference_id INT,
    IN p_user_id INT
)
BEGIN
    DECLARE current_stock INT DEFAULT 0;
    
    START TRANSACTION;
    
    -- Get current stock
    SELECT stock_quantity INTO current_stock 
    FROM products 
    WHERE id = p_product_id 
    FOR UPDATE;
    
    -- Update product stock
    UPDATE products 
    SET stock_quantity = stock_quantity + p_quantity_change,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_product_id;
    
    -- Log inventory movement
    INSERT INTO inventory_movements (
        product_id, movement_type, quantity, 
        reference_type, reference_id, user_id
    ) VALUES (
        p_product_id, p_movement_type, ABS(p_quantity_change),
        p_reference_type, p_reference_id, p_user_id
    );
    
    COMMIT;
END //

CREATE PROCEDURE GetDashboardStats(
    IN start_date DATE,
    IN end_date DATE
)
BEGIN
    -- Get comprehensive dashboard statistics
    SELECT 
        'orders' as metric_type,
        COUNT(*) as total_count,
        SUM(total_amount) as total_value,
        AVG(total_amount) as average_value,
        COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_count
    FROM orders 
    WHERE DATE(order_date) BETWEEN start_date AND end_date
    
    UNION ALL
    
    SELECT 
        'users' as metric_type,
        COUNT(*) as total_count,
        0 as total_value,
        0 as average_value,
        COUNT(CASE WHEN is_active = 1 THEN 1 END) as completed_count
    FROM users 
    WHERE DATE(created_at) BETWEEN start_date AND end_date
    
    UNION ALL
    
    SELECT 
        'products' as metric_type,
        COUNT(*) as total_count,
        SUM(price * stock_quantity) as total_value,
        AVG(price) as average_value,
        COUNT(CASE WHEN is_active = 1 THEN 1 END) as completed_count
    FROM products;
END //

DELIMITER ;

-- Insert system configuration defaults
INSERT INTO system_config (config_key, config_value, description) VALUES
('site_name', '"DevOps Dashboard"', 'Application name'),
('maintenance_mode', 'false', 'Enable/disable maintenance mode'),
('max_order_items', '50', 'Maximum items per order'),
('low_stock_threshold', '10', 'Threshold for low stock alerts'),
('session_timeout', '3600', 'Session timeout in seconds'),
('email_notifications', 'true', 'Enable email notifications'),
('analytics_enabled', 'true', 'Enable analytics tracking'),
('api_rate_limit', '100', 'API requests per minute per user');

-- Create triggers for automatic logging
DELIMITER //

CREATE TRIGGER user_activity_after_insert
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    INSERT INTO user_activity_log (user_id, action, entity_type, entity_id, timestamp)
    VALUES (NEW.id, 'create', 'user', NEW.id, NOW());
END //

CREATE TRIGGER user_activity_after_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    INSERT INTO user_activity_log (user_id, action, entity_type, entity_id, timestamp)
    VALUES (NEW.id, 'update', 'user', NEW.id, NOW());
END //

CREATE TRIGGER order_activity_after_insert
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    INSERT INTO user_activity_log (user_id, action, entity_type, entity_id, timestamp)
    VALUES (NEW.user_id, 'create', 'order', NEW.id, NOW());
END //

CREATE TRIGGER order_activity_after_update
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    INSERT INTO user_activity_log (user_id, action, entity_type, entity_id, timestamp)
    VALUES (NEW.user_id, 'update', 'order', NEW.id, NOW());
END //

DELIMITER ;

-- Create indexes for performance optimization
CREATE INDEX idx_orders_user_date ON orders(user_id, order_date);
CREATE INDEX idx_orders_status_date ON orders(status, order_date);
CREATE INDEX idx_user_activity_user_timestamp ON user_activity_log(user_id, timestamp);
CREATE INDEX idx_inventory_product_timestamp ON inventory_movements(product_id, timestamp);

COMMIT;

-- Database Initialization Script with Sample Data
-- This script creates tables and populates them with dummy data for demonstration

-- ===========================================
-- MySQL Sample Data
-- ===========================================

-- Create products table
CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INT NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create customers table
CREATE TABLE IF NOT EXISTS customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(50),
    country VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATE NOT NULL,
    total_amount DECIMAL(12,2) NOT NULL,
    status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);

-- Create order_items table
CREATE TABLE IF NOT EXISTS order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

-- Insert sample products
INSERT IGNORE INTO products (name, category, price, stock_quantity, description) VALUES
('Laptop Pro', 'Electronics', 1299.99, 50, 'High-performance laptop for professionals'),
('Wireless Mouse', 'Electronics', 29.99, 200, 'Ergonomic wireless mouse with USB receiver'),
('Office Chair', 'Furniture', 199.99, 30, 'Comfortable ergonomic office chair'),
('Desk Lamp', 'Furniture', 79.99, 75, 'LED desk lamp with adjustable brightness'),
('Coffee Mug', 'Kitchen', 12.99, 150, 'Ceramic coffee mug with company logo'),
('Notebook Set', 'Stationery', 24.99, 100, 'Set of 3 professional notebooks'),
('USB Cable', 'Electronics', 9.99, 300, 'High-speed USB-C cable'),
('Monitor Stand', 'Furniture', 89.99, 40, 'Adjustable monitor stand with storage'),
('Keyboard', 'Electronics', 149.99, 80, 'Mechanical keyboard with RGB lighting'),
('Water Bottle', 'Kitchen', 19.99, 120, 'Stainless steel insulated water bottle');

-- Insert sample customers
INSERT IGNORE INTO customers (first_name, last_name, email, phone, address, city, country) VALUES
('John', 'Doe', 'john.doe@email.com', '+1-555-0101', '123 Main St', 'New York', 'USA'),
('Jane', 'Smith', 'jane.smith@email.com', '+1-555-0102', '456 Oak Ave', 'Los Angeles', 'USA'),
('Michael', 'Johnson', 'michael.j@email.com', '+1-555-0103', '789 Pine Rd', 'Chicago', 'USA'),
('Emily', 'Brown', 'emily.brown@email.com', '+1-555-0104', '321 Elm St', 'Houston', 'USA'),
('David', 'Wilson', 'david.wilson@email.com', '+1-555-0105', '654 Maple Dr', 'Phoenix', 'USA'),
('Sarah', 'Miller', 'sarah.miller@email.com', '+1-555-0106', '987 Cedar Ln', 'Philadelphia', 'USA'),
('Robert', 'Davis', 'robert.davis@email.com', '+1-555-0107', '147 Birch Way', 'San Antonio', 'USA'),
('Lisa', 'Garcia', 'lisa.garcia@email.com', '+1-555-0108', '258 Spruce St', 'San Diego', 'USA'),
('James', 'Rodriguez', 'james.r@email.com', '+1-555-0109', '369 Willow Ave', 'Dallas', 'USA'),
('Maria', 'Martinez', 'maria.martinez@email.com', '+1-555-0110', '741 Poplar Rd', 'San Jose', 'USA');

-- Insert sample orders
INSERT IGNORE INTO orders (customer_id, order_date, total_amount, status) VALUES
(1, '2024-01-15', 1329.98, 'delivered'),
(2, '2024-01-16', 229.98, 'delivered'),
(3, '2024-01-17', 89.99, 'shipped'),
(4, '2024-01-18', 42.98, 'delivered'),
(5, '2024-01-19', 1449.98, 'processing'),
(6, '2024-01-20', 104.98, 'pending'),
(7, '2024-01-21', 179.98, 'shipped'),
(8, '2024-01-22', 32.98, 'delivered'),
(9, '2024-01-23', 259.98, 'processing'),
(10, '2024-01-24', 69.98, 'pending');

-- Insert sample order items
INSERT IGNORE INTO order_items (order_id, product_id, quantity, unit_price, subtotal) VALUES
(1, 1, 1, 1299.99, 1299.99), (1, 2, 1, 29.99, 29.99),
(2, 3, 1, 199.99, 199.99), (2, 2, 1, 29.99, 29.99),
(3, 8, 1, 89.99, 89.99),
(4, 5, 2, 12.99, 25.98), (4, 6, 1, 24.99, 24.99),
(5, 1, 1, 1299.99, 1299.99), (5, 9, 1, 149.99, 149.99),
(6, 4, 1, 79.99, 79.99), (6, 6, 1, 24.99, 24.99),
(7, 3, 1, 199.99, 199.99), (7, 2, 1, 29.99, 29.99),
(8, 5, 1, 12.99, 12.99), (8, 10, 1, 19.99, 19.99),
(9, 9, 1, 149.99, 149.99), (9, 8, 1, 89.99, 89.99), (9, 10, 1, 19.99, 19.99),
(10, 4, 1, 79.99, 79.99), (10, 7, 1, 9.99, 9.99);

-- Create view for order analytics
CREATE OR REPLACE VIEW order_analytics AS
SELECT 
    DATE(o.order_date) as date,
    COUNT(o.id) as total_orders,
    SUM(o.total_amount) as daily_revenue,
    AVG(o.total_amount) as avg_order_value,
    o.status,
    c.country
FROM orders o
JOIN customers c ON o.customer_id = c.id
GROUP BY DATE(o.order_date), o.status, c.country
ORDER BY o.order_date DESC;

-- Create sample user activity table for real-time updates demo
CREATE TABLE IF NOT EXISTS user_activity (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    user_agent TEXT,
    session_id VARCHAR(100),
    page_url VARCHAR(255)
);

-- Insert sample user activity data
INSERT INTO user_activity (user_id, activity_type, ip_address, user_agent, session_id, page_url) VALUES
(1, 'login', '192.168.1.100', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', 'sess_001', '/login'),
(2, 'page_view', '192.168.1.101', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', 'sess_002', '/products'),
(3, 'add_to_cart', '192.168.1.102', 'Mozilla/5.0 (X11; Linux x86_64)', 'sess_003', '/cart'),
(1, 'purchase', '192.168.1.100', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', 'sess_001', '/checkout'),
(4, 'signup', '192.168.1.103', 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1)', 'sess_004', '/register'),
(2, 'logout', '192.168.1.101', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', 'sess_002', '/logout'),
(5, 'search', '192.168.1.104', 'Mozilla/5.0 (Android 11; Mobile)', 'sess_005', '/search?q=laptop'),
(3, 'purchase', '192.168.1.102', 'Mozilla/5.0 (X11; Linux x86_64)', 'sess_003', '/checkout'),
(6, 'page_view', '192.168.1.105', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', 'sess_006', '/about'),
(4, 'add_to_cart', '192.168.1.103', 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1)', 'sess_004', '/cart');

-- Create trigger for real-time updates demonstration
DELIMITER //
CREATE TRIGGER after_order_insert
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    INSERT INTO user_activity (user_id, activity_type, ip_address, session_id, page_url)
    VALUES (NEW.customer_id, 'order_placed', '192.168.1.999', CONCAT('sess_', NEW.id), '/order-confirmation');
END//
DELIMITER ;

-- Create sample dashboard metrics table
CREATE TABLE IF NOT EXISTS dashboard_metrics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(15,2) NOT NULL,
    metric_date DATE NOT NULL,
    category VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample dashboard metrics
INSERT INTO dashboard_metrics (metric_name, metric_value, metric_date, category) VALUES
('total_revenue', 5247.82, '2024-01-24', 'sales'),
('total_orders', 25, '2024-01-24', 'sales'),
('new_customers', 3, '2024-01-24', 'customers'),
('page_views', 1250, '2024-01-24', 'website'),
('conversion_rate', 3.2, '2024-01-24', 'website'),
('avg_order_value', 209.91, '2024-01-24', 'sales'),
('total_revenue', 4892.15, '2024-01-23', 'sales'),
('total_orders', 22, '2024-01-23', 'sales'),
('new_customers', 2, '2024-01-23', 'customers'),
('page_views', 1180, '2024-01-23', 'website');

SELECT 'MySQL sample data inserted successfully!' as message; 
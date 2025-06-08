-- MySQL Sample Data Seed Script
-- Populates tables with realistic test data

USE devops_app;

-- Insert sample users
INSERT INTO users (username, email, password_hash, first_name, last_name, is_active, last_login) VALUES
('john_doe', 'john.doe@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewLN83K7bX9B6YZm', 'John', 'Doe', true, NOW() - INTERVAL 1 HOUR),
('jane_smith', 'jane.smith@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewLN83K7bX9B6YZm', 'Jane', 'Smith', true, NOW() - INTERVAL 2 HOURS),
('mike_johnson', 'mike.johnson@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewLN83K7bX9B6YZm', 'Mike', 'Johnson', true, NOW() - INTERVAL 3 HOURS),
('sarah_wilson', 'sarah.wilson@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewLN83K7bX9B6YZm', 'Sarah', 'Wilson', true, NOW() - INTERVAL 4 HOURS),
('david_brown', 'david.brown@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewLN83K7bX9B6YZm', 'David', 'Brown', true, NOW() - INTERVAL 5 HOURS),
('emily_davis', 'emily.davis@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewLN83K7bX9B6YZm', 'Emily', 'Davis', true, NOW() - INTERVAL 6 HOURS),
('robert_miller', 'robert.miller@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewLN83K7bX9B6YZm', 'Robert', 'Miller', true, NOW() - INTERVAL 1 DAY),
('lisa_garcia', 'lisa.garcia@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewLN83K7bX9B6YZm', 'Lisa', 'Garcia', true, NOW() - INTERVAL 2 DAYS),
('admin_user', 'admin@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewLN83K7bX9B6YZm', 'Admin', 'User', true, NOW() - INTERVAL 30 MINUTES),
('test_user', 'test@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewLN83K7bX9B6YZm', 'Test', 'User', false, NULL);

-- Insert sample products
INSERT INTO products (name, description, price, category, sku, stock_quantity, is_active) VALUES
('Wireless Bluetooth Headphones', 'High-quality wireless headphones with noise cancellation', 149.99, 'Electronics', 'WBH-001', 45, true),
('Ergonomic Office Chair', 'Comfortable office chair with lumbar support', 299.99, 'Furniture', 'EOC-002', 23, true),
('Stainless Steel Water Bottle', 'Insulated water bottle keeps drinks cold for 24 hours', 24.99, 'Sports', 'SWB-003', 78, true),
('Gaming Mechanical Keyboard', 'RGB backlit mechanical keyboard for gaming', 89.99, 'Electronics', 'GMK-004', 34, true),
('Yoga Exercise Mat', 'Non-slip yoga mat perfect for home workouts', 39.99, 'Sports', 'YEM-005', 56, true),
('Coffee Bean Grinder', 'Electric coffee grinder with multiple settings', 59.99, 'Kitchen', 'CBG-006', 67, true),
('LED Desk Lamp', 'Adjustable LED desk lamp with USB charging port', 49.99, 'Electronics', 'LDL-007', 42, true),
('Running Shoes', 'Lightweight running shoes with cushioned sole', 119.99, 'Sports', 'RS-008', 89, true),
('Laptop Stand', 'Adjustable aluminum laptop stand for better ergonomics', 79.99, 'Electronics', 'LS-009', 31, true),
('Ceramic Mug Set', 'Set of 4 ceramic mugs perfect for coffee or tea', 29.99, 'Kitchen', 'CMS-010', 25, true),
('Wireless Mouse', 'Precision wireless mouse with long battery life', 34.99, 'Electronics', 'WM-011', 73, true),
('Plant Pot Set', 'Set of 3 decorative plant pots for indoor plants', 44.99, 'Home', 'PPS-012', 19, true),
('Phone Case', 'Protective phone case with drop protection', 19.99, 'Electronics', 'PC-013', 156, true),
('Notebook Set', 'Set of 3 premium notebooks for writing', 24.99, 'Office', 'NBS-014', 67, true),
('Portable Speaker', 'Compact Bluetooth speaker with excellent sound quality', 79.99, 'Electronics', 'PS-015', 43, true),
('Kitchen Knife Set', 'Professional chef knife set with wooden block', 129.99, 'Kitchen', 'KNS-016', 18, true),
('Fitness Tracker', 'Advanced fitness tracker with heart rate monitor', 199.99, 'Electronics', 'FT-017', 28, true),
('Desk Organizer', 'Wooden desk organizer with multiple compartments', 34.99, 'Office', 'DO-018', 52, true),
('Throw Pillow', 'Comfortable throw pillow with removable cover', 19.99, 'Home', 'TP-019', 84, true),
('Power Bank', '10000mAh portable power bank with fast charging', 39.99, 'Electronics', 'PB-020', 91, true);

-- Insert sample orders with realistic dates
INSERT INTO orders (user_id, order_number, status, total_amount, shipping_address, billing_address, payment_method, payment_status, order_date) VALUES
(1, 'ORD-2024-001', 'delivered', 179.98, '123 Main St, Anytown, USA', '123 Main St, Anytown, USA', 'credit_card', 'completed', NOW() - INTERVAL 7 DAYS),
(2, 'ORD-2024-002', 'shipped', 349.98, '456 Oak Ave, City, USA', '456 Oak Ave, City, USA', 'paypal', 'completed', NOW() - INTERVAL 5 DAYS),
(3, 'ORD-2024-003', 'processing', 64.98, '789 Pine St, Town, USA', '789 Pine St, Town, USA', 'credit_card', 'completed', NOW() - INTERVAL 3 DAYS),
(4, 'ORD-2024-004', 'delivered', 129.99, '321 Elm St, Village, USA', '321 Elm St, Village, USA', 'debit_card', 'completed', NOW() - INTERVAL 10 DAYS),
(5, 'ORD-2024-005', 'pending', 89.99, '654 Maple Dr, County, USA', '654 Maple Dr, County, USA', 'credit_card', 'pending', NOW() - INTERVAL 1 DAY),
(1, 'ORD-2024-006', 'delivered', 274.97, '123 Main St, Anytown, USA', '123 Main St, Anytown, USA', 'credit_card', 'completed', NOW() - INTERVAL 15 DAYS),
(6, 'ORD-2024-007', 'shipped', 199.99, '987 Cedar Ln, Suburb, USA', '987 Cedar Ln, Suburb, USA', 'paypal', 'completed', NOW() - INTERVAL 2 DAYS),
(7, 'ORD-2024-008', 'delivered', 54.98, '147 Birch Rd, District, USA', '147 Birch Rd, District, USA', 'credit_card', 'completed', NOW() - INTERVAL 12 DAYS),
(2, 'ORD-2024-009', 'processing', 159.98, '456 Oak Ave, City, USA', '456 Oak Ave, City, USA', 'debit_card', 'completed', NOW() - INTERVAL 4 DAYS),
(8, 'ORD-2024-010', 'cancelled', 79.99, '258 Willow St, Region, USA', '258 Willow St, Region, USA', 'credit_card', 'refunded', NOW() - INTERVAL 8 DAYS),
(3, 'ORD-2024-011', 'delivered', 109.98, '789 Pine St, Town, USA', '789 Pine St, Town, USA', 'paypal', 'completed', NOW() - INTERVAL 20 DAYS),
(4, 'ORD-2024-012', 'shipped', 44.99, '321 Elm St, Village, USA', '321 Elm St, Village, USA', 'credit_card', 'completed', NOW() - INTERVAL 1 DAY),
(5, 'ORD-2024-013', 'pending', 234.97, '654 Maple Dr, County, USA', '654 Maple Dr, County, USA', 'debit_card', 'pending', NOW() - INTERVAL 6 HOURS),
(6, 'ORD-2024-014', 'delivered', 69.98, '987 Cedar Ln, Suburb, USA', '987 Cedar Ln, Suburb, USA', 'credit_card', 'completed', NOW() - INTERVAL 25 DAYS),
(1, 'ORD-2024-015', 'processing', 149.99, '123 Main St, Anytown, USA', '123 Main St, Anytown, USA', 'paypal', 'completed', NOW() - INTERVAL 2 HOURS);

-- Insert order items
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
-- Order 1: Headphones + Water Bottle
(1, 1, 1, 149.99),
(1, 3, 1, 24.99),

-- Order 2: Office Chair + Desk Lamp
(2, 2, 1, 299.99),
(2, 7, 1, 49.99),

-- Order 3: Keyboard + Mouse
(3, 4, 1, 89.99),
(3, 11, 1, 34.99),

-- Order 4: Kitchen Knife Set
(4, 16, 1, 129.99),

-- Order 5: Gaming Keyboard
(5, 4, 1, 89.99),

-- Order 6: Yoga Mat + Running Shoes + Water Bottle
(6, 5, 1, 39.99),
(6, 8, 1, 119.99),
(6, 3, 1, 24.99),

-- Order 7: Fitness Tracker
(7, 17, 1, 199.99),

-- Order 8: Phone Case + Mug Set
(8, 13, 1, 19.99),
(8, 10, 1, 29.99),

-- Order 9: Laptop Stand + Portable Speaker
(9, 9, 1, 79.99),
(9, 15, 1, 79.99),

-- Order 10: Portable Speaker (cancelled)
(10, 15, 1, 79.99),

-- Order 11: Coffee Grinder + Power Bank
(11, 6, 1, 59.99),
(11, 20, 1, 39.99),

-- Order 12: Plant Pot Set
(12, 12, 1, 44.99),

-- Order 13: Headphones + Desk Organizer + Throw Pillow
(13, 1, 1, 149.99),
(13, 18, 1, 34.99),
(13, 19, 1, 19.99),

-- Order 14: Notebook Set + Power Bank
(14, 14, 1, 24.99),
(14, 20, 1, 39.99),

-- Order 15: Headphones
(15, 1, 1, 149.99);

-- Insert customer reviews
INSERT INTO customer_reviews (user_id, product_id, order_id, rating, title, review_text, is_verified) VALUES
(1, 1, 1, 5, 'Excellent sound quality!', 'These headphones exceeded my expectations. The noise cancellation is fantastic and they\'re very comfortable for long listening sessions.', true),
(1, 3, 1, 4, 'Great water bottle', 'Keeps my drinks cold all day. The only downside is it\'s a bit heavy when full.', true),
(2, 2, 2, 5, 'Perfect office chair', 'Finally found a chair that supports my back properly. Assembly was easy and it feels very sturdy.', true),
(3, 4, 3, 5, 'Amazing keyboard for gaming', 'The RGB lighting is beautiful and the mechanical switches feel great. Highly recommend for gamers.', true),
(4, 16, 4, 5, 'Professional quality knives', 'These knives are incredibly sharp and well-made. The wooden block looks great on my counter.', true),
(6, 17, 7, 4, 'Good fitness tracker', 'Accurate heart rate monitoring and the battery lasts for days. The app could be better though.', true),
(1, 5, 6, 5, 'Perfect for home workouts', 'Non-slip surface works great and it\'s the perfect thickness. Easy to clean too.', true),
(2, 7, 2, 4, 'Bright and adjustable', 'Love the USB charging port. The light is very bright and adjustable. Good value for money.', true),
(3, 11, 3, 4, 'Reliable wireless mouse', 'Works great with my laptop. Battery life is excellent and it\'s very responsive.', true),
(7, 13, 8, 3, 'Decent protection', 'Protects my phone well but it\'s a bit bulky. Material feels durable though.', true);

-- Insert inventory movements (some historical data)
INSERT INTO inventory_movements (product_id, movement_type, quantity, reference_type, reference_id, user_id, timestamp) VALUES
-- Stock additions (receiving inventory)
(1, 'in', 50, 'purchase', 1001, 9, NOW() - INTERVAL 30 DAYS),
(2, 'in', 30, 'purchase', 1002, 9, NOW() - INTERVAL 30 DAYS),
(3, 'in', 100, 'purchase', 1003, 9, NOW() - INTERVAL 30 DAYS),
(4, 'in', 40, 'purchase', 1004, 9, NOW() - INTERVAL 30 DAYS),
(5, 'in', 60, 'purchase', 1005, 9, NOW() - INTERVAL 30 DAYS),

-- Stock outbound (from orders)
(1, 'out', 3, 'order', 1, NULL, NOW() - INTERVAL 15 DAYS),
(1, 'out', 1, 'order', 13, NULL, NOW() - INTERVAL 6 HOURS),
(1, 'out', 1, 'order', 15, NULL, NOW() - INTERVAL 2 HOURS),
(2, 'out', 1, 'order', 2, NULL, NOW() - INTERVAL 5 DAYS),
(3, 'out', 2, 'order', 1, NULL, NOW() - INTERVAL 15 DAYS),
(3, 'out', 1, 'order', 6, NULL, NOW() - INTERVAL 15 DAYS),

-- Stock adjustments
(12, 'adjustment', -1, 'damage', NULL, 9, NOW() - INTERVAL 10 DAYS),
(8, 'adjustment', 5, 'return', NULL, 9, NOW() - INTERVAL 8 DAYS);

-- Insert user activity log entries
INSERT INTO user_activity_log (user_id, action, entity_type, entity_id, ip_address, user_agent, timestamp) VALUES
(1, 'login', 'user', 1, INET6_ATON('192.168.1.100'), 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', NOW() - INTERVAL 1 HOUR),
(2, 'login', 'user', 2, INET6_ATON('192.168.1.101'), 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36', NOW() - INTERVAL 2 HOURS),
(1, 'view', 'product', 1, INET6_ATON('192.168.1.100'), 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', NOW() - INTERVAL 50 MINUTES),
(1, 'add_to_cart', 'product', 1, INET6_ATON('192.168.1.100'), 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', NOW() - INTERVAL 45 MINUTES),
(3, 'login', 'user', 3, INET6_ATON('192.168.1.102'), 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36', NOW() - INTERVAL 3 HOURS),
(4, 'order_placed', 'order', 12, INET6_ATON('192.168.1.103'), 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X)', NOW() - INTERVAL 1 DAY),
(5, 'login', 'user', 5, INET6_ATON('192.168.1.104'), 'Mozilla/5.0 (Android 11; Mobile; rv:92.0)', NOW() - INTERVAL 5 HOURS),
(6, 'review_submitted', 'product', 17, INET6_ATON('192.168.1.105'), 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', NOW() - INTERVAL 2 DAYS);

-- Update some orders with shipped and delivered dates
UPDATE orders SET 
    shipped_date = order_date + INTERVAL 1 DAY,
    delivered_date = order_date + INTERVAL 4 DAYS
WHERE status = 'delivered';

UPDATE orders SET 
    shipped_date = order_date + INTERVAL 1 DAY
WHERE status = 'shipped';

-- Create some sample sessions (for demonstration)
INSERT INTO user_sessions (id, user_id, session_data, expires_at) VALUES
(SHA2(CONCAT('session_', 1, '_', UNIX_TIMESTAMP()), 256), 1, 
 JSON_OBJECT('login_time', NOW(), 'ip_address', '192.168.1.100', 'user_agent', 'Mozilla/5.0'),
 NOW() + INTERVAL 1 HOUR),
(SHA2(CONCAT('session_', 2, '_', UNIX_TIMESTAMP()), 256), 2,
 JSON_OBJECT('login_time', NOW() - INTERVAL 2 HOURS, 'ip_address', '192.168.1.101', 'user_agent', 'Mozilla/5.0'),
 NOW() + INTERVAL 30 MINUTES);

-- Generate some recent activity for dashboard demo
INSERT INTO user_activity_log (user_id, action, entity_type, entity_id, ip_address, timestamp) VALUES
(1, 'dashboard_view', 'dashboard', NULL, INET6_ATON('192.168.1.100'), NOW() - INTERVAL 5 MINUTES),
(2, 'search', 'product', NULL, INET6_ATON('192.168.1.101'), NOW() - INTERVAL 3 MINUTES),
(3, 'product_view', 'product', 15, INET6_ATON('192.168.1.102'), NOW() - INTERVAL 2 MINUTES),
(1, 'cart_update', 'cart', NULL, INET6_ATON('192.168.1.100'), NOW() - INTERVAL 1 MINUTE),
(4, 'checkout_started', 'order', NULL, INET6_ATON('192.168.1.103'), NOW() - INTERVAL 30 SECONDS);

COMMIT;

-- Display summary of inserted data
SELECT 'Data Seed Summary' as summary;
SELECT 'Users' as table_name, COUNT(*) as record_count FROM users
UNION ALL
SELECT 'Products', COUNT(*) FROM products
UNION ALL
SELECT 'Orders', COUNT(*) FROM orders
UNION ALL
SELECT 'Order Items', COUNT(*) FROM order_items
UNION ALL
SELECT 'Reviews', COUNT(*) FROM customer_reviews
UNION ALL
SELECT 'Inventory Movements', COUNT(*) FROM inventory_movements
UNION ALL
SELECT 'Activity Log', COUNT(*) FROM user_activity_log;

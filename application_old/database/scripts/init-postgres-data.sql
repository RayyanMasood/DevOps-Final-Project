-- PostgreSQL Database Initialization Script with Sample Data
-- This script creates tables and populates them with dummy data for demonstration

-- ===========================================
-- PostgreSQL Sample Data
-- ===========================================

-- Create analytics events table
CREATE TABLE IF NOT EXISTS analytics_events (
    id SERIAL PRIMARY KEY,
    event_name VARCHAR(100) NOT NULL,
    user_id INTEGER,
    session_id VARCHAR(100),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    properties JSONB,
    user_agent TEXT,
    ip_address INET,
    page_url VARCHAR(255),
    referrer VARCHAR(255)
);

-- Create sales analytics table
CREATE TABLE IF NOT EXISTS sales_analytics (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    sales_amount DECIMAL(10,2) NOT NULL,
    quantity_sold INTEGER NOT NULL,
    region VARCHAR(50) NOT NULL,
    channel VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create user engagement metrics table
CREATE TABLE IF NOT EXISTS user_engagement (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    session_duration INTEGER, -- in seconds
    page_views INTEGER,
    bounced BOOLEAN DEFAULT FALSE,
    converted BOOLEAN DEFAULT FALSE,
    device_type VARCHAR(50),
    browser VARCHAR(50),
    os VARCHAR(50),
    country VARCHAR(50),
    visit_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create financial metrics table
CREATE TABLE IF NOT EXISTS financial_metrics (
    id SERIAL PRIMARY KEY,
    metric_date DATE NOT NULL,
    revenue DECIMAL(15,2),
    costs DECIMAL(15,2),
    profit DECIMAL(15,2),
    orders_count INTEGER,
    refunds DECIMAL(10,2),
    new_customers INTEGER,
    returning_customers INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample analytics events
INSERT INTO analytics_events (event_name, user_id, session_id, properties, user_agent, ip_address, page_url, referrer) VALUES
('page_view', 1, 'sess_001', '{"page_title": "Home Page", "load_time": 1.2}', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', '192.168.1.100', '/', 'https://google.com'),
('click', 1, 'sess_001', '{"element": "buy_button", "product_id": 1}', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', '192.168.1.100', '/products/1', '/'),
('purchase', 1, 'sess_001', '{"amount": 1299.99, "currency": "USD", "items": 1}', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', '192.168.1.100', '/checkout', '/cart'),
('page_view', 2, 'sess_002', '{"page_title": "Products", "load_time": 0.8}', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', '192.168.1.101', '/products', 'https://bing.com'),
('search', 2, 'sess_002', '{"query": "laptop", "results_count": 15}', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', '192.168.1.101', '/search', '/products'),
('add_to_cart', 3, 'sess_003', '{"product_id": 3, "quantity": 1, "price": 199.99}', 'Mozilla/5.0 (X11; Linux x86_64)', '192.168.1.102', '/products/3', '/products'),
('signup', 4, 'sess_004', '{"method": "email", "source": "organic"}', 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1)', '192.168.1.103', '/signup', '/'),
('login', 2, 'sess_005', '{"method": "email", "remember_me": true}', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', '192.168.1.101', '/login', '/account'),
('logout', 1, 'sess_001', '{"session_duration": 1800}', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', '192.168.1.100', '/logout', '/dashboard'),
('error', 5, 'sess_006', '{"error_type": "404", "page": "/old-page"}', 'Mozilla/5.0 (Android 11; Mobile)', '192.168.1.104', '/old-page', '/products');

-- Insert sample sales analytics data
INSERT INTO sales_analytics (date, product_name, category, sales_amount, quantity_sold, region, channel) VALUES
('2024-01-15', 'Laptop Pro', 'Electronics', 1299.99, 1, 'North America', 'Online'),
('2024-01-15', 'Wireless Mouse', 'Electronics', 29.99, 2, 'North America', 'Online'),
('2024-01-16', 'Office Chair', 'Furniture', 199.99, 1, 'Europe', 'Retail'),
('2024-01-16', 'Desk Lamp', 'Furniture', 79.99, 1, 'Asia', 'Online'),
('2024-01-17', 'Coffee Mug', 'Kitchen', 12.99, 3, 'North America', 'Online'),
('2024-01-17', 'Notebook Set', 'Stationery', 24.99, 2, 'Europe', 'Retail'),
('2024-01-18', 'USB Cable', 'Electronics', 9.99, 5, 'Asia', 'Online'),
('2024-01-18', 'Monitor Stand', 'Furniture', 89.99, 1, 'North America', 'Retail'),
('2024-01-19', 'Keyboard', 'Electronics', 149.99, 1, 'Europe', 'Online'),
('2024-01-19', 'Water Bottle', 'Kitchen', 19.99, 2, 'Asia', 'Online'),
('2024-01-20', 'Laptop Pro', 'Electronics', 1299.99, 2, 'North America', 'Retail'),
('2024-01-20', 'Office Chair', 'Furniture', 199.99, 1, 'Europe', 'Online'),
('2024-01-21', 'Wireless Mouse', 'Electronics', 29.99, 3, 'Asia', 'Online'),
('2024-01-21', 'Desk Lamp', 'Furniture', 79.99, 2, 'North America', 'Retail'),
('2024-01-22', 'Coffee Mug', 'Kitchen', 12.99, 4, 'Europe', 'Online'),
('2024-01-22', 'Keyboard', 'Electronics', 149.99, 1, 'Asia', 'Retail'),
('2024-01-23', 'USB Cable', 'Electronics', 9.99, 8, 'North America', 'Online'),
('2024-01-23', 'Water Bottle', 'Kitchen', 19.99, 3, 'Europe', 'Online'),
('2024-01-24', 'Monitor Stand', 'Furniture', 89.99, 2, 'Asia', 'Retail'),
('2024-01-24', 'Notebook Set', 'Stationery', 24.99, 1, 'North America', 'Online');

-- Insert sample user engagement data
INSERT INTO user_engagement (user_id, session_duration, page_views, bounced, converted, device_type, browser, os, country, visit_date) VALUES
(1, 1800, 15, FALSE, TRUE, 'Desktop', 'Chrome', 'Windows', 'USA', '2024-01-15'),
(2, 450, 3, TRUE, FALSE, 'Mobile', 'Safari', 'iOS', 'Canada', '2024-01-15'),
(3, 1200, 8, FALSE, FALSE, 'Desktop', 'Firefox', 'Linux', 'Germany', '2024-01-16'),
(4, 300, 2, TRUE, FALSE, 'Tablet', 'Chrome', 'Android', 'Japan', '2024-01-16'),
(5, 2100, 12, FALSE, TRUE, 'Desktop', 'Edge', 'Windows', 'UK', '2024-01-17'),
(6, 600, 5, FALSE, FALSE, 'Mobile', 'Chrome', 'Android', 'France', '2024-01-17'),
(7, 150, 1, TRUE, FALSE, 'Desktop', 'Safari', 'macOS', 'Australia', '2024-01-18'),
(8, 900, 7, FALSE, FALSE, 'Mobile', 'Firefox', 'iOS', 'Brazil', '2024-01-18'),
(9, 1350, 9, FALSE, TRUE, 'Desktop', 'Chrome', 'Windows', 'India', '2024-01-19'),
(10, 750, 6, FALSE, FALSE, 'Tablet', 'Safari', 'iPadOS', 'Spain', '2024-01-19'),
(1, 1950, 14, FALSE, TRUE, 'Desktop', 'Chrome', 'Windows', 'USA', '2024-01-20'),
(3, 420, 4, FALSE, FALSE, 'Mobile', 'Chrome', 'Android', 'Germany', '2024-01-20'),
(5, 1680, 11, FALSE, FALSE, 'Desktop', 'Edge', 'Windows', 'UK', '2024-01-21'),
(7, 240, 2, TRUE, FALSE, 'Mobile', 'Safari', 'iOS', 'Australia', '2024-01-21'),
(9, 1560, 13, FALSE, TRUE, 'Desktop', 'Firefox', 'Linux', 'India', '2024-01-22');

-- Insert sample financial metrics
INSERT INTO financial_metrics (metric_date, revenue, costs, profit, orders_count, refunds, new_customers, returning_customers) VALUES
('2024-01-15', 5247.82, 2100.50, 3147.32, 25, 150.00, 8, 17),
('2024-01-16', 4892.15, 1950.75, 2941.40, 22, 89.99, 6, 16),
('2024-01-17', 6124.73, 2450.20, 3674.53, 31, 0.00, 12, 19),
('2024-01-18', 3756.84, 1500.80, 2256.04, 18, 199.99, 4, 14),
('2024-01-19', 7892.56, 3150.45, 4742.11, 38, 79.99, 15, 23),
('2024-01-20', 5634.21, 2250.90, 3383.31, 27, 0.00, 9, 18),
('2024-01-21', 4987.63, 1995.10, 2992.53, 24, 29.99, 7, 17),
('2024-01-22', 6789.45, 2715.80, 4073.65, 33, 149.99, 11, 22),
('2024-01-23', 5123.78, 2049.50, 3074.28, 26, 0.00, 8, 18),
('2024-01-24', 7234.92, 2893.95, 4340.97, 35, 89.99, 13, 22);

-- Create real-time updates table for dashboard demonstration
CREATE TABLE IF NOT EXISTS real_time_metrics (
    id SERIAL PRIMARY KEY,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(15,2) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

-- Insert initial real-time metrics
INSERT INTO real_time_metrics (metric_name, metric_value, metadata) VALUES
('current_visitors', 247, '{"source": "google_analytics"}'),
('sales_today', 8945.67, '{"currency": "USD", "updated": "real_time"}'),
('conversion_rate', 3.2, '{"period": "last_hour"}'),
('cart_abandonment', 68.5, '{"period": "today"}'),
('avg_session_duration', 285, '{"unit": "seconds"}'),
('bounce_rate', 42.3, '{"period": "today"}'),
('new_signups_today', 23, '{"source": "all_channels"}'),
('server_response_time', 145, '{"unit": "milliseconds"}');

-- Create view for dashboard analytics
CREATE OR REPLACE VIEW dashboard_summary AS
SELECT 
    DATE(s.date) as report_date,
    SUM(s.sales_amount) as total_revenue,
    COUNT(s.id) as total_transactions,
    AVG(s.sales_amount) as avg_transaction_value,
    s.region,
    s.channel,
    COUNT(DISTINCT e.user_id) as unique_users
FROM sales_analytics s
LEFT JOIN analytics_events e ON DATE(s.date) = DATE(e.timestamp)
GROUP BY DATE(s.date), s.region, s.channel
ORDER BY DATE(s.date) DESC;

-- Create function to simulate real-time data updates
CREATE OR REPLACE FUNCTION update_real_time_metrics()
RETURNS void AS $$
BEGIN
    -- Update current visitors (random between 200-300)
    UPDATE real_time_metrics 
    SET metric_value = (200 + RANDOM() * 100)::DECIMAL(15,2), 
        timestamp = CURRENT_TIMESTAMP
    WHERE metric_name = 'current_visitors';
    
    -- Update sales today (incrementally)
    UPDATE real_time_metrics 
    SET metric_value = metric_value + (50 + RANDOM() * 200)::DECIMAL(15,2),
        timestamp = CURRENT_TIMESTAMP
    WHERE metric_name = 'sales_today';
    
    -- Update conversion rate (random between 2.5-4.0)
    UPDATE real_time_metrics 
    SET metric_value = (2.5 + RANDOM() * 1.5)::DECIMAL(15,2),
        timestamp = CURRENT_TIMESTAMP
    WHERE metric_name = 'conversion_rate';
    
    -- Log the update event
    INSERT INTO analytics_events (event_name, properties, timestamp)
    VALUES ('metrics_updated', '{"type": "real_time_update"}', CURRENT_TIMESTAMP);
END;
$$ LANGUAGE plpgsql;

-- Create trigger function for new sales events
CREATE OR REPLACE FUNCTION notify_new_sale()
RETURNS trigger AS $$
BEGIN
    -- Insert notification event
    INSERT INTO analytics_events (event_name, properties, timestamp)
    VALUES ('new_sale', json_build_object(
        'product', NEW.product_name,
        'amount', NEW.sales_amount,
        'region', NEW.region,
        'channel', NEW.channel
    )::jsonb, NEW.created_at);
    
    -- Update real-time metrics
    UPDATE real_time_metrics 
    SET metric_value = metric_value + NEW.sales_amount,
        timestamp = CURRENT_TIMESTAMP
    WHERE metric_name = 'sales_today';
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for new sales
DROP TRIGGER IF EXISTS sales_analytics_notify ON sales_analytics;
CREATE TRIGGER sales_analytics_notify
    AFTER INSERT ON sales_analytics
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_sale();

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_analytics_events_timestamp ON analytics_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX IF NOT EXISTS idx_sales_analytics_date ON sales_analytics(date);
CREATE INDEX IF NOT EXISTS idx_sales_analytics_region ON sales_analytics(region);
CREATE INDEX IF NOT EXISTS idx_user_engagement_date ON user_engagement(visit_date);
CREATE INDEX IF NOT EXISTS idx_financial_metrics_date ON financial_metrics(metric_date);

-- Final success message
SELECT 'PostgreSQL sample data and real-time features initialized successfully!' as message; 
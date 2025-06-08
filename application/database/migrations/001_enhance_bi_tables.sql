-- Enhanced BI Tables Migration
-- Adds additional tables and structures optimized for business intelligence dashboards

USE devops_app;

-- Sales Performance Tracking
CREATE TABLE IF NOT EXISTS sales_targets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    target_period VARCHAR(20) NOT NULL, -- 'daily', 'weekly', 'monthly', 'quarterly', 'yearly'
    target_date DATE NOT NULL,
    target_amount DECIMAL(15, 2) NOT NULL,
    achieved_amount DECIMAL(15, 2) DEFAULT 0.00,
    category VARCHAR(100),
    region VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_target_period (target_period),
    INDEX idx_target_date (target_date),
    INDEX idx_category (category),
    INDEX idx_region (region),
    UNIQUE KEY unique_target (target_period, target_date, category, region)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Customer Segmentation
CREATE TABLE IF NOT EXISTS customer_segments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    segment_type VARCHAR(50) NOT NULL, -- 'VIP', 'Regular', 'New', 'Churned', 'At-Risk'
    segment_score DECIMAL(5, 2),
    lifetime_value DECIMAL(12, 2) DEFAULT 0.00,
    total_orders INT DEFAULT 0,
    last_order_date DATE,
    avg_order_value DECIMAL(10, 2) DEFAULT 0.00,
    days_since_last_order INT,
    assigned_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_segment_type (segment_type),
    INDEX idx_segment_score (segment_score),
    INDEX idx_lifetime_value (lifetime_value),
    INDEX idx_assigned_date (assigned_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Product Performance Analytics
CREATE TABLE IF NOT EXISTS product_analytics (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    metric_date DATE NOT NULL,
    views_count INT DEFAULT 0,
    cart_additions INT DEFAULT 0,
    purchases_count INT DEFAULT 0,
    revenue DECIMAL(12, 2) DEFAULT 0.00,
    return_count INT DEFAULT 0,
    review_count INT DEFAULT 0,
    avg_rating DECIMAL(3, 2) DEFAULT 0.00,
    conversion_rate DECIMAL(5, 4) DEFAULT 0.0000,
    
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    INDEX idx_product_id (product_id),
    INDEX idx_metric_date (metric_date),
    INDEX idx_conversion_rate (conversion_rate),
    UNIQUE KEY unique_product_date (product_id, metric_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Marketing Campaign Tracking
CREATE TABLE IF NOT EXISTS marketing_campaigns (
    id INT AUTO_INCREMENT PRIMARY KEY,
    campaign_name VARCHAR(200) NOT NULL,
    campaign_type VARCHAR(50), -- 'email', 'social', 'ppc', 'display', 'affiliate'
    start_date DATE NOT NULL,
    end_date DATE,
    budget DECIMAL(12, 2),
    spent DECIMAL(12, 2) DEFAULT 0.00,
    target_audience TEXT,
    status ENUM('draft', 'active', 'paused', 'completed', 'cancelled') DEFAULT 'draft',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_campaign_type (campaign_type),
    INDEX idx_status (status),
    INDEX idx_start_date (start_date),
    INDEX idx_end_date (end_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Campaign Performance Metrics
CREATE TABLE IF NOT EXISTS campaign_metrics (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    campaign_id INT NOT NULL,
    metric_date DATE NOT NULL,
    impressions INT DEFAULT 0,
    clicks INT DEFAULT 0,
    conversions INT DEFAULT 0,
    cost DECIMAL(10, 2) DEFAULT 0.00,
    revenue DECIMAL(12, 2) DEFAULT 0.00,
    leads_generated INT DEFAULT 0,
    
    FOREIGN KEY (campaign_id) REFERENCES marketing_campaigns(id) ON DELETE CASCADE,
    INDEX idx_campaign_id (campaign_id),
    INDEX idx_metric_date (metric_date),
    UNIQUE KEY unique_campaign_date (campaign_id, metric_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Website Traffic Analytics
CREATE TABLE IF NOT EXISTS traffic_analytics (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    date_recorded DATE NOT NULL,
    page_path VARCHAR(500) NOT NULL,
    unique_visitors INT DEFAULT 0,
    page_views INT DEFAULT 0,
    bounce_rate DECIMAL(5, 4) DEFAULT 0.0000,
    avg_session_duration INT DEFAULT 0, -- in seconds
    conversion_rate DECIMAL(5, 4) DEFAULT 0.0000,
    traffic_source VARCHAR(100), -- 'organic', 'direct', 'referral', 'social', 'email', 'paid'
    device_type VARCHAR(50), -- 'desktop', 'mobile', 'tablet'
    
    INDEX idx_date_recorded (date_recorded),
    INDEX idx_page_path (page_path),
    INDEX idx_traffic_source (traffic_source),
    INDEX idx_device_type (device_type),
    UNIQUE KEY unique_traffic_record (date_recorded, page_path, traffic_source, device_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Financial Metrics
CREATE TABLE IF NOT EXISTS financial_metrics (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    metric_date DATE NOT NULL,
    revenue DECIMAL(15, 2) DEFAULT 0.00,
    costs DECIMAL(15, 2) DEFAULT 0.00,
    profit DECIMAL(15, 2) DEFAULT 0.00,
    orders_count INT DEFAULT 0,
    refunds_amount DECIMAL(12, 2) DEFAULT 0.00,
    refunds_count INT DEFAULT 0,
    new_customers INT DEFAULT 0,
    returning_customers INT DEFAULT 0,
    avg_order_value DECIMAL(10, 2) DEFAULT 0.00,
    
    INDEX idx_metric_date (metric_date),
    UNIQUE KEY unique_metric_date (metric_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Inventory Forecasting
CREATE TABLE IF NOT EXISTS inventory_forecasts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    forecast_date DATE NOT NULL,
    predicted_demand INT DEFAULT 0,
    current_stock INT DEFAULT 0,
    recommended_order_quantity INT DEFAULT 0,
    forecast_confidence DECIMAL(5, 4) DEFAULT 0.0000,
    lead_time_days INT DEFAULT 0,
    safety_stock INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    INDEX idx_product_id (product_id),
    INDEX idx_forecast_date (forecast_date),
    INDEX idx_forecast_confidence (forecast_confidence),
    UNIQUE KEY unique_product_forecast (product_id, forecast_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Customer Support Metrics
CREATE TABLE IF NOT EXISTS support_tickets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ticket_number VARCHAR(50) UNIQUE NOT NULL,
    user_id INT,
    category VARCHAR(100), -- 'technical', 'billing', 'product', 'general'
    priority ENUM('low', 'medium', 'high', 'urgent') DEFAULT 'medium',
    status ENUM('open', 'in_progress', 'pending', 'resolved', 'closed') DEFAULT 'open',
    subject VARCHAR(500) NOT NULL,
    description TEXT,
    assigned_to INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL,
    resolution_time_minutes INT,
    satisfaction_rating TINYINT CHECK (satisfaction_rating >= 1 AND satisfaction_rating <= 5),
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_category (category),
    INDEX idx_priority (priority),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at),
    INDEX idx_resolved_at (resolved_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Real-time Dashboard KPIs
CREATE TABLE IF NOT EXISTS kpi_snapshots (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    snapshot_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_revenue_today DECIMAL(12, 2) DEFAULT 0.00,
    total_orders_today INT DEFAULT 0,
    active_users_now INT DEFAULT 0,
    conversion_rate_today DECIMAL(5, 4) DEFAULT 0.0000,
    avg_order_value_today DECIMAL(10, 2) DEFAULT 0.00,
    top_selling_product_id INT,
    inventory_alerts_count INT DEFAULT 0,
    support_tickets_open INT DEFAULT 0,
    website_uptime_percentage DECIMAL(5, 2) DEFAULT 100.00,
    
    INDEX idx_snapshot_time (snapshot_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Enhanced Views for BI
CREATE OR REPLACE VIEW sales_performance_daily AS
SELECT 
    DATE(o.order_date) as sale_date,
    COUNT(*) as orders_count,
    SUM(o.total_amount) as revenue,
    AVG(o.total_amount) as avg_order_value,
    COUNT(DISTINCT o.user_id) as unique_customers,
    SUM(CASE WHEN u.created_at >= DATE_SUB(o.order_date, INTERVAL 30 DAY) THEN 1 ELSE 0 END) as new_customer_orders
FROM orders o
LEFT JOIN users u ON o.user_id = u.id
WHERE o.status IN ('completed', 'delivered')
GROUP BY DATE(o.order_date)
ORDER BY sale_date DESC;

CREATE OR REPLACE VIEW product_performance AS
SELECT 
    p.id,
    p.name,
    p.category,
    p.price,
    p.stock_quantity,
    COALESCE(SUM(oi.quantity), 0) as total_sold,
    COALESCE(SUM(oi.total_price), 0) as total_revenue,
    COALESCE(COUNT(DISTINCT oi.order_id), 0) as order_count,
    COALESCE(AVG(cr.rating), 0) as avg_rating,
    COALESCE(COUNT(cr.id), 0) as review_count,
    p.created_at
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.id AND o.status IN ('completed', 'delivered')
LEFT JOIN customer_reviews cr ON p.id = cr.product_id
GROUP BY p.id;

CREATE OR REPLACE VIEW customer_analytics AS
SELECT 
    u.id,
    u.username,
    u.email,
    u.created_at as registration_date,
    u.last_login,
    COALESCE(COUNT(DISTINCT o.id), 0) as total_orders,
    COALESCE(SUM(o.total_amount), 0) as lifetime_value,
    COALESCE(AVG(o.total_amount), 0) as avg_order_value,
    COALESCE(MAX(o.order_date), NULL) as last_order_date,
    COALESCE(DATEDIFF(CURRENT_DATE, MAX(o.order_date)), 0) as days_since_last_order,
    cs.segment_type,
    cs.segment_score
FROM users u
LEFT JOIN orders o ON u.id = o.user_id AND o.status IN ('completed', 'delivered')
LEFT JOIN customer_segments cs ON u.id = cs.user_id AND cs.is_active = 1
GROUP BY u.id;

-- Triggers for automatic data updates
DELIMITER //

CREATE TRIGGER update_product_analytics_after_order
    AFTER INSERT ON order_items
    FOR EACH ROW
BEGIN
    INSERT INTO product_analytics (
        product_id, metric_date, purchases_count, revenue
    ) VALUES (
        NEW.product_id, DATE(NOW()), 1, NEW.total_price
    ) ON DUPLICATE KEY UPDATE 
        purchases_count = purchases_count + 1,
        revenue = revenue + NEW.total_price;
END//

CREATE TRIGGER update_financial_metrics_after_order
    AFTER UPDATE ON orders
    FOR EACH ROW
BEGIN
    IF NEW.status IN ('completed', 'delivered') AND OLD.status NOT IN ('completed', 'delivered') THEN
        INSERT INTO financial_metrics (
            metric_date, revenue, orders_count
        ) VALUES (
            DATE(NEW.order_date), NEW.total_amount, 1
        ) ON DUPLICATE KEY UPDATE 
            revenue = revenue + NEW.total_amount,
            orders_count = orders_count + 1;
    END IF;
END//

DELIMITER ;

-- Create indexes for better performance
CREATE INDEX idx_orders_date_status ON orders(order_date, status);
CREATE INDEX idx_order_items_product_order ON order_items(product_id, order_id);
CREATE INDEX idx_users_created_active ON users(created_at, is_active);
CREATE INDEX idx_reviews_product_rating ON customer_reviews(product_id, rating);

-- Initial configuration data
INSERT INTO system_config (config_key, config_value, description) VALUES
('dashboard_refresh_interval', '30', 'Dashboard auto-refresh interval in seconds'),
('kpi_alert_thresholds', '{"revenue_drop": 0.15, "conversion_drop": 0.20, "inventory_low": 10}', 'Alert thresholds for KPI monitoring'),
('business_hours', '{"start": "09:00", "end": "17:00", "timezone": "UTC"}', 'Business operating hours'),
('currency_settings', '{"code": "USD", "symbol": "$", "decimal_places": 2}', 'Currency display settings')
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

-- Sample sales targets
INSERT INTO sales_targets (target_period, target_date, target_amount, category) VALUES
('monthly', LAST_DAY(CURRENT_DATE), 100000.00, 'Electronics'),
('monthly', LAST_DAY(CURRENT_DATE), 75000.00, 'Furniture'),
('monthly', LAST_DAY(CURRENT_DATE), 50000.00, 'Sports'),
('weekly', DATE_ADD(CURRENT_DATE, INTERVAL (7 - WEEKDAY(CURRENT_DATE)) DAY), 25000.00, NULL),
('daily', CURRENT_DATE, 3500.00, NULL)
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

COMMIT;

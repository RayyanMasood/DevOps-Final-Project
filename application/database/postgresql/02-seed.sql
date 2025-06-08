-- PostgreSQL Analytics Database Seed Script
-- Populates analytics tables with realistic sample data

\c devops_analytics;

-- Generate sample analytics events
INSERT INTO analytics_events (
    session_id, user_id, event_type, event_name, page_url, referrer_url,
    device_type, browser, operating_system, screen_resolution, country, city, event_data
) VALUES
-- User 1 sessions
(uuid_generate_v4(), 1, 'page_view', 'home_view', '/dashboard', 'https://google.com', 'desktop', 'Chrome', 'Windows', '1920x1080', 'US', 'New York', '{"load_time": 1200, "engagement_time": 45}'),
(uuid_generate_v4(), 1, 'click', 'navigation_click', '/dashboard', NULL, 'desktop', 'Chrome', 'Windows', '1920x1080', 'US', 'New York', '{"element": "menu_analytics", "position": {"x": 150, "y": 60}}'),
(uuid_generate_v4(), 1, 'page_view', 'analytics_view', '/analytics', '/dashboard', 'desktop', 'Chrome', 'Windows', '1920x1080', 'US', 'New York', '{"load_time": 800, "engagement_time": 120}'),

-- User 2 sessions  
(uuid_generate_v4(), 2, 'page_view', 'home_view', '/dashboard', 'https://github.com', 'mobile', 'Safari', 'iOS', '375x812', 'CA', 'Toronto', '{"load_time": 2100, "engagement_time": 30}'),
(uuid_generate_v4(), 2, 'scroll', 'page_scroll', '/dashboard', NULL, 'mobile', 'Safari', 'iOS', '375x812', 'CA', 'Toronto', '{"scroll_depth": 75, "max_scroll": 850}'),
(uuid_generate_v4(), 2, 'click', 'button_click', '/dashboard', NULL, 'mobile', 'Safari', 'iOS', '375x812', 'CA', 'Toronto', '{"element": "refresh_button", "element_text": "Refresh"}'),

-- User 3 sessions
(uuid_generate_v4(), 3, 'page_view', 'monitoring_view', '/monitoring', NULL, 'tablet', 'Firefox', 'Android', '768x1024', 'GB', 'London', '{"load_time": 1500, "engagement_time": 200}'),
(uuid_generate_v4(), 3, 'form_submit', 'filter_update', '/monitoring', NULL, 'tablet', 'Firefox', 'Android', '768x1024', 'GB', 'London', '{"form_id": "metrics_filter", "fields": ["time_range", "metric_type"]}'),

-- Anonymous sessions
(uuid_generate_v4(), NULL, 'page_view', 'landing_view', '/', 'https://linkedin.com', 'desktop', 'Edge', 'Windows', '1366x768', 'DE', 'Berlin', '{"load_time": 1800, "engagement_time": 15}'),
(uuid_generate_v4(), NULL, 'click', 'cta_click', '/', NULL, 'desktop', 'Edge', 'Windows', '1366x768', 'DE', 'Berlin', '{"element": "signup_button", "conversion_goal": "registration"}');

-- Generate sample performance metrics
INSERT INTO performance_metrics (metric_name, metric_type, value, unit, source, tags) VALUES
-- System metrics
('cpu_usage', 'gauge', 45.2, 'percent', 'system', '{"hostname": "web-server-1", "environment": "production"}'),
('memory_usage', 'gauge', 62.8, 'percent', 'system', '{"hostname": "web-server-1", "environment": "production"}'),
('disk_usage', 'gauge', 34.1, 'percent', 'system', '{"hostname": "web-server-1", "mount": "/", "environment": "production"}'),
('network_io', 'gauge', 125.7, 'mbps', 'system', '{"hostname": "web-server-1", "interface": "eth0", "environment": "production"}'),

-- Application metrics
('response_time', 'histogram', 245.0, 'milliseconds', 'application', '{"endpoint": "/api/dashboard", "method": "GET", "environment": "production"}'),
('request_count', 'counter', 1250, 'requests', 'application', '{"endpoint": "/api/dashboard", "method": "GET", "status": "200", "environment": "production"}'),
('error_rate', 'gauge', 0.5, 'percent', 'application', '{"service": "backend", "environment": "production"}'),
('active_connections', 'gauge', 45, 'connections', 'application', '{"service": "websocket", "environment": "production"}'),

-- Database metrics
('db_connections', 'gauge', 25, 'connections', 'database', '{"database": "mysql", "environment": "production"}'),
('db_query_time', 'histogram', 35.0, 'milliseconds', 'database', '{"database": "mysql", "query_type": "select", "environment": "production"}'),
('db_deadlocks', 'counter', 0, 'count', 'database', '{"database": "mysql", "environment": "production"}'),
('db_slow_queries', 'counter', 2, 'count', 'database', '{"database": "mysql", "threshold": "1000ms", "environment": "production"}'),

-- Business metrics
('orders_per_minute', 'gauge', 12.5, 'orders', 'business', '{"source": "ecommerce", "environment": "production"}'),
('revenue_per_hour', 'gauge', 2450.75, 'dollars', 'business', '{"source": "ecommerce", "environment": "production"}'),
('conversion_rate', 'gauge', 3.4, 'percent', 'business', '{"funnel": "checkout", "environment": "production"}'),
('customer_satisfaction', 'gauge', 4.2, 'rating', 'business', '{"scale": "5", "period": "daily", "environment": "production"}');

-- Generate sample real-time data
INSERT INTO real_time_data (data_type, data_source, value, metadata, expires_at) VALUES
('kpi', 'sales', '{"revenue": 45234.67, "orders": 128, "conversion_rate": 3.4}', '{"updated_by": "system", "calculation": "rolling_24h"}', NOW() + INTERVAL '1 hour'),
('status', 'system', '{"active_users": 234, "server_load": 65.2, "error_rate": 0.8}', '{"health_check": "passed", "last_restart": "2024-01-15T08:30:00Z"}', NOW() + INTERVAL '5 minutes'),
('dashboard', 'analytics', '{"page_views": 1450, "unique_visitors": 892, "bounce_rate": 35.2}', '{"time_range": "last_hour", "filter": "all_pages"}', NOW() + INTERVAL '15 minutes'),
('alerts', 'monitoring', '{"high_cpu": false, "disk_full": false, "db_slow": true}', '{"severity": "warning", "auto_resolve": true}', NOW() + INTERVAL '30 minutes'),
('user_activity', 'live', '{"online_users": 67, "active_sessions": 45, "concurrent_requests": 23}', '{"sampling_rate": "1s", "aggregation": "5min"}', NOW() + INTERVAL '2 minutes');

-- Generate sample system health data
INSERT INTO system_health (
    service_name, health_status, response_time_ms, cpu_usage_percent, 
    memory_usage_percent, disk_usage_percent, active_connections, 
    error_rate_percent, additional_metrics
) VALUES
('backend-api', 'healthy', 245, 45.2, 62.8, 34.1, 45, 0.5, '{"uptime": "15d 4h 23m", "version": "1.2.3", "last_deployment": "2024-01-10T14:30:00Z"}'),
('mysql-primary', 'healthy', 12, 25.1, 78.3, 45.6, 25, 0.0, '{"replication_lag": "0ms", "slow_queries": 2, "deadlocks": 0}'),
('postgresql-analytics', 'healthy', 18, 18.7, 56.2, 23.4, 12, 0.0, '{"query_performance": "good", "cache_hit_ratio": 0.94}'),
('redis-cache', 'healthy', 3, 8.4, 12.1, 15.2, 145, 0.0, '{"hit_rate": 0.89, "evicted_keys": 0, "memory_fragmentation": 1.12}'),
('nginx-proxy', 'healthy', 5, 12.3, 8.7, 22.1, 234, 0.1, '{"requests_per_second": 125.5, "upstream_response_time": "245ms"}'),
('websocket-service', 'warning', 156, 72.4, 45.1, 34.1, 67, 1.2, '{"active_connections": 67, "message_queue_size": 234, "last_heartbeat": "30s"}');

-- Generate sample error logs
INSERT INTO error_logs (
    error_level, error_message, error_code, stack_trace, service_name, 
    endpoint, http_method, http_status_code, user_id, session_id, 
    request_id, user_agent, ip_address, additional_context, occurred_at
) VALUES
('warning', 'Slow database query detected', 'SLOW_QUERY_001', 'at DatabaseConnection.query (db.js:45)\n    at OrderService.getOrders (orders.js:23)', 'backend-api', '/api/orders', 'GET', 200, 3, uuid_generate_v4(), uuid_generate_v4(), 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', '192.168.1.102', '{"query_time": 1245, "threshold": 1000, "query": "SELECT * FROM orders WHERE..."}', NOW() - INTERVAL '2 hours'),

('error', 'Database connection timeout', 'DB_TIMEOUT_002', 'at DatabasePool.connect (pool.js:67)\n    at UserService.createUser (users.js:15)', 'backend-api', '/api/users', 'POST', 500, NULL, uuid_generate_v4(), uuid_generate_v4(), 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', '192.168.1.105', '{"timeout": 30000, "pool_size": 10, "active_connections": 10}', NOW() - INTERVAL '4 hours'),

('critical', 'Memory usage exceeded threshold', 'MEM_CRITICAL_003', NULL, 'system', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '10.0.1.50', '{"memory_usage": 95.2, "threshold": 90.0, "available_memory": "245MB"}', NOW() - INTERVAL '6 hours'),

('warning', 'High response time detected', 'PERF_WARNING_004', NULL, 'nginx-proxy', '/api/dashboard', 'GET', 200, 1, uuid_generate_v4(), uuid_generate_v4(), 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X)', '192.168.1.100', '{"response_time": 2500, "threshold": 2000, "upstream": "backend-api"}', NOW() - INTERVAL '1 hour'),

('error', 'WebSocket connection failed', 'WS_ERROR_005', 'at SocketService.connect (socket.js:34)\n    at Dashboard.componentDidMount (Dashboard.js:56)', 'websocket-service', '/socket.io/', 'GET', 500, 2, uuid_generate_v4(), uuid_generate_v4(), 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36', '192.168.1.101', '{"connection_attempt": 3, "last_error": "Connection refused", "retry_in": "5s"}', NOW() - INTERVAL '30 minutes');

-- Generate sample user sessions analytics
INSERT INTO user_sessions_analytics (
    session_id, user_id, started_at, ended_at, page_views, events_count,
    device_type, browser, operating_system, country, city, referrer_domain,
    entry_page, exit_page, is_bounce, conversion_events
) VALUES
(uuid_generate_v4(), 1, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '1 hour 45 minutes', 5, 12, 'desktop', 'Chrome', 'Windows', 'US', 'New York', 'google.com', '/dashboard', '/analytics', false, '["page_view", "button_click", "form_submit"]'),
(uuid_generate_v4(), 2, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '2 hours 50 minutes', 3, 7, 'mobile', 'Safari', 'iOS', 'CA', 'Toronto', 'github.com', '/dashboard', '/dashboard', false, '["page_view", "scroll"]'),
(uuid_generate_v4(), 3, NOW() - INTERVAL '4 hours', NOW() - INTERVAL '3 hours 30 minutes', 8, 15, 'tablet', 'Firefox', 'Android', 'GB', 'London', 'linkedin.com', '/monitoring', '/settings', false, '["page_view", "filter_update", "data_export"]'),
(uuid_generate_v4(), NULL, NOW() - INTERVAL '1 hour', NOW() - INTERVAL '59 minutes', 1, 1, 'desktop', 'Edge', 'Windows', 'DE', 'Berlin', 'linkedin.com', '/', '/', true, '[]'),
(uuid_generate_v4(), 4, NOW() - INTERVAL '5 hours', NOW() - INTERVAL '4 hours 20 minutes', 12, 28, 'desktop', 'Chrome', 'macOS', 'US', 'San Francisco', 'direct', '/dashboard', '/monitoring', false, '["page_view", "chart_interaction", "data_export", "settings_change"]'),
(uuid_generate_v4(), 5, NOW() - INTERVAL '6 hours', NOW() - INTERVAL '5 hours 45 minutes', 4, 9, 'mobile', 'Chrome', 'Android', 'FR', 'Paris', 'twitter.com', '/analytics', '/dashboard', false, '["page_view", "filter_change"]');

-- Generate sample A/B test results
INSERT INTO ab_test_results (test_name, variant_name, user_id, session_id, event_type, event_value, additional_data) VALUES
('dashboard_layout_v2', 'control', 1, uuid_generate_v4(), 'conversion', 1.0, '{"converted": true, "time_to_convert": 245}'),
('dashboard_layout_v2', 'variant_a', 2, uuid_generate_v4(), 'conversion', 0.0, '{"converted": false, "exit_point": "analytics_page"}'),
('dashboard_layout_v2', 'variant_b', 3, uuid_generate_v4(), 'conversion', 1.0, '{"converted": true, "time_to_convert": 189}'),
('button_color_test', 'blue', 4, uuid_generate_v4(), 'click', 1.0, '{"element": "cta_button", "position": "header"}'),
('button_color_test', 'green', 5, uuid_generate_v4(), 'click', 1.0, '{"element": "cta_button", "position": "header"}'),
('loading_animation', 'spinner', 1, uuid_generate_v4(), 'engagement', 8.5, '{"engagement_score": 8.5, "bounce": false}'),
('loading_animation', 'progress_bar', 2, uuid_generate_v4(), 'engagement', 7.2, '{"engagement_score": 7.2, "bounce": false}');

-- Generate sample BI aggregations
INSERT INTO bi_aggregations (
    aggregation_type, time_period, period_start, period_end, dimensions, metrics
) VALUES
('user_activity', 'daily', DATE_TRUNC('day', NOW() - INTERVAL '1 day'), DATE_TRUNC('day', NOW()), 
 '{"date": "2024-01-15", "device_type": "desktop"}', 
 '{"active_users": 145, "page_views": 1250, "avg_session_duration": 342}'),

('user_activity', 'daily', DATE_TRUNC('day', NOW() - INTERVAL '1 day'), DATE_TRUNC('day', NOW()), 
 '{"date": "2024-01-15", "device_type": "mobile"}', 
 '{"active_users": 89, "page_views": 456, "avg_session_duration": 186}'),

('performance', 'hourly', DATE_TRUNC('hour', NOW() - INTERVAL '1 hour'), DATE_TRUNC('hour', NOW()),
 '{"service": "backend-api", "hour": "14"}',
 '{"avg_response_time": 245.6, "request_count": 1250, "error_rate": 0.5}'),

('business', 'daily', DATE_TRUNC('day', NOW() - INTERVAL '1 day'), DATE_TRUNC('day', NOW()),
 '{"date": "2024-01-15", "channel": "web"}',
 '{"revenue": 15467.89, "orders": 67, "conversion_rate": 3.4, "avg_order_value": 230.87}');

-- Generate sample data quality metrics
INSERT INTO data_quality_metrics (
    table_name, metric_name, metric_value, threshold_min, threshold_max, status, details
) VALUES
('analytics_events', 'completeness_rate', 98.5, 95.0, 100.0, 'pass', '{"missing_fields": ["country: 1.2%", "city: 0.3%"], "total_records": 15678}'),
('analytics_events', 'duplicate_rate', 0.8, 0.0, 2.0, 'pass', '{"duplicate_sessions": 12, "total_sessions": 1456}'),
('performance_metrics', 'timeliness', 99.2, 95.0, 100.0, 'pass', '{"late_arrivals": 45, "total_metrics": 5678, "avg_delay": "12s"}'),
('user_sessions_analytics', 'accuracy_rate', 97.8, 90.0, 100.0, 'pass', '{"validation_errors": 34, "total_sessions": 1543}'),
('real_time_data', 'freshness', 94.2, 95.0, 100.0, 'warning', '{"stale_records": 23, "total_records": 398, "max_age": "15m"}');

-- Generate some recent performance metrics for real-time dashboard
INSERT INTO performance_metrics (metric_name, metric_type, value, unit, source, tags, timestamp) VALUES
-- Recent CPU metrics
('cpu_usage', 'gauge', 42.1, 'percent', 'system', '{"hostname": "web-server-1"}', NOW() - INTERVAL '1 minute'),
('cpu_usage', 'gauge', 45.8, 'percent', 'system', '{"hostname": "web-server-1"}', NOW() - INTERVAL '2 minutes'),
('cpu_usage', 'gauge', 38.9, 'percent', 'system', '{"hostname": "web-server-1"}', NOW() - INTERVAL '3 minutes'),

-- Recent memory metrics
('memory_usage', 'gauge', 65.2, 'percent', 'system', '{"hostname": "web-server-1"}', NOW() - INTERVAL '1 minute'),
('memory_usage', 'gauge', 63.7, 'percent', 'system', '{"hostname": "web-server-1"}', NOW() - INTERVAL '2 minutes'),
('memory_usage', 'gauge', 62.1, 'percent', 'system', '{"hostname": "web-server-1"}', NOW() - INTERVAL '3 minutes'),

-- Recent response time metrics
('response_time', 'histogram', 234.0, 'milliseconds', 'application', '{"endpoint": "/api/dashboard"}', NOW() - INTERVAL '30 seconds'),
('response_time', 'histogram', 267.0, 'milliseconds', 'application', '{"endpoint": "/api/dashboard"}', NOW() - INTERVAL '1 minute'),
('response_time', 'histogram', 189.0, 'milliseconds', 'application', '{"endpoint": "/api/dashboard"}', NOW() - INTERVAL '90 seconds'),

-- Recent request counts
('request_count', 'counter', 45, 'requests', 'application', '{"endpoint": "/api/dashboard", "status": "200"}', NOW() - INTERVAL '1 minute'),
('request_count', 'counter', 52, 'requests', 'application', '{"endpoint": "/api/analytics", "status": "200"}', NOW() - INTERVAL '1 minute'),
('request_count', 'counter', 23, 'requests', 'application', '{"endpoint": "/api/monitoring", "status": "200"}', NOW() - INTERVAL '1 minute');

-- Call the function to generate additional sample data
SELECT generate_sample_analytics_data();

-- Refresh materialized views
SELECT refresh_analytics_views();

-- Update statistics for better query performance
ANALYZE analytics_events;
ANALYZE performance_metrics;
ANALYZE real_time_data;
ANALYZE system_health;
ANALYZE user_sessions_analytics;

COMMIT;

-- Display summary of inserted data
SELECT 'PostgreSQL Analytics Data Seed Summary' as summary;

SELECT 
    'analytics_events' as table_name, 
    COUNT(*) as record_count,
    MIN(timestamp) as earliest_record,
    MAX(timestamp) as latest_record
FROM analytics_events

UNION ALL

SELECT 
    'performance_metrics' as table_name, 
    COUNT(*) as record_count,
    MIN(timestamp) as earliest_record,
    MAX(timestamp) as latest_record
FROM performance_metrics

UNION ALL

SELECT 
    'real_time_data' as table_name, 
    COUNT(*) as record_count,
    MIN(timestamp) as earliest_record,
    MAX(timestamp) as latest_record
FROM real_time_data

UNION ALL

SELECT 
    'system_health' as table_name, 
    COUNT(*) as record_count,
    MIN(checked_at) as earliest_record,
    MAX(checked_at) as latest_record
FROM system_health

UNION ALL

SELECT 
    'user_sessions_analytics' as table_name, 
    COUNT(*) as record_count,
    MIN(started_at) as earliest_record,
    MAX(started_at) as latest_record
FROM user_sessions_analytics

UNION ALL

SELECT 
    'error_logs' as table_name, 
    COUNT(*) as record_count,
    MIN(occurred_at) as earliest_record,
    MAX(occurred_at) as latest_record
FROM error_logs;

-- Show sample real-time dashboard data
SELECT * FROM real_time_dashboard;

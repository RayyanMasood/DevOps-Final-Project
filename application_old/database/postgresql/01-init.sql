-- PostgreSQL Analytics Database Initialization Script
-- Creates tables for analytics, metrics, and real-time data

\c devops_analytics;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Analytics Events table
CREATE TABLE analytics_events (
    id BIGSERIAL PRIMARY KEY,
    session_id UUID NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    event_name VARCHAR(200) NOT NULL,
    page_url TEXT,
    referrer_url TEXT,
    device_type VARCHAR(50),
    browser VARCHAR(100),
    operating_system VARCHAR(100),
    screen_resolution VARCHAR(20),
    country VARCHAR(10),
    city VARCHAR(100),
    event_data JSONB,
    user_id INTEGER,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes for performance
    INDEX idx_analytics_events_session_id (session_id),
    INDEX idx_analytics_events_event_type (event_type),
    INDEX idx_analytics_events_timestamp (timestamp),
    INDEX idx_analytics_events_user_id (user_id),
    INDEX idx_analytics_events_country (country),
    INDEX idx_analytics_events_device_type (device_type),
    INDEX idx_analytics_events_event_data (event_data) USING GIN
);

-- Performance Metrics table
CREATE TABLE performance_metrics (
    id BIGSERIAL PRIMARY KEY,
    metric_name VARCHAR(200) NOT NULL,
    metric_type VARCHAR(50) NOT NULL, -- gauge, counter, histogram, summary
    value DOUBLE PRECISION NOT NULL,
    unit VARCHAR(50),
    source VARCHAR(100) NOT NULL,
    tags JSONB,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes for performance
    INDEX idx_performance_metrics_name (metric_name),
    INDEX idx_performance_metrics_type (metric_type),
    INDEX idx_performance_metrics_source (source),
    INDEX idx_performance_metrics_timestamp (timestamp),
    INDEX idx_performance_metrics_tags (tags) USING GIN,
    INDEX idx_performance_metrics_name_timestamp (metric_name, timestamp)
);

-- Real-time Data table
CREATE TABLE real_time_data (
    id BIGSERIAL PRIMARY KEY,
    data_type VARCHAR(100) NOT NULL,
    data_source VARCHAR(100) NOT NULL,
    value JSONB NOT NULL,
    metadata JSONB,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    
    -- Indexes for performance
    INDEX idx_real_time_data_type (data_type),
    INDEX idx_real_time_data_source (data_source),
    INDEX idx_real_time_data_timestamp (timestamp),
    INDEX idx_real_time_data_expires_at (expires_at),
    INDEX idx_real_time_data_value (value) USING GIN
);

-- System Health table
CREATE TABLE system_health (
    id BIGSERIAL PRIMARY KEY,
    service_name VARCHAR(100) NOT NULL,
    health_status VARCHAR(20) NOT NULL, -- healthy, warning, critical, unknown
    response_time_ms INTEGER,
    cpu_usage_percent DOUBLE PRECISION,
    memory_usage_percent DOUBLE PRECISION,
    disk_usage_percent DOUBLE PRECISION,
    active_connections INTEGER,
    error_rate_percent DOUBLE PRECISION,
    additional_metrics JSONB,
    checked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_system_health_service (service_name),
    INDEX idx_system_health_status (health_status),
    INDEX idx_system_health_checked_at (checked_at),
    INDEX idx_system_health_service_time (service_name, checked_at)
);

-- Error Logs table
CREATE TABLE error_logs (
    id BIGSERIAL PRIMARY KEY,
    error_level VARCHAR(20) NOT NULL, -- error, warning, critical
    error_message TEXT NOT NULL,
    error_code VARCHAR(50),
    stack_trace TEXT,
    service_name VARCHAR(100),
    endpoint VARCHAR(500),
    http_method VARCHAR(10),
    http_status_code INTEGER,
    user_id INTEGER,
    session_id UUID,
    request_id UUID,
    user_agent TEXT,
    ip_address INET,
    additional_context JSONB,
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolved_at TIMESTAMP WITH TIME ZONE,
    
    -- Indexes
    INDEX idx_error_logs_level (error_level),
    INDEX idx_error_logs_service (service_name),
    INDEX idx_error_logs_occurred_at (occurred_at),
    INDEX idx_error_logs_http_status (http_status_code),
    INDEX idx_error_logs_user_id (user_id),
    INDEX idx_error_logs_unresolved (resolved_at) WHERE resolved_at IS NULL
);

-- User Sessions Analytics table
CREATE TABLE user_sessions_analytics (
    id BIGSERIAL PRIMARY KEY,
    session_id UUID UNIQUE NOT NULL,
    user_id INTEGER,
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ended_at TIMESTAMP WITH TIME ZONE,
    duration_seconds INTEGER GENERATED ALWAYS AS (
        CASE 
            WHEN ended_at IS NOT NULL 
            THEN EXTRACT(EPOCH FROM (ended_at - started_at))::INTEGER
            ELSE NULL
        END
    ) STORED,
    page_views INTEGER DEFAULT 0,
    events_count INTEGER DEFAULT 0,
    device_type VARCHAR(50),
    browser VARCHAR(100),
    operating_system VARCHAR(100),
    country VARCHAR(10),
    city VARCHAR(100),
    referrer_domain VARCHAR(200),
    entry_page TEXT,
    exit_page TEXT,
    is_bounce BOOLEAN DEFAULT FALSE,
    conversion_events JSONB,
    
    -- Indexes
    INDEX idx_user_sessions_analytics_session_id (session_id),
    INDEX idx_user_sessions_analytics_user_id (user_id),
    INDEX idx_user_sessions_analytics_started_at (started_at),
    INDEX idx_user_sessions_analytics_duration (duration_seconds),
    INDEX idx_user_sessions_analytics_country (country),
    INDEX idx_user_sessions_analytics_device (device_type)
);

-- A/B Test Results table
CREATE TABLE ab_test_results (
    id BIGSERIAL PRIMARY KEY,
    test_name VARCHAR(200) NOT NULL,
    variant_name VARCHAR(100) NOT NULL,
    user_id INTEGER,
    session_id UUID,
    event_type VARCHAR(100) NOT NULL,
    event_value DOUBLE PRECISION,
    additional_data JSONB,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_ab_test_results_test_name (test_name),
    INDEX idx_ab_test_results_variant (variant_name),
    INDEX idx_ab_test_results_recorded_at (recorded_at),
    INDEX idx_ab_test_results_test_variant (test_name, variant_name)
);

-- Business Intelligence Aggregations table
CREATE TABLE bi_aggregations (
    id BIGSERIAL PRIMARY KEY,
    aggregation_type VARCHAR(100) NOT NULL,
    time_period VARCHAR(50) NOT NULL, -- hourly, daily, weekly, monthly
    period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    dimensions JSONB NOT NULL,
    metrics JSONB NOT NULL,
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_bi_aggregations_type (aggregation_type),
    INDEX idx_bi_aggregations_period (time_period),
    INDEX idx_bi_aggregations_start (period_start),
    INDEX idx_bi_aggregations_type_period (aggregation_type, time_period, period_start),
    INDEX idx_bi_aggregations_dimensions (dimensions) USING GIN
);

-- Data Quality Metrics table
CREATE TABLE data_quality_metrics (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DOUBLE PRECISION NOT NULL,
    threshold_min DOUBLE PRECISION,
    threshold_max DOUBLE PRECISION,
    status VARCHAR(20) NOT NULL, -- pass, warning, fail
    details JSONB,
    checked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_data_quality_table (table_name),
    INDEX idx_data_quality_metric (metric_name),
    INDEX idx_data_quality_status (status),
    INDEX idx_data_quality_checked_at (checked_at)
);

-- Create partitioned table for analytics events (for better performance with large datasets)
CREATE TABLE analytics_events_partitioned (
    id BIGSERIAL,
    session_id UUID NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    event_name VARCHAR(200) NOT NULL,
    page_url TEXT,
    referrer_url TEXT,
    device_type VARCHAR(50),
    browser VARCHAR(100),
    operating_system VARCHAR(100),
    screen_resolution VARCHAR(20),
    country VARCHAR(10),
    city VARCHAR(100),
    event_data JSONB,
    user_id INTEGER,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
) PARTITION BY RANGE (timestamp);

-- Create monthly partitions for current and next month
CREATE TABLE analytics_events_y2024m01 PARTITION OF analytics_events_partitioned
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE analytics_events_y2024m02 PARTITION OF analytics_events_partitioned
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

CREATE TABLE analytics_events_y2024m03 PARTITION OF analytics_events_partitioned
    FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');

-- Create views for common analytics queries
CREATE VIEW daily_active_users AS
SELECT 
    DATE(timestamp) as date,
    COUNT(DISTINCT user_id) as active_users,
    COUNT(DISTINCT session_id) as unique_sessions,
    COUNT(*) as total_events
FROM analytics_events 
WHERE user_id IS NOT NULL
GROUP BY DATE(timestamp)
ORDER BY date DESC;

CREATE VIEW popular_pages AS
SELECT 
    page_url,
    COUNT(*) as page_views,
    COUNT(DISTINCT session_id) as unique_visitors,
    COUNT(DISTINCT user_id) as unique_users
FROM analytics_events 
WHERE event_type = 'page_view' 
  AND page_url IS NOT NULL
  AND timestamp >= NOW() - INTERVAL '7 days'
GROUP BY page_url
ORDER BY page_views DESC;

CREATE VIEW device_analytics AS
SELECT 
    device_type,
    browser,
    operating_system,
    COUNT(DISTINCT session_id) as sessions,
    COUNT(DISTINCT user_id) as users,
    AVG(
        CASE 
            WHEN usa.duration_seconds IS NOT NULL 
            THEN usa.duration_seconds 
            ELSE NULL 
        END
    ) as avg_session_duration
FROM analytics_events ae
LEFT JOIN user_sessions_analytics usa ON ae.session_id = usa.session_id
WHERE ae.timestamp >= NOW() - INTERVAL '30 days'
GROUP BY device_type, browser, operating_system
ORDER BY sessions DESC;

CREATE VIEW real_time_dashboard AS
SELECT 
    'active_users' as metric,
    COUNT(DISTINCT user_id) as value,
    NOW() as timestamp
FROM analytics_events 
WHERE timestamp >= NOW() - INTERVAL '5 minutes'

UNION ALL

SELECT 
    'page_views' as metric,
    COUNT(*) as value,
    NOW() as timestamp
FROM analytics_events 
WHERE event_type = 'page_view' 
  AND timestamp >= NOW() - INTERVAL '1 hour'

UNION ALL

SELECT 
    'bounce_rate' as metric,
    (COUNT(CASE WHEN is_bounce THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0)) as value,
    NOW() as timestamp
FROM user_sessions_analytics 
WHERE started_at >= NOW() - INTERVAL '24 hours';

-- Create functions for data processing
CREATE OR REPLACE FUNCTION update_session_analytics()
RETURNS TRIGGER AS $$
BEGIN
    -- Update or insert session analytics
    INSERT INTO user_sessions_analytics (
        session_id, user_id, started_at, device_type, browser, 
        operating_system, country, city, entry_page
    )
    VALUES (
        NEW.session_id, NEW.user_id, NEW.timestamp, NEW.device_type,
        NEW.browser, NEW.operating_system, NEW.country, NEW.city, NEW.page_url
    )
    ON CONFLICT (session_id) DO UPDATE SET
        ended_at = NEW.timestamp,
        page_views = user_sessions_analytics.page_views + 
                    CASE WHEN NEW.event_type = 'page_view' THEN 1 ELSE 0 END,
        events_count = user_sessions_analytics.events_count + 1,
        exit_page = NEW.page_url;
        
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update session analytics
CREATE TRIGGER trigger_update_session_analytics
    AFTER INSERT ON analytics_events
    FOR EACH ROW
    EXECUTE FUNCTION update_session_analytics();

-- Create function to clean old data
CREATE OR REPLACE FUNCTION cleanup_old_data()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER := 0;
BEGIN
    -- Delete analytics events older than 1 year
    DELETE FROM analytics_events 
    WHERE timestamp < NOW() - INTERVAL '1 year';
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Delete real-time data that has expired
    DELETE FROM real_time_data 
    WHERE expires_at IS NOT NULL AND expires_at < NOW();
    
    -- Delete old performance metrics (keep 6 months)
    DELETE FROM performance_metrics 
    WHERE timestamp < NOW() - INTERVAL '6 months';
    
    -- Delete resolved error logs older than 3 months
    DELETE FROM error_logs 
    WHERE resolved_at IS NOT NULL AND resolved_at < NOW() - INTERVAL '3 months';
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create materialized view for performance
CREATE MATERIALIZED VIEW hourly_metrics AS
SELECT 
    DATE_TRUNC('hour', timestamp) as hour,
    metric_name,
    metric_type,
    source,
    AVG(value) as avg_value,
    MIN(value) as min_value,
    MAX(value) as max_value,
    COUNT(*) as sample_count
FROM performance_metrics
GROUP BY DATE_TRUNC('hour', timestamp), metric_name, metric_type, source
ORDER BY hour DESC, metric_name;

-- Create index on materialized view
CREATE INDEX idx_hourly_metrics_hour ON hourly_metrics(hour);
CREATE INDEX idx_hourly_metrics_name ON hourly_metrics(metric_name);

-- Create function to refresh materialized views
CREATE OR REPLACE FUNCTION refresh_analytics_views()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW hourly_metrics;
    -- Add more materialized views here as needed
END;
$$ LANGUAGE plpgsql;

-- Create stored procedures for common analytics operations
CREATE OR REPLACE FUNCTION get_user_journey(user_session_id UUID)
RETURNS TABLE (
    event_order INTEGER,
    event_type VARCHAR(100),
    event_name VARCHAR(200),
    page_url TEXT,
    timestamp TIMESTAMP WITH TIME ZONE,
    event_data JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ROW_NUMBER() OVER (ORDER BY ae.timestamp)::INTEGER as event_order,
        ae.event_type,
        ae.event_name,
        ae.page_url,
        ae.timestamp,
        ae.event_data
    FROM analytics_events ae
    WHERE ae.session_id = user_session_id
    ORDER BY ae.timestamp;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_funnel_analysis(
    funnel_steps TEXT[],
    start_date TIMESTAMP WITH TIME ZONE DEFAULT NOW() - INTERVAL '30 days',
    end_date TIMESTAMP WITH TIME ZONE DEFAULT NOW()
)
RETURNS TABLE (
    step_name TEXT,
    step_order INTEGER,
    users_count BIGINT,
    conversion_rate DOUBLE PRECISION
) AS $$
DECLARE
    total_users BIGINT;
BEGIN
    -- Get total users who started the funnel
    SELECT COUNT(DISTINCT user_id) INTO total_users
    FROM analytics_events
    WHERE event_name = funnel_steps[1]
      AND timestamp BETWEEN start_date AND end_date
      AND user_id IS NOT NULL;
    
    -- Return funnel analysis
    RETURN QUERY
    WITH funnel_data AS (
        SELECT 
            unnest(funnel_steps) as step_name,
            generate_subscripts(funnel_steps, 1) as step_order
    )
    SELECT 
        fd.step_name,
        fd.step_order,
        COUNT(DISTINCT ae.user_id) as users_count,
        CASE 
            WHEN total_users > 0 
            THEN (COUNT(DISTINCT ae.user_id) * 100.0 / total_users)
            ELSE 0.0
        END as conversion_rate
    FROM funnel_data fd
    LEFT JOIN analytics_events ae ON ae.event_name = fd.step_name
        AND ae.timestamp BETWEEN start_date AND end_date
        AND ae.user_id IS NOT NULL
    GROUP BY fd.step_name, fd.step_order
    ORDER BY fd.step_order;
END;
$$ LANGUAGE plpgsql;

-- Create indexes for better query performance
CREATE INDEX CONCURRENTLY idx_analytics_events_user_timestamp 
ON analytics_events(user_id, timestamp) 
WHERE user_id IS NOT NULL;

CREATE INDEX CONCURRENTLY idx_analytics_events_page_timestamp 
ON analytics_events(page_url, timestamp) 
WHERE page_url IS NOT NULL;

CREATE INDEX CONCURRENTLY idx_performance_metrics_composite 
ON performance_metrics(metric_name, source, timestamp DESC);

-- Create function to generate sample data (for testing)
CREATE OR REPLACE FUNCTION generate_sample_analytics_data()
RETURNS VOID AS $$
DECLARE
    i INTEGER;
    sample_session_id UUID;
    sample_user_id INTEGER;
BEGIN
    -- This function will be called from the seed script
    FOR i IN 1..1000 LOOP
        sample_session_id := uuid_generate_v4();
        sample_user_id := (random() * 10)::INTEGER + 1;
        
        INSERT INTO analytics_events (
            session_id, user_id, event_type, event_name, page_url,
            device_type, browser, country, timestamp
        ) VALUES (
            sample_session_id,
            sample_user_id,
            (ARRAY['page_view', 'click', 'scroll', 'form_submit'])[ceil(random() * 4)],
            (ARRAY['home_view', 'product_view', 'add_to_cart', 'checkout'])[ceil(random() * 4)],
            (ARRAY['/home', '/products', '/cart', '/checkout', '/profile'])[ceil(random() * 5)],
            (ARRAY['desktop', 'mobile', 'tablet'])[ceil(random() * 3)],
            (ARRAY['Chrome', 'Firefox', 'Safari', 'Edge'])[ceil(random() * 4)],
            (ARRAY['US', 'CA', 'GB', 'DE', 'FR'])[ceil(random() * 5)],
            NOW() - (random() * INTERVAL '30 days')
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMIT;

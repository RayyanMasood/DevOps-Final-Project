-- Enhanced PostgreSQL Analytics Tables Migration
-- Adds advanced analytics tables and structures optimized for business intelligence

-- Connect to the analytics database
\c devops_analytics;

-- User Journey Analytics
CREATE TABLE IF NOT EXISTS user_journeys (
    id BIGSERIAL PRIMARY KEY,
    session_id VARCHAR(100) NOT NULL,
    user_id INTEGER,
    journey_start TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    journey_end TIMESTAMP WITH TIME ZONE,
    total_events INTEGER DEFAULT 0,
    pages_visited INTEGER DEFAULT 0,
    conversion_goal VARCHAR(100),
    converted BOOLEAN DEFAULT FALSE,
    conversion_value DECIMAL(10, 2),
    device_info JSONB,
    utm_source VARCHAR(100),
    utm_medium VARCHAR(100),
    utm_campaign VARCHAR(100),
    referrer_url TEXT,
    landing_page VARCHAR(500),
    exit_page VARCHAR(500)
);

-- Create indexes for user journeys
CREATE INDEX idx_user_journeys_session ON user_journeys(session_id);
CREATE INDEX idx_user_journeys_user ON user_journeys(user_id);
CREATE INDEX idx_user_journeys_start ON user_journeys(journey_start);
CREATE INDEX idx_user_journeys_conversion ON user_journeys(converted, conversion_goal);
CREATE INDEX idx_user_journeys_utm ON user_journeys(utm_source, utm_medium, utm_campaign);

-- Funnel Analysis
CREATE TABLE IF NOT EXISTS conversion_funnels (
    id BIGSERIAL PRIMARY KEY,
    funnel_name VARCHAR(200) NOT NULL,
    step_number INTEGER NOT NULL,
    step_name VARCHAR(200) NOT NULL,
    step_criteria JSONB, -- Conditions that define this step
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_conversion_funnels_name ON conversion_funnels(funnel_name);
CREATE INDEX idx_conversion_funnels_step ON conversion_funnels(funnel_name, step_number);

-- Funnel Performance Tracking
CREATE TABLE IF NOT EXISTS funnel_performance (
    id BIGSERIAL PRIMARY KEY,
    funnel_name VARCHAR(200) NOT NULL,
    date_recorded DATE NOT NULL,
    step_number INTEGER NOT NULL,
    users_entered INTEGER DEFAULT 0,
    users_completed INTEGER DEFAULT 0,
    conversion_rate DECIMAL(5, 4) DEFAULT 0.0000,
    avg_time_to_convert INTERVAL,
    drop_off_rate DECIMAL(5, 4) DEFAULT 0.0000
);

CREATE INDEX idx_funnel_performance_funnel ON funnel_performance(funnel_name);
CREATE INDEX idx_funnel_performance_date ON funnel_performance(date_recorded);
CREATE UNIQUE INDEX idx_funnel_performance_unique ON funnel_performance(funnel_name, date_recorded, step_number);

-- Cohort Analysis
CREATE TABLE IF NOT EXISTS user_cohorts (
    id BIGSERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    cohort_month DATE NOT NULL, -- First month user was active
    period_number INTEGER NOT NULL, -- Months since cohort_month (0, 1, 2, ...)
    is_active BOOLEAN DEFAULT FALSE,
    revenue DECIMAL(12, 2) DEFAULT 0.00,
    orders_count INTEGER DEFAULT 0,
    last_activity TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_user_cohorts_user ON user_cohorts(user_id);
CREATE INDEX idx_user_cohorts_cohort ON user_cohorts(cohort_month);
CREATE INDEX idx_user_cohorts_period ON user_cohorts(period_number);
CREATE UNIQUE INDEX idx_user_cohorts_unique ON user_cohorts(user_id, cohort_month, period_number);

-- A/B Testing Framework
CREATE TABLE IF NOT EXISTS ab_tests (
    id SERIAL PRIMARY KEY,
    test_name VARCHAR(200) NOT NULL UNIQUE,
    description TEXT,
    start_date DATE NOT NULL,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'draft', -- draft, running, paused, completed
    hypothesis TEXT,
    success_metric VARCHAR(100),
    confidence_level DECIMAL(3, 2) DEFAULT 0.95,
    min_sample_size INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_ab_tests_status ON ab_tests(status);
CREATE INDEX idx_ab_tests_dates ON ab_tests(start_date, end_date);

-- A/B Test Variants
CREATE TABLE IF NOT EXISTS ab_test_variants (
    id SERIAL PRIMARY KEY,
    test_id INTEGER NOT NULL REFERENCES ab_tests(id) ON DELETE CASCADE,
    variant_name VARCHAR(100) NOT NULL,
    variant_description TEXT,
    traffic_allocation DECIMAL(3, 2) DEFAULT 0.50, -- Percentage of traffic
    is_control BOOLEAN DEFAULT FALSE,
    configuration JSONB
);

CREATE INDEX idx_ab_test_variants_test ON ab_test_variants(test_id);
CREATE UNIQUE INDEX idx_ab_test_variants_unique ON ab_test_variants(test_id, variant_name);

-- A/B Test Results
CREATE TABLE IF NOT EXISTS ab_test_results (
    id BIGSERIAL PRIMARY KEY,
    test_id INTEGER NOT NULL REFERENCES ab_tests(id) ON DELETE CASCADE,
    variant_id INTEGER NOT NULL REFERENCES ab_test_variants(id) ON DELETE CASCADE,
    user_id INTEGER,
    session_id VARCHAR(100),
    event_type VARCHAR(100), -- 'exposure', 'conversion', 'interaction'
    event_value DECIMAL(10, 2),
    metadata JSONB,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_ab_test_results_test ON ab_test_results(test_id);
CREATE INDEX idx_ab_test_results_variant ON ab_test_results(variant_id);
CREATE INDEX idx_ab_test_results_event ON ab_test_results(event_type);
CREATE INDEX idx_ab_test_results_timestamp ON ab_test_results(timestamp);

-- Revenue Attribution
CREATE TABLE IF NOT EXISTS revenue_attribution (
    id BIGSERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    user_id INTEGER,
    session_id VARCHAR(100),
    attribution_model VARCHAR(50), -- 'first_touch', 'last_touch', 'linear', 'time_decay'
    channel VARCHAR(100), -- 'organic', 'paid_search', 'social', 'email', 'direct'
    campaign VARCHAR(200),
    touchpoint_position INTEGER, -- Position in customer journey
    attribution_weight DECIMAL(5, 4) DEFAULT 1.0000,
    attributed_revenue DECIMAL(12, 2),
    attributed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_revenue_attribution_order ON revenue_attribution(order_id);
CREATE INDEX idx_revenue_attribution_channel ON revenue_attribution(channel);
CREATE INDEX idx_revenue_attribution_campaign ON revenue_attribution(campaign);
CREATE INDEX idx_revenue_attribution_model ON revenue_attribution(attribution_model);

-- Customer Lifetime Value Predictions
CREATE TABLE IF NOT EXISTS clv_predictions (
    id BIGSERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    prediction_date DATE NOT NULL,
    predicted_clv DECIMAL(12, 2),
    confidence_score DECIMAL(5, 4),
    prediction_horizon_days INTEGER, -- How far into future (e.g., 365 days)
    model_version VARCHAR(50),
    features_used JSONB, -- Features/data points used for prediction
    actual_clv DECIMAL(12, 2), -- Updated as actual data comes in
    prediction_accuracy DECIMAL(5, 4) -- How close prediction was to actual
);

CREATE INDEX idx_clv_predictions_user ON clv_predictions(user_id);
CREATE INDEX idx_clv_predictions_date ON clv_predictions(prediction_date);
CREATE INDEX idx_clv_predictions_model ON clv_predictions(model_version);
CREATE UNIQUE INDEX idx_clv_predictions_unique ON clv_predictions(user_id, prediction_date, prediction_horizon_days);

-- Advanced Performance Metrics with Partitioning
CREATE TABLE performance_metrics_hourly (
    id BIGSERIAL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    metric_type VARCHAR(50),
    value DECIMAL(15, 4),
    unit VARCHAR(50),
    source VARCHAR(100),
    tags JSONB,
    aggregation_type VARCHAR(20) DEFAULT 'avg' -- avg, sum, min, max, count
) PARTITION BY RANGE (timestamp);

-- Create monthly partitions for the last year and next year
DO $$
DECLARE
    start_date DATE;
    end_date DATE;
    partition_name TEXT;
BEGIN
    start_date := date_trunc('month', CURRENT_DATE - INTERVAL '12 months');
    
    WHILE start_date <= CURRENT_DATE + INTERVAL '12 months' LOOP
        end_date := start_date + INTERVAL '1 month';
        partition_name := 'performance_metrics_hourly_' || to_char(start_date, 'YYYY_MM');
        
        EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF performance_metrics_hourly 
                       FOR VALUES FROM (%L) TO (%L)', 
                       partition_name, start_date, end_date);
        
        start_date := end_date;
    END LOOP;
END $$;

-- Indexes for partitioned table
CREATE INDEX idx_perf_metrics_hourly_timestamp ON performance_metrics_hourly(timestamp);
CREATE INDEX idx_perf_metrics_hourly_metric ON performance_metrics_hourly(metric_name);
CREATE INDEX idx_perf_metrics_hourly_source ON performance_metrics_hourly(source);
CREATE INDEX idx_perf_metrics_hourly_tags ON performance_metrics_hourly USING GIN(tags);

-- Real-time Analytics Aggregations
CREATE MATERIALIZED VIEW daily_analytics_summary AS
SELECT 
    DATE(timestamp) as analytics_date,
    COUNT(DISTINCT session_id) as unique_sessions,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(*) as total_events,
    COUNT(*) FILTER (WHERE event_type = 'page_view') as page_views,
    COUNT(*) FILTER (WHERE event_type = 'click') as clicks,
    COUNT(*) FILTER (WHERE event_type = 'form_submit') as form_submissions,
    COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN page_url END) as unique_pages_viewed,
    AVG(CASE WHEN event_type = 'page_view' AND event_data->>'load_time' IS NOT NULL 
             THEN (event_data->>'load_time')::numeric END) as avg_page_load_time
FROM analytics_events
WHERE timestamp >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE(timestamp)
ORDER BY analytics_date DESC;

CREATE UNIQUE INDEX idx_daily_analytics_summary_date ON daily_analytics_summary(analytics_date);

-- Hourly analytics for real-time dashboards
CREATE MATERIALIZED VIEW hourly_analytics_summary AS
SELECT 
    DATE_TRUNC('hour', timestamp) as hour,
    COUNT(DISTINCT session_id) as unique_sessions,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(*) as total_events,
    device_type,
    browser,
    country
FROM analytics_events
WHERE timestamp >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE_TRUNC('hour', timestamp), device_type, browser, country
ORDER BY hour DESC;

CREATE UNIQUE INDEX idx_hourly_analytics_summary ON hourly_analytics_summary(hour, device_type, browser, country);

-- Advanced Analytics Functions
CREATE OR REPLACE FUNCTION calculate_conversion_rate(
    start_date DATE,
    end_date DATE,
    funnel_name VARCHAR DEFAULT NULL
) RETURNS TABLE(
    date_period DATE,
    total_visitors INTEGER,
    conversions INTEGER,
    conversion_rate DECIMAL(5, 4)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        DATE(ae.timestamp) as date_period,
        COUNT(DISTINCT ae.session_id)::INTEGER as total_visitors,
        COUNT(DISTINCT CASE WHEN ae.event_type = 'conversion' THEN ae.session_id END)::INTEGER as conversions,
        CASE 
            WHEN COUNT(DISTINCT ae.session_id) > 0 
            THEN ROUND(COUNT(DISTINCT CASE WHEN ae.event_type = 'conversion' THEN ae.session_id END)::DECIMAL / 
                      COUNT(DISTINCT ae.session_id), 4)
            ELSE 0
        END as conversion_rate
    FROM analytics_events ae
    WHERE ae.timestamp::DATE BETWEEN start_date AND end_date
    GROUP BY DATE(ae.timestamp)
    ORDER BY date_period;
END;
$$ LANGUAGE plpgsql;

-- User Retention Analysis Function
CREATE OR REPLACE FUNCTION calculate_user_retention(
    cohort_start DATE,
    cohort_end DATE
) RETURNS TABLE(
    cohort_month DATE,
    users_count INTEGER,
    period_0 DECIMAL(5, 4),
    period_1 DECIMAL(5, 4),
    period_2 DECIMAL(5, 4),
    period_3 DECIMAL(5, 4),
    period_6 DECIMAL(5, 4),
    period_12 DECIMAL(5, 4)
) AS $$
BEGIN
    RETURN QUERY
    WITH cohort_data AS (
        SELECT 
            uc.cohort_month,
            COUNT(DISTINCT uc.user_id) as total_users,
            uc.period_number,
            COUNT(DISTINCT CASE WHEN uc.is_active THEN uc.user_id END) as active_users
        FROM user_cohorts uc
        WHERE uc.cohort_month BETWEEN cohort_start AND cohort_end
        GROUP BY uc.cohort_month, uc.period_number
    )
    SELECT 
        cd.cohort_month,
        MAX(CASE WHEN cd.period_number = 0 THEN cd.total_users END)::INTEGER as users_count,
        MAX(CASE WHEN cd.period_number = 0 THEN cd.active_users::DECIMAL / cd.total_users END) as period_0,
        MAX(CASE WHEN cd.period_number = 1 THEN cd.active_users::DECIMAL / cd.total_users END) as period_1,
        MAX(CASE WHEN cd.period_number = 2 THEN cd.active_users::DECIMAL / cd.total_users END) as period_2,
        MAX(CASE WHEN cd.period_number = 3 THEN cd.active_users::DECIMAL / cd.total_users END) as period_3,
        MAX(CASE WHEN cd.period_number = 6 THEN cd.active_users::DECIMAL / cd.total_users END) as period_6,
        MAX(CASE WHEN cd.period_number = 12 THEN cd.active_users::DECIMAL / cd.total_users END) as period_12
    FROM cohort_data cd
    GROUP BY cd.cohort_month
    ORDER BY cd.cohort_month;
END;
$$ LANGUAGE plpgsql;

-- Automated Data Refresh Functions
CREATE OR REPLACE FUNCTION refresh_analytics_views() 
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY daily_analytics_summary;
    REFRESH MATERIALIZED VIEW CONCURRENTLY hourly_analytics_summary;
    
    -- Log the refresh
    INSERT INTO real_time_data (data_type, data_value, metadata)
    VALUES ('view_refresh', '1', jsonb_build_object(
        'refreshed_at', NOW(),
        'views', ARRAY['daily_analytics_summary', 'hourly_analytics_summary']
    ));
END;
$$ LANGUAGE plpgsql;

-- Trigger for automatic user journey completion
CREATE OR REPLACE FUNCTION update_user_journey()
RETURNS TRIGGER AS $$
BEGIN
    -- Update journey when conversion event occurs
    IF NEW.event_type = 'conversion' THEN
        UPDATE user_journeys 
        SET 
            converted = TRUE,
            conversion_goal = NEW.event_name,
            conversion_value = COALESCE((NEW.event_data->>'value')::DECIMAL, 0),
            journey_end = NEW.timestamp,
            total_events = total_events + 1
        WHERE session_id = NEW.session_id;
    ELSE
        -- Update journey with regular events
        UPDATE user_journeys 
        SET 
            total_events = total_events + 1,
            pages_visited = CASE 
                WHEN NEW.event_type = 'page_view' THEN pages_visited + 1 
                ELSE pages_visited 
            END,
            exit_page = CASE 
                WHEN NEW.event_type = 'page_view' THEN NEW.page_url 
                ELSE exit_page 
            END
        WHERE session_id = NEW.session_id;
        
        -- Create journey if it doesn't exist
        IF NOT FOUND THEN
            INSERT INTO user_journeys (
                session_id, user_id, journey_start, total_events, pages_visited,
                landing_page, exit_page, device_info
            ) VALUES (
                NEW.session_id, NEW.user_id, NEW.timestamp, 1,
                CASE WHEN NEW.event_type = 'page_view' THEN 1 ELSE 0 END,
                CASE WHEN NEW.event_type = 'page_view' THEN NEW.page_url END,
                CASE WHEN NEW.event_type = 'page_view' THEN NEW.page_url END,
                jsonb_build_object(
                    'device_type', NEW.device_type,
                    'browser', NEW.browser,
                    'operating_system', NEW.operating_system
                )
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_user_journey
    AFTER INSERT ON analytics_events
    FOR EACH ROW
    EXECUTE FUNCTION update_user_journey();

-- Create sample A/B tests
INSERT INTO ab_tests (test_name, description, start_date, status, hypothesis, success_metric) VALUES
('checkout_button_color', 'Test different checkout button colors', CURRENT_DATE, 'running', 'Red button will increase conversions', 'conversion_rate'),
('product_recommendation', 'Test AI vs manual product recommendations', CURRENT_DATE, 'running', 'AI recommendations will increase revenue per visitor', 'revenue_per_visitor')
ON CONFLICT (test_name) DO NOTHING;

-- Create A/B test variants
INSERT INTO ab_test_variants (test_id, variant_name, variant_description, traffic_allocation, is_control) 
SELECT t.id, 'control', 'Original blue button', 0.50, TRUE FROM ab_tests t WHERE t.test_name = 'checkout_button_color'
UNION ALL
SELECT t.id, 'treatment', 'Red button', 0.50, FALSE FROM ab_tests t WHERE t.test_name = 'checkout_button_color'
ON CONFLICT (test_id, variant_name) DO NOTHING;

-- Sample conversion funnels
INSERT INTO conversion_funnels (funnel_name, step_number, step_name, step_criteria) VALUES
('ecommerce_purchase', 1, 'Homepage Visit', '{"event_type": "page_view", "page_url": "/"}'),
('ecommerce_purchase', 2, 'Product View', '{"event_type": "page_view", "page_url": "/products/*"}'),
('ecommerce_purchase', 3, 'Add to Cart', '{"event_type": "click", "element": "add_to_cart"}'),
('ecommerce_purchase', 4, 'Checkout Start', '{"event_type": "page_view", "page_url": "/checkout"}'),
('ecommerce_purchase', 5, 'Purchase Complete', '{"event_type": "conversion", "event_name": "purchase"}')
ON CONFLICT DO NOTHING;

-- Schedule automatic view refreshes (requires pg_cron extension)
-- SELECT cron.schedule('refresh-analytics-views', '*/5 * * * *', 'SELECT refresh_analytics_views();');

COMMIT;

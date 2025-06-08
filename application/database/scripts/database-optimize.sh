#!/bin/bash

# Database Performance Optimization Script
# Analyzes and optimizes MySQL and PostgreSQL performance

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/tunnel-config.env"
LOG_FILE="/tmp/database-optimize.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
}

# Analyze MySQL performance
analyze_mysql_performance() {
    log_info "Analyzing MySQL performance..."
    
    if ! command -v mysql >/dev/null 2>&1 || [[ -z "${MYSQL_USER:-}" || -z "${MYSQL_PASSWORD:-}" ]]; then
        log_warning "MySQL analysis skipped - client or credentials not available"
        return
    fi
    
    local mysql_cmd="mysql -h localhost -P ${LOCAL_MYSQL_PORT:-3307} -u $MYSQL_USER -p$MYSQL_PASSWORD"
    local analysis_file="/tmp/mysql_analysis_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== MySQL Performance Analysis ==="
        echo "Generated: $(date)"
        echo
        
        echo "=== Server Status ==="
        $mysql_cmd -e "SHOW STATUS LIKE 'Uptime%'; SHOW STATUS LIKE 'Questions'; SHOW STATUS LIKE 'Queries';" 2>/dev/null
        echo
        
        echo "=== Connection Statistics ==="
        $mysql_cmd -e "
            SHOW STATUS LIKE 'Threads_connected';
            SHOW STATUS LIKE 'Threads_running';
            SHOW STATUS LIKE 'Max_used_connections';
            SHOW STATUS LIKE 'Aborted_connects';
            SHOW STATUS LIKE 'Aborted_clients';
            SHOW VARIABLES LIKE 'max_connections';
        " 2>/dev/null
        echo
        
        echo "=== Query Cache Performance ==="
        $mysql_cmd -e "
            SHOW STATUS LIKE 'Qcache%';
            SHOW VARIABLES LIKE 'query_cache%';
        " 2>/dev/null
        echo
        
        echo "=== InnoDB Buffer Pool ==="
        $mysql_cmd -e "
            SHOW STATUS LIKE 'Innodb_buffer_pool%';
            SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
        " 2>/dev/null
        echo
        
        echo "=== Slow Query Log ==="
        $mysql_cmd -e "
            SHOW STATUS LIKE 'Slow_queries';
            SHOW VARIABLES LIKE 'slow_query_log%';
            SHOW VARIABLES LIKE 'long_query_time';
        " 2>/dev/null
        echo
        
        echo "=== Table Lock Statistics ==="
        $mysql_cmd -e "
            SHOW STATUS LIKE 'Table_locks%';
            SHOW STATUS LIKE '%lock%';
        " 2>/dev/null
        echo
        
        echo "=== Index Usage Analysis ==="
        $mysql_cmd -e "
            SELECT 
                table_schema,
                table_name,
                index_name,
                non_unique,
                column_name,
                cardinality
            FROM information_schema.statistics 
            WHERE table_schema = 'devops_app'
            ORDER BY table_name, seq_in_index;
        " 2>/dev/null
        echo
        
        echo "=== Table Size Analysis ==="
        $mysql_cmd -e "
            SELECT 
                table_name,
                table_rows,
                ROUND(data_length / 1024 / 1024, 2) as data_size_mb,
                ROUND(index_length / 1024 / 1024, 2) as index_size_mb,
                ROUND((data_length + index_length) / 1024 / 1024, 2) as total_size_mb
            FROM information_schema.tables
            WHERE table_schema = 'devops_app'
            ORDER BY (data_length + index_length) DESC;
        " 2>/dev/null
        echo
        
        echo "=== Recommendations ==="
        
        # Check buffer pool hit ratio
        local buffer_reads=$($mysql_cmd -e "SHOW STATUS LIKE 'Innodb_buffer_pool_reads';" 2>/dev/null | tail -1 | awk '{print $2}')
        local buffer_read_requests=$($mysql_cmd -e "SHOW STATUS LIKE 'Innodb_buffer_pool_read_requests';" 2>/dev/null | tail -1 | awk '{print $2}')
        
        if [[ -n "$buffer_reads" && -n "$buffer_read_requests" && $buffer_read_requests -gt 0 ]]; then
            local hit_ratio=$((100 - (buffer_reads * 100 / buffer_read_requests)))
            echo "Buffer Pool Hit Ratio: $hit_ratio%"
            if [[ $hit_ratio -lt 95 ]]; then
                echo "⚠️  Consider increasing innodb_buffer_pool_size"
            else
                echo "✅ Buffer pool hit ratio is good"
            fi
        fi
        
        # Check slow queries
        local slow_queries=$($mysql_cmd -e "SHOW STATUS LIKE 'Slow_queries';" 2>/dev/null | tail -1 | awk '{print $2}')
        if [[ -n "$slow_queries" && $slow_queries -gt 0 ]]; then
            echo "⚠️  $slow_queries slow queries detected - review and optimize"
        else
            echo "✅ No slow queries detected"
        fi
        
        # Check table locks
        local table_locks_waited=$($mysql_cmd -e "SHOW STATUS LIKE 'Table_locks_waited';" 2>/dev/null | tail -1 | awk '{print $2}')
        local table_locks_immediate=$($mysql_cmd -e "SHOW STATUS LIKE 'Table_locks_immediate';" 2>/dev/null | tail -1 | awk '{print $2}')
        
        if [[ -n "$table_locks_waited" && -n "$table_locks_immediate" && $table_locks_immediate -gt 0 ]]; then
            local lock_ratio=$((table_locks_waited * 100 / (table_locks_waited + table_locks_immediate)))
            if [[ $lock_ratio -gt 5 ]]; then
                echo "⚠️  High table lock contention ($lock_ratio%) - consider optimizing queries"
            else
                echo "✅ Table lock contention is acceptable"
            fi
        fi
        
    } > "$analysis_file"
    
    log_success "MySQL analysis completed: $(basename "$analysis_file")"
    echo "Full report: $analysis_file"
    echo
    
    # Show summary
    echo "=== MySQL Performance Summary ==="
    tail -20 "$analysis_file"
}

# Analyze PostgreSQL performance
analyze_postgresql_performance() {
    log_info "Analyzing PostgreSQL performance..."
    
    if ! command -v psql >/dev/null 2>&1 || [[ -z "${POSTGRESQL_USER:-}" || -z "${POSTGRESQL_PASSWORD:-}" ]]; then
        log_warning "PostgreSQL analysis skipped - client or credentials not available"
        return
    fi
    
    export PGPASSWORD="$POSTGRESQL_PASSWORD"
    local psql_cmd="psql -h localhost -p ${LOCAL_POSTGRESQL_PORT:-5433} -U $POSTGRESQL_USER -d ${POSTGRESQL_DATABASE:-devops_analytics}"
    local analysis_file="/tmp/postgresql_analysis_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== PostgreSQL Performance Analysis ==="
        echo "Generated: $(date)"
        echo
        
        echo "=== Server Information ==="
        $psql_cmd -c "SELECT version();" 2>/dev/null
        $psql_cmd -c "SELECT pg_postmaster_start_time();" 2>/dev/null
        $psql_cmd -c "SELECT pg_size_pretty(pg_database_size(current_database()));" 2>/dev/null
        echo
        
        echo "=== Connection Statistics ==="
        $psql_cmd -c "
            SELECT 
                count(*) as total_connections,
                count(*) FILTER (WHERE state = 'active') as active_connections,
                count(*) FILTER (WHERE state = 'idle') as idle_connections,
                count(*) FILTER (WHERE state = 'idle in transaction') as idle_in_transaction
            FROM pg_stat_activity;
        " 2>/dev/null
        
        $psql_cmd -c "SHOW max_connections;" 2>/dev/null
        echo
        
        echo "=== Database Statistics ==="
        $psql_cmd -c "
            SELECT 
                datname,
                numbackends as connections,
                xact_commit as commits,
                xact_rollback as rollbacks,
                blks_read,
                blks_hit,
                CASE 
                    WHEN blks_read + blks_hit > 0 
                    THEN ROUND(100.0 * blks_hit / (blks_read + blks_hit), 2) 
                    ELSE 0 
                END as cache_hit_ratio
            FROM pg_stat_database 
            WHERE datname = current_database();
        " 2>/dev/null
        echo
        
        echo "=== Table Statistics ==="
        $psql_cmd -c "
            SELECT 
                schemaname,
                tablename,
                n_tup_ins as inserts,
                n_tup_upd as updates,
                n_tup_del as deletes,
                n_tup_hot_upd as hot_updates,
                n_live_tup as live_tuples,
                n_dead_tup as dead_tuples,
                last_vacuum,
                last_autovacuum,
                last_analyze,
                last_autoanalyze
            FROM pg_stat_user_tables 
            ORDER BY n_live_tup DESC;
        " 2>/dev/null
        echo
        
        echo "=== Index Statistics ==="
        $psql_cmd -c "
            SELECT 
                schemaname,
                tablename,
                indexname,
                idx_tup_read,
                idx_tup_fetch,
                CASE 
                    WHEN idx_tup_read > 0 
                    THEN ROUND(100.0 * idx_tup_fetch / idx_tup_read, 2) 
                    ELSE 0 
                END as index_efficiency
            FROM pg_stat_user_indexes 
            ORDER BY idx_tup_read DESC;
        " 2>/dev/null
        echo
        
        echo "=== Table Sizes ==="
        $psql_cmd -c "
            SELECT 
                tablename,
                pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
                pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
                pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as index_size
            FROM pg_tables 
            WHERE schemaname = 'public'
            ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
        " 2>/dev/null
        echo
        
        echo "=== Long Running Queries ==="
        $psql_cmd -c "
            SELECT 
                pid,
                usename,
                application_name,
                state,
                EXTRACT(EPOCH FROM (NOW() - query_start)) as duration_seconds,
                LEFT(query, 100) as query_preview
            FROM pg_stat_activity 
            WHERE state = 'active' 
                AND query_start < NOW() - INTERVAL '1 minute'
                AND query NOT LIKE '%pg_stat_activity%'
            ORDER BY query_start;
        " 2>/dev/null
        echo
        
        echo "=== Lock Information ==="
        $psql_cmd -c "
            SELECT 
                mode,
                locktype,
                granted,
                count(*)
            FROM pg_locks 
            GROUP BY mode, locktype, granted
            ORDER BY count(*) DESC;
        " 2>/dev/null
        echo
        
        echo "=== Recommendations ==="
        
        # Check cache hit ratio
        local cache_hit_ratio=$($psql_cmd -t -c "
            SELECT ROUND(100.0 * sum(blks_hit) / (sum(blks_hit) + sum(blks_read)), 2)
            FROM pg_stat_database WHERE datname = current_database();
        " 2>/dev/null | xargs)
        
        if [[ -n "$cache_hit_ratio" ]]; then
            echo "Cache Hit Ratio: $cache_hit_ratio%"
            if (( $(echo "$cache_hit_ratio < 95" | bc -l 2>/dev/null) )); then
                echo "⚠️  Consider increasing shared_buffers or effective_cache_size"
            else
                echo "✅ Cache hit ratio is good"
            fi
        fi
        
        # Check for tables needing vacuum
        local tables_need_vacuum=$($psql_cmd -t -c "
            SELECT count(*) FROM pg_stat_user_tables 
            WHERE n_dead_tup > n_live_tup * 0.1 AND n_live_tup > 1000;
        " 2>/dev/null | xargs)
        
        if [[ -n "$tables_need_vacuum" && $tables_need_vacuum -gt 0 ]]; then
            echo "⚠️  $tables_need_vacuum tables may need manual VACUUM"
        else
            echo "✅ Table maintenance appears current"
        fi
        
        # Check for unused indexes
        local unused_indexes=$($psql_cmd -t -c "
            SELECT count(*) FROM pg_stat_user_indexes 
            WHERE idx_tup_read = 0 AND idx_tup_fetch = 0;
        " 2>/dev/null | xargs)
        
        if [[ -n "$unused_indexes" && $unused_indexes -gt 0 ]]; then
            echo "⚠️  $unused_indexes potentially unused indexes found"
        else
            echo "✅ All indexes appear to be used"
        fi
        
    } > "$analysis_file"
    
    unset PGPASSWORD
    
    log_success "PostgreSQL analysis completed: $(basename "$analysis_file")"
    echo "Full report: $analysis_file"
    echo
    
    # Show summary
    echo "=== PostgreSQL Performance Summary ==="
    tail -20 "$analysis_file"
}

# Generate optimization recommendations
generate_optimization_recommendations() {
    log_info "Generating optimization recommendations..."
    
    local recommendations_file="/tmp/optimization_recommendations_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$recommendations_file" << EOF
# Database Optimization Recommendations

Generated: $(date)

## MySQL Optimizations

### Configuration Parameters
\`\`\`ini
# InnoDB Buffer Pool (set to 70-80% of available RAM)
innodb_buffer_pool_size = 2G

# InnoDB Log Files
innodb_log_file_size = 256M
innodb_log_buffer_size = 16M

# Query Cache (if using MySQL < 8.0)
query_cache_type = 1
query_cache_size = 256M

# Connection Settings
max_connections = 200
max_connect_errors = 1000000

# Slow Query Log
slow_query_log = 1
long_query_time = 2
log_queries_not_using_indexes = 1
\`\`\`

### Index Optimization
- Add composite indexes for frequent WHERE clause combinations
- Remove unused indexes to improve INSERT/UPDATE performance
- Consider covering indexes for SELECT-only queries

### Query Optimization
- Use EXPLAIN to analyze query execution plans
- Avoid SELECT * in production queries
- Use LIMIT for large result sets
- Optimize JOIN operations with proper indexing

## PostgreSQL Optimizations

### Configuration Parameters (\`postgresql.conf\`)
\`\`\`ini
# Memory Settings
shared_buffers = 2GB                    # 25% of RAM
effective_cache_size = 6GB              # 75% of RAM
work_mem = 16MB                         # Per connection
maintenance_work_mem = 256MB

# Checkpoint Settings
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100

# Planner Settings
random_page_cost = 1.1                  # For SSD storage
effective_io_concurrency = 200          # For SSD storage

# Logging
log_min_duration_statement = 1000       # Log slow queries
log_line_prefix = '%t [%p-%l] %q%u@%d '
log_checkpoints = on
log_connections = on
log_disconnections = on
\`\`\`

### Index Optimization
- Create partial indexes for filtered queries
- Use expression indexes for computed columns
- Consider GIN indexes for JSONB columns
- Use covering indexes (INCLUDE clause) for SELECT-only queries

### Maintenance Tasks
\`\`\`sql
-- Regular maintenance
VACUUM ANALYZE;

-- For heavily updated tables
REINDEX INDEX index_name;

-- Update table statistics
ANALYZE table_name;
\`\`\`

## General Performance Tips

### Application Level
1. **Connection Pooling**: Use connection pools to manage database connections
2. **Prepared Statements**: Use prepared statements to reduce parsing overhead
3. **Batch Operations**: Batch INSERT/UPDATE operations when possible
4. **Async Operations**: Use async processing for non-critical operations

### Database Design
1. **Normalization**: Proper normalization to reduce data redundancy
2. **Partitioning**: Consider table partitioning for large tables
3. **Archiving**: Archive old data to separate tables/databases
4. **Data Types**: Use appropriate data types for storage efficiency

### Monitoring
1. **Query Performance**: Regular monitoring of slow queries
2. **Resource Usage**: Monitor CPU, memory, and I/O usage
3. **Connection Monitoring**: Track connection counts and patterns
4. **Index Usage**: Monitor index usage and efficiency

## BI-Specific Optimizations

### Data Warehouse Patterns
1. **Star Schema**: Use star schema for analytical queries
2. **Materialized Views**: Pre-compute complex aggregations
3. **Column Stores**: Consider columnar storage for analytics
4. **Data Compression**: Use compression for historical data

### Real-time Analytics
1. **Streaming**: Use streaming for real-time data ingestion
2. **Caching**: Cache frequently accessed aggregations
3. **Read Replicas**: Use read replicas for analytical queries
4. **Time-based Partitioning**: Partition by date for time-series data

## Automated Optimization

### MySQL
\`\`\`bash
# MySQL Tuner (install and run)
wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl
perl mysqltuner.pl

# MySQL Performance Schema
SELECT * FROM performance_schema.events_statements_summary_by_digest 
ORDER BY sum_timer_wait DESC LIMIT 10;
\`\`\`

### PostgreSQL
\`\`\`bash
# pg_stat_statements extension
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

# Analyze top queries
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY total_time DESC LIMIT 10;
\`\`\`

## Implementation Priority

### High Priority
1. Enable slow query logging
2. Optimize top 10 slowest queries
3. Add missing indexes for frequent queries
4. Configure appropriate buffer sizes

### Medium Priority
1. Implement connection pooling
2. Set up monitoring and alerting
3. Optimize table structures
4. Configure automated maintenance

### Low Priority
1. Advanced indexing strategies
2. Partitioning implementation
3. Read replica setup
4. Advanced caching strategies

## Monitoring Queries

### MySQL Performance Queries
\`\`\`sql
-- Top 10 slowest queries
SELECT 
    query_time,
    lock_time,
    rows_sent,
    rows_examined,
    sql_text
FROM mysql.slow_log 
ORDER BY query_time DESC 
LIMIT 10;

-- Buffer pool efficiency
SELECT 
    ROUND(100 - (Innodb_buffer_pool_reads * 100 / Innodb_buffer_pool_read_requests), 2) as buffer_pool_hit_ratio
FROM information_schema.global_status 
WHERE variable_name IN ('Innodb_buffer_pool_reads', 'Innodb_buffer_pool_read_requests');
\`\`\`

### PostgreSQL Performance Queries
\`\`\`sql
-- Top 10 slowest queries
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 10;

-- Cache hit ratio
SELECT 
    datname,
    ROUND(100.0 * blks_hit / (blks_hit + blks_read), 2) as cache_hit_ratio
FROM pg_stat_database 
WHERE datname = current_database();
\`\`\`
EOF

    log_success "Optimization recommendations generated: $(basename "$recommendations_file")"
    echo "Full recommendations: $recommendations_file"
}

# Apply basic optimizations
apply_basic_optimizations() {
    log_info "Applying basic database optimizations..."
    
    # MySQL optimizations
    if command -v mysql >/dev/null 2>&1 && [[ -n "${MYSQL_USER:-}" && -n "${MYSQL_PASSWORD:-}" ]]; then
        log_info "Applying MySQL optimizations..."
        
        local mysql_cmd="mysql -h localhost -P ${LOCAL_MYSQL_PORT:-3307} -u $MYSQL_USER -p$MYSQL_PASSWORD"
        
        # Enable performance schema if not already enabled
        $mysql_cmd -e "
            UPDATE performance_schema.setup_consumers 
            SET enabled = 'YES' 
            WHERE name LIKE 'events_statements%';
            
            UPDATE performance_schema.setup_instruments 
            SET enabled = 'YES' 
            WHERE name LIKE 'statement/%';
        " 2>/dev/null || log_warning "Could not enable MySQL performance schema"
        
        # Analyze tables to update statistics
        $mysql_cmd -e "
            SELECT CONCAT('ANALYZE TABLE ', table_schema, '.', table_name, ';') as analyze_statements
            FROM information_schema.tables 
            WHERE table_schema = 'devops_app' 
            AND table_type = 'BASE TABLE';
        " 2>/dev/null | grep "ANALYZE TABLE" | while read -r stmt; do
            $mysql_cmd -e "$stmt" 2>/dev/null || true
        done
        
        log_success "MySQL basic optimizations applied"
    fi
    
    # PostgreSQL optimizations
    if command -v psql >/dev/null 2>&1 && [[ -n "${POSTGRESQL_USER:-}" && -n "${POSTGRESQL_PASSWORD:-}" ]]; then
        log_info "Applying PostgreSQL optimizations..."
        
        export PGPASSWORD="$POSTGRESQL_PASSWORD"
        local psql_cmd="psql -h localhost -p ${LOCAL_POSTGRESQL_PORT:-5433} -U $POSTGRESQL_USER -d ${POSTGRESQL_DATABASE:-devops_analytics}"
        
        # Enable pg_stat_statements if not already enabled
        $psql_cmd -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;" 2>/dev/null || log_warning "Could not enable pg_stat_statements"
        
        # Update table statistics
        $psql_cmd -c "
            SELECT 'ANALYZE ' || schemaname || '.' || tablename || ';' as analyze_statements
            FROM pg_tables 
            WHERE schemaname = 'public';
        " -t 2>/dev/null | while read -r stmt; do
            if [[ -n "$stmt" ]]; then
                $psql_cmd -c "$stmt" 2>/dev/null || true
            fi
        done
        
        # Refresh materialized views
        $psql_cmd -c "REFRESH MATERIALIZED VIEW daily_analytics_summary;" 2>/dev/null || true
        $psql_cmd -c "REFRESH MATERIALIZED VIEW hourly_analytics_summary;" 2>/dev/null || true
        
        unset PGPASSWORD
        log_success "PostgreSQL basic optimizations applied"
    fi
}

# Create performance monitoring queries
create_monitoring_queries() {
    log_info "Creating performance monitoring queries..."
    
    local queries_dir="${SCRIPT_DIR}/../queries"
    mkdir -p "$queries_dir"
    
    # MySQL monitoring queries
    cat > "${queries_dir}/mysql_performance_queries.sql" << 'EOF'
-- MySQL Performance Monitoring Queries

-- 1. Buffer Pool Hit Ratio
SELECT 
    ROUND(100 - (
        (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') * 100 /
        (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests')
    ), 2) as buffer_pool_hit_ratio_percent;

-- 2. Top 10 Largest Tables
SELECT 
    table_name,
    table_rows,
    ROUND(data_length / 1024 / 1024, 2) as data_size_mb,
    ROUND(index_length / 1024 / 1024, 2) as index_size_mb,
    ROUND((data_length + index_length) / 1024 / 1024, 2) as total_size_mb
FROM information_schema.tables
WHERE table_schema = 'devops_app'
ORDER BY (data_length + index_length) DESC
LIMIT 10;

-- 3. Connection Statistics
SELECT 
    VARIABLE_NAME,
    VARIABLE_VALUE
FROM information_schema.GLOBAL_STATUS
WHERE VARIABLE_NAME IN (
    'Threads_connected',
    'Threads_running',
    'Max_used_connections',
    'Aborted_connects',
    'Aborted_clients'
);

-- 4. Slow Query Statistics
SELECT 
    VARIABLE_NAME,
    VARIABLE_VALUE
FROM information_schema.GLOBAL_STATUS
WHERE VARIABLE_NAME IN (
    'Slow_queries',
    'Questions',
    'Uptime'
);

-- 5. InnoDB Status
SELECT 
    VARIABLE_NAME,
    VARIABLE_VALUE
FROM information_schema.GLOBAL_STATUS
WHERE VARIABLE_NAME LIKE 'Innodb_%'
AND VARIABLE_NAME IN (
    'Innodb_buffer_pool_size',
    'Innodb_buffer_pool_pages_total',
    'Innodb_buffer_pool_pages_free',
    'Innodb_buffer_pool_pages_data'
);
EOF

    # PostgreSQL monitoring queries
    cat > "${queries_dir}/postgresql_performance_queries.sql" << 'EOF'
-- PostgreSQL Performance Monitoring Queries

-- 1. Database Cache Hit Ratio
SELECT 
    datname,
    ROUND(100.0 * blks_hit / (blks_hit + blks_read), 2) as cache_hit_ratio
FROM pg_stat_database 
WHERE datname = current_database();

-- 2. Top 10 Largest Tables
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size('public.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size('public.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size('public.'||tablename) - pg_relation_size('public.'||tablename)) as index_size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size('public.'||tablename) DESC
LIMIT 10;

-- 3. Connection Statistics
SELECT 
    count(*) as total_connections,
    count(*) FILTER (WHERE state = 'active') as active_connections,
    count(*) FILTER (WHERE state = 'idle') as idle_connections,
    count(*) FILTER (WHERE state = 'idle in transaction') as idle_in_transaction
FROM pg_stat_activity;

-- 4. Top 10 Most Time Consuming Queries (requires pg_stat_statements)
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows,
    ROUND(100.0 * total_time / sum(total_time) OVER (), 2) as percentage_of_total_time
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 10;

-- 5. Table Statistics
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_tuples,
    n_dead_tup as dead_tuples,
    CASE 
        WHEN n_live_tup > 0 
        THEN ROUND(100.0 * n_dead_tup / n_live_tup, 2) 
        ELSE 0 
    END as dead_tuple_percentage
FROM pg_stat_user_tables 
ORDER BY n_live_tup DESC;

-- 6. Index Usage Statistics
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_tup_read,
    idx_tup_fetch,
    CASE 
        WHEN idx_tup_read > 0 
        THEN ROUND(100.0 * idx_tup_fetch / idx_tup_read, 2) 
        ELSE 0 
    END as index_efficiency_percentage
FROM pg_stat_user_indexes 
ORDER BY idx_tup_read DESC;
EOF

    log_success "Performance monitoring queries created"
}

# Show usage
usage() {
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  analyze     Analyze database performance"
    echo "  mysql       Analyze MySQL performance only"
    echo "  postgresql  Analyze PostgreSQL performance only"
    echo "  recommend   Generate optimization recommendations"
    echo "  optimize    Apply basic optimizations"
    echo "  queries     Create performance monitoring queries"
    echo "  full        Run complete optimization analysis"
    echo "  help        Show this help message"
    echo
    echo "Examples:"
    echo "  $0 full        # Complete performance analysis"
    echo "  $0 analyze     # Analyze both databases"
    echo "  $0 optimize    # Apply basic optimizations"
}

# Main function
main() {
    local command="${1:-full}"
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    
    # Load configuration
    load_config
    
    case "$command" in
        analyze)
            analyze_mysql_performance
            analyze_postgresql_performance
            ;;
        mysql)
            analyze_mysql_performance
            ;;
        postgresql)
            analyze_postgresql_performance
            ;;
        recommend)
            generate_optimization_recommendations
            ;;
        optimize)
            apply_basic_optimizations
            ;;
        queries)
            create_monitoring_queries
            ;;
        full)
            log_info "Starting complete database optimization analysis..."
            analyze_mysql_performance
            analyze_postgresql_performance
            generate_optimization_recommendations
            apply_basic_optimizations
            create_monitoring_queries
            log_success "Database optimization analysis completed"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'log_info "Optimization interrupted"; exit 1' INT TERM

# Run main function
main "$@"

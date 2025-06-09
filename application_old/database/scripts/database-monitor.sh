#!/bin/bash

# Database Monitoring Script
# Monitors MySQL and PostgreSQL health, performance, and connection status

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/tunnel-config.env"
LOG_FILE="/tmp/database-monitor.log"
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_CONNECTIONS=80
ALERT_THRESHOLD_SLOW_QUERIES=10

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

# Check if SSH tunnels are running
check_tunnels() {
    log_info "Checking SSH tunnel status..."
    
    local mysql_tunnel_running=false
    local postgresql_tunnel_running=false
    
    # Check MySQL tunnel
    if lsof -Pi :${LOCAL_MYSQL_PORT:-3307} -sTCP:LISTEN -t >/dev/null 2>&1; then
        mysql_tunnel_running=true
        log_success "MySQL SSH tunnel is running"
    else
        log_error "MySQL SSH tunnel is not running"
    fi
    
    # Check PostgreSQL tunnel
    if lsof -Pi :${LOCAL_POSTGRESQL_PORT:-5433} -sTCP:LISTEN -t >/dev/null 2>&1; then
        postgresql_tunnel_running=true
        log_success "PostgreSQL SSH tunnel is running"
    else
        log_error "PostgreSQL SSH tunnel is not running"
    fi
    
    if [[ "$mysql_tunnel_running" == false || "$postgresql_tunnel_running" == false ]]; then
        log_warning "Some SSH tunnels are not running. Database connections may fail."
        return 1
    fi
    
    return 0
}

# Test database connectivity
test_database_connections() {
    log_info "Testing database connections..."
    
    local mysql_connected=false
    local postgresql_connected=false
    
    # Test MySQL connection
    if command -v mysql >/dev/null 2>&1 && [[ -n "${MYSQL_USER:-}" && -n "${MYSQL_PASSWORD:-}" ]]; then
        if mysql -h localhost -P "${LOCAL_MYSQL_PORT:-3307}" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1;" >/dev/null 2>&1; then
            mysql_connected=true
            log_success "MySQL connection successful"
        else
            log_error "MySQL connection failed"
        fi
    else
        log_warning "MySQL client not available or credentials not configured"
    fi
    
    # Test PostgreSQL connection
    if command -v psql >/dev/null 2>&1 && [[ -n "${POSTGRESQL_USER:-}" && -n "${POSTGRESQL_PASSWORD:-}" ]]; then
        export PGPASSWORD="$POSTGRESQL_PASSWORD"
        if psql -h localhost -p "${LOCAL_POSTGRESQL_PORT:-5433}" -U "$POSTGRESQL_USER" -d "${POSTGRESQL_DATABASE:-postgres}" -c "SELECT 1;" >/dev/null 2>&1; then
            postgresql_connected=true
            log_success "PostgreSQL connection successful"
        else
            log_error "PostgreSQL connection failed"
        fi
        unset PGPASSWORD
    else
        log_warning "PostgreSQL client not available or credentials not configured"
    fi
    
    if [[ "$mysql_connected" == false || "$postgresql_connected" == false ]]; then
        log_warning "Some database connections failed"
        return 1
    fi
    
    return 0
}

# Monitor MySQL performance
monitor_mysql() {
    log_info "Monitoring MySQL performance..."
    
    if ! command -v mysql >/dev/null 2>&1 || [[ -z "${MYSQL_USER:-}" || -z "${MYSQL_PASSWORD:-}" ]]; then
        log_warning "MySQL monitoring skipped - client or credentials not available"
        return
    fi
    
    local mysql_cmd="mysql -h localhost -P ${LOCAL_MYSQL_PORT:-3307} -u $MYSQL_USER -p$MYSQL_PASSWORD -e"
    
    # Connection count
    local connections=$($mysql_cmd "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null | tail -1 | awk '{print $2}' || echo "0")
    local max_connections=$($mysql_cmd "SHOW VARIABLES LIKE 'max_connections';" 2>/dev/null | tail -1 | awk '{print $2}' || echo "100")
    local connection_usage=$((connections * 100 / max_connections))
    
    echo "MySQL Connections: $connections/$max_connections ($connection_usage%)" | tee -a "$LOG_FILE"
    
    if [[ $connection_usage -gt $ALERT_THRESHOLD_CONNECTIONS ]]; then
        log_warning "MySQL connection usage is high: $connection_usage%"
    fi
    
    # Slow queries
    local slow_queries=$($mysql_cmd "SHOW STATUS LIKE 'Slow_queries';" 2>/dev/null | tail -1 | awk '{print $2}' || echo "0")
    echo "MySQL Slow Queries: $slow_queries" | tee -a "$LOG_FILE"
    
    if [[ $slow_queries -gt $ALERT_THRESHOLD_SLOW_QUERIES ]]; then
        log_warning "MySQL has $slow_queries slow queries"
    fi
    
    # Buffer pool hit ratio
    local buffer_pool_reads=$($mysql_cmd "SHOW STATUS LIKE 'Innodb_buffer_pool_reads';" 2>/dev/null | tail -1 | awk '{print $2}' || echo "1")
    local buffer_pool_read_requests=$($mysql_cmd "SHOW STATUS LIKE 'Innodb_buffer_pool_read_requests';" 2>/dev/null | tail -1 | awk '{print $2}' || echo "1")
    
    if [[ $buffer_pool_read_requests -gt 0 ]]; then
        local hit_ratio=$((100 - (buffer_pool_reads * 100 / buffer_pool_read_requests)))
        echo "MySQL Buffer Pool Hit Ratio: $hit_ratio%" | tee -a "$LOG_FILE"
        
        if [[ $hit_ratio -lt 95 ]]; then
            log_warning "MySQL buffer pool hit ratio is low: $hit_ratio%"
        fi
    fi
    
    # Database sizes
    $mysql_cmd "
        SELECT 
            table_schema AS 'Database',
            ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
        FROM information_schema.tables
        WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
        GROUP BY table_schema;
    " 2>/dev/null | tee -a "$LOG_FILE" || log_warning "Failed to get MySQL database sizes"
}

# Monitor PostgreSQL performance
monitor_postgresql() {
    log_info "Monitoring PostgreSQL performance..."
    
    if ! command -v psql >/dev/null 2>&1 || [[ -z "${POSTGRESQL_USER:-}" || -z "${POSTGRESQL_PASSWORD:-}" ]]; then
        log_warning "PostgreSQL monitoring skipped - client or credentials not available"
        return
    fi
    
    export PGPASSWORD="$POSTGRESQL_PASSWORD"
    local psql_cmd="psql -h localhost -p ${LOCAL_POSTGRESQL_PORT:-5433} -U $POSTGRESQL_USER -d ${POSTGRESQL_DATABASE:-postgres} -t -c"
    
    # Connection count
    local connections=$($psql_cmd "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | xargs || echo "0")
    local max_connections=$($psql_cmd "SHOW max_connections;" 2>/dev/null | xargs || echo "100")
    local connection_usage=$((connections * 100 / max_connections))
    
    echo "PostgreSQL Connections: $connections/$max_connections ($connection_usage%)" | tee -a "$LOG_FILE"
    
    if [[ $connection_usage -gt $ALERT_THRESHOLD_CONNECTIONS ]]; then
        log_warning "PostgreSQL connection usage is high: $connection_usage%"
    fi
    
    # Cache hit ratio
    local cache_hit_ratio=$($psql_cmd "
        SELECT ROUND(
            100.0 * sum(blks_hit) / (sum(blks_hit) + sum(blks_read)), 2
        ) FROM pg_stat_database WHERE datname = current_database();
    " 2>/dev/null | xargs || echo "0")
    
    echo "PostgreSQL Cache Hit Ratio: $cache_hit_ratio%" | tee -a "$LOG_FILE"
    
    if [[ $(echo "$cache_hit_ratio < 95" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        log_warning "PostgreSQL cache hit ratio is low: $cache_hit_ratio%"
    fi
    
    # Long running queries
    local long_queries=$($psql_cmd "
        SELECT COUNT(*) FROM pg_stat_activity 
        WHERE state = 'active' 
        AND query_start < NOW() - INTERVAL '5 minutes';
    " 2>/dev/null | xargs || echo "0")
    
    echo "PostgreSQL Long Running Queries: $long_queries" | tee -a "$LOG_FILE"
    
    if [[ $long_queries -gt 0 ]]; then
        log_warning "PostgreSQL has $long_queries long-running queries"
        
        # Show long running queries
        $psql_cmd "
            SELECT 
                pid,
                usename,
                application_name,
                state,
                EXTRACT(EPOCH FROM (NOW() - query_start)) AS duration_seconds,
                LEFT(query, 100) AS query_preview
            FROM pg_stat_activity 
            WHERE state = 'active' 
            AND query_start < NOW() - INTERVAL '5 minutes'
            ORDER BY query_start;
        " 2>/dev/null | tee -a "$LOG_FILE" || true
    fi
    
    # Database sizes
    $psql_cmd "
        SELECT 
            datname AS database,
            pg_size_pretty(pg_database_size(datname)) AS size
        FROM pg_database 
        WHERE datistemplate = false
        ORDER BY pg_database_size(datname) DESC;
    " 2>/dev/null | tee -a "$LOG_FILE" || log_warning "Failed to get PostgreSQL database sizes"
    
    unset PGPASSWORD
}

# Monitor disk space for database data
monitor_disk_space() {
    log_info "Monitoring disk space..."
    
    # Check disk usage for common database data directories
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    echo "Root filesystem usage: $disk_usage%" | tee -a "$LOG_FILE"
    
    if [[ $disk_usage -gt 85 ]]; then
        log_warning "Root filesystem usage is high: $disk_usage%"
    fi
    
    # Check /tmp directory (where logs might be stored)
    if [[ -d /tmp ]]; then
        local tmp_usage=$(df -h /tmp | tail -1 | awk '{print $5}' | sed 's/%//' 2>/dev/null || echo "0")
        echo "Tmp filesystem usage: $tmp_usage%" | tee -a "$LOG_FILE"
        
        if [[ $tmp_usage -gt 90 ]]; then
            log_warning "Tmp filesystem usage is high: $tmp_usage%"
        fi
    fi
}

# Check for database locks
check_database_locks() {
    log_info "Checking for database locks..."
    
    # MySQL locks
    if command -v mysql >/dev/null 2>&1 && [[ -n "${MYSQL_USER:-}" && -n "${MYSQL_PASSWORD:-}" ]]; then
        local mysql_cmd="mysql -h localhost -P ${LOCAL_MYSQL_PORT:-3307} -u $MYSQL_USER -p$MYSQL_PASSWORD -e"
        
        local mysql_locks=$($mysql_cmd "SHOW PROCESSLIST;" 2>/dev/null | grep -c "Locked" || echo "0")
        echo "MySQL Locked Processes: $mysql_locks" | tee -a "$LOG_FILE"
        
        if [[ $mysql_locks -gt 0 ]]; then
            log_warning "MySQL has $mysql_locks locked processes"
        fi
    fi
    
    # PostgreSQL locks
    if command -v psql >/dev/null 2>&1 && [[ -n "${POSTGRESQL_USER:-}" && -n "${POSTGRESQL_PASSWORD:-}" ]]; then
        export PGPASSWORD="$POSTGRESQL_PASSWORD"
        local psql_cmd="psql -h localhost -p ${LOCAL_POSTGRESQL_PORT:-5433} -U $POSTGRESQL_USER -d ${POSTGRESQL_DATABASE:-postgres} -t -c"
        
        local pg_locks=$($psql_cmd "SELECT COUNT(*) FROM pg_locks WHERE NOT granted;" 2>/dev/null | xargs || echo "0")
        echo "PostgreSQL Blocked Locks: $pg_locks" | tee -a "$LOG_FILE"
        
        if [[ $pg_locks -gt 0 ]]; then
            log_warning "PostgreSQL has $pg_locks blocked locks"
        fi
        
        unset PGPASSWORD
    fi
}

# Generate monitoring report
generate_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "=== Database Monitoring Report ===" | tee -a "$LOG_FILE"
    echo "Timestamp: $timestamp" | tee -a "$LOG_FILE"
    echo "Generated by: $(whoami)@$(hostname)" | tee -a "$LOG_FILE"
    echo | tee -a "$LOG_FILE"
    
    check_tunnels
    echo | tee -a "$LOG_FILE"
    
    test_database_connections
    echo | tee -a "$LOG_FILE"
    
    monitor_mysql
    echo | tee -a "$LOG_FILE"
    
    monitor_postgresql
    echo | tee -a "$LOG_FILE"
    
    monitor_disk_space
    echo | tee -a "$LOG_FILE"
    
    check_database_locks
    echo | tee -a "$LOG_FILE"
    
    echo "=== End of Report ===" | tee -a "$LOG_FILE"
    echo | tee -a "$LOG_FILE"
}

# Continuous monitoring mode
monitor_continuous() {
    local interval=${1:-300}  # Default 5 minutes
    
    log_info "Starting continuous monitoring (interval: ${interval}s)"
    log_info "Log file: $LOG_FILE"
    log_info "Press Ctrl+C to stop"
    
    while true; do
        generate_report
        
        log_info "Sleeping for ${interval} seconds..."
        sleep "$interval"
    done
}

# Health check mode (for external monitoring)
health_check() {
    local exit_code=0
    
    # Check tunnels
    if ! check_tunnels >/dev/null 2>&1; then
        exit_code=1
    fi
    
    # Check database connections
    if ! test_database_connections >/dev/null 2>&1; then
        exit_code=1
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        echo "OK - All database services are healthy"
    else
        echo "CRITICAL - Some database services are unhealthy"
    fi
    
    exit $exit_code
}

# Show usage
usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  report              Generate monitoring report (default)"
    echo "  continuous [INTERVAL]  Start continuous monitoring (interval in seconds)"
    echo "  health              Health check for external monitoring"
    echo "  tunnels             Check SSH tunnel status only"
    echo "  connections         Test database connections only"
    echo "  help                Show this help message"
    echo
    echo "Examples:"
    echo "  $0                  # Generate single report"
    echo "  $0 continuous 60    # Monitor every 60 seconds"
    echo "  $0 health           # Health check (exit code 0=OK, 1=ERROR)"
}

# Main function
main() {
    local command="${1:-report}"
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    
    # Load configuration
    load_config
    
    case "$command" in
        report)
            generate_report
            ;;
        continuous)
            local interval="${2:-300}"
            monitor_continuous "$interval"
            ;;
        health)
            health_check
            ;;
        tunnels)
            check_tunnels
            ;;
        connections)
            test_database_connections
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
trap 'log_info "Monitoring interrupted"; exit 0' INT TERM

# Run main function
main "$@"

#!/bin/bash

# Metabase Monitoring Script
# Monitors Metabase health, performance, and system metrics

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METABASE_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/tmp/metabase-monitor.log"
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEMORY=85
ALERT_THRESHOLD_DISK=90
ALERT_THRESHOLD_RESPONSE_TIME=5000  # 5 seconds

# Load environment variables
if [[ -f "$METABASE_DIR/.env" ]]; then
    set -a
    source "$METABASE_DIR/.env"
    set +a
fi

METABASE_URL="${METABASE_SITE_URL:-http://localhost:3000}"
WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"

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

log_alert() {
    echo -e "${RED}[ALERT]${NC} $1" | tee -a "$LOG_FILE"
    send_alert "$1"
}

# Send alert notification
send_alert() {
    local message="$1"
    local timestamp=$(date -Iseconds)
    
    if [[ -n "$WEBHOOK_URL" ]]; then
        local payload=$(cat <<EOF
{
    "text": "🚨 Metabase Alert",
    "attachments": [
        {
            "color": "danger",
            "fields": [
                {
                    "title": "Alert Message",
                    "value": "$message",
                    "short": false
                },
                {
                    "title": "Timestamp",
                    "value": "$timestamp",
                    "short": true
                },
                {
                    "title": "Host",
                    "value": "$(hostname)",
                    "short": true
                }
            ]
        }
    ]
}
EOF
)
        
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "$payload" >/dev/null 2>&1 || log_warning "Failed to send alert notification"
    fi
}

# Check Docker services status
check_docker_services() {
    log_info "Checking Docker services status..."
    
    cd "$METABASE_DIR"
    
    # Check if docker-compose.yml exists
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found in $METABASE_DIR"
        return 1
    fi
    
    # Get service status
    local services=$(docker-compose ps --services)
    local all_healthy=true
    
    for service in $services; do
        local status=$(docker-compose ps "$service" --format json 2>/dev/null | jq -r '.[0].State' 2>/dev/null || echo "unknown")
        
        case "$status" in
            "running")
                log_success "Service $service: Running"
                ;;
            "exited")
                log_error "Service $service: Exited"
                all_healthy=false
                ;;
            "restarting")
                log_warning "Service $service: Restarting"
                ;;
            *)
                log_warning "Service $service: $status"
                all_healthy=false
                ;;
        esac
    done
    
    if [[ "$all_healthy" == "true" ]]; then
        log_success "All Docker services are healthy"
        return 0
    else
        log_alert "Some Docker services are not healthy"
        return 1
    fi
}

# Check Metabase application health
check_metabase_health() {
    log_info "Checking Metabase application health..."
    
    local start_time=$(date +%s)
    local response_code=$(curl -s -o /dev/null -w "%{http_code}" "$METABASE_URL/api/health" --max-time 10 || echo "000")
    local end_time=$(date +%s)
    local response_time=$((end_time - start_time))
    local response_time_ms=$((response_time * 1000))
    
    if [[ "$response_code" == "200" ]]; then
        log_success "Metabase health check passed (${response_time_ms}ms)"
        
        if [[ $response_time_ms -gt $ALERT_THRESHOLD_RESPONSE_TIME ]]; then
            log_warning "Metabase response time is high: ${response_time_ms}ms"
        fi
        
        return 0
    else
        log_alert "Metabase health check failed (HTTP $response_code)"
        return 1
    fi
}

# Check database connectivity
check_database_connectivity() {
    log_info "Checking database connectivity..."
    
    local postgres_healthy=false
    
    # Check Metabase PostgreSQL
    if docker exec metabase-postgres pg_isready -U metabase_user -d metabase >/dev/null 2>&1; then
        log_success "Metabase PostgreSQL: Connected"
        postgres_healthy=true
    else
        log_error "Metabase PostgreSQL: Connection failed"
    fi
    
    # Check Redis if configured
    if docker ps --filter name=metabase-redis --format "{{.Names}}" | grep -q metabase-redis; then
        if docker exec metabase-redis redis-cli ping >/dev/null 2>&1; then
            log_success "Redis: Connected"
        else
            log_warning "Redis: Connection failed"
        fi
    fi
    
    if [[ "$postgres_healthy" == "true" ]]; then
        return 0
    else
        log_alert "Database connectivity issues detected"
        return 1
    fi
}

# Monitor system resources
monitor_system_resources() {
    log_info "Monitoring system resources..."
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    cpu_usage=${cpu_usage%.*}  # Remove decimal part
    
    if [[ $cpu_usage -gt $ALERT_THRESHOLD_CPU ]]; then
        log_alert "High CPU usage: ${cpu_usage}%"
    else
        log_info "CPU usage: ${cpu_usage}%"
    fi
    
    # Memory usage
    local memory_info=$(free | grep Mem)
    local total_mem=$(echo $memory_info | awk '{print $2}')
    local used_mem=$(echo $memory_info | awk '{print $3}')
    local memory_usage=$((used_mem * 100 / total_mem))
    
    if [[ $memory_usage -gt $ALERT_THRESHOLD_MEMORY ]]; then
        log_alert "High memory usage: ${memory_usage}%"
    else
        log_info "Memory usage: ${memory_usage}%"
    fi
    
    # Disk usage
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [[ $disk_usage -gt $ALERT_THRESHOLD_DISK ]]; then
        log_alert "High disk usage: ${disk_usage}%"
    else
        log_info "Disk usage: ${disk_usage}%"
    fi
    
    # Docker resource usage
    check_docker_resources
}

# Check Docker container resources
check_docker_resources() {
    log_info "Checking Docker container resources..."
    
    cd "$METABASE_DIR"
    
    # Get container stats
    local containers=$(docker-compose ps -q)
    
    for container in $containers; do
        if [[ -n "$container" ]]; then
            local stats=$(docker stats --no-stream --format "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" "$container" 2>/dev/null || echo "")
            
            if [[ -n "$stats" ]]; then
                local name=$(echo "$stats" | cut -f1)
                local cpu_perc=$(echo "$stats" | cut -f2 | sed 's/%//')
                local mem_usage=$(echo "$stats" | cut -f3)
                
                log_info "Container $name: CPU=${cpu_perc}%, Memory=${mem_usage}"
                
                # Check for high CPU usage in containers
                if [[ ${cpu_perc%.*} -gt 90 ]]; then
                    log_warning "Container $name has high CPU usage: ${cpu_perc}%"
                fi
            fi
        fi
    done
}

# Check log files for errors
check_log_errors() {
    log_info "Checking for recent errors in logs..."
    
    # Check Metabase logs
    local metabase_errors=$(docker logs metabase --since="1h" 2>&1 | grep -i "error\|exception\|failed" | wc -l)
    
    if [[ $metabase_errors -gt 0 ]]; then
        log_warning "Found $metabase_errors error(s) in Metabase logs in the last hour"
        
        # Show last few errors
        log_info "Recent Metabase errors:"
        docker logs metabase --since="1h" 2>&1 | grep -i "error\|exception\|failed" | tail -3 | while read -r line; do
            log_warning "  $line"
        done
    else
        log_success "No recent errors in Metabase logs"
    fi
    
    # Check PostgreSQL logs
    local postgres_errors=$(docker logs metabase-postgres --since="1h" 2>&1 | grep -i "error\|fatal" | wc -l)
    
    if [[ $postgres_errors -gt 0 ]]; then
        log_warning "Found $postgres_errors error(s) in PostgreSQL logs in the last hour"
    else
        log_success "No recent errors in PostgreSQL logs"
    fi
    
    # Check Nginx logs if available
    if docker ps --filter name=metabase-nginx --format "{{.Names}}" | grep -q metabase-nginx; then
        local nginx_errors=$(docker logs metabase-nginx --since="1h" 2>&1 | grep -i "error" | wc -l)
        
        if [[ $nginx_errors -gt 0 ]]; then
            log_warning "Found $nginx_errors error(s) in Nginx logs in the last hour"
        else
            log_success "No recent errors in Nginx logs"
        fi
    fi
}

# Check backup status
check_backup_status() {
    log_info "Checking backup status..."
    
    local backup_dir="$METABASE_DIR/backups"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_warning "Backup directory not found: $backup_dir"
        return 1
    fi
    
    # Check for recent database backups
    local recent_db_backup=$(find "$backup_dir/database" -name "*.sql.gz" -mtime -1 2>/dev/null | head -1)
    
    if [[ -n "$recent_db_backup" ]]; then
        local backup_age=$(stat -c %Y "$recent_db_backup" 2>/dev/null || stat -f %m "$recent_db_backup" 2>/dev/null)
        local current_time=$(date +%s)
        local hours_old=$(( (current_time - backup_age) / 3600 ))
        
        if [[ $hours_old -lt 24 ]]; then
            log_success "Recent database backup found (${hours_old} hours old)"
        else
            log_warning "Database backup is ${hours_old} hours old"
        fi
    else
        log_warning "No recent database backup found"
    fi
    
    # Check backup disk usage
    local backup_size=$(du -sh "$backup_dir" 2>/dev/null | awk '{print $1}')
    log_info "Backup directory size: ${backup_size:-Unknown}"
}

# Check SSL certificate
check_ssl_certificate() {
    log_info "Checking SSL certificate..."
    
    local ssl_cert="$METABASE_DIR/ssl/metabase.crt"
    
    if [[ -f "$ssl_cert" ]]; then
        local expiry_date=$(openssl x509 -in "$ssl_cert" -noout -enddate 2>/dev/null | cut -d= -f2)
        
        if [[ -n "$expiry_date" ]]; then
            local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
            local current_epoch=$(date +%s)
            local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
            
            if [[ $days_until_expiry -lt 30 ]]; then
                log_warning "SSL certificate expires in $days_until_expiry days"
            elif [[ $days_until_expiry -lt 0 ]]; then
                log_alert "SSL certificate has expired"
            else
                log_success "SSL certificate is valid (expires in $days_until_expiry days)"
            fi
        else
            log_warning "Could not determine SSL certificate expiry"
        fi
    else
        log_warning "SSL certificate not found: $ssl_cert"
    fi
}

# Monitor dashboard performance
monitor_dashboard_performance() {
    log_info "Monitoring dashboard performance..."
    
    # Get dashboard list (requires authentication)
    local session_response=$(curl -s -X POST "$METABASE_URL/api/session" \
        -H "Content-Type: application/json" \
        -d "{\"username\": \"${METABASE_ADMIN_EMAIL:-}\", \"password\": \"${METABASE_ADMIN_PASSWORD:-}\"}" 2>/dev/null || echo "")
    
    if [[ -n "$session_response" ]]; then
        local session_id=$(echo "$session_response" | jq -r '.id' 2>/dev/null || echo "")
        
        if [[ -n "$session_id" && "$session_id" != "null" ]]; then
            # Get dashboard count
            local dashboard_count=$(curl -s -H "X-Metabase-Session: $session_id" \
                "$METABASE_URL/api/dashboard" 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
            
            log_info "Active dashboards: $dashboard_count"
            
            # Get database count
            local database_count=$(curl -s -H "X-Metabase-Session: $session_id" \
                "$METABASE_URL/api/database" 2>/dev/null | jq '.data | length' 2>/dev/null || echo "0")
            
            log_info "Connected databases: $database_count"
            
            # Test a simple query performance
            local query_start=$(date +%s%N)
            curl -s -H "X-Metabase-Session: $session_id" \
                "$METABASE_URL/api/health" >/dev/null 2>&1
            local query_end=$(date +%s%N)
            local query_time_ms=$(( (query_end - query_start) / 1000000 ))
            
            log_info "API response time: ${query_time_ms}ms"
            
            if [[ $query_time_ms -gt 2000 ]]; then
                log_warning "Slow API response time: ${query_time_ms}ms"
            fi
        else
            log_warning "Could not authenticate with Metabase for performance monitoring"
        fi
    else
        log_warning "Could not connect to Metabase API for performance monitoring"
    fi
}

# Network connectivity check
check_network_connectivity() {
    log_info "Checking network connectivity..."
    
    # Check external connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_success "External network connectivity: OK"
    else
        log_warning "External network connectivity: FAILED"
    fi
    
    # Check DNS resolution
    if nslookup google.com >/dev/null 2>&1; then
        log_success "DNS resolution: OK"
    else
        log_warning "DNS resolution: FAILED"
    fi
    
    # Check container network
    cd "$METABASE_DIR"
    local network_name=$(docker-compose config | grep -A 10 "networks:" | grep -v "networks:" | head -1 | awk '{print $1}' | sed 's/://')
    
    if [[ -n "$network_name" ]]; then
        local network_exists=$(docker network ls --filter name="$network_name" --format "{{.Name}}" | head -1)
        
        if [[ -n "$network_exists" ]]; then
            log_success "Docker network '$network_name': OK"
        else
            log_warning "Docker network '$network_name': NOT FOUND"
        fi
    fi
}

# Generate health report
generate_health_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="/tmp/metabase-health-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== Metabase Health Report ==="
        echo "Generated: $timestamp"
        echo "Host: $(hostname)"
        echo "Metabase URL: $METABASE_URL"
        echo
        
        echo "=== Service Status ==="
        check_docker_services
        echo
        
        echo "=== Application Health ==="
        check_metabase_health
        echo
        
        echo "=== Database Connectivity ==="
        check_database_connectivity
        echo
        
        echo "=== System Resources ==="
        monitor_system_resources
        echo
        
        echo "=== Log Analysis ==="
        check_log_errors
        echo
        
        echo "=== Backup Status ==="
        check_backup_status
        echo
        
        echo "=== SSL Certificate ==="
        check_ssl_certificate
        echo
        
        echo "=== Network Connectivity ==="
        check_network_connectivity
        echo
        
        echo "=== Performance Metrics ==="
        monitor_dashboard_performance
        echo
        
        echo "=== Docker Container Status ==="
        cd "$METABASE_DIR"
        docker-compose ps
        echo
        
        echo "=== Disk Usage ==="
        df -h
        echo
        
        echo "=== Memory Usage ==="
        free -h
        echo
        
        echo "=== Recent Log Entries ==="
        echo "Last 5 Metabase log entries:"
        docker logs metabase --tail 5 2>&1 | head -5
        echo
        
        echo "=== End of Report ==="
        
    } > "$report_file"
    
    log_success "Health report generated: $report_file"
    
    # Show summary on console
    echo
    echo "=== Health Report Summary ==="
    cat "$report_file" | grep -E "(SUCCESS|FAILED|WARNING|ERROR)" | tail -10
    echo
    echo "Full report: $report_file"
}

# Continuous monitoring mode
monitor_continuous() {
    local interval=${1:-300}  # Default 5 minutes
    
    log_info "Starting continuous monitoring (interval: ${interval}s)"
    log_info "Press Ctrl+C to stop"
    
    while true; do
        generate_health_report
        log_info "Sleeping for ${interval} seconds..."
        sleep "$interval"
    done
}

# Health check for external monitoring
health_check() {
    local exit_code=0
    
    # Check essential services
    if ! check_docker_services >/dev/null 2>&1; then
        exit_code=1
    fi
    
    if ! check_metabase_health >/dev/null 2>&1; then
        exit_code=1
    fi
    
    if ! check_database_connectivity >/dev/null 2>&1; then
        exit_code=1
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        echo "OK - All Metabase services are healthy"
    else
        echo "CRITICAL - Some Metabase services are unhealthy"
    fi
    
    exit $exit_code
}

# Show usage
usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  report              Generate health report (default)"
    echo "  continuous [INTERVAL]  Start continuous monitoring (interval in seconds)"
    echo "  health              Health check for external monitoring"
    echo "  services            Check Docker services only"
    echo "  performance         Check performance metrics only"
    echo "  resources           Check system resources only"
    echo "  help                Show this help message"
    echo
    echo "Examples:"
    echo "  $0                  # Generate health report"
    echo "  $0 continuous 60    # Monitor every 60 seconds"
    echo "  $0 health           # Health check (exit code 0=OK, 1=ERROR)"
    echo "  $0 performance      # Check performance only"
}

# Main function
main() {
    local command="${1:-report}"
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    
    case "$command" in
        report)
            generate_health_report
            ;;
        continuous)
            local interval="${2:-300}"
            monitor_continuous "$interval"
            ;;
        health)
            health_check
            ;;
        services)
            check_docker_services
            ;;
        performance)
            monitor_dashboard_performance
            ;;
        resources)
            monitor_system_resources
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

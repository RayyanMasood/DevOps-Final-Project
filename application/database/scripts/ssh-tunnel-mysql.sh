#!/bin/bash

# SSH Tunnel Script for MySQL RDS Access
# Creates secure tunnel through bastion host to access MySQL RDS in private subnet

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/tunnel-config.env"

# Default values (can be overridden by config file)
BASTION_HOST=""
BASTION_USER="ec2-user"
BASTION_KEY="${HOME}/.ssh/devops-key.pem"
RDS_MYSQL_HOST=""
RDS_MYSQL_PORT="3306"
LOCAL_MYSQL_PORT="3307"
TUNNEL_PID_FILE="/tmp/mysql-tunnel.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load configuration if exists
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Loading configuration from $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        log_warning "Configuration file not found: $CONFIG_FILE"
        log_info "Creating example configuration file..."
        create_example_config
    fi
}

# Create example configuration file
create_example_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# SSH Tunnel Configuration for MySQL RDS
# Copy this file and update with your actual values

# Bastion Host Configuration
BASTION_HOST="your-bastion-public-ip-or-dns"
BASTION_USER="ec2-user"
BASTION_KEY="${HOME}/.ssh/your-key.pem"

# RDS MySQL Configuration
RDS_MYSQL_HOST="your-mysql-rds-endpoint"
RDS_MYSQL_PORT="3306"

# Local Tunnel Configuration
LOCAL_MYSQL_PORT="3307"

# Optional: Database Credentials
MYSQL_USER="app_user"
MYSQL_PASSWORD="your_password"
MYSQL_DATABASE="devops_app"
EOF
    log_warning "Please update $CONFIG_FILE with your actual values"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if SSH key exists
    if [[ ! -f "$BASTION_KEY" ]]; then
        log_error "SSH key not found: $BASTION_KEY"
        exit 1
    fi
    
    # Check key permissions
    local key_perms=$(stat -c "%a" "$BASTION_KEY" 2>/dev/null || stat -f "%A" "$BASTION_KEY" 2>/dev/null)
    if [[ "$key_perms" != "600" ]]; then
        log_warning "SSH key permissions are not secure. Fixing..."
        chmod 600 "$BASTION_KEY"
    fi
    
    # Check if required variables are set
    if [[ -z "$BASTION_HOST" || -z "$RDS_MYSQL_HOST" ]]; then
        log_error "Required configuration missing. Please update $CONFIG_FILE"
        exit 1
    fi
    
    # Check if local port is available
    if lsof -Pi :$LOCAL_MYSQL_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_error "Local port $LOCAL_MYSQL_PORT is already in use"
        log_info "Run: $0 stop to close existing tunnel"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Start SSH tunnel
start_tunnel() {
    log_info "Starting SSH tunnel for MySQL..."
    log_info "Local port: $LOCAL_MYSQL_PORT -> $RDS_MYSQL_HOST:$RDS_MYSQL_PORT via $BASTION_USER@$BASTION_HOST"
    
    # Start SSH tunnel in background
    ssh -f -N -L "$LOCAL_MYSQL_PORT:$RDS_MYSQL_HOST:$RDS_MYSQL_PORT" \
        -i "$BASTION_KEY" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        -o ServerAliveInterval=60 \
        -o ServerAliveCountMax=3 \
        "$BASTION_USER@$BASTION_HOST"
    
    # Get the PID of the SSH process
    local ssh_pid=$(ps aux | grep "ssh -f -N -L $LOCAL_MYSQL_PORT:$RDS_MYSQL_HOST:$RDS_MYSQL_PORT" | grep -v grep | awk '{print $2}')
    
    if [[ -n "$ssh_pid" ]]; then
        echo "$ssh_pid" > "$TUNNEL_PID_FILE"
        log_success "SSH tunnel started successfully (PID: $ssh_pid)"
        log_info "MySQL is now accessible at localhost:$LOCAL_MYSQL_PORT"
        
        # Test connection
        test_connection
    else
        log_error "Failed to start SSH tunnel"
        exit 1
    fi
}

# Stop SSH tunnel
stop_tunnel() {
    log_info "Stopping SSH tunnel for MySQL..."
    
    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        local pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$TUNNEL_PID_FILE"
            log_success "SSH tunnel stopped (PID: $pid)"
        else
            log_warning "Process $pid not found, cleaning up PID file"
            rm -f "$TUNNEL_PID_FILE"
        fi
    else
        # Try to find and kill tunnel process by command line
        local ssh_pid=$(ps aux | grep "ssh -f -N -L $LOCAL_MYSQL_PORT:$RDS_MYSQL_HOST:$RDS_MYSQL_PORT" | grep -v grep | awk '{print $2}')
        if [[ -n "$ssh_pid" ]]; then
            kill "$ssh_pid"
            log_success "SSH tunnel stopped (PID: $ssh_pid)"
        else
            log_warning "No active SSH tunnel found"
        fi
    fi
}

# Check tunnel status
status_tunnel() {
    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        local pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_success "SSH tunnel is running (PID: $pid)"
            log_info "MySQL accessible at localhost:$LOCAL_MYSQL_PORT"
        else
            log_warning "PID file exists but process not found"
            rm -f "$TUNNEL_PID_FILE"
        fi
    else
        local ssh_pid=$(ps aux | grep "ssh -f -N -L $LOCAL_MYSQL_PORT:$RDS_MYSQL_HOST:$RDS_MYSQL_PORT" | grep -v grep | awk '{print $2}')
        if [[ -n "$ssh_pid" ]]; then
            log_warning "SSH tunnel running but PID file missing (PID: $ssh_pid)"
            echo "$ssh_pid" > "$TUNNEL_PID_FILE"
        else
            log_info "SSH tunnel is not running"
        fi
    fi
}

# Test database connection
test_connection() {
    log_info "Testing MySQL connection..."
    
    # Wait a moment for tunnel to establish
    sleep 2
    
    if command -v mysql >/dev/null 2>&1; then
        if [[ -n "${MYSQL_USER:-}" && -n "${MYSQL_PASSWORD:-}" ]]; then
            if mysql -h localhost -P "$LOCAL_MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1;" >/dev/null 2>&1; then
                log_success "MySQL connection test successful"
            else
                log_error "MySQL connection test failed"
            fi
        else
            log_info "Database credentials not configured, skipping connection test"
        fi
    else
        log_info "MySQL client not installed, skipping connection test"
        log_info "You can test manually: mysql -h localhost -P $LOCAL_MYSQL_PORT -u username -p"
    fi
}

# Connect with MySQL client
connect_mysql() {
    if ! command -v mysql >/dev/null 2>&1; then
        log_error "MySQL client not installed"
        log_info "Install with: sudo apt-get install mysql-client (Ubuntu/Debian)"
        log_info "Or: brew install mysql (macOS)"
        exit 1
    fi
    
    if [[ -z "${MYSQL_USER:-}" || -z "${MYSQL_PASSWORD:-}" ]]; then
        log_error "Database credentials not configured"
        log_info "Please set MYSQL_USER and MYSQL_PASSWORD in $CONFIG_FILE"
        exit 1
    fi
    
    log_info "Connecting to MySQL via tunnel..."
    mysql -h localhost -P "$LOCAL_MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "${MYSQL_DATABASE:-}"
}

# Show connection details
show_details() {
    echo
    echo "=== MySQL SSH Tunnel Details ==="
    echo "Bastion Host: $BASTION_USER@$BASTION_HOST"
    echo "Remote MySQL: $RDS_MYSQL_HOST:$RDS_MYSQL_PORT"
    echo "Local Access: localhost:$LOCAL_MYSQL_PORT"
    echo "SSH Key: $BASTION_KEY"
    if [[ -n "${MYSQL_USER:-}" ]]; then
        echo "Database User: $MYSQL_USER"
        echo "Database: ${MYSQL_DATABASE:-devops_app}"
    fi
    echo
    echo "=== Connection Commands ==="
    echo "MySQL CLI: mysql -h localhost -P $LOCAL_MYSQL_PORT -u username -p"
    echo "DBeaver: localhost:$LOCAL_MYSQL_PORT"
    echo
}

# Show usage
usage() {
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  start     Start SSH tunnel to MySQL"
    echo "  stop      Stop SSH tunnel"
    echo "  restart   Restart SSH tunnel"
    echo "  status    Check tunnel status"
    echo "  test      Test database connection"
    echo "  connect   Connect with MySQL client"
    echo "  details   Show connection details"
    echo "  help      Show this help message"
    echo
    echo "Configuration file: $CONFIG_FILE"
}

# Main function
main() {
    local command="${1:-help}"
    
    case "$command" in
        start)
            load_config
            check_prerequisites
            start_tunnel
            show_details
            ;;
        stop)
            stop_tunnel
            ;;
        restart)
            load_config
            stop_tunnel
            sleep 2
            check_prerequisites
            start_tunnel
            show_details
            ;;
        status)
            status_tunnel
            ;;
        test)
            load_config
            test_connection
            ;;
        connect)
            load_config
            status_tunnel
            connect_mysql
            ;;
        details)
            load_config
            show_details
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
trap 'log_info "Script interrupted"; exit 1' INT TERM

# Run main function
main "$@"

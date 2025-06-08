#!/bin/bash

# SSH Tunnel Script for PostgreSQL RDS Access
# Creates secure tunnel through bastion host to access PostgreSQL RDS in private subnet

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/tunnel-config.env"

# Default values (can be overridden by config file)
BASTION_HOST=""
BASTION_USER="ec2-user"
BASTION_KEY="${HOME}/.ssh/devops-key.pem"
RDS_POSTGRESQL_HOST=""
RDS_POSTGRESQL_PORT="5432"
LOCAL_POSTGRESQL_PORT="5433"
TUNNEL_PID_FILE="/tmp/postgresql-tunnel.pid"

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
# SSH Tunnel Configuration for PostgreSQL RDS
# Copy this file and update with your actual values

# Bastion Host Configuration
BASTION_HOST="your-bastion-public-ip-or-dns"
BASTION_USER="ec2-user"
BASTION_KEY="${HOME}/.ssh/your-key.pem"

# RDS PostgreSQL Configuration
RDS_POSTGRESQL_HOST="your-postgresql-rds-endpoint"
RDS_POSTGRESQL_PORT="5432"

# Local Tunnel Configuration
LOCAL_POSTGRESQL_PORT="5433"

# Optional: Database Credentials
POSTGRESQL_USER="analytics_user"
POSTGRESQL_PASSWORD="your_password"
POSTGRESQL_DATABASE="devops_analytics"
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
    if [[ -z "$BASTION_HOST" || -z "$RDS_POSTGRESQL_HOST" ]]; then
        log_error "Required configuration missing. Please update $CONFIG_FILE"
        exit 1
    fi
    
    # Check if local port is available
    if lsof -Pi :$LOCAL_POSTGRESQL_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_error "Local port $LOCAL_POSTGRESQL_PORT is already in use"
        log_info "Run: $0 stop to close existing tunnel"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Start SSH tunnel
start_tunnel() {
    log_info "Starting SSH tunnel for PostgreSQL..."
    log_info "Local port: $LOCAL_POSTGRESQL_PORT -> $RDS_POSTGRESQL_HOST:$RDS_POSTGRESQL_PORT via $BASTION_USER@$BASTION_HOST"
    
    # Start SSH tunnel in background
    ssh -f -N -L "$LOCAL_POSTGRESQL_PORT:$RDS_POSTGRESQL_HOST:$RDS_POSTGRESQL_PORT" \
        -i "$BASTION_KEY" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        -o ServerAliveInterval=60 \
        -o ServerAliveCountMax=3 \
        "$BASTION_USER@$BASTION_HOST"
    
    # Get the PID of the SSH process
    local ssh_pid=$(ps aux | grep "ssh -f -N -L $LOCAL_POSTGRESQL_PORT:$RDS_POSTGRESQL_HOST:$RDS_POSTGRESQL_PORT" | grep -v grep | awk '{print $2}')
    
    if [[ -n "$ssh_pid" ]]; then
        echo "$ssh_pid" > "$TUNNEL_PID_FILE"
        log_success "SSH tunnel started successfully (PID: $ssh_pid)"
        log_info "PostgreSQL is now accessible at localhost:$LOCAL_POSTGRESQL_PORT"
        
        # Test connection
        test_connection
    else
        log_error "Failed to start SSH tunnel"
        exit 1
    fi
}

# Stop SSH tunnel
stop_tunnel() {
    log_info "Stopping SSH tunnel for PostgreSQL..."
    
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
        local ssh_pid=$(ps aux | grep "ssh -f -N -L $LOCAL_POSTGRESQL_PORT:$RDS_POSTGRESQL_HOST:$RDS_POSTGRESQL_PORT" | grep -v grep | awk '{print $2}')
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
            log_info "PostgreSQL accessible at localhost:$LOCAL_POSTGRESQL_PORT"
        else
            log_warning "PID file exists but process not found"
            rm -f "$TUNNEL_PID_FILE"
        fi
    else
        local ssh_pid=$(ps aux | grep "ssh -f -N -L $LOCAL_POSTGRESQL_PORT:$RDS_POSTGRESQL_HOST:$RDS_POSTGRESQL_PORT" | grep -v grep | awk '{print $2}')
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
    log_info "Testing PostgreSQL connection..."
    
    # Wait a moment for tunnel to establish
    sleep 2
    
    if command -v psql >/dev/null 2>&1; then
        if [[ -n "${POSTGRESQL_USER:-}" && -n "${POSTGRESQL_PASSWORD:-}" ]]; then
            export PGPASSWORD="$POSTGRESQL_PASSWORD"
            if psql -h localhost -p "$LOCAL_POSTGRESQL_PORT" -U "$POSTGRESQL_USER" -d "${POSTGRESQL_DATABASE:-postgres}" -c "SELECT 1;" >/dev/null 2>&1; then
                log_success "PostgreSQL connection test successful"
            else
                log_error "PostgreSQL connection test failed"
            fi
            unset PGPASSWORD
        else
            log_info "Database credentials not configured, skipping connection test"
        fi
    else
        log_info "PostgreSQL client not installed, skipping connection test"
        log_info "You can test manually: psql -h localhost -p $LOCAL_POSTGRESQL_PORT -U username -d database"
    fi
}

# Connect with PostgreSQL client
connect_postgresql() {
    if ! command -v psql >/dev/null 2>&1; then
        log_error "PostgreSQL client not installed"
        log_info "Install with: sudo apt-get install postgresql-client (Ubuntu/Debian)"
        log_info "Or: brew install postgresql (macOS)"
        exit 1
    fi
    
    if [[ -z "${POSTGRESQL_USER:-}" || -z "${POSTGRESQL_PASSWORD:-}" ]]; then
        log_error "Database credentials not configured"
        log_info "Please set POSTGRESQL_USER and POSTGRESQL_PASSWORD in $CONFIG_FILE"
        exit 1
    fi
    
    log_info "Connecting to PostgreSQL via tunnel..."
    export PGPASSWORD="$POSTGRESQL_PASSWORD"
    psql -h localhost -p "$LOCAL_POSTGRESQL_PORT" -U "$POSTGRESQL_USER" -d "${POSTGRESQL_DATABASE:-postgres}"
    unset PGPASSWORD
}

# Show connection details
show_details() {
    echo
    echo "=== PostgreSQL SSH Tunnel Details ==="
    echo "Bastion Host: $BASTION_USER@$BASTION_HOST"
    echo "Remote PostgreSQL: $RDS_POSTGRESQL_HOST:$RDS_POSTGRESQL_PORT"
    echo "Local Access: localhost:$LOCAL_POSTGRESQL_PORT"
    echo "SSH Key: $BASTION_KEY"
    if [[ -n "${POSTGRESQL_USER:-}" ]]; then
        echo "Database User: $POSTGRESQL_USER"
        echo "Database: ${POSTGRESQL_DATABASE:-devops_analytics}"
    fi
    echo
    echo "=== Connection Commands ==="
    echo "PostgreSQL CLI: psql -h localhost -p $LOCAL_POSTGRESQL_PORT -U username -d database"
    echo "DBeaver: localhost:$LOCAL_POSTGRESQL_PORT"
    echo
}

# Show usage
usage() {
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  start     Start SSH tunnel to PostgreSQL"
    echo "  stop      Stop SSH tunnel"
    echo "  restart   Restart SSH tunnel"
    echo "  status    Check tunnel status"
    echo "  test      Test database connection"
    echo "  connect   Connect with PostgreSQL client"
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
            connect_postgresql
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

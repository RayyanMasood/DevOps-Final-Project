#!/bin/bash

# Database Security Configuration Script
# Configures security settings for RDS instances and bastion host access

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/tunnel-config.env"
LOG_FILE="/tmp/database-security.log"

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
        log_warning "Configuration file not found: $CONFIG_FILE"
    fi
}

# Create secure SSH configuration
create_ssh_config() {
    log_info "Creating secure SSH configuration..."
    
    local ssh_config_dir="${HOME}/.ssh"
    local ssh_config_file="${ssh_config_dir}/config"
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "$ssh_config_dir"
    chmod 700 "$ssh_config_dir"
    
    # Backup existing SSH config
    if [[ -f "$ssh_config_file" ]]; then
        cp "$ssh_config_file" "${ssh_config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Existing SSH config backed up"
    fi
    
    # Create SSH config for bastion host
    cat >> "$ssh_config_file" << EOF

# DevOps Database Access Configuration
Host devops-bastion
    HostName ${BASTION_HOST:-your-bastion-host}
    User ${BASTION_USER:-ec2-user}
    IdentityFile ${BASTION_KEY:-~/.ssh/devops-key.pem}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ControlMaster auto
    ControlPath /tmp/ssh_mux_%h_%p_%r
    ControlPersist 10m

# MySQL Tunnel
Host mysql-tunnel
    HostName ${BASTION_HOST:-your-bastion-host}
    User ${BASTION_USER:-ec2-user}
    IdentityFile ${BASTION_KEY:-~/.ssh/devops-key.pem}
    LocalForward ${LOCAL_MYSQL_PORT:-3307} ${RDS_MYSQL_HOST:-mysql-endpoint}:${RDS_MYSQL_PORT:-3306}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    ServerAliveInterval 60
    ServerAliveCountMax 3

# PostgreSQL Tunnel
Host postgresql-tunnel
    HostName ${BASTION_HOST:-your-bastion-host}
    User ${BASTION_USER:-ec2-user}
    IdentityFile ${BASTION_KEY:-~/.ssh/devops-key.pem}
    LocalForward ${LOCAL_POSTGRESQL_PORT:-5433} ${RDS_POSTGRESQL_HOST:-postgresql-endpoint}:${RDS_POSTGRESQL_PORT:-5432}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF

    chmod 600 "$ssh_config_file"
    log_success "SSH configuration created"
}

# Configure database user security
configure_database_users() {
    log_info "Configuring database user security..."
    
    # MySQL user configuration
    if command -v mysql >/dev/null 2>&1 && [[ -n "${MYSQL_USER:-}" && -n "${MYSQL_PASSWORD:-}" ]]; then
        log_info "Configuring MySQL users..."
        
        local mysql_cmd="mysql -h localhost -P ${LOCAL_MYSQL_PORT:-3307} -u root -p"
        
        cat > /tmp/mysql_security.sql << EOF
-- Create application-specific users with limited privileges
CREATE USER IF NOT EXISTS 'app_readonly'@'%' IDENTIFIED BY '$(openssl rand -base64 32)';
CREATE USER IF NOT EXISTS 'analytics_user'@'%' IDENTIFIED BY '$(openssl rand -base64 32)';
CREATE USER IF NOT EXISTS 'backup_user'@'%' IDENTIFIED BY '$(openssl rand -base64 32)';

-- Grant minimal required privileges
GRANT SELECT ON devops_app.* TO 'app_readonly'@'%';
GRANT SELECT, INSERT, UPDATE ON devops_app.* TO 'analytics_user'@'%';
GRANT SELECT, LOCK TABLES, SHOW VIEW ON devops_app.* TO 'backup_user'@'%';

-- Remove unnecessary privileges
REVOKE ALL ON *.* FROM 'app_user'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON devops_app.* TO 'app_user'@'%';

-- Enable password validation
SET GLOBAL validate_password.policy = STRONG;
SET GLOBAL validate_password.length = 12;

-- Configure SSL requirements (if supported)
ALTER USER 'app_user'@'%' REQUIRE SSL;
ALTER USER 'analytics_user'@'%' REQUIRE SSL;

-- Set account resource limits
ALTER USER 'app_user'@'%' WITH MAX_QUERIES_PER_HOUR 10000;
ALTER USER 'analytics_user'@'%' WITH MAX_QUERIES_PER_HOUR 5000;

FLUSH PRIVILEGES;
EOF

        log_info "MySQL security configuration script created at /tmp/mysql_security.sql"
        log_warning "Run this script manually with root privileges to apply security settings"
    fi
    
    # PostgreSQL user configuration
    if command -v psql >/dev/null 2>&1 && [[ -n "${POSTGRESQL_USER:-}" && -n "${POSTGRESQL_PASSWORD:-}" ]]; then
        log_info "Configuring PostgreSQL users..."
        
        export PGPASSWORD="$POSTGRESQL_PASSWORD"
        
        cat > /tmp/postgresql_security.sql << EOF
-- Create role-based access control
CREATE ROLE IF NOT EXISTS analytics_readonly;
CREATE ROLE IF NOT EXISTS analytics_readwrite;
CREATE ROLE IF NOT EXISTS analytics_admin;

-- Grant privileges to roles
GRANT CONNECT ON DATABASE devops_analytics TO analytics_readonly;
GRANT USAGE ON SCHEMA public TO analytics_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO analytics_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO analytics_readonly;

GRANT CONNECT ON DATABASE devops_analytics TO analytics_readwrite;
GRANT USAGE, CREATE ON SCHEMA public TO analytics_readwrite;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO analytics_readwrite;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO analytics_readwrite;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO analytics_readwrite;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO analytics_readwrite;

-- Create users with specific roles
CREATE USER analytics_viewer WITH PASSWORD 'secure_readonly_password_$(openssl rand -hex 8)';
CREATE USER analytics_writer WITH PASSWORD 'secure_readwrite_password_$(openssl rand -hex 8)';
CREATE USER analytics_backup WITH PASSWORD 'secure_backup_password_$(openssl rand -hex 8)';

-- Assign roles to users
GRANT analytics_readonly TO analytics_viewer;
GRANT analytics_readwrite TO analytics_writer;
GRANT analytics_readonly TO analytics_backup;

-- Set connection limits
ALTER USER analytics_viewer CONNECTION LIMIT 10;
ALTER USER analytics_writer CONNECTION LIMIT 20;
ALTER USER analytics_backup CONNECTION LIMIT 5;

-- Configure security settings
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
ALTER SYSTEM SET log_statement = 'mod';
ALTER SYSTEM SET log_min_duration_statement = '1000';

-- Row Level Security example (uncomment if needed)
-- ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY user_data_policy ON analytics_events FOR ALL TO analytics_viewer USING (user_id = current_setting('app.current_user_id')::int);

SELECT pg_reload_conf();
EOF

        log_info "PostgreSQL security configuration script created at /tmp/postgresql_security.sql"
        log_warning "Run this script manually with superuser privileges to apply security settings"
        
        unset PGPASSWORD
    fi
}

# Create database connection monitoring
setup_connection_monitoring() {
    log_info "Setting up database connection monitoring..."
    
    # Create connection monitor script
    cat > "${SCRIPT_DIR}/connection-monitor.sh" << 'EOF'
#!/bin/bash

# Database Connection Monitor
# Monitors active connections and alerts on suspicious activity

LOG_FILE="/tmp/connection-monitor.log"
ALERT_THRESHOLD_CONNECTIONS=50
ALERT_THRESHOLD_FAILED_LOGINS=10

log_alert() {
    echo "[ALERT $(date)] $1" | tee -a "$LOG_FILE"
    # Send to external monitoring system if configured
    # curl -X POST "$WEBHOOK_URL" -d "{\"alert\": \"$1\"}"
}

# Monitor MySQL connections
monitor_mysql_connections() {
    if command -v mysql >/dev/null 2>&1; then
        local connections=$(mysql -h localhost -P 3307 -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null | tail -1 | awk '{print $2}')
        
        if [[ $connections -gt $ALERT_THRESHOLD_CONNECTIONS ]]; then
            log_alert "High MySQL connection count: $connections"
        fi
        
        # Check for failed login attempts
        local failed_logins=$(mysql -h localhost -P 3307 -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW STATUS LIKE 'Aborted_connects';" 2>/dev/null | tail -1 | awk '{print $2}')
        
        if [[ $failed_logins -gt $ALERT_THRESHOLD_FAILED_LOGINS ]]; then
            log_alert "High MySQL failed login attempts: $failed_logins"
        fi
    fi
}

# Monitor PostgreSQL connections
monitor_postgresql_connections() {
    if command -v psql >/dev/null 2>&1; then
        export PGPASSWORD="$POSTGRESQL_PASSWORD"
        
        local connections=$(psql -h localhost -p 5433 -U "$POSTGRESQL_USER" -d "$POSTGRESQL_DATABASE" -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | xargs)
        
        if [[ $connections -gt $ALERT_THRESHOLD_CONNECTIONS ]]; then
            log_alert "High PostgreSQL connection count: $connections"
        fi
        
        # Check for long-running queries
        local long_queries=$(psql -h localhost -p 5433 -U "$POSTGRESQL_USER" -d "$POSTGRESQL_DATABASE" -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active' AND query_start < NOW() - INTERVAL '10 minutes';" 2>/dev/null | xargs)
        
        if [[ $long_queries -gt 0 ]]; then
            log_alert "PostgreSQL has $long_queries long-running queries"
        fi
        
        unset PGPASSWORD
    fi
}

# Load configuration
if [[ -f "$(dirname "$0")/tunnel-config.env" ]]; then
    source "$(dirname "$0")/tunnel-config.env"
fi

# Run monitoring
monitor_mysql_connections
monitor_postgresql_connections
EOF

    chmod +x "${SCRIPT_DIR}/connection-monitor.sh"
    log_success "Connection monitoring script created"
}

# Create SSL certificate configuration
setup_ssl_certificates() {
    log_info "Setting up SSL certificate configuration..."
    
    local ssl_dir="${SCRIPT_DIR}/../ssl"
    mkdir -p "$ssl_dir"
    
    # Create certificate configuration
    cat > "${ssl_dir}/ssl-config.cnf" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[dn]
C=US
ST=State
L=City
O=DevOps Organization
OU=Database Team
CN=database.devops.local
emailAddress=admin@devops.local

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = database.devops.local
IP.1 = 127.0.0.1
EOF

    # Create self-signed certificate for local development
    if command -v openssl >/dev/null 2>&1; then
        openssl req -new -x509 -days 365 -nodes \
            -out "${ssl_dir}/database-cert.pem" \
            -keyout "${ssl_dir}/database-key.pem" \
            -config "${ssl_dir}/ssl-config.cnf" \
            -extensions v3_req 2>/dev/null
        
        chmod 600 "${ssl_dir}/database-key.pem"
        chmod 644 "${ssl_dir}/database-cert.pem"
        
        log_success "SSL certificates created for local development"
    fi
    
    # Create SSL connection guide
    cat > "${ssl_dir}/README.md" << EOF
# SSL Configuration Guide

## Files
- \`database-cert.pem\`: SSL certificate for database connections
- \`database-key.pem\`: Private key for SSL certificate
- \`ssl-config.cnf\`: Certificate configuration

## MySQL SSL Connection
\`\`\`bash
mysql -h localhost -P 3307 -u username -p \\
  --ssl-ca=ssl/database-cert.pem \\
  --ssl-verify-server-cert
\`\`\`

## PostgreSQL SSL Connection
\`\`\`bash
psql "host=localhost port=5433 user=username dbname=database sslmode=require sslcert=ssl/database-cert.pem sslkey=ssl/database-key.pem"
\`\`\`

## DBeaver SSL Configuration
1. Go to connection properties
2. Enable "Use SSL"
3. Set SSL mode to "Require"
4. Browse to certificate file: \`ssl/database-cert.pem\`
5. Browse to key file: \`ssl/database-key.pem\`

## Production Notes
- Replace self-signed certificates with proper CA-signed certificates
- Configure RDS to require SSL connections
- Use AWS Certificate Manager for managed certificates
EOF

    log_success "SSL configuration guide created"
}

# Create audit logging configuration
setup_audit_logging() {
    log_info "Setting up database audit logging..."
    
    local audit_dir="${SCRIPT_DIR}/../logs"
    mkdir -p "$audit_dir"
    
    # Create audit log rotation configuration
    cat > "${audit_dir}/logrotate.conf" << EOF
# Database Audit Log Rotation Configuration

${audit_dir}/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    sharedscripts
    postrotate
        # Send signal to reload logs if needed
        /bin/kill -HUP \$(cat /var/run/rsyslog.pid 2>/dev/null) 2>/dev/null || true
    endscript
}

/tmp/database-*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF

    # Create audit script
    cat > "${SCRIPT_DIR}/audit-logger.sh" << 'EOF'
#!/bin/bash

# Database Audit Logger
# Logs database operations for security auditing

AUDIT_LOG="/tmp/database-audit.log"

log_audit() {
    local operation="$1"
    local details="$2"
    local user="${3:-$(whoami)}"
    local timestamp=$(date -Iseconds)
    
    echo "[$timestamp] USER:$user OPERATION:$operation DETAILS:$details" >> "$AUDIT_LOG"
}

# Function to wrap database commands with audit logging
audit_mysql() {
    log_audit "MYSQL_CONNECT" "host=localhost:3307 user=$MYSQL_USER"
    mysql -h localhost -P 3307 -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$@"
    log_audit "MYSQL_DISCONNECT" "exit_code=$?"
}

audit_psql() {
    log_audit "POSTGRESQL_CONNECT" "host=localhost:5433 user=$POSTGRESQL_USER"
    export PGPASSWORD="$POSTGRESQL_PASSWORD"
    psql -h localhost -p 5433 -U "$POSTGRESQL_USER" -d "$POSTGRESQL_DATABASE" "$@"
    local exit_code=$?
    unset PGPASSWORD
    log_audit "POSTGRESQL_DISCONNECT" "exit_code=$exit_code"
}

# Load configuration
if [[ -f "$(dirname "$0")/tunnel-config.env" ]]; then
    source "$(dirname "$0")/tunnel-config.env"
fi

# Check if function is being called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        mysql)
            shift
            audit_mysql "$@"
            ;;
        psql)
            shift
            audit_psql "$@"
            ;;
        *)
            echo "Usage: $0 [mysql|psql] [additional_args...]"
            exit 1
            ;;
    esac
fi
EOF

    chmod +x "${SCRIPT_DIR}/audit-logger.sh"
    log_success "Audit logging configuration created"
}

# Create security checklist
create_security_checklist() {
    log_info "Creating security checklist..."
    
    cat > "${SCRIPT_DIR}/../SECURITY_CHECKLIST.md" << EOF
# Database Security Checklist

## Infrastructure Security
- [ ] RDS instances are in private subnets
- [ ] Security groups restrict database access to bastion host only
- [ ] Bastion host has minimal necessary ports open (22)
- [ ] SSH keys are properly secured (600 permissions)
- [ ] VPC has flow logs enabled
- [ ] Network ACLs are configured restrictively

## Database Security
- [ ] Root/superuser accounts have strong passwords
- [ ] Application users have minimal required privileges
- [ ] SSL/TLS encryption is enforced for connections
- [ ] Database audit logging is enabled
- [ ] Regular security updates are applied
- [ ] Backup encryption is enabled
- [ ] Parameter groups follow security best practices

## Access Control
- [ ] SSH access is restricted to specific IP ranges
- [ ] Database users are created per application/service
- [ ] Connection limits are set appropriately
- [ ] Failed login monitoring is configured
- [ ] Session timeouts are configured

## Monitoring & Alerting
- [ ] Connection monitoring is active
- [ ] Slow query logging is enabled
- [ ] Failed authentication attempts are monitored
- [ ] Unusual access patterns trigger alerts
- [ ] Regular security scans are performed

## Backup & Recovery
- [ ] Automated backups are encrypted
- [ ] Backup retention policies are defined
- [ ] Recovery procedures are tested
- [ ] Point-in-time recovery is available
- [ ] Cross-region backup replication (if required)

## Compliance
- [ ] Data at rest encryption is enabled
- [ ] Data in transit encryption is enforced
- [ ] Audit trails are maintained
- [ ] Access logs are retained per policy
- [ ] Regular compliance scans are performed

## Emergency Procedures
- [ ] Incident response plan is documented
- [ ] Emergency contact list is current
- [ ] Backup restore procedures are tested
- [ ] Disaster recovery plan is documented
- [ ] Security breach procedures are defined
EOF

    log_success "Security checklist created"
}

# Generate security report
generate_security_report() {
    log_info "Generating security assessment report..."
    
    local report_file="${SCRIPT_DIR}/../security-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== Database Security Assessment Report ==="
        echo "Generated: $(date)"
        echo "Host: $(hostname)"
        echo "User: $(whoami)"
        echo
        
        echo "=== SSH Configuration ==="
        if [[ -f "${HOME}/.ssh/config" ]]; then
            echo "SSH config exists: ✓"
        else
            echo "SSH config missing: ✗"
        fi
        
        if [[ -f "${BASTION_KEY:-}" ]]; then
            local key_perms=$(stat -c "%a" "$BASTION_KEY" 2>/dev/null || stat -f "%A" "$BASTION_KEY" 2>/dev/null)
            if [[ "$key_perms" == "600" ]]; then
                echo "SSH key permissions secure: ✓"
            else
                echo "SSH key permissions insecure ($key_perms): ✗"
            fi
        else
            echo "SSH key not found: ✗"
        fi
        
        echo
        echo "=== Database Connectivity ==="
        if lsof -Pi :${LOCAL_MYSQL_PORT:-3307} -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo "MySQL tunnel active: ✓"
        else
            echo "MySQL tunnel inactive: ✗"
        fi
        
        if lsof -Pi :${LOCAL_POSTGRESQL_PORT:-5433} -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo "PostgreSQL tunnel active: ✓"
        else
            echo "PostgreSQL tunnel inactive: ✗"
        fi
        
        echo
        echo "=== Security Files ==="
        echo "SSL certificates: $([[ -f "${SCRIPT_DIR}/../ssl/database-cert.pem" ]] && echo "✓" || echo "✗")"
        echo "Audit logging: $([[ -f "${SCRIPT_DIR}/audit-logger.sh" ]] && echo "✓" || echo "✗")"
        echo "Connection monitor: $([[ -f "${SCRIPT_DIR}/connection-monitor.sh" ]] && echo "✓" || echo "✗")"
        
        echo
        echo "=== Recommendations ==="
        echo "1. Regularly rotate SSH keys and database passwords"
        echo "2. Monitor connection logs for suspicious activity"
        echo "3. Keep bastion host and database software updated"
        echo "4. Implement network-level monitoring"
        echo "5. Regular security audits and penetration testing"
        
    } > "$report_file"
    
    log_success "Security report generated: $(basename "$report_file")"
    
    # Display summary
    echo
    echo "=== Security Report Summary ==="
    cat "$report_file"
}

# Show usage
usage() {
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  setup       Run complete security setup"
    echo "  ssh         Configure SSH settings"
    echo "  users       Configure database users"
    echo "  monitor     Setup connection monitoring"
    echo "  ssl         Setup SSL certificates"
    echo "  audit       Setup audit logging"
    echo "  checklist   Create security checklist"
    echo "  report      Generate security assessment"
    echo "  help        Show this help message"
    echo
    echo "Examples:"
    echo "  $0 setup     # Complete security configuration"
    echo "  $0 report    # Generate security assessment"
}

# Main function
main() {
    local command="${1:-setup}"
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    
    # Load configuration
    load_config
    
    case "$command" in
        setup)
            log_info "Starting complete security setup..."
            create_ssh_config
            configure_database_users
            setup_connection_monitoring
            setup_ssl_certificates
            setup_audit_logging
            create_security_checklist
            generate_security_report
            log_success "Security setup completed"
            ;;
        ssh)
            create_ssh_config
            ;;
        users)
            configure_database_users
            ;;
        monitor)
            setup_connection_monitoring
            ;;
        ssl)
            setup_ssl_certificates
            ;;
        audit)
            setup_audit_logging
            ;;
        checklist)
            create_security_checklist
            ;;
        report)
            generate_security_report
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
trap 'log_info "Security setup interrupted"; exit 1' INT TERM

# Run main function
main "$@"

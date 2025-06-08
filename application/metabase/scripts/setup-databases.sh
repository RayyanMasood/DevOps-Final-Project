#!/bin/bash

# Metabase Database Connection Setup Script
# Configures connections to MySQL and PostgreSQL RDS instances

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/metabase-db-setup.log"
METABASE_URL="${METABASE_URL:-http://localhost:3000}"
CONFIG_FILE="${SCRIPT_DIR}/../config/database-connections.json"

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

# Load environment variables
load_environment() {
    local env_file="${SCRIPT_DIR}/../.env"
    
    if [[ -f "$env_file" ]]; then
        # Load environment variables
        set -a
        source "$env_file"
        set +a
        log_info "Environment variables loaded"
    else
        log_error "Environment file not found: $env_file"
        exit 1
    fi
}

# Wait for Metabase to be ready
wait_for_metabase() {
    log_info "Waiting for Metabase to be ready..."
    
    local max_attempts=60
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f -s "$METABASE_URL/api/health" >/dev/null 2>&1; then
            log_success "Metabase is ready"
            return 0
        else
            log_info "Waiting for Metabase... (attempt $attempt/$max_attempts)"
            sleep 5
            ((attempt++))
        fi
    done
    
    log_error "Metabase is not ready after $max_attempts attempts"
    return 1
}

# Get Metabase session token
get_session_token() {
    log_info "Authenticating with Metabase..."
    
    # Check if Metabase is set up
    local setup_token=$(curl -s "$METABASE_URL/api/session/properties" | jq -r '.["setup-token"]' 2>/dev/null || echo "null")
    
    if [[ "$setup_token" != "null" && -n "$setup_token" ]]; then
        log_info "Metabase setup required. Running initial setup..."
        run_initial_setup "$setup_token"
    fi
    
    # Authenticate with admin credentials
    local response=$(curl -s -X POST "$METABASE_URL/api/session" \
        -H "Content-Type: application/json" \
        -d "{
            \"username\": \"${METABASE_ADMIN_EMAIL}\",
            \"password\": \"${METABASE_ADMIN_PASSWORD}\"
        }")
    
    local session_id=$(echo "$response" | jq -r '.id' 2>/dev/null || echo "null")
    
    if [[ "$session_id" == "null" || -z "$session_id" ]]; then
        log_error "Failed to authenticate with Metabase"
        log_error "Response: $response"
        return 1
    fi
    
    echo "$session_id"
}

# Run initial Metabase setup
run_initial_setup() {
    local setup_token="$1"
    
    log_info "Running Metabase initial setup..."
    
    # Generate admin password if not set
    if [[ -z "${METABASE_ADMIN_PASSWORD:-}" ]]; then
        METABASE_ADMIN_PASSWORD=$(openssl rand -base64 20)
        log_info "Generated admin password: $METABASE_ADMIN_PASSWORD"
    fi
    
    # Setup admin user and skip initial database setup
    local setup_response=$(curl -s -X POST "$METABASE_URL/api/setup" \
        -H "Content-Type: application/json" \
        -d "{
            \"token\": \"$setup_token\",
            \"user\": {
                \"first_name\": \"Admin\",
                \"last_name\": \"User\",
                \"email\": \"${METABASE_ADMIN_EMAIL}\",
                \"password\": \"${METABASE_ADMIN_PASSWORD}\"
            },
            \"database\": null,
            \"invite\": null,
            \"prefs\": {
                \"site_name\": \"DevOps Analytics Dashboard\",
                \"allow_tracking\": false
            }
        }")
    
    local setup_id=$(echo "$setup_response" | jq -r '.id' 2>/dev/null || echo "null")
    
    if [[ "$setup_id" == "null" ]]; then
        log_error "Failed to complete initial setup"
        log_error "Response: $setup_response"
        return 1
    fi
    
    log_success "Initial setup completed"
    
    # Save admin credentials
    cat >> "${SCRIPT_DIR}/../.env" <<EOF

# Metabase Admin Credentials (Generated during setup)
METABASE_ADMIN_PASSWORD=${METABASE_ADMIN_PASSWORD}
EOF
}

# Create database connection
create_database_connection() {
    local session_token="$1"
    local db_config="$2"
    
    local db_name=$(echo "$db_config" | jq -r '.name')
    local db_engine=$(echo "$db_config" | jq -r '.engine')
    
    log_info "Creating database connection: $db_name ($db_engine)"
    
    # Check if database already exists
    local existing_db=$(curl -s -H "X-Metabase-Session: $session_token" \
        "$METABASE_URL/api/database" | \
        jq -r ".data[] | select(.name == \"$db_name\") | .id" 2>/dev/null || echo "")
    
    if [[ -n "$existing_db" ]]; then
        log_warning "Database connection '$db_name' already exists (ID: $existing_db)"
        echo "$existing_db"
        return 0
    fi
    
    # Create new database connection
    local response=$(curl -s -X POST "$METABASE_URL/api/database" \
        -H "Content-Type: application/json" \
        -H "X-Metabase-Session: $session_token" \
        -d "$db_config")
    
    local db_id=$(echo "$response" | jq -r '.id' 2>/dev/null || echo "null")
    
    if [[ "$db_id" == "null" || -z "$db_id" ]]; then
        log_error "Failed to create database connection: $db_name"
        log_error "Response: $response"
        return 1
    fi
    
    log_success "Database connection created: $db_name (ID: $db_id)"
    
    # Sync database schema
    log_info "Syncing database schema for $db_name..."
    curl -s -X POST "$METABASE_URL/api/database/$db_id/sync_schema" \
        -H "X-Metabase-Session: $session_token" >/dev/null
    
    echo "$db_id"
}

# Setup MySQL connection
setup_mysql_connection() {
    local session_token="$1"
    
    log_info "Setting up MySQL connection..."
    
    local mysql_config=$(cat <<EOF
{
    "name": "DevOps MySQL (Business Data)",
    "engine": "mysql",
    "details": {
        "host": "${MYSQL_RDS_HOST}",
        "port": ${MYSQL_RDS_PORT:-3306},
        "dbname": "${MYSQL_RDS_DATABASE}",
        "user": "${MYSQL_RDS_USER}",
        "password": "${MYSQL_RDS_PASSWORD}",
        "ssl": true,
        "ssl-mode": "preferred",
        "tunnel-enabled": false,
        "additional-options": "useUnicode=true&characterEncoding=UTF8&autoReconnect=true&useSSL=true&verifyServerCertificate=false",
        "let-user-control-scheduling": false
    },
    "auto_run_queries": true,
    "is_full_sync": true,
    "schedules": {
        "metadata_sync": {
            "schedule_day": null,
            "schedule_frame": null,
            "schedule_hour": 0,
            "schedule_type": "hourly"
        },
        "cache_field_values": {
            "schedule_day": null,
            "schedule_frame": null,
            "schedule_hour": 0,
            "schedule_type": "hourly"
        }
    }
}
EOF
)
    
    create_database_connection "$session_token" "$mysql_config"
}

# Setup PostgreSQL connection
setup_postgresql_connection() {
    local session_token="$1"
    
    log_info "Setting up PostgreSQL connection..."
    
    local postgresql_config=$(cat <<EOF
{
    "name": "DevOps PostgreSQL (Analytics)",
    "engine": "postgres",
    "details": {
        "host": "${POSTGRESQL_RDS_HOST}",
        "port": ${POSTGRESQL_RDS_PORT:-5432},
        "dbname": "${POSTGRESQL_RDS_DATABASE}",
        "user": "${POSTGRESQL_RDS_USER}",
        "password": "${POSTGRESQL_RDS_PASSWORD}",
        "ssl": true,
        "ssl-mode": "require",
        "tunnel-enabled": false,
        "schema-filters-type": "inclusion",
        "schema-filters-patterns": "public",
        "let-user-control-scheduling": false
    },
    "auto_run_queries": true,
    "is_full_sync": true,
    "schedules": {
        "metadata_sync": {
            "schedule_day": null,
            "schedule_frame": null,
            "schedule_hour": 0,
            "schedule_type": "hourly"
        },
        "cache_field_values": {
            "schedule_day": null,
            "schedule_frame": null,
            "schedule_hour": 0,
            "schedule_type": "hourly"
        }
    }
}
EOF
)
    
    create_database_connection "$session_token" "$postgresql_config"
}

# Create database users for read-only access
create_readonly_users() {
    log_info "Creating read-only database users..."
    
    # MySQL read-only user creation script
    cat > "/tmp/create_mysql_readonly_user.sql" <<EOF
-- Create read-only user for Metabase
CREATE USER IF NOT EXISTS '${MYSQL_RDS_USER}'@'%' IDENTIFIED BY '${MYSQL_RDS_PASSWORD}';

-- Grant SELECT privileges on all tables in devops_app database
GRANT SELECT ON ${MYSQL_RDS_DATABASE}.* TO '${MYSQL_RDS_USER}'@'%';

-- Grant SHOW VIEW privilege to see views
GRANT SHOW VIEW ON ${MYSQL_RDS_DATABASE}.* TO '${MYSQL_RDS_USER}'@'%';

-- Refresh privileges
FLUSH PRIVILEGES;

-- Show granted privileges
SHOW GRANTS FOR '${MYSQL_RDS_USER}'@'%';
EOF

    # PostgreSQL read-only user creation script
    cat > "/tmp/create_postgresql_readonly_user.sql" <<EOF
-- Create read-only user for Metabase
CREATE USER ${POSTGRESQL_RDS_USER} WITH PASSWORD '${POSTGRESQL_RDS_PASSWORD}';

-- Grant connect privilege
GRANT CONNECT ON DATABASE ${POSTGRESQL_RDS_DATABASE} TO ${POSTGRESQL_RDS_USER};

-- Grant usage on public schema
GRANT USAGE ON SCHEMA public TO ${POSTGRESQL_RDS_USER};

-- Grant select on all existing tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ${POSTGRESQL_RDS_USER};

-- Grant select on all sequences (for auto-incrementing fields)
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO ${POSTGRESQL_RDS_USER};

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO ${POSTGRESQL_RDS_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO ${POSTGRESQL_RDS_USER};

-- Show granted privileges
\du ${POSTGRESQL_RDS_USER}
EOF

    log_success "Database user creation scripts generated"
    log_info "MySQL script: /tmp/create_mysql_readonly_user.sql"
    log_info "PostgreSQL script: /tmp/create_postgresql_readonly_user.sql"
    log_warning "Please execute these scripts on your respective databases to create read-only users"
}

# Test database connections
test_database_connections() {
    local session_token="$1"
    
    log_info "Testing database connections..."
    
    # Get all databases
    local databases=$(curl -s -H "X-Metabase-Session: $session_token" \
        "$METABASE_URL/api/database" | jq -r '.data[].id')
    
    for db_id in $databases; do
        log_info "Testing connection for database ID: $db_id"
        
        local test_result=$(curl -s -X POST "$METABASE_URL/api/database/$db_id/validate" \
            -H "X-Metabase-Session: $session_token")
        
        local is_valid=$(echo "$test_result" | jq -r '.valid' 2>/dev/null || echo "false")
        
        if [[ "$is_valid" == "true" ]]; then
            log_success "Database connection test passed for ID: $db_id"
        else
            log_error "Database connection test failed for ID: $db_id"
            log_error "Error: $(echo "$test_result" | jq -r '.message' 2>/dev/null || echo "Unknown error")"
        fi
    done
}

# Configure database refresh schedules
configure_refresh_schedules() {
    local session_token="$1"
    
    log_info "Configuring database refresh schedules..."
    
    # Get all databases
    local databases=$(curl -s -H "X-Metabase-Session: $session_token" \
        "$METABASE_URL/api/database" | jq -r '.data[] | select(.engine != "h2") | .id')
    
    for db_id in $databases; do
        log_info "Configuring refresh schedule for database ID: $db_id"
        
        # Set metadata sync to every hour
        curl -s -X PUT "$METABASE_URL/api/database/$db_id" \
            -H "Content-Type: application/json" \
            -H "X-Metabase-Session: $session_token" \
            -d "{
                \"schedules\": {
                    \"metadata_sync\": {
                        \"schedule_day\": null,
                        \"schedule_frame\": null,
                        \"schedule_hour\": 0,
                        \"schedule_type\": \"hourly\"
                    },
                    \"cache_field_values\": {
                        \"schedule_day\": null,
                        \"schedule_frame\": null,
                        \"schedule_hour\": 0,
                        \"schedule_type\": \"daily\"
                    }
                }
            }" >/dev/null
        
        log_success "Refresh schedule configured for database ID: $db_id"
    done
}

# Save database configuration
save_database_config() {
    local session_token="$1"
    
    log_info "Saving database configuration..."
    
    # Create config directory if it doesn't exist
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # Get all database configurations
    local databases=$(curl -s -H "X-Metabase-Session: $session_token" \
        "$METABASE_URL/api/database")
    
    # Save to config file
    echo "$databases" | jq '.' > "$CONFIG_FILE"
    
    log_success "Database configuration saved to: $CONFIG_FILE"
}

# Show connection summary
show_connection_summary() {
    local session_token="$1"
    
    echo
    echo "=== Database Connection Summary ==="
    
    # Get all databases
    local databases=$(curl -s -H "X-Metabase-Session: $session_token" \
        "$METABASE_URL/api/database" | jq -r '.data[]')
    
    echo "$databases" | jq -r '. | "Database: \(.name) (ID: \(.id))\nEngine: \(.engine)\nHost: \(.details.host // "N/A")\nDatabase: \(.details.dbname // "N/A")\nStatus: \(if .is_sample then "Sample" else "Active" end)\n"'
    
    echo "=== Next Steps ==="
    echo "1. Verify database connections in Metabase admin panel"
    echo "2. Run the dashboard creation script"
    echo "3. Configure user permissions and groups"
    echo "4. Set up email notifications (optional)"
    echo
}

# Main function
main() {
    local action="${1:-setup}"
    
    case "$action" in
        setup)
            log_info "Starting database connection setup..."
            load_environment
            wait_for_metabase
            create_readonly_users
            
            local session_token
            session_token=$(get_session_token)
            
            if [[ -z "$session_token" ]]; then
                log_error "Failed to get session token"
                exit 1
            fi
            
            local mysql_db_id=$(setup_mysql_connection "$session_token")
            local postgresql_db_id=$(setup_postgresql_connection "$session_token")
            
            test_database_connections "$session_token"
            configure_refresh_schedules "$session_token"
            save_database_config "$session_token"
            show_connection_summary "$session_token"
            
            log_success "Database connection setup completed!"
            ;;
        test)
            log_info "Testing database connections..."
            load_environment
            wait_for_metabase
            
            local session_token
            session_token=$(get_session_token)
            
            if [[ -z "$session_token" ]]; then
                log_error "Failed to get session token"
                exit 1
            fi
            
            test_database_connections "$session_token"
            ;;
        users)
            create_readonly_users
            ;;
        *)
            echo "Usage: $0 [setup|test|users]"
            echo
            echo "Commands:"
            echo "  setup  - Complete database connection setup (default)"
            echo "  test   - Test existing database connections"
            echo "  users  - Generate database user creation scripts"
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'log_error "Database setup interrupted"; exit 1' INT TERM

# Run main function
main "$@"

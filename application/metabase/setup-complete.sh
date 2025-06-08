#!/bin/bash

# Complete Metabase Setup Script
# Orchestrates the full deployment and configuration of Metabase BI platform

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/metabase-complete-setup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# Print banner
print_banner() {
    echo
    echo "=================================================================="
    echo "        Metabase BI Platform - Complete Setup"
    echo "=================================================================="
    echo "This script will deploy and configure a complete Metabase"
    echo "Business Intelligence platform with:"
    echo "  • Production-ready Docker deployment"
    echo "  • SSL/TLS encryption and security"
    echo "  • Database connections to MySQL and PostgreSQL RDS"
    echo "  • Comprehensive BI dashboards with real-time data"
    echo "  • Automated backup and monitoring systems"
    echo "=================================================================="
    echo
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check if running as non-root with sudo access
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        log_info "Please run as a regular user with sudo privileges"
        exit 1
    fi
    
    if ! sudo -n true 2>/dev/null; then
        log_error "This script requires sudo privileges"
        log_info "Please ensure your user has sudo access"
        exit 1
    fi
    
    # Check required commands
    local required_commands=("docker" "docker-compose" "curl" "jq" "python3" "pip3")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        log_info "Please install the missing commands and run again"
        exit 1
    fi
    
    # Check Python packages
    if ! python3 -c "import requests" 2>/dev/null; then
        log_info "Installing Python requests package..."
        pip3 install requests || {
            log_error "Failed to install Python requests package"
            exit 1
        }
    fi
    
    log_success "Prerequisites check passed"
}

# Setup file permissions
setup_permissions() {
    log_step "Setting up file permissions..."
    
    # Make all shell scripts executable
    find "$SCRIPT_DIR/scripts" -name "*.sh" -type f -exec chmod +x {} \;
    
    # Make Python scripts executable
    find "$SCRIPT_DIR/scripts" -name "*.py" -type f -exec chmod +x {} \;
    
    # Make main setup script executable
    chmod +x "$SCRIPT_DIR/setup-complete.sh"
    
    log_success "File permissions configured"
}

# Validate environment configuration
validate_environment() {
    log_step "Validating environment configuration..."
    
    local env_file="$SCRIPT_DIR/.env"
    
    if [[ ! -f "$env_file" ]]; then
        log_warning "Environment file not found, creating from example..."
        cp "$SCRIPT_DIR/.env.example" "$env_file"
        log_error "Please edit $env_file with your actual configuration values"
        log_info "Required settings:"
        log_info "  - METABASE_SITE_URL"
        log_info "  - METABASE_ADMIN_EMAIL"
        log_info "  - Database connection details (MySQL and PostgreSQL RDS)"
        log_info "After updating the configuration, run this script again"
        exit 1
    fi
    
    # Load environment
    set -a
    source "$env_file"
    set +a
    
    # Check critical settings
    local required_vars=(
        "METABASE_ADMIN_EMAIL"
        "MYSQL_RDS_HOST"
        "POSTGRESQL_RDS_HOST"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" || "${!var}" == *"your-"* ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing or incomplete configuration variables:"
        for var in "${missing_vars[@]}"; do
            log_error "  - $var"
        done
        log_info "Please update $env_file with actual values"
        exit 1
    fi
    
    log_success "Environment configuration validated"
}

# Deploy Metabase infrastructure
deploy_metabase() {
    log_step "Deploying Metabase infrastructure..."
    
    cd "$SCRIPT_DIR"
    
    # Run the deployment script
    if ./scripts/deploy-metabase.sh deploy; then
        log_success "Metabase infrastructure deployed successfully"
    else
        log_error "Metabase deployment failed"
        return 1
    fi
}

# Wait for Metabase to be ready
wait_for_metabase() {
    log_step "Waiting for Metabase to be ready..."
    
    local metabase_url="${METABASE_SITE_URL:-http://localhost:3000}"
    local max_attempts=60
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f -s "$metabase_url/api/health" >/dev/null 2>&1; then
            log_success "Metabase is ready and responding"
            return 0
        else
            log_info "Waiting for Metabase to start... (attempt $attempt/$max_attempts)"
            sleep 10
            ((attempt++))
        fi
    done
    
    log_error "Metabase did not start within expected time"
    log_info "Check logs: docker-compose logs -f metabase"
    return 1
}

# Setup database connections
setup_databases() {
    log_step "Setting up database connections..."
    
    cd "$SCRIPT_DIR"
    
    if ./scripts/setup-databases.sh setup; then
        log_success "Database connections configured successfully"
    else
        log_error "Database setup failed"
        return 1
    fi
}

# Create BI dashboards
create_dashboards() {
    log_step "Creating BI dashboards..."
    
    cd "$SCRIPT_DIR"
    
    # Get admin credentials
    local admin_email="${METABASE_ADMIN_EMAIL}"
    local admin_password="${METABASE_ADMIN_PASSWORD:-}"
    
    if [[ -z "$admin_password" ]]; then
        log_error "Admin password not found in environment"
        log_info "Please check the Metabase logs for the generated admin password"
        log_info "Or set METABASE_ADMIN_PASSWORD in your .env file"
        return 1
    fi
    
    local metabase_url="${METABASE_SITE_URL:-http://localhost:3000}"
    
    if python3 scripts/create-dashboards.py \
        --url "$metabase_url" \
        --email "$admin_email" \
        --password "$admin_password" \
        --dashboards all; then
        log_success "BI dashboards created successfully"
    else
        log_error "Dashboard creation failed"
        return 1
    fi
}

# Setup monitoring and backup
setup_monitoring() {
    log_step "Setting up monitoring and backup systems..."
    
    cd "$SCRIPT_DIR"
    
    # Create backup schedule (cron job)
    local backup_schedule="${BACKUP_SCHEDULE:-0 2 * * *}"  # Daily at 2 AM
    local backup_cron="$backup_schedule cd $SCRIPT_DIR && ./scripts/backup-metabase.sh full >/dev/null 2>&1"
    
    # Add to crontab
    (crontab -l 2>/dev/null | grep -v "backup-metabase.sh"; echo "$backup_cron") | crontab -
    
    log_success "Backup schedule configured: $backup_schedule"
    
    # Setup monitoring cron job (every 5 minutes)
    local monitor_cron="*/5 * * * * cd $SCRIPT_DIR && ./scripts/monitor-metabase.sh health >/dev/null 2>&1"
    (crontab -l 2>/dev/null | grep -v "monitor-metabase.sh"; echo "$monitor_cron") | crontab -
    
    log_success "Health monitoring configured"
}

# Run initial backup
run_initial_backup() {
    log_step "Creating initial backup..."
    
    cd "$SCRIPT_DIR"
    
    if ./scripts/backup-metabase.sh full; then
        log_success "Initial backup completed"
    else
        log_warning "Initial backup failed (this is normal for first run)"
    fi
}

# Verify installation
verify_installation() {
    log_step "Verifying installation..."
    
    cd "$SCRIPT_DIR"
    
    local all_good=true
    
    # Check services
    if ! ./scripts/monitor-metabase.sh services >/dev/null 2>&1; then
        log_error "Service health check failed"
        all_good=false
    fi
    
    # Check database connections
    if ! ./scripts/setup-databases.sh test >/dev/null 2>&1; then
        log_error "Database connection test failed"
        all_good=false
    fi
    
    # Check Metabase health
    local metabase_url="${METABASE_SITE_URL:-http://localhost:3000}"
    if ! curl -f -s "$metabase_url/api/health" >/dev/null 2>&1; then
        log_error "Metabase health check failed"
        all_good=false
    fi
    
    if [[ "$all_good" == "true" ]]; then
        log_success "Installation verification passed"
        return 0
    else
        log_error "Installation verification failed"
        return 1
    fi
}

# Display final information
show_completion_info() {
    local metabase_url="${METABASE_SITE_URL:-http://localhost:3000}"
    local public_ip=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}')
    
    echo
    echo "=================================================================="
    echo "         Metabase BI Platform Setup Complete!"
    echo "=================================================================="
    echo
    echo "🎉 Your Metabase BI platform is ready!"
    echo
    echo "📊 Access Information:"
    echo "   Primary URL:    $metabase_url"
    echo "   IP Access:      http://$public_ip:3000"
    echo "   Admin Email:    $METABASE_ADMIN_EMAIL"
    echo
    echo "📈 Available Dashboards:"
    echo "   • Executive Overview    - Real-time business KPIs"
    echo "   • Sales Analytics      - Sales performance metrics"
    echo "   • Customer Analytics   - Customer behavior analysis"
    echo "   • Real-time Monitor    - Live system metrics (30s refresh)"
    echo "   • Marketing Performance - Campaign analytics"
    echo
    echo "🛠 Management Commands:"
    echo "   Start:    sudo systemctl start metabase"
    echo "   Stop:     sudo systemctl stop metabase"
    echo "   Status:   sudo systemctl status metabase"
    echo "   Logs:     docker-compose logs -f metabase"
    echo
    echo "🔧 Maintenance Scripts:"
    echo "   Health Check:  ./scripts/monitor-metabase.sh report"
    echo "   Backup:        ./scripts/backup-metabase.sh full"
    echo "   Database Test: ./scripts/setup-databases.sh test"
    echo
    echo "📋 Next Steps:"
    echo "   1. Access Metabase at: $metabase_url"
    echo "   2. Login with your admin credentials"
    echo "   3. Explore the pre-built dashboards"
    echo "   4. Configure additional users and permissions"
    echo "   5. Set up SSL certificates for production"
    echo "   6. Configure monitoring alerts"
    echo
    echo "📚 Documentation:"
    echo "   Setup Guide:   ./README.md"
    echo "   Troubleshooting: Check logs in /opt/metabase/logs/"
    echo
    echo "🚀 Your BI platform is production-ready with:"
    echo "   ✅ SSL/TLS encryption"
    echo "   ✅ Automated backups"
    echo "   ✅ Health monitoring"
    echo "   ✅ Real-time dashboards"
    echo "   ✅ Database connections"
    echo "   ✅ Security configurations"
    echo
    echo "=================================================================="
}

# Main installation function
main() {
    local skip_deploy=false
    local skip_dashboards=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-deploy)
                skip_deploy=true
                shift
                ;;
            --skip-dashboards)
                skip_dashboards=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --skip-deploy      Skip infrastructure deployment"
                echo "  --skip-dashboards  Skip dashboard creation"
                echo "  --help            Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Create log file
    touch "$LOG_FILE"
    
    print_banner
    
    log_info "Starting complete Metabase setup..."
    log_info "Log file: $LOG_FILE"
    
    # Run setup steps
    check_prerequisites
    setup_permissions
    validate_environment
    
    if [[ "$skip_deploy" == false ]]; then
        deploy_metabase
        wait_for_metabase
    fi
    
    setup_databases
    
    if [[ "$skip_dashboards" == false ]]; then
        create_dashboards
    fi
    
    setup_monitoring
    run_initial_backup
    verify_installation
    
    show_completion_info
    
    log_success "Complete Metabase setup finished successfully!"
}

# Handle script interruption
trap 'log_error "Setup interrupted"; exit 1' INT TERM

# Run main function
main "$@"

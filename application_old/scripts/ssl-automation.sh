#!/bin/bash

# SSL Certificate Automation Script
# Manages SSL certificates, monitoring, and renewal for the DevOps Dashboard

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
LOG_FILE="/tmp/ssl-automation.log"

# Default values
AWS_REGION="${AWS_REGION:-us-east-1}"
DOMAIN_NAME="${DOMAIN_NAME:-}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
PROJECT_NAME="${PROJECT_NAME:-devops-dashboard}"

# Certificate paths
CERT_DIR="/opt/ssl"
LOCAL_CERT_DIR="$SCRIPT_DIR/../ssl"

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

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check required commands
    local required_commands=("openssl" "curl" "aws" "jq")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        exit 1
    fi
    
    # Check if running with appropriate permissions
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root. This is okay for system certificate management."
    fi
    
    log_success "Prerequisites check passed"
}

# Load configuration from environment or Terraform
load_configuration() {
    log_step "Loading configuration..."
    
    # Try to load from Terraform outputs if available
    if [[ -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]]; then
        cd "$PROJECT_ROOT/terraform"
        
        DOMAIN_NAME=$(terraform output -raw domain_name 2>/dev/null || echo "")
        SSL_CERT_ARN=$(terraform output -raw ssl_certificate_arn 2>/dev/null || echo "")
        METABASE_CERT_ARN=$(terraform output -raw metabase_certificate_arn 2>/dev/null || echo "")
        
        if [[ "$DOMAIN_NAME" == "Not configured" ]]; then
            DOMAIN_NAME=""
        fi
    fi
    
    # Load from environment if not set
    DOMAIN_NAME="${DOMAIN_NAME:-$DOMAIN_NAME}"
    
    if [[ -z "$DOMAIN_NAME" ]]; then
        log_error "Domain name not configured. Please set DOMAIN_NAME environment variable."
        exit 1
    fi
    
    log_success "Configuration loaded"
    log_info "Domain: $DOMAIN_NAME"
    log_info "AWS Region: $AWS_REGION"
}

# Create certificate directories
setup_certificate_directories() {
    log_step "Setting up certificate directories..."
    
    # Create directories with appropriate permissions
    sudo mkdir -p "$CERT_DIR"/{certs,private,csr,backup}
    mkdir -p "$LOCAL_CERT_DIR"/{certs,private,csr,backup}
    
    # Set permissions
    sudo chmod 755 "$CERT_DIR"
    sudo chmod 750 "$CERT_DIR"/{certs,csr,backup}
    sudo chmod 700 "$CERT_DIR/private"
    
    chmod 755 "$LOCAL_CERT_DIR"
    chmod 750 "$LOCAL_CERT_DIR"/{certs,csr,backup}
    chmod 700 "$LOCAL_CERT_DIR/private"
    
    log_success "Certificate directories created"
}

# Generate self-signed certificates for development
generate_self_signed_certificates() {
    log_step "Generating self-signed certificates for development..."
    
    local cert_file="$LOCAL_CERT_DIR/certs/$DOMAIN_NAME.crt"
    local key_file="$LOCAL_CERT_DIR/private/$DOMAIN_NAME.key"
    local csr_file="$LOCAL_CERT_DIR/csr/$DOMAIN_NAME.csr"
    
    # Generate private key
    openssl genrsa -out "$key_file" 2048
    chmod 600 "$key_file"
    
    # Create certificate request configuration
    cat > "$LOCAL_CERT_DIR/cert-config.conf" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C=US
ST=State
L=City
O=DevOps Dashboard
OU=IT Department
CN=$DOMAIN_NAME

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN_NAME
DNS.2 = *.$DOMAIN_NAME
DNS.3 = app.$DOMAIN_NAME
DNS.4 = bi.$DOMAIN_NAME
DNS.5 = api.$DOMAIN_NAME
DNS.6 = admin.$DOMAIN_NAME
EOF
    
    # Generate certificate signing request
    openssl req -new -key "$key_file" -out "$csr_file" -config "$LOCAL_CERT_DIR/cert-config.conf"
    
    # Generate self-signed certificate
    openssl x509 -req -in "$csr_file" -signkey "$key_file" -out "$cert_file" \
        -days 365 -extensions req_ext -extfile "$LOCAL_CERT_DIR/cert-config.conf"
    
    chmod 644 "$cert_file"
    
    log_success "Self-signed certificates generated"
    log_info "Certificate: $cert_file"
    log_info "Private key: $key_file"
}

# Download certificates from ACM
download_acm_certificates() {
    log_step "Downloading certificates from AWS Certificate Manager..."
    
    if [[ -z "$SSL_CERT_ARN" ]]; then
        log_warning "No ACM certificate ARN available"
        return 1
    fi
    
    local cert_file="$LOCAL_CERT_DIR/certs/$DOMAIN_NAME-acm.crt"
    local chain_file="$LOCAL_CERT_DIR/certs/$DOMAIN_NAME-chain.crt"
    local bundle_file="$LOCAL_CERT_DIR/certs/$DOMAIN_NAME-bundle.crt"
    
    # Get certificate details from ACM
    local cert_data=$(aws acm get-certificate \
        --certificate-arn "$SSL_CERT_ARN" \
        --region "$AWS_REGION" \
        --output json 2>/dev/null || echo "{}")
    
    if [[ "$cert_data" == "{}" ]]; then
        log_error "Failed to retrieve certificate from ACM"
        return 1
    fi
    
    # Extract certificate and chain
    echo "$cert_data" | jq -r '.Certificate' > "$cert_file"
    echo "$cert_data" | jq -r '.CertificateChain' > "$chain_file"
    
    # Create bundle
    cat "$cert_file" "$chain_file" > "$bundle_file"
    
    # Set permissions
    chmod 644 "$cert_file" "$chain_file" "$bundle_file"
    
    log_success "ACM certificates downloaded"
    log_info "Certificate: $cert_file"
    log_info "Chain: $chain_file"
    log_info "Bundle: $bundle_file"
}

# Install certificates to system
install_certificates() {
    log_step "Installing certificates to system..."
    
    local source_cert="$LOCAL_CERT_DIR/certs/$DOMAIN_NAME.crt"
    local source_key="$LOCAL_CERT_DIR/private/$DOMAIN_NAME.key"
    
    # Check if certificates exist
    if [[ ! -f "$source_cert" || ! -f "$source_key" ]]; then
        log_error "Certificates not found. Generate or download them first."
        return 1
    fi
    
    # Install to system certificate directory
    sudo cp "$source_cert" "$CERT_DIR/certs/"
    sudo cp "$source_key" "$CERT_DIR/private/"
    
    # Set system permissions
    sudo chmod 644 "$CERT_DIR/certs/$(basename "$source_cert")"
    sudo chmod 600 "$CERT_DIR/private/$(basename "$source_key")"
    sudo chown root:root "$CERT_DIR/certs/$(basename "$source_cert")"
    sudo chown root:root "$CERT_DIR/private/$(basename "$source_key")"
    
    log_success "Certificates installed to system"
}

# Validate certificate
validate_certificate() {
    log_step "Validating certificate..."
    
    local cert_file="${1:-$LOCAL_CERT_DIR/certs/$DOMAIN_NAME.crt}"
    
    if [[ ! -f "$cert_file" ]]; then
        log_error "Certificate file not found: $cert_file"
        return 1
    fi
    
    # Check certificate details
    log_info "Certificate details:"
    openssl x509 -in "$cert_file" -noout -text | grep -E "(Subject:|DNS:|Not Before|Not After)"
    
    # Check certificate validity
    local not_after=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    local expiry_timestamp=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
    local current_timestamp=$(date +%s)
    local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
    
    log_info "Certificate expires in $days_until_expiry days"
    
    if [[ $days_until_expiry -lt 30 ]]; then
        log_warning "Certificate expires soon: $days_until_expiry days"
        return 1
    elif [[ $days_until_expiry -lt 0 ]]; then
        log_error "Certificate has expired"
        return 1
    else
        log_success "Certificate is valid"
        return 0
    fi
}

# Test SSL configuration
test_ssl_configuration() {
    log_step "Testing SSL configuration..."
    
    local subdomains=("app" "bi" "api" "admin")
    local all_working=true
    
    for subdomain in "${subdomains[@]}"; do
        local fqdn="$subdomain.$DOMAIN_NAME"
        log_info "Testing SSL for: $fqdn"
        
        # Test SSL connection
        local ssl_test=$(echo | openssl s_client -servername "$fqdn" \
            -connect "$fqdn:443" -verify_return_error 2>&1 || echo "FAILED")
        
        if echo "$ssl_test" | grep -q "Verify return code: 0"; then
            log_success "  SSL verification: OK"
        else
            log_error "  SSL verification: Failed"
            all_working=false
            
            # Show specific error
            local error=$(echo "$ssl_test" | grep "verify error" | head -1)
            if [[ -n "$error" ]]; then
                log_error "  Error: $error"
            fi
        fi
        
        # Test HTTPS response
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time 10 \
            "https://$fqdn" 2>/dev/null || echo "000")
        
        if [[ "$response_code" != "000" ]]; then
            log_success "  HTTPS response: $response_code"
        else
            log_error "  HTTPS connection failed"
            all_working=false
        fi
    done
    
    if [[ "$all_working" == "true" ]]; then
        log_success "SSL configuration test passed"
        return 0
    else
        log_error "SSL configuration test failed"
        return 1
    fi
}

# Monitor certificate expiry
monitor_certificate_expiry() {
    log_step "Monitoring certificate expiry..."
    
    local alert_days="${1:-30}"
    local certificates=()
    
    # Find all certificates to monitor
    if [[ -f "$LOCAL_CERT_DIR/certs/$DOMAIN_NAME.crt" ]]; then
        certificates+=("$LOCAL_CERT_DIR/certs/$DOMAIN_NAME.crt")
    fi
    
    if [[ -f "$LOCAL_CERT_DIR/certs/$DOMAIN_NAME-acm.crt" ]]; then
        certificates+=("$LOCAL_CERT_DIR/certs/$DOMAIN_NAME-acm.crt")
    fi
    
    local expiring_soon=()
    
    for cert_file in "${certificates[@]}"; do
        if [[ -f "$cert_file" ]]; then
            local not_after=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
            local expiry_timestamp=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
            local current_timestamp=$(date +%s)
            local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
            
            log_info "$(basename "$cert_file"): $days_until_expiry days until expiry"
            
            if [[ $days_until_expiry -le $alert_days ]]; then
                expiring_soon+=("$(basename "$cert_file"):$days_until_expiry")
            fi
        fi
    done
    
    if [[ ${#expiring_soon[@]} -gt 0 ]]; then
        log_warning "Certificates expiring soon:"
        for cert in "${expiring_soon[@]}"; do
            log_warning "  $cert days"
        done
        return 1
    else
        log_success "All certificates are within acceptable expiry range"
        return 0
    fi
}

# Backup certificates
backup_certificates() {
    log_step "Backing up certificates..."
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$LOCAL_CERT_DIR/backup/ssl-backup-$timestamp.tar.gz"
    
    # Create backup
    tar -czf "$backup_file" -C "$LOCAL_CERT_DIR" certs/ private/ csr/ 2>/dev/null || {
        log_error "Failed to create certificate backup"
        return 1
    }
    
    # Set backup permissions
    chmod 600 "$backup_file"
    
    # Clean old backups (keep last 10)
    find "$LOCAL_CERT_DIR/backup" -name "ssl-backup-*.tar.gz" -type f | \
        sort -r | tail -n +11 | xargs rm -f 2>/dev/null || true
    
    log_success "Certificate backup created: $backup_file"
}

# Restore certificates from backup
restore_certificates() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        log_error "Please specify backup file to restore"
        return 1
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log_step "Restoring certificates from backup..."
    
    # Create restore directory
    local restore_dir="/tmp/ssl-restore-$(date +%s)"
    mkdir -p "$restore_dir"
    
    # Extract backup
    tar -xzf "$backup_file" -C "$restore_dir" || {
        log_error "Failed to extract backup"
        rm -rf "$restore_dir"
        return 1
    }
    
    # Restore certificates
    cp -r "$restore_dir"/* "$LOCAL_CERT_DIR/"
    
    # Set permissions
    chmod 700 "$LOCAL_CERT_DIR/private"
    chmod 600 "$LOCAL_CERT_DIR/private"/*
    chmod 644 "$LOCAL_CERT_DIR/certs"/*
    
    # Cleanup
    rm -rf "$restore_dir"
    
    log_success "Certificates restored from backup"
}

# Setup certificate monitoring
setup_monitoring() {
    log_step "Setting up certificate monitoring..."
    
    # Create monitoring script
    local monitor_script="$SCRIPT_DIR/ssl-monitor.sh"
    
    cat > "$monitor_script" << 'EOF'
#!/bin/bash
# SSL Certificate Monitoring Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Run certificate monitoring
./ssl-automation.sh monitor 30

# Send results to CloudWatch if AWS CLI is available
if command -v aws >/dev/null 2>&1; then
    exit_code=$?
    aws cloudwatch put-metric-data \
        --namespace "SSL/Certificates" \
        --metric-data MetricName=MonitoringStatus,Value=$exit_code,Unit=Count \
        --region "${AWS_REGION:-us-east-1}" 2>/dev/null || true
fi
EOF
    
    chmod +x "$monitor_script"
    
    # Add cron job for daily monitoring
    local cron_schedule="0 8 * * *"  # Daily at 8 AM
    local cron_job="$cron_schedule cd $SCRIPT_DIR && ./ssl-monitor.sh >/dev/null 2>&1"
    
    # Add to crontab if not already present
    if ! crontab -l 2>/dev/null | grep -q "ssl-monitor.sh"; then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        log_success "SSL monitoring cron job added"
    else
        log_info "SSL monitoring cron job already exists"
    fi
    
    log_success "Certificate monitoring setup complete"
}

# Generate SSL report
generate_ssl_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="/tmp/ssl-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== SSL Certificate Report ==="
        echo "Generated: $timestamp"
        echo "Domain: $DOMAIN_NAME"
        echo "Environment: $ENVIRONMENT"
        echo
        
        echo "=== Certificate Validation ==="
        for cert_file in "$LOCAL_CERT_DIR/certs"/*.crt; do
            if [[ -f "$cert_file" ]]; then
                echo "Checking: $(basename "$cert_file")"
                validate_certificate "$cert_file"
                echo
            fi
        done
        
        echo "=== SSL Configuration Test ==="
        test_ssl_configuration
        echo
        
        echo "=== Certificate Expiry Monitoring ==="
        monitor_certificate_expiry
        echo
        
        echo "=== Certificate Files ==="
        ls -la "$LOCAL_CERT_DIR/certs"/ 2>/dev/null || echo "No certificates found"
        echo
        
        echo "=== End of Report ==="
        
    } > "$report_file" 2>&1
    
    log_success "SSL report generated: $report_file"
    
    # Show summary
    echo
    echo "=== SSL Report Summary ==="
    cat "$report_file" | grep -E "(SUCCESS|FAILED|WARNING|ERROR)" | tail -10
    echo
    echo "Full report: $report_file"
}

# Show usage
usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  setup               Setup certificate directories"
    echo "  generate-self       Generate self-signed certificates"
    echo "  download-acm        Download certificates from ACM"
    echo "  install             Install certificates to system"
    echo "  validate [FILE]     Validate certificate"
    echo "  test                Test SSL configuration"
    echo "  monitor [DAYS]      Monitor certificate expiry (default: 30)"
    echo "  backup              Backup certificates"
    echo "  restore FILE        Restore certificates from backup"
    echo "  setup-monitoring    Setup automated monitoring"
    echo "  report              Generate SSL report"
    echo "  help                Show this help message"
    echo
    echo "Examples:"
    echo "  $0 setup            # Setup certificate directories"
    echo "  $0 generate-self    # Generate self-signed certificates"
    echo "  $0 test             # Test SSL configuration"
    echo "  $0 monitor 15       # Monitor with 15-day alert"
    echo "  $0 backup           # Backup all certificates"
}

# Main function
main() {
    local command="${1:-help}"
    
    # Create log file
    touch "$LOG_FILE"
    
    case "$command" in
        setup)
            check_prerequisites
            load_configuration
            setup_certificate_directories
            ;;
        generate-self)
            check_prerequisites
            load_configuration
            setup_certificate_directories
            generate_self_signed_certificates
            ;;
        download-acm)
            check_prerequisites
            load_configuration
            setup_certificate_directories
            download_acm_certificates
            ;;
        install)
            check_prerequisites
            load_configuration
            install_certificates
            ;;
        validate)
            check_prerequisites
            load_configuration
            validate_certificate "$2"
            ;;
        test)
            check_prerequisites
            load_configuration
            test_ssl_configuration
            ;;
        monitor)
            local alert_days="${2:-30}"
            check_prerequisites
            load_configuration
            monitor_certificate_expiry "$alert_days"
            ;;
        backup)
            check_prerequisites
            load_configuration
            backup_certificates
            ;;
        restore)
            check_prerequisites
            load_configuration
            restore_certificates "$2"
            ;;
        setup-monitoring)
            check_prerequisites
            load_configuration
            setup_monitoring
            ;;
        report)
            check_prerequisites
            load_configuration
            generate_ssl_report
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
trap 'log_info "SSL automation interrupted"; exit 1' INT TERM

# Run main function
main "$@"

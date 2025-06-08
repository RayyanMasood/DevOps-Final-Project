#!/bin/bash

# Domain and SSL Management Script
# Manages domain validation, SSL certificates, and DNS health monitoring

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/tmp/domain-management.log"

# Default values
AWS_REGION="${AWS_REGION:-us-east-1}"
DOMAIN_NAME="${DOMAIN_NAME:-}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
PROJECT_NAME="${PROJECT_NAME:-devops-dashboard}"

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
    local required_commands=("aws" "dig" "openssl" "jq" "curl")
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
    
    # Check AWS CLI configuration
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS CLI not configured or credentials invalid"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Load Terraform outputs
load_terraform_outputs() {
    log_step "Loading Terraform configuration..."
    
    cd "$PROJECT_ROOT"
    
    if [[ ! -f "terraform.tfstate" ]]; then
        log_error "Terraform state file not found. Please run 'terraform apply' first."
        exit 1
    fi
    
    # Extract values from Terraform state
    DOMAIN_NAME=$(terraform output -raw domain_name 2>/dev/null || echo "")
    HOSTED_ZONE_ID=$(terraform output -raw hosted_zone_id 2>/dev/null || echo "")
    SSL_CERT_ARN=$(terraform output -raw ssl_certificate_arn 2>/dev/null || echo "")
    ALB_DNS_NAME=$(terraform output -raw load_balancer_dns_name 2>/dev/null || echo "")
    
    if [[ -z "$DOMAIN_NAME" || "$DOMAIN_NAME" == "Not configured" ]]; then
        log_error "Domain not configured in Terraform. Please set domain_name variable."
        exit 1
    fi
    
    log_success "Terraform configuration loaded"
    log_info "Domain: $DOMAIN_NAME"
    log_info "Hosted Zone ID: $HOSTED_ZONE_ID"
    log_info "SSL Certificate: $SSL_CERT_ARN"
}

# Validate DNS configuration
validate_dns() {
    log_step "Validating DNS configuration..."
    
    local all_valid=true
    local subdomains=("app" "bi" "api" "admin" "")
    
    for subdomain in "${subdomains[@]}"; do
        local fqdn="${subdomain:+$subdomain.}$DOMAIN_NAME"
        log_info "Checking DNS for: $fqdn"
        
        # Check A record
        local dns_result=$(dig +short "$fqdn" A 2>/dev/null || echo "")
        if [[ -n "$dns_result" ]]; then
            log_success "  A record: $dns_result"
        else
            log_error "  A record not found"
            all_valid=false
        fi
        
        # Check if it resolves to ALB
        local cname_result=$(dig +short "$fqdn" CNAME 2>/dev/null || echo "")
        if [[ -n "$cname_result" ]]; then
            log_info "  CNAME: $cname_result"
        fi
    done
    
    if [[ "$all_valid" == "true" ]]; then
        log_success "DNS validation passed"
        return 0
    else
        log_error "DNS validation failed"
        return 1
    fi
}

# Check SSL certificate status
check_ssl_certificate() {
    log_step "Checking SSL certificate status..."
    
    if [[ -z "$SSL_CERT_ARN" ]]; then
        log_warning "No SSL certificate configured"
        return 1
    fi
    
    # Get certificate details from ACM
    local cert_details=$(aws acm describe-certificate \
        --certificate-arn "$SSL_CERT_ARN" \
        --region "$AWS_REGION" \
        --output json 2>/dev/null || echo "{}")
    
    if [[ "$cert_details" == "{}" ]]; then
        log_error "Failed to retrieve certificate details"
        return 1
    fi
    
    local status=$(echo "$cert_details" | jq -r '.Certificate.Status // "UNKNOWN"')
    local domain=$(echo "$cert_details" | jq -r '.Certificate.DomainName // "UNKNOWN"')
    local expiry=$(echo "$cert_details" | jq -r '.Certificate.NotAfter // "UNKNOWN"')
    
    log_info "Certificate Status: $status"
    log_info "Certificate Domain: $domain"
    log_info "Certificate Expiry: $expiry"
    
    case "$status" in
        "ISSUED")
            log_success "SSL certificate is valid and issued"
            
            # Check expiry date
            if [[ "$expiry" != "UNKNOWN" ]]; then
                local expiry_timestamp=$(date -d "$expiry" +%s 2>/dev/null || echo "0")
                local current_timestamp=$(date +%s)
                local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
                
                if [[ $days_until_expiry -lt 30 ]]; then
                    log_warning "Certificate expires in $days_until_expiry days"
                elif [[ $days_until_expiry -lt 0 ]]; then
                    log_error "Certificate has expired"
                    return 1
                else
                    log_success "Certificate expires in $days_until_expiry days"
                fi
            fi
            ;;
        "PENDING_VALIDATION")
            log_warning "SSL certificate is pending validation"
            return 1
            ;;
        "FAILED")
            log_error "SSL certificate validation failed"
            return 1
            ;;
        *)
            log_warning "SSL certificate status: $status"
            return 1
            ;;
    esac
    
    return 0
}

# Test HTTPS connectivity
test_https_connectivity() {
    log_step "Testing HTTPS connectivity..."
    
    local subdomains=("app" "bi" "api")
    local all_working=true
    
    for subdomain in "${subdomains[@]}"; do
        local url="https://$subdomain.$DOMAIN_NAME"
        log_info "Testing: $url"
        
        # Test HTTPS connection
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time 10 \
            --connect-timeout 5 \
            "$url" 2>/dev/null || echo "000")
        
        local ssl_result=$(curl -s -o /dev/null -w "%{ssl_verify_result}" \
            --max-time 10 \
            "$url" 2>/dev/null || echo "1")
        
        if [[ "$response_code" != "000" ]]; then
            log_success "  HTTP Response: $response_code"
        else
            log_error "  Connection failed"
            all_working=false
        fi
        
        if [[ "$ssl_result" == "0" ]]; then
            log_success "  SSL verification: OK"
        else
            log_error "  SSL verification: Failed"
            all_working=false
        fi
        
        # Check SSL certificate details
        local cert_info=$(echo | openssl s_client -servername "$subdomain.$DOMAIN_NAME" \
            -connect "$subdomain.$DOMAIN_NAME:443" 2>/dev/null | \
            openssl x509 -noout -dates 2>/dev/null || echo "")
        
        if [[ -n "$cert_info" ]]; then
            log_info "  Certificate dates: $cert_info"
        fi
    done
    
    if [[ "$all_working" == "true" ]]; then
        log_success "HTTPS connectivity test passed"
        return 0
    else
        log_error "HTTPS connectivity test failed"
        return 1
    fi
}

# Check HTTP to HTTPS redirect
test_http_redirect() {
    log_step "Testing HTTP to HTTPS redirect..."
    
    local subdomains=("app" "bi" "api")
    local all_redirecting=true
    
    for subdomain in "${subdomains[@]}"; do
        local http_url="http://$subdomain.$DOMAIN_NAME"
        local https_url="https://$subdomain.$DOMAIN_NAME"
        
        log_info "Testing redirect: $http_url -> $https_url"
        
        # Test redirect
        local redirect_location=$(curl -s -o /dev/null -w "%{redirect_url}" \
            --max-time 10 \
            --max-redirs 0 \
            "$http_url" 2>/dev/null || echo "")
        
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time 10 \
            --max-redirs 0 \
            "$http_url" 2>/dev/null || echo "000")
        
        if [[ "$response_code" =~ ^30[1-8]$ ]]; then
            if [[ "$redirect_location" == "$https_url" || "$redirect_location" =~ ^https://$subdomain\.$DOMAIN_NAME ]]; then
                log_success "  Redirect: $response_code -> $redirect_location"
            else
                log_warning "  Unexpected redirect: $response_code -> $redirect_location"
                all_redirecting=false
            fi
        else
            log_error "  No redirect detected (HTTP $response_code)"
            all_redirecting=false
        fi
    done
    
    if [[ "$all_redirecting" == "true" ]]; then
        log_success "HTTP to HTTPS redirect test passed"
        return 0
    else
        log_error "HTTP to HTTPS redirect test failed"
        return 1
    fi
}

# Monitor certificate expiry
monitor_certificate_expiry() {
    log_step "Monitoring certificate expiry..."
    
    local alert_days="${1:-30}"
    
    if [[ -z "$SSL_CERT_ARN" ]]; then
        log_warning "No SSL certificate to monitor"
        return 0
    fi
    
    # Get certificate expiry
    local cert_details=$(aws acm describe-certificate \
        --certificate-arn "$SSL_CERT_ARN" \
        --region "$AWS_REGION" \
        --output json 2>/dev/null || echo "{}")
    
    local expiry=$(echo "$cert_details" | jq -r '.Certificate.NotAfter // "UNKNOWN"')
    
    if [[ "$expiry" == "UNKNOWN" ]]; then
        log_error "Cannot determine certificate expiry date"
        return 1
    fi
    
    local expiry_timestamp=$(date -d "$expiry" +%s 2>/dev/null || echo "0")
    local current_timestamp=$(date +%s)
    local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
    
    log_info "Certificate expires in $days_until_expiry days"
    
    if [[ $days_until_expiry -le $alert_days ]]; then
        log_warning "Certificate expiry alert: $days_until_expiry days remaining"
        
        # Send CloudWatch metric if configured
        if command -v aws >/dev/null 2>&1; then
            aws cloudwatch put-metric-data \
                --namespace "Domain/SSL" \
                --metric-data MetricName=CertificateExpiryDays,Value=$days_until_expiry,Unit=Count \
                --region "$AWS_REGION" 2>/dev/null || true
        fi
        
        return 1
    else
        log_success "Certificate expiry is within acceptable range"
        return 0
    fi
}

# Check Route53 health checks
check_health_checks() {
    log_step "Checking Route53 health checks..."
    
    # Get health check IDs from Terraform output
    local health_check_output=$(terraform output -json health_check_ids 2>/dev/null || echo "{}")
    
    if [[ "$health_check_output" == "{}" ]]; then
        log_warning "No health checks configured"
        return 0
    fi
    
    local app_health_check=$(echo "$health_check_output" | jq -r '.app // ""')
    local bi_health_check=$(echo "$health_check_output" | jq -r '.bi // ""')
    
    local all_healthy=true
    
    for health_check_id in "$app_health_check" "$bi_health_check"; do
        if [[ -n "$health_check_id" && "$health_check_id" != "null" ]]; then
            local health_status=$(aws route53 get-health-check-status \
                --health-check-id "$health_check_id" \
                --region "$AWS_REGION" \
                --output json 2>/dev/null || echo "{}")
            
            local status=$(echo "$health_status" | jq -r '.StatusChecker.Status // "UNKNOWN"')
            
            log_info "Health Check $health_check_id: $status"
            
            if [[ "$status" != "Success" ]]; then
                all_healthy=false
            fi
        fi
    done
    
    if [[ "$all_healthy" == "true" ]]; then
        log_success "All health checks are passing"
        return 0
    else
        log_error "Some health checks are failing"
        return 1
    fi
}

# Validate domain ownership
validate_domain_ownership() {
    log_step "Validating domain ownership..."
    
    # Check if we can query the hosted zone
    if [[ -z "$HOSTED_ZONE_ID" ]]; then
        log_error "Hosted zone ID not available"
        return 1
    fi
    
    local zone_info=$(aws route53 get-hosted-zone \
        --id "$HOSTED_ZONE_ID" \
        --output json 2>/dev/null || echo "{}")
    
    local zone_name=$(echo "$zone_info" | jq -r '.HostedZone.Name // "UNKNOWN"')
    local record_count=$(echo "$zone_info" | jq -r '.HostedZone.ResourceRecordSetCount // 0')
    
    log_info "Hosted zone: $zone_name"
    log_info "Record count: $record_count"
    
    if [[ "$zone_name" == "$DOMAIN_NAME." || "$zone_name" == "$DOMAIN_NAME" ]]; then
        log_success "Domain ownership validated"
        return 0
    else
        log_error "Domain ownership validation failed"
        return 1
    fi
}

# Generate domain report
generate_domain_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="/tmp/domain-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== Domain and SSL Report ==="
        echo "Generated: $timestamp"
        echo "Domain: $DOMAIN_NAME"
        echo "Environment: $ENVIRONMENT"
        echo
        
        echo "=== DNS Validation ==="
        validate_dns
        echo
        
        echo "=== SSL Certificate Status ==="
        check_ssl_certificate
        echo
        
        echo "=== HTTPS Connectivity ==="
        test_https_connectivity
        echo
        
        echo "=== HTTP to HTTPS Redirect ==="
        test_http_redirect
        echo
        
        echo "=== Health Checks ==="
        check_health_checks
        echo
        
        echo "=== Domain Ownership ==="
        validate_domain_ownership
        echo
        
        echo "=== Certificate Expiry Monitoring ==="
        monitor_certificate_expiry
        echo
        
        echo "=== URLs Summary ==="
        echo "App URL: https://app.$DOMAIN_NAME"
        echo "BI URL: https://bi.$DOMAIN_NAME"
        echo "API URL: https://api.$DOMAIN_NAME"
        echo "Admin URL: https://admin.$DOMAIN_NAME"
        echo
        
        echo "=== End of Report ==="
        
    } > "$report_file" 2>&1
    
    log_success "Domain report generated: $report_file"
    
    # Show summary
    echo
    echo "=== Domain Report Summary ==="
    cat "$report_file" | grep -E "(SUCCESS|FAILED|WARNING|ERROR)" | tail -10
    echo
    echo "Full report: $report_file"
}

# Setup SSL certificate monitoring
setup_ssl_monitoring() {
    log_step "Setting up SSL certificate monitoring..."
    
    # Create CloudWatch alarm for certificate expiry
    local alarm_name="$PROJECT_NAME-$ENVIRONMENT-ssl-certificate-expiry"
    
    aws cloudwatch put-metric-alarm \
        --alarm-name "$alarm_name" \
        --alarm-description "SSL certificate expiry monitoring" \
        --metric-name "CertificateExpiryDays" \
        --namespace "Domain/SSL" \
        --statistic "Minimum" \
        --period 86400 \
        --threshold 30 \
        --comparison-operator "LessThanThreshold" \
        --evaluation-periods 1 \
        --region "$AWS_REGION" 2>/dev/null || {
        log_warning "Failed to create CloudWatch alarm"
    }
    
    # Create cron job for regular monitoring
    local cron_schedule="0 9 * * *"  # Daily at 9 AM
    local cron_job="$cron_schedule cd $PROJECT_ROOT && ./scripts/domain-management.sh monitor >/dev/null 2>&1"
    
    # Add to crontab if not already present
    if ! crontab -l 2>/dev/null | grep -q "domain-management.sh monitor"; then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        log_success "SSL monitoring cron job added"
    else
        log_info "SSL monitoring cron job already exists"
    fi
}

# Force SSL certificate renewal (for testing)
force_certificate_renewal() {
    log_step "Forcing SSL certificate renewal..."
    
    if [[ -z "$SSL_CERT_ARN" ]]; then
        log_error "No SSL certificate to renew"
        return 1
    fi
    
    log_warning "Note: ACM certificates auto-renew. Manual renewal is not typically needed."
    log_info "If you need to force renewal, consider:"
    log_info "1. Creating a new certificate with additional domains"
    log_info "2. Updating the domain validation"
    log_info "3. Checking that DNS records are correct"
    
    # Trigger certificate validation check
    aws acm resend-validation-email \
        --certificate-arn "$SSL_CERT_ARN" \
        --domain "$DOMAIN_NAME" \
        --validation-domain "$DOMAIN_NAME" \
        --region "$AWS_REGION" 2>/dev/null || {
        log_warning "Failed to resend validation email (DNS validation may be in use)"
    }
}

# Show usage
usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  validate            Validate DNS and SSL configuration"
    echo "  report              Generate comprehensive domain report"
    echo "  monitor [DAYS]      Monitor certificate expiry (default: 30 days)"
    echo "  setup-monitoring    Setup automated SSL monitoring"
    echo "  test-https          Test HTTPS connectivity"
    echo "  test-redirect       Test HTTP to HTTPS redirect"
    echo "  check-health        Check Route53 health checks"
    echo "  renew-cert          Force certificate renewal (testing)"
    echo "  help                Show this help message"
    echo
    echo "Examples:"
    echo "  $0 validate         # Validate all domain configuration"
    echo "  $0 report           # Generate comprehensive report"
    echo "  $0 monitor 15       # Monitor certificate with 15-day alert"
    echo "  $0 test-https       # Test HTTPS connectivity only"
}

# Main function
main() {
    local command="${1:-validate}"
    
    # Create log file
    touch "$LOG_FILE"
    
    case "$command" in
        validate)
            check_prerequisites
            load_terraform_outputs
            validate_dns
            check_ssl_certificate
            test_https_connectivity
            test_http_redirect
            ;;
        report)
            check_prerequisites
            load_terraform_outputs
            generate_domain_report
            ;;
        monitor)
            local alert_days="${2:-30}"
            check_prerequisites
            load_terraform_outputs
            monitor_certificate_expiry "$alert_days"
            ;;
        setup-monitoring)
            check_prerequisites
            load_terraform_outputs
            setup_ssl_monitoring
            ;;
        test-https)
            check_prerequisites
            load_terraform_outputs
            test_https_connectivity
            ;;
        test-redirect)
            check_prerequisites
            load_terraform_outputs
            test_http_redirect
            ;;
        check-health)
            check_prerequisites
            load_terraform_outputs
            check_health_checks
            ;;
        renew-cert)
            check_prerequisites
            load_terraform_outputs
            force_certificate_renewal
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
trap 'log_info "Domain management interrupted"; exit 1' INT TERM

# Run main function
main "$@"

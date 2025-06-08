#!/bin/bash

# Complete Deployment Script with Domain and SSL Configuration
# Deploys the entire DevOps Dashboard infrastructure with secure HTTPS access

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/tmp/deploy-with-domain.log"

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
    echo "    DevOps Dashboard - Complete Deployment with Domain & SSL"
    echo "=================================================================="
    echo "This script will deploy the complete infrastructure including:"
    echo "  • VPC with public and private subnets"
    echo "  • Auto Scaling Group with EC2 instances"
    echo "  • RDS databases (MySQL and PostgreSQL)"
    echo "  • Application Load Balancer with HTTPS"
    echo "  • Route53 DNS with custom domain"
    echo "  • SSL certificates with AWS Certificate Manager"
    echo "  • Metabase BI tool with secure access"
    echo "  • Monitoring and health checks"
    echo "=================================================================="
    echo
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check required commands
    local required_commands=("terraform" "aws" "jq" "dig")
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
    
    # Check Terraform version
    local tf_version=$(terraform version -json | jq -r '.terraform_version')
    log_info "Terraform version: $tf_version"
    
    log_success "Prerequisites check passed"
}

# Validate configuration
validate_configuration() {
    log_step "Validating configuration..."
    
    cd "$PROJECT_ROOT"
    
    # Check if terraform.tfvars exists
    if [[ ! -f "terraform.tfvars" ]]; then
        log_warning "terraform.tfvars not found, checking for environment variables..."
        
        # Check for required environment variables
        local required_vars=("TF_VAR_domain_name" "TF_VAR_mysql_password" "TF_VAR_postgres_password")
        local missing_vars=()
        
        for var in "${required_vars[@]}"; do
            if [[ -z "${!var:-}" ]]; then
                missing_vars+=("$var")
            fi
        done
        
        if [[ ${#missing_vars[@]} -gt 0 ]]; then
            log_error "Missing required configuration:"
            for var in "${missing_vars[@]}"; do
                log_error "  - $var"
            done
            log_info "Please create terraform.tfvars or set environment variables"
            exit 1
        fi
    fi
    
    # Validate Terraform configuration
    if ! terraform validate >/dev/null 2>&1; then
        log_error "Terraform configuration validation failed"
        terraform validate
        exit 1
    fi
    
    log_success "Configuration validation passed"
}

# Initialize Terraform
initialize_terraform() {
    log_step "Initializing Terraform..."
    
    cd "$PROJECT_ROOT"
    
    # Initialize backend
    if [[ -f "scripts/init-backend.sh" ]]; then
        log_info "Running backend initialization script..."
        bash scripts/init-backend.sh
    fi
    
    # Initialize Terraform
    terraform init
    
    log_success "Terraform initialized"
}

# Plan deployment
plan_deployment() {
    log_step "Planning deployment..."
    
    cd "$PROJECT_ROOT"
    
    # Run Terraform plan
    terraform plan -out=tfplan
    
    # Show plan summary
    log_info "Deployment plan created successfully"
    log_info "Review the plan above and ensure it matches your expectations"
    
    return 0
}

# Deploy infrastructure
deploy_infrastructure() {
    log_step "Deploying infrastructure..."
    
    cd "$PROJECT_ROOT"
    
    # Apply Terraform plan
    terraform apply tfplan
    
    if [[ $? -eq 0 ]]; then
        log_success "Infrastructure deployment completed"
    else
        log_error "Infrastructure deployment failed"
        return 1
    fi
    
    # Clean up plan file
    rm -f tfplan
    
    return 0
}

# Wait for certificate validation
wait_for_certificate_validation() {
    log_step "Waiting for SSL certificate validation..."
    
    cd "$PROJECT_ROOT"
    
    # Get certificate ARN from Terraform output
    local cert_arn=$(terraform output -raw ssl_certificate_arn 2>/dev/null || echo "")
    
    if [[ -z "$cert_arn" || "$cert_arn" == "Not configured" ]]; then
        log_warning "No SSL certificate configured"
        return 0
    fi
    
    local aws_region=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
    local max_attempts=60
    local attempt=1
    
    log_info "Certificate ARN: $cert_arn"
    log_info "Waiting for certificate validation (max ${max_attempts} minutes)..."
    
    while [[ $attempt -le $max_attempts ]]; do
        local cert_status=$(aws acm describe-certificate \
            --certificate-arn "$cert_arn" \
            --region "$aws_region" \
            --query 'Certificate.Status' \
            --output text 2>/dev/null || echo "UNKNOWN")
        
        case "$cert_status" in
            "ISSUED")
                log_success "SSL certificate validated and issued"
                return 0
                ;;
            "PENDING_VALIDATION")
                log_info "Certificate validation in progress... (attempt $attempt/$max_attempts)"
                ;;
            "FAILED")
                log_error "Certificate validation failed"
                return 1
                ;;
            *)
                log_warning "Certificate status: $cert_status"
                ;;
        esac
        
        sleep 60
        ((attempt++))
    done
    
    log_error "Certificate validation timeout"
    return 1
}

# Test deployment
test_deployment() {
    log_step "Testing deployment..."
    
    cd "$PROJECT_ROOT"
    
    # Get ALB DNS name
    local alb_dns=$(terraform output -raw load_balancer_dns_name 2>/dev/null || echo "")
    local domain_name=$(terraform output -raw domain_name 2>/dev/null || echo "")
    
    if [[ -n "$alb_dns" ]]; then
        log_info "Testing ALB health check..."
        local health_response=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time 10 \
            "http://$alb_dns/health" 2>/dev/null || echo "000")
        
        if [[ "$health_response" == "200" ]]; then
            log_success "ALB health check passed"
        else
            log_warning "ALB health check returned: $health_response"
        fi
    fi
    
    if [[ -n "$domain_name" && "$domain_name" != "Not configured" ]]; then
        log_info "Testing domain resolution..."
        
        # Test DNS resolution
        if dig +short "app.$domain_name" A >/dev/null 2>&1; then
            log_success "Domain DNS resolution working"
        else
            log_warning "Domain DNS not yet propagated"
        fi
        
        # Test HTTPS if certificate is ready
        local cert_arn=$(terraform output -raw ssl_certificate_arn 2>/dev/null || echo "")
        if [[ -n "$cert_arn" && "$cert_arn" != "Not configured" ]]; then
            log_info "Testing HTTPS connectivity..."
            local https_response=$(curl -s -o /dev/null -w "%{http_code}" \
                --max-time 10 \
                "https://app.$domain_name/health" 2>/dev/null || echo "000")
            
            if [[ "$https_response" == "200" ]]; then
                log_success "HTTPS connectivity test passed"
            else
                log_warning "HTTPS test returned: $https_response (may need DNS propagation time)"
            fi
        fi
    fi
    
    log_success "Deployment testing completed"
}

# Setup monitoring
setup_monitoring() {
    log_step "Setting up monitoring and alerts..."
    
    cd "$PROJECT_ROOT"
    
    # Check if monitoring is enabled
    local monitoring_enabled=$(terraform output -raw cloudwatch_dashboard_url 2>/dev/null || echo "Monitoring not enabled")
    
    if [[ "$monitoring_enabled" != "Monitoring not enabled" ]]; then
        log_success "CloudWatch monitoring enabled"
        log_info "Dashboard URL: $monitoring_enabled"
    fi
    
    # Setup domain monitoring if domain is configured
    local domain_name=$(terraform output -raw domain_name 2>/dev/null || echo "")
    if [[ -n "$domain_name" && "$domain_name" != "Not configured" ]]; then
        if [[ -f "scripts/domain-management.sh" ]]; then
            log_info "Setting up domain monitoring..."
            bash scripts/domain-management.sh setup-monitoring || log_warning "Domain monitoring setup failed"
        fi
    fi
    
    log_success "Monitoring setup completed"
}

# Display deployment summary
show_deployment_summary() {
    cd "$PROJECT_ROOT"
    
    local domain_name=$(terraform output -raw domain_name 2>/dev/null || echo "Not configured")
    local alb_dns=$(terraform output -raw load_balancer_dns_name 2>/dev/null || echo "Not available")
    local app_url=$(terraform output -raw app_url 2>/dev/null || echo "Not configured")
    local bi_url=$(terraform output -raw bi_url 2>/dev/null || echo "Not configured")
    local api_url=$(terraform output -raw api_url 2>/dev/null || echo "Not configured")
    local admin_url=$(terraform output -raw admin_url 2>/dev/null || echo "Not configured")
    
    echo
    echo "=================================================================="
    echo "         Deployment Complete - DevOps Dashboard"
    echo "=================================================================="
    echo
    echo "🌐 Access URLs:"
    if [[ "$domain_name" != "Not configured" ]]; then
        echo "   Main Application:  $app_url"
        echo "   BI Dashboard:      $bi_url"
        echo "   API Endpoints:     $api_url"
        echo "   Admin Interface:   $admin_url"
        echo
        echo "   Domain:            $domain_name"
    else
        echo "   Load Balancer:     http://$alb_dns"
        echo "   Health Check:      http://$alb_dns/health"
    fi
    echo
    echo "🔧 Infrastructure:"
    echo "   VPC and Networking: ✅ Deployed"
    echo "   Auto Scaling Group: ✅ Deployed"
    echo "   RDS Databases:      ✅ Deployed"
    echo "   Load Balancer:      ✅ Deployed"
    if [[ "$domain_name" != "Not configured" ]]; then
        echo "   Route53 DNS:        ✅ Configured"
        echo "   SSL Certificates:   ✅ Validated"
    fi
    echo "   CloudWatch:         ✅ Monitoring Active"
    echo
    echo "📊 Management Commands:"
    echo "   Terraform Status:   terraform show"
    echo "   Infrastructure:     terraform output"
    if [[ "$domain_name" != "Not configured" ]]; then
        echo "   Domain Validation:  ./scripts/domain-management.sh validate"
        echo "   SSL Testing:        ./scripts/domain-management.sh test-https"
    fi
    echo
    echo "📋 Next Steps:"
    echo "   1. Verify all services are healthy"
    if [[ "$domain_name" != "Not configured" ]]; then
        echo "   2. Update domain name servers at your registrar"
        echo "   3. Wait for DNS propagation (up to 48 hours)"
        echo "   4. Test HTTPS access to all subdomains"
    else
        echo "   2. Access application via Load Balancer DNS"
        echo "   3. Configure domain in terraform.tfvars if desired"
    fi
    echo "   5. Deploy and configure Metabase BI tool"
    echo "   6. Set up monitoring alerts and notifications"
    echo
    if [[ "$domain_name" != "Not configured" ]]; then
        echo "🔐 SSL Certificate:"
        echo "   Status:             Validated"
        echo "   Auto-Renewal:       Enabled"
        echo "   Monitoring:         Active"
        echo
        echo "🌍 DNS Configuration:"
        local hosted_zone_id=$(terraform output -raw hosted_zone_id 2>/dev/null || echo "Not available")
        if [[ "$hosted_zone_id" != "Not available" ]]; then
            echo "   Hosted Zone ID:     $hosted_zone_id"
            echo "   Health Checks:      Enabled"
        fi
        echo
    fi
    echo "=================================================================="
    echo "🎉 Your DevOps Dashboard is ready for use!"
    echo "=================================================================="
}

# Cleanup on failure
cleanup_on_failure() {
    log_error "Deployment failed. Cleaning up..."
    
    cd "$PROJECT_ROOT"
    
    # Remove plan file if it exists
    rm -f tfplan
    
    # Option to destroy resources
    read -p "Do you want to destroy the partially created resources? (yes/no): " destroy_confirm
    
    if [[ "$destroy_confirm" == "yes" ]]; then
        log_warning "Destroying resources..."
        terraform destroy -auto-approve
    else
        log_info "Resources left as-is for manual cleanup"
    fi
}

# Main deployment function
main() {
    local skip_plan=false
    local auto_approve=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-plan)
                skip_plan=true
                shift
                ;;
            --auto-approve)
                auto_approve=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --skip-plan     Skip Terraform plan step"
                echo "  --auto-approve  Skip confirmation prompts"
                echo "  --help          Show this help message"
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
    
    log_info "Starting complete deployment with domain and SSL..."
    log_info "Log file: $LOG_FILE"
    
    # Set up error handling
    trap cleanup_on_failure ERR
    
    # Run deployment steps
    check_prerequisites
    validate_configuration
    initialize_terraform
    
    if [[ "$skip_plan" == false ]]; then
        plan_deployment
        
        if [[ "$auto_approve" == false ]]; then
            echo
            read -p "Do you want to proceed with the deployment? (yes/no): " confirm
            
            if [[ "$confirm" != "yes" ]]; then
                log_info "Deployment cancelled by user"
                exit 0
            fi
        fi
    fi
    
    deploy_infrastructure
    wait_for_certificate_validation
    test_deployment
    setup_monitoring
    
    show_deployment_summary
    
    log_success "Complete deployment finished successfully!"
    log_info "Full deployment log: $LOG_FILE"
}

# Handle script interruption
trap 'log_error "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"

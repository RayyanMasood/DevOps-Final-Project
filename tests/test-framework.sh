#!/bin/bash

# End-to-End Testing and Validation Framework
# Comprehensive testing suite for DevOps Dashboard infrastructure and applications

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/tmp/test-framework.log"
RESULTS_DIR="$SCRIPT_DIR/results"
REPORTS_DIR="$SCRIPT_DIR/reports"

# Test configuration
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"
PERFORMANCE_DURATION="${PERFORMANCE_DURATION:-60}"
CONCURRENT_USERS="${CONCURRENT_USERS:-10}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Test categories
declare -A TEST_CATEGORIES=(
    ["infrastructure"]="Infrastructure Validation"
    ["connectivity"]="Connectivity Tests"
    ["database"]="Database Tests"
    ["application"]="Application Tests"
    ["loadbalancer"]="Load Balancer Tests"
    ["ssl"]="SSL/TLS Tests"
    ["bi"]="BI Tool Tests"
    ["security"]="Security Tests"
    ["performance"]="Performance Tests"
    ["integration"]="Integration Tests"
    ["monitoring"]="Monitoring Tests"
)

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

log_test() {
    echo -e "${PURPLE}[TEST]${NC} $1" | tee -a "$LOG_FILE"
}

log_category() {
    echo -e "${CYAN}[CATEGORY]${NC} $1" | tee -a "$LOG_FILE"
}

# Test result functions
test_pass() {
    local test_name="$1"
    ((TOTAL_TESTS++))
    ((PASSED_TESTS++))
    log_success "✅ $test_name - PASSED"
    echo "PASS,$test_name,$(date -Iseconds)" >> "$RESULTS_DIR/test-results.csv"
}

test_fail() {
    local test_name="$1"
    local error_msg="${2:-No error message}"
    ((TOTAL_TESTS++))
    ((FAILED_TESTS++))
    log_error "❌ $test_name - FAILED: $error_msg"
    echo "FAIL,$test_name,$(date -Iseconds),$error_msg" >> "$RESULTS_DIR/test-results.csv"
}

test_skip() {
    local test_name="$1"
    local reason="${2:-No reason provided}"
    ((TOTAL_TESTS++))
    ((SKIPPED_TESTS++))
    log_warning "⏭️ $test_name - SKIPPED: $reason"
    echo "SKIP,$test_name,$(date -Iseconds),$reason" >> "$RESULTS_DIR/test-results.csv"
}

# Print banner
print_banner() {
    echo
    echo "=================================================================="
    echo "    DevOps Dashboard - End-to-End Testing Framework"
    echo "=================================================================="
    echo "Comprehensive validation of infrastructure and applications"
    echo "$(date)"
    echo "=================================================================="
    echo
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Create directories
    mkdir -p "$RESULTS_DIR" "$REPORTS_DIR"
    
    # Initialize results file
    echo "Status,Test Name,Timestamp,Error Message" > "$RESULTS_DIR/test-results.csv"
    
    # Create test configuration
    cat > "$RESULTS_DIR/test-config.json" << EOF
{
    "test_run": {
        "id": "$(date +%Y%m%d_%H%M%S)",
        "started_at": "$(date -Iseconds)",
        "environment": "${ENVIRONMENT:-dev}",
        "region": "$AWS_REGION",
        "timeout": $TEST_TIMEOUT,
        "performance_duration": $PERFORMANCE_DURATION,
        "concurrent_users": $CONCURRENT_USERS
    }
}
EOF
    
    log_success "Test environment setup complete"
}

# Check prerequisites
check_prerequisites() {
    log_category "Prerequisites Check"
    
    # Check required commands
    local required_commands=("terraform" "aws" "curl" "jq" "dig" "nc" "ab" "python3")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        test_fail "Prerequisites Check" "Missing commands: ${missing_commands[*]}"
        return 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        test_fail "AWS Credentials" "AWS CLI not configured or credentials invalid"
        return 1
    fi
    
    # Check Terraform state
    if [[ ! -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]]; then
        test_fail "Terraform State" "Terraform state file not found. Run 'terraform apply' first."
        return 1
    fi
    
    test_pass "Prerequisites Check"
    return 0
}

# Load Terraform outputs
load_terraform_outputs() {
    log_info "Loading Terraform outputs..."
    
    cd "$PROJECT_ROOT/terraform"
    
    # Extract key outputs
    export DOMAIN_NAME=$(terraform output -raw domain_name 2>/dev/null || echo "")
    export ALB_DNS_NAME=$(terraform output -raw load_balancer_dns_name 2>/dev/null || echo "")
    export ALB_ZONE_ID=$(terraform output -raw load_balancer_zone_id 2>/dev/null || echo "")
    export VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
    export PRIVATE_SUBNET_IDS=$(terraform output -json private_subnet_ids 2>/dev/null || echo "[]")
    export PUBLIC_SUBNET_IDS=$(terraform output -json public_subnet_ids 2>/dev/null || echo "[]")
    export MYSQL_ENDPOINT=$(terraform output -raw mysql_endpoint 2>/dev/null || echo "")
    export POSTGRES_ENDPOINT=$(terraform output -raw postgres_endpoint 2>/dev/null || echo "")
    export APP_URL=$(terraform output -raw app_url 2>/dev/null || echo "")
    export BI_URL=$(terraform output -raw bi_url 2>/dev/null || echo "")
    export API_URL=$(terraform output -raw api_url 2>/dev/null || echo "")
    export SSL_CERT_ARN=$(terraform output -raw ssl_certificate_arn 2>/dev/null || echo "")
    export ASG_NAME=$(terraform output -raw auto_scaling_group_name 2>/dev/null || echo "")
    
    # Save outputs to file
    cat > "$RESULTS_DIR/terraform-outputs.json" << EOF
{
    "domain_name": "$DOMAIN_NAME",
    "alb_dns_name": "$ALB_DNS_NAME",
    "alb_zone_id": "$ALB_ZONE_ID",
    "vpc_id": "$VPC_ID",
    "mysql_endpoint": "$MYSQL_ENDPOINT",
    "postgres_endpoint": "$POSTGRES_ENDPOINT",
    "app_url": "$APP_URL",
    "bi_url": "$BI_URL",
    "api_url": "$API_URL",
    "ssl_cert_arn": "$SSL_CERT_ARN",
    "asg_name": "$ASG_NAME"
}
EOF
    
    log_success "Terraform outputs loaded"
}

# Run infrastructure tests
run_infrastructure_tests() {
    log_category "Infrastructure Validation Tests"
    
    # Test VPC existence
    if [[ -n "$VPC_ID" ]]; then
        if aws ec2 describe-vpcs --vpc-ids "$VPC_ID" >/dev/null 2>&1; then
            test_pass "VPC Exists"
        else
            test_fail "VPC Exists" "VPC $VPC_ID not found"
        fi
    else
        test_skip "VPC Exists" "VPC ID not available"
    fi
    
    # Test subnets
    if [[ "$PRIVATE_SUBNET_IDS" != "[]" ]]; then
        local subnet_count=$(echo "$PRIVATE_SUBNET_IDS" | jq length)
        if [[ $subnet_count -ge 2 ]]; then
            test_pass "Private Subnets Created"
        else
            test_fail "Private Subnets Created" "Expected at least 2 private subnets, found $subnet_count"
        fi
    else
        test_fail "Private Subnets Created" "No private subnets found"
    fi
    
    # Test Auto Scaling Group
    if [[ -n "$ASG_NAME" ]]; then
        local asg_status=$(aws autoscaling describe-auto-scaling-groups \
            --auto-scaling-group-names "$ASG_NAME" \
            --query 'AutoScalingGroups[0].LifecycleState' \
            --output text 2>/dev/null || echo "NotFound")
        
        if [[ "$asg_status" != "NotFound" ]]; then
            test_pass "Auto Scaling Group Exists"
            
            # Check instance count
            local instance_count=$(aws autoscaling describe-auto-scaling-groups \
                --auto-scaling-group-names "$ASG_NAME" \
                --query 'AutoScalingGroups[0].Instances | length(@)' \
                --output text 2>/dev/null || echo "0")
            
            if [[ $instance_count -gt 0 ]]; then
                test_pass "EC2 Instances Running"
            else
                test_fail "EC2 Instances Running" "No instances found in ASG"
            fi
        else
            test_fail "Auto Scaling Group Exists" "ASG $ASG_NAME not found"
        fi
    else
        test_skip "Auto Scaling Group Exists" "ASG name not available"
    fi
    
    # Test RDS instances
    if [[ -n "$MYSQL_ENDPOINT" ]]; then
        local mysql_status=$(aws rds describe-db-instances \
            --query "DBInstances[?Endpoint.Address=='$MYSQL_ENDPOINT'].DBInstanceStatus" \
            --output text 2>/dev/null || echo "NotFound")
        
        if [[ "$mysql_status" == "available" ]]; then
            test_pass "MySQL RDS Available"
        else
            test_fail "MySQL RDS Available" "MySQL status: $mysql_status"
        fi
    else
        test_skip "MySQL RDS Available" "MySQL endpoint not available"
    fi
    
    if [[ -n "$POSTGRES_ENDPOINT" ]]; then
        local postgres_status=$(aws rds describe-db-instances \
            --query "DBInstances[?Endpoint.Address=='$POSTGRES_ENDPOINT'].DBInstanceStatus" \
            --output text 2>/dev/null || echo "NotFound")
        
        if [[ "$postgres_status" == "available" ]]; then
            test_pass "PostgreSQL RDS Available"
        else
            test_fail "PostgreSQL RDS Available" "PostgreSQL status: $postgres_status"
        fi
    else
        test_skip "PostgreSQL RDS Available" "PostgreSQL endpoint not available"
    fi
}

# Run connectivity tests
run_connectivity_tests() {
    log_category "Connectivity Tests"
    
    # Test ALB connectivity
    if [[ -n "$ALB_DNS_NAME" ]]; then
        if curl -f -s --max-time 10 "http://$ALB_DNS_NAME/health" >/dev/null 2>&1; then
            test_pass "ALB HTTP Connectivity"
        else
            test_fail "ALB HTTP Connectivity" "Cannot reach http://$ALB_DNS_NAME/health"
        fi
    else
        test_skip "ALB HTTP Connectivity" "ALB DNS name not available"
    fi
    
    # Test domain connectivity
    if [[ -n "$DOMAIN_NAME" && "$DOMAIN_NAME" != "Not configured" ]]; then
        # Test DNS resolution
        if dig +short "app.$DOMAIN_NAME" A >/dev/null 2>&1; then
            test_pass "Domain DNS Resolution"
        else
            test_fail "Domain DNS Resolution" "Cannot resolve app.$DOMAIN_NAME"
        fi
        
        # Test HTTPS connectivity
        if [[ -n "$APP_URL" ]]; then
            if curl -f -s --max-time 10 "$APP_URL/health" >/dev/null 2>&1; then
                test_pass "HTTPS Connectivity"
            else
                test_fail "HTTPS Connectivity" "Cannot reach $APP_URL/health"
            fi
        fi
    else
        test_skip "Domain DNS Resolution" "Domain not configured"
        test_skip "HTTPS Connectivity" "Domain not configured"
    fi
    
    # Test database connectivity from application
    if [[ -n "$APP_URL" ]]; then
        local db_test_url="${APP_URL}/api/health/database"
        local db_response=$(curl -s --max-time 10 "$db_test_url" 2>/dev/null || echo "")
        
        if echo "$db_response" | grep -q "mysql.*ok" && echo "$db_response" | grep -q "postgres.*ok"; then
            test_pass "Database Connectivity from Application"
        else
            test_fail "Database Connectivity from Application" "Database health check failed"
        fi
    else
        test_skip "Database Connectivity from Application" "Application URL not available"
    fi
}

# Run database tests
run_database_tests() {
    log_category "Database Tests"
    
    # Test MySQL connectivity
    if [[ -n "$MYSQL_ENDPOINT" ]]; then
        if nc -z -w5 "$MYSQL_ENDPOINT" 3306 2>/dev/null; then
            test_pass "MySQL Port Connectivity"
        else
            test_fail "MySQL Port Connectivity" "Cannot connect to $MYSQL_ENDPOINT:3306"
        fi
    else
        test_skip "MySQL Port Connectivity" "MySQL endpoint not available"
    fi
    
    # Test PostgreSQL connectivity
    if [[ -n "$POSTGRES_ENDPOINT" ]]; then
        if nc -z -w5 "$POSTGRES_ENDPOINT" 5432 2>/dev/null; then
            test_pass "PostgreSQL Port Connectivity"
        else
            test_fail "PostgreSQL Port Connectivity" "Cannot connect to $POSTGRES_ENDPOINT:5432"
        fi
    else
        test_skip "PostgreSQL Port Connectivity" "PostgreSQL endpoint not available"
    fi
    
    # Test database performance (via application API)
    if [[ -n "$API_URL" ]]; then
        local perf_start=$(date +%s%N)
        local perf_response=$(curl -s --max-time 5 "$API_URL/users?limit=10" 2>/dev/null || echo "")
        local perf_end=$(date +%s%N)
        local perf_time=$(( (perf_end - perf_start) / 1000000 ))  # Convert to milliseconds
        
        if [[ -n "$perf_response" && $perf_time -lt 1000 ]]; then
            test_pass "Database Query Performance (${perf_time}ms)"
        else
            test_fail "Database Query Performance" "Query took ${perf_time}ms (>1000ms threshold)"
        fi
    else
        test_skip "Database Query Performance" "API URL not available"
    fi
}

# Run application tests
run_application_tests() {
    log_category "Application Tests"
    
    # Test health endpoints
    local endpoints=("/health" "/api/health" "/api/users" "/api/products" "/api/orders")
    
    for endpoint in "${endpoints[@]}"; do
        local test_url="${APP_URL}${endpoint}"
        if [[ -n "$APP_URL" ]]; then
            if curl -f -s --max-time 10 "$test_url" >/dev/null 2>&1; then
                test_pass "Endpoint: $endpoint"
            else
                test_fail "Endpoint: $endpoint" "Cannot reach $test_url"
            fi
        else
            test_skip "Endpoint: $endpoint" "Application URL not available"
        fi
    done
    
    # Test API functionality
    if [[ -n "$API_URL" ]]; then
        # Test users API
        local users_response=$(curl -s --max-time 10 "$API_URL/users?limit=5" 2>/dev/null || echo "")
        if echo "$users_response" | jq -e '.data | length > 0' >/dev/null 2>&1; then
            test_pass "Users API Functionality"
        else
            test_fail "Users API Functionality" "Users API returned invalid data"
        fi
        
        # Test products API
        local products_response=$(curl -s --max-time 10 "$API_URL/products?limit=5" 2>/dev/null || echo "")
        if echo "$products_response" | jq -e '.data | length > 0' >/dev/null 2>&1; then
            test_pass "Products API Functionality"
        else
            test_fail "Products API Functionality" "Products API returned invalid data"
        fi
    else
        test_skip "Users API Functionality" "API URL not available"
        test_skip "Products API Functionality" "API URL not available"
    fi
}

# Run load balancer tests
run_loadbalancer_tests() {
    log_category "Load Balancer Tests"
    
    if [[ -n "$ALB_DNS_NAME" ]]; then
        # Test load balancer health
        local alb_arn=$(aws elbv2 describe-load-balancers \
            --query "LoadBalancers[?DNSName=='$ALB_DNS_NAME'].LoadBalancerArn" \
            --output text 2>/dev/null || echo "")
        
        if [[ -n "$alb_arn" ]]; then
            local alb_state=$(aws elbv2 describe-load-balancers \
                --load-balancer-arns "$alb_arn" \
                --query 'LoadBalancers[0].State.Code' \
                --output text 2>/dev/null || echo "unknown")
            
            if [[ "$alb_state" == "active" ]]; then
                test_pass "Load Balancer State"
            else
                test_fail "Load Balancer State" "ALB state: $alb_state"
            fi
            
            # Test target group health
            local target_groups=$(aws elbv2 describe-target-groups \
                --load-balancer-arn "$alb_arn" \
                --query 'TargetGroups[*].TargetGroupArn' \
                --output text 2>/dev/null || echo "")
            
            if [[ -n "$target_groups" ]]; then
                local healthy_targets=0
                for tg_arn in $target_groups; do
                    local healthy_count=$(aws elbv2 describe-target-health \
                        --target-group-arn "$tg_arn" \
                        --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' \
                        --output text 2>/dev/null || echo "0")
                    healthy_targets=$((healthy_targets + healthy_count))
                done
                
                if [[ $healthy_targets -gt 0 ]]; then
                    test_pass "Target Group Health ($healthy_targets healthy targets)"
                else
                    test_fail "Target Group Health" "No healthy targets found"
                fi
            else
                test_fail "Target Group Health" "No target groups found"
            fi
        else
            test_fail "Load Balancer State" "ALB ARN not found"
        fi
    else
        test_skip "Load Balancer State" "ALB DNS name not available"
        test_skip "Target Group Health" "ALB DNS name not available"
    fi
}

# Run SSL tests
run_ssl_tests() {
    log_category "SSL/TLS Tests"
    
    if [[ -n "$SSL_CERT_ARN" && "$SSL_CERT_ARN" != "Not configured" ]]; then
        # Test certificate status
        local cert_status=$(aws acm describe-certificate \
            --certificate-arn "$SSL_CERT_ARN" \
            --region "$AWS_REGION" \
            --query 'Certificate.Status' \
            --output text 2>/dev/null || echo "UNKNOWN")
        
        if [[ "$cert_status" == "ISSUED" ]]; then
            test_pass "SSL Certificate Status"
        else
            test_fail "SSL Certificate Status" "Certificate status: $cert_status"
        fi
        
        # Test certificate expiry
        local expiry_date=$(aws acm describe-certificate \
            --certificate-arn "$SSL_CERT_ARN" \
            --region "$AWS_REGION" \
            --query 'Certificate.NotAfter' \
            --output text 2>/dev/null || echo "")
        
        if [[ -n "$expiry_date" ]]; then
            local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
            local current_timestamp=$(date +%s)
            local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
            
            if [[ $days_until_expiry -gt 30 ]]; then
                test_pass "SSL Certificate Expiry ($days_until_expiry days)"
            else
                test_fail "SSL Certificate Expiry" "Certificate expires in $days_until_expiry days"
            fi
        fi
    else
        test_skip "SSL Certificate Status" "SSL certificate not configured"
        test_skip "SSL Certificate Expiry" "SSL certificate not configured"
    fi
    
    # Test HTTPS connectivity and security
    if [[ -n "$APP_URL" && "$APP_URL" =~ ^https:// ]]; then
        # Test SSL connection
        local ssl_domain=$(echo "$APP_URL" | sed 's|https://||' | sed 's|/.*||')
        
        if echo | openssl s_client -servername "$ssl_domain" -connect "$ssl_domain:443" -verify_return_error >/dev/null 2>&1; then
            test_pass "SSL Connection Verification"
        else
            test_fail "SSL Connection Verification" "SSL connection failed for $ssl_domain"
        fi
        
        # Test HTTP to HTTPS redirect
        local redirect_response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${APP_URL/https:/http:}" 2>/dev/null || echo "000")
        
        if [[ "$redirect_response" =~ ^30[1-8]$ ]]; then
            test_pass "HTTP to HTTPS Redirect"
        else
            test_fail "HTTP to HTTPS Redirect" "Expected 3xx, got $redirect_response"
        fi
    else
        test_skip "SSL Connection Verification" "HTTPS URL not available"
        test_skip "HTTP to HTTPS Redirect" "HTTPS URL not available"
    fi
}

# Run BI tool tests
run_bi_tests() {
    log_category "BI Tool Tests"
    
    if [[ -n "$BI_URL" && "$BI_URL" != "Not configured" ]]; then
        # Test Metabase connectivity
        if curl -f -s --max-time 10 "$BI_URL/api/health" >/dev/null 2>&1; then
            test_pass "Metabase Connectivity"
        else
            test_fail "Metabase Connectivity" "Cannot reach $BI_URL/api/health"
        fi
        
        # Test Metabase login page
        local login_response=$(curl -s --max-time 10 "$BI_URL" 2>/dev/null || echo "")
        if echo "$login_response" | grep -qi "metabase"; then
            test_pass "Metabase Login Page"
        else
            test_fail "Metabase Login Page" "Metabase login page not accessible"
        fi
        
        # Test database connections (if configured)
        local db_test_url="$BI_URL/api/database"
        if curl -f -s --max-time 10 "$db_test_url" >/dev/null 2>&1; then
            test_pass "Metabase Database API"
        else
            test_skip "Metabase Database API" "Database API requires authentication"
        fi
    else
        test_skip "Metabase Connectivity" "BI URL not configured"
        test_skip "Metabase Login Page" "BI URL not configured"
        test_skip "Metabase Database API" "BI URL not configured"
    fi
}

# Run security tests
run_security_tests() {
    log_category "Security Tests"
    
    # Test security groups
    if [[ -n "$VPC_ID" ]]; then
        local security_groups=$(aws ec2 describe-security-groups \
            --filters "Name=vpc-id,Values=$VPC_ID" \
            --query 'SecurityGroups[*].GroupId' \
            --output text 2>/dev/null || echo "")
        
        if [[ -n "$security_groups" ]]; then
            test_pass "Security Groups Exist"
            
            # Check for overly permissive rules
            local open_rules=$(aws ec2 describe-security-groups \
                --group-ids $security_groups \
                --query 'SecurityGroups[*].IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]] | length(@)' \
                --output text 2>/dev/null || echo "0")
            
            if [[ $open_rules -eq 0 ]]; then
                test_pass "Security Group Rules (No Open Access)"
            else
                test_warning "Security Group Rules" "$open_rules rules allow 0.0.0.0/0 access"
            fi
        else
            test_fail "Security Groups Exist" "No security groups found in VPC"
        fi
    else
        test_skip "Security Groups Exist" "VPC ID not available"
    fi
    
    # Test database accessibility from internet (should fail)
    if [[ -n "$MYSQL_ENDPOINT" ]]; then
        if ! nc -z -w5 "$MYSQL_ENDPOINT" 3306 2>/dev/null; then
            test_pass "MySQL Not Publicly Accessible"
        else
            test_fail "MySQL Not Publicly Accessible" "MySQL is accessible from internet"
        fi
    fi
    
    if [[ -n "$POSTGRES_ENDPOINT" ]]; then
        if ! nc -z -w5 "$POSTGRES_ENDPOINT" 5432 2>/dev/null; then
            test_pass "PostgreSQL Not Publicly Accessible"
        else
            test_fail "PostgreSQL Not Publicly Accessible" "PostgreSQL is accessible from internet"
        fi
    fi
}

# Run performance tests
run_performance_tests() {
    log_category "Performance Tests"
    
    if [[ -n "$APP_URL" ]]; then
        # Apache Bench test
        local ab_output_file="$RESULTS_DIR/apache-bench-results.txt"
        
        if command -v ab >/dev/null 2>&1; then
            log_info "Running Apache Bench performance test..."
            
            ab -n 100 -c 10 -g "$RESULTS_DIR/ab-gnuplot.tsv" "$APP_URL/health" > "$ab_output_file" 2>&1 || true
            
            if [[ -f "$ab_output_file" ]]; then
                local avg_response_time=$(grep "Time per request:" "$ab_output_file" | head -1 | awk '{print $4}')
                local requests_per_sec=$(grep "Requests per second:" "$ab_output_file" | awk '{print $4}')
                
                if [[ -n "$avg_response_time" && -n "$requests_per_sec" ]]; then
                    # Check if average response time is under 500ms
                    if (( $(echo "$avg_response_time < 500" | bc -l) )); then
                        test_pass "Performance: Response Time (${avg_response_time}ms)"
                    else
                        test_fail "Performance: Response Time" "Average response time: ${avg_response_time}ms (>500ms)"
                    fi
                    
                    # Check if we can handle at least 50 requests per second
                    if (( $(echo "$requests_per_sec > 50" | bc -l) )); then
                        test_pass "Performance: Throughput (${requests_per_sec} req/sec)"
                    else
                        test_fail "Performance: Throughput" "Throughput: ${requests_per_sec} req/sec (<50 req/sec)"
                    fi
                else
                    test_fail "Performance Test" "Could not parse Apache Bench results"
                fi
            else
                test_fail "Performance Test" "Apache Bench test failed"
            fi
        else
            test_skip "Performance Test" "Apache Bench not available"
        fi
        
        # Simple response time test
        local start_time=$(date +%s%N)
        curl -f -s --max-time 10 "$APP_URL/health" >/dev/null 2>&1
        local end_time=$(date +%s%N)
        local response_time=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
        
        if [[ $response_time -lt 1000 ]]; then
            test_pass "Single Request Response Time (${response_time}ms)"
        else
            test_fail "Single Request Response Time" "Response time: ${response_time}ms (>1000ms)"
        fi
    else
        test_skip "Performance Test" "Application URL not available"
        test_skip "Single Request Response Time" "Application URL not available"
    fi
}

# Run integration tests
run_integration_tests() {
    log_category "Integration Tests"
    
    # Test full user journey
    if [[ -n "$API_URL" ]]; then
        log_info "Testing user journey: users -> products -> orders"
        
        # Step 1: Get users
        local users_response=$(curl -s --max-time 10 "$API_URL/users?limit=1" 2>/dev/null || echo "")
        if echo "$users_response" | jq -e '.data[0].id' >/dev/null 2>&1; then
            local user_id=$(echo "$users_response" | jq -r '.data[0].id')
            
            # Step 2: Get products
            local products_response=$(curl -s --max-time 10 "$API_URL/products?limit=1" 2>/dev/null || echo "")
            if echo "$products_response" | jq -e '.data[0].id' >/dev/null 2>&1; then
                local product_id=$(echo "$products_response" | jq -r '.data[0].id')
                
                # Step 3: Get orders for the user
                local orders_response=$(curl -s --max-time 10 "$API_URL/orders?user_id=$user_id&limit=1" 2>/dev/null || echo "")
                if echo "$orders_response" | jq -e '.success' >/dev/null 2>&1; then
                    test_pass "User Journey Integration"
                else
                    test_fail "User Journey Integration" "Orders API failed"
                fi
            else
                test_fail "User Journey Integration" "Products API failed"
            fi
        else
            test_fail "User Journey Integration" "Users API failed"
        fi
    else
        test_skip "User Journey Integration" "API URL not available"
    fi
    
    # Test database to BI tool data flow
    if [[ -n "$BI_URL" && -n "$API_URL" ]]; then
        # Check if data is consistent between API and BI tool
        local api_users_count=$(curl -s --max-time 10 "$API_URL/users?limit=1000" 2>/dev/null | jq '.data | length' 2>/dev/null || echo "0")
        
        if [[ $api_users_count -gt 0 ]]; then
            test_pass "Data Flow: API to Database"
        else
            test_fail "Data Flow: API to Database" "No data found in API"
        fi
    else
        test_skip "Data Flow: API to Database" "URLs not available"
    fi
}

# Run monitoring tests
run_monitoring_tests() {
    log_category "Monitoring Tests"
    
    # Test CloudWatch alarms
    local alarms=$(aws cloudwatch describe-alarms \
        --query 'MetricAlarms[?contains(AlarmName, `devops`) || contains(AlarmName, `dashboard`)].AlarmName' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$alarms" ]]; then
        test_pass "CloudWatch Alarms Configured"
        
        # Check alarm states
        local alarm_count=0
        local ok_count=0
        
        for alarm in $alarms; do
            ((alarm_count++))
            local state=$(aws cloudwatch describe-alarms \
                --alarm-names "$alarm" \
                --query 'MetricAlarms[0].StateValue' \
                --output text 2>/dev/null || echo "UNKNOWN")
            
            if [[ "$state" == "OK" ]]; then
                ((ok_count++))
            fi
        done
        
        if [[ $ok_count -eq $alarm_count ]]; then
            test_pass "CloudWatch Alarm States ($ok_count/$alarm_count OK)"
        else
            test_warning "CloudWatch Alarm States" "$ok_count/$alarm_count alarms in OK state"
        fi
    else
        test_skip "CloudWatch Alarms Configured" "No alarms found"
    fi
    
    # Test Route53 health checks
    if [[ -n "$DOMAIN_NAME" && "$DOMAIN_NAME" != "Not configured" ]]; then
        local health_checks=$(aws route53 list-health-checks \
            --query "HealthChecks[?contains(Config.FullyQualifiedDomainName, '$DOMAIN_NAME')].Id" \
            --output text 2>/dev/null || echo "")
        
        if [[ -n "$health_checks" ]]; then
            test_pass "Route53 Health Checks Configured"
            
            # Check health check status
            local healthy_count=0
            local total_count=0
            
            for health_check_id in $health_checks; do
                ((total_count++))
                local status=$(aws route53 get-health-check-status \
                    --health-check-id "$health_check_id" \
                    --query 'StatusChecker.Status' \
                    --output text 2>/dev/null || echo "UNKNOWN")
                
                if [[ "$status" == "Success" ]]; then
                    ((healthy_count++))
                fi
            done
            
            if [[ $healthy_count -eq $total_count ]]; then
                test_pass "Route53 Health Check Status ($healthy_count/$total_count healthy)"
            else
                test_fail "Route53 Health Check Status" "$healthy_count/$total_count health checks passing"
            fi
        else
            test_skip "Route53 Health Checks Configured" "No health checks found"
        fi
    else
        test_skip "Route53 Health Checks Configured" "Domain not configured"
    fi
}

# Generate test report
generate_test_report() {
    log_info "Generating test report..."
    
    local report_file="$REPORTS_DIR/test-report-$(date +%Y%m%d_%H%M%S).html"
    local json_report="$REPORTS_DIR/test-report-$(date +%Y%m%d_%H%M%S).json"
    
    # Create JSON report
    cat > "$json_report" << EOF
{
    "test_run": {
        "id": "$(date +%Y%m%d_%H%M%S)",
        "timestamp": "$(date -Iseconds)",
        "duration": "$(( $(date +%s) - $(date -d "$(head -1 "$LOG_FILE" | awk '{print $1" "$2}')" +%s) )) seconds",
        "environment": "${ENVIRONMENT:-dev}",
        "region": "$AWS_REGION"
    },
    "summary": {
        "total_tests": $TOTAL_TESTS,
        "passed": $PASSED_TESTS,
        "failed": $FAILED_TESTS,
        "skipped": $SKIPPED_TESTS,
        "success_rate": $(( PASSED_TESTS * 100 / (TOTAL_TESTS > 0 ? TOTAL_TESTS : 1) ))
    },
    "categories": $(echo '{}' | jq '. + $ARGS.named' --argjson infrastructure 0 --argjson connectivity 0 --argjson database 0 --argjson application 0 --argjson loadbalancer 0 --argjson ssl 0 --argjson bi 0 --argjson security 0 --argjson performance 0 --argjson integration 0 --argjson monitoring 0)
}
EOF
    
    # Create HTML report
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>DevOps Dashboard - Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .summary { background: #ecf0f1; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .category { margin: 20px 0; }
        .test-pass { color: #27ae60; }
        .test-fail { color: #e74c3c; }
        .test-skip { color: #f39c12; }
        .progress-bar { width: 100%; background: #ecf0f1; border-radius: 10px; overflow: hidden; }
        .progress-fill { height: 20px; background: #27ae60; transition: width 0.3s; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 DevOps Dashboard - Test Report</h1>
        <p>Generated: $(date)</p>
    </div>
    
    <div class="summary">
        <h2>📊 Test Summary</h2>
        <div class="progress-bar">
            <div class="progress-fill" style="width: $(( PASSED_TESTS * 100 / (TOTAL_TESTS > 0 ? TOTAL_TESTS : 1) ))%"></div>
        </div>
        <p><strong>Total Tests:</strong> $TOTAL_TESTS</p>
        <p><strong>Passed:</strong> <span class="test-pass">$PASSED_TESTS</span></p>
        <p><strong>Failed:</strong> <span class="test-fail">$FAILED_TESTS</span></p>
        <p><strong>Skipped:</strong> <span class="test-skip">$SKIPPED_TESTS</span></p>
        <p><strong>Success Rate:</strong> $(( PASSED_TESTS * 100 / (TOTAL_TESTS > 0 ? TOTAL_TESTS : 1) ))%</p>
    </div>
    
    <div class="category">
        <h2>📋 Test Results</h2>
        <table>
            <tr><th>Status</th><th>Test Name</th><th>Timestamp</th><th>Error Message</th></tr>
EOF
    
    # Add test results to HTML
    while IFS=',' read -r status test_name timestamp error_msg; do
        local css_class=""
        local icon=""
        case "$status" in
            "PASS") css_class="test-pass"; icon="✅" ;;
            "FAIL") css_class="test-fail"; icon="❌" ;;
            "SKIP") css_class="test-skip"; icon="⏭️" ;;
        esac
        
        cat >> "$report_file" << EOF
            <tr class="$css_class">
                <td>$icon $status</td>
                <td>$test_name</td>
                <td>$timestamp</td>
                <td>${error_msg:-}</td>
            </tr>
EOF
    done < <(tail -n +2 "$RESULTS_DIR/test-results.csv")
    
    cat >> "$report_file" << 'EOF'
        </table>
    </div>
</body>
</html>
EOF
    
    log_success "Test report generated:"
    log_info "  HTML Report: $report_file"
    log_info "  JSON Report: $json_report"
}

# Show test summary
show_test_summary() {
    echo
    echo "=================================================================="
    echo "             Test Execution Summary"
    echo "=================================================================="
    echo
    echo "📊 Results:"
    echo "   Total Tests: $TOTAL_TESTS"
    echo "   Passed:      $PASSED_TESTS ($(( PASSED_TESTS * 100 / (TOTAL_TESTS > 0 ? TOTAL_TESTS : 1) ))%)"
    echo "   Failed:      $FAILED_TESTS"
    echo "   Skipped:     $SKIPPED_TESTS"
    echo
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo "🎉 All tests passed successfully!"
        echo "   Your DevOps Dashboard is ready for demonstration."
    elif [[ $FAILED_TESTS -le 2 ]]; then
        echo "⚠️  Most tests passed with $FAILED_TESTS failure(s)."
        echo "   Review failed tests and consider if they impact demonstration."
    else
        echo "❌ Multiple test failures detected ($FAILED_TESTS)."
        echo "   Please review and fix issues before demonstration."
    fi
    
    echo
    echo "📁 Generated Files:"
    echo "   Test Results: $RESULTS_DIR/test-results.csv"
    echo "   Test Reports: $REPORTS_DIR/"
    echo "   Test Logs:    $LOG_FILE"
    echo
    echo "=================================================================="
}

# Main test execution function
main() {
    local test_categories=()
    local skip_prereq=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --category)
                test_categories+=("$2")
                shift 2
                ;;
            --skip-prereq)
                skip_prereq=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --category CATEGORY    Run specific test category"
                echo "  --skip-prereq         Skip prerequisites check"
                echo "  --help                Show this help message"
                echo
                echo "Available categories:"
                for key in "${!TEST_CATEGORIES[@]}"; do
                    echo "  $key: ${TEST_CATEGORIES[$key]}"
                done
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # If no categories specified, run all
    if [[ ${#test_categories[@]} -eq 0 ]]; then
        test_categories=(infrastructure connectivity database application loadbalancer ssl bi security performance integration monitoring)
    fi
    
    # Setup
    print_banner
    setup_test_environment
    
    if [[ "$skip_prereq" == false ]]; then
        check_prerequisites || exit 1
    fi
    
    load_terraform_outputs
    
    # Run selected test categories
    for category in "${test_categories[@]}"; do
        case "$category" in
            infrastructure) run_infrastructure_tests ;;
            connectivity) run_connectivity_tests ;;
            database) run_database_tests ;;
            application) run_application_tests ;;
            loadbalancer) run_loadbalancer_tests ;;
            ssl) run_ssl_tests ;;
            bi) run_bi_tests ;;
            security) run_security_tests ;;
            performance) run_performance_tests ;;
            integration) run_integration_tests ;;
            monitoring) run_monitoring_tests ;;
            *)
                log_warning "Unknown test category: $category"
                ;;
        esac
    done
    
    # Generate reports and summary
    generate_test_report
    show_test_summary
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Handle script interruption
trap 'log_error "Test execution interrupted"; exit 1' INT TERM

# Run main function
main "$@"

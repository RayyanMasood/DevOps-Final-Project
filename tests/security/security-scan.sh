#!/bin/bash

# Security Validation Script for DevOps Dashboard
# Comprehensive security testing and compliance checks

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
LOG_FILE="/tmp/security-scan.log"
RESULTS_DIR="$SCRIPT_DIR/results"

# Security test configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
SEVERITY_THRESHOLD="${SEVERITY_THRESHOLD:-medium}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Test tracking
SECURITY_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
    ((PASSED_TESTS++))
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    ((FAILED_TESTS++))
}

log_critical() {
    echo -e "${RED}[CRITICAL]${NC} $1" | tee -a "$LOG_FILE"
    ((FAILED_TESTS++))
}

log_category() {
    echo -e "${PURPLE}[CATEGORY]${NC} $1" | tee -a "$LOG_FILE"
}

test_security() {
    local test_name="$1"
    ((SECURITY_TESTS++))
    log_info "Testing: $test_name"
}

# Setup security scan environment
setup_security_environment() {
    log_info "Setting up security scan environment..."
    
    mkdir -p "$RESULTS_DIR"
    
    # Initialize results file
    cat > "$RESULTS_DIR/security-scan-results.json" << EOF
{
    "scan_info": {
        "timestamp": "$(date -Iseconds)",
        "region": "$AWS_REGION",
        "severity_threshold": "$SEVERITY_THRESHOLD"
    },
    "results": {}
}
EOF
    
    log_success "Security scan environment ready"
}

# Load Terraform outputs for security testing
load_terraform_outputs() {
    log_info "Loading infrastructure information..."
    
    cd "$PROJECT_ROOT/terraform"
    
    # Extract security-relevant outputs
    export VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
    export SECURITY_GROUP_IDS=$(terraform output -json security_group_ids 2>/dev/null || echo "{}")
    export ALB_ARN=$(terraform output -raw load_balancer_arn 2>/dev/null || echo "")
    export SSL_CERT_ARN=$(terraform output -raw ssl_certificate_arn 2>/dev/null || echo "")
    export DOMAIN_NAME=$(terraform output -raw domain_name 2>/dev/null || echo "")
    export RDS_INSTANCES=$(terraform output -json rds_instance_ids 2>/dev/null || echo "[]")
    export S3_BUCKETS=$(aws s3api list-buckets --query 'Buckets[*].Name' --output json 2>/dev/null || echo "[]")
    
    log_success "Infrastructure information loaded"
}

# Test VPC security configuration
test_vpc_security() {
    log_category "VPC Security Configuration"
    
    if [[ -z "$VPC_ID" ]]; then
        log_error "VPC ID not available"
        return 1
    fi
    
    test_security "VPC Flow Logs"
    
    # Check if VPC Flow Logs are enabled
    local flow_logs=$(aws ec2 describe-flow-logs \
        --filter "Name=resource-id,Values=$VPC_ID" \
        --query 'FlowLogs[?FlowLogStatus==`ACTIVE`]' \
        --output json 2>/dev/null || echo "[]")
    
    if [[ $(echo "$flow_logs" | jq length) -gt 0 ]]; then
        log_success "VPC Flow Logs are enabled"
    else
        log_warning "VPC Flow Logs are not enabled - consider enabling for security monitoring"
    fi
    
    test_security "Default Security Group"
    
    # Check default security group rules
    local default_sg=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=default" \
        --query 'SecurityGroups[0]' \
        --output json 2>/dev/null || echo "{}")
    
    if [[ "$default_sg" != "{}" ]]; then
        local inbound_rules=$(echo "$default_sg" | jq '.IpPermissions | length')
        local outbound_rules=$(echo "$default_sg" | jq '.IpPermissionsEgress | length')
        
        if [[ $inbound_rules -eq 0 && $outbound_rules -le 1 ]]; then
            log_success "Default security group properly restricted"
        else
            log_warning "Default security group has $inbound_rules inbound and $outbound_rules outbound rules"
        fi
    fi
}

# Test security group configurations
test_security_groups() {
    log_category "Security Group Analysis"
    
    if [[ "$SECURITY_GROUP_IDS" == "{}" ]]; then
        log_error "Security group information not available"
        return 1
    fi
    
    # Get all security groups in VPC
    local security_groups=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'SecurityGroups[*]' \
        --output json 2>/dev/null || echo "[]")
    
    test_security "Open Security Group Rules"
    
    local open_rules_found=0
    local critical_open_rules=0
    
    echo "$security_groups" | jq -c '.[]' | while read -r sg; do
        local sg_id=$(echo "$sg" | jq -r '.GroupId')
        local sg_name=$(echo "$sg" | jq -r '.GroupName')
        
        # Check inbound rules
        echo "$sg" | jq -c '.IpPermissions[]?' | while read -r rule; do
            local from_port=$(echo "$rule" | jq -r '.FromPort // "N/A"')
            local to_port=$(echo "$rule" | jq -r '.ToPort // "N/A"')
            local protocol=$(echo "$rule" | jq -r '.IpProtocol')
            
            # Check for 0.0.0.0/0 access
            local open_cidrs=$(echo "$rule" | jq -r '.IpRanges[]? | select(.CidrIp == "0.0.0.0/0") | .CidrIp')
            
            if [[ -n "$open_cidrs" ]]; then
                if [[ "$from_port" == "22" || "$from_port" == "3389" || "$from_port" == "3306" || "$from_port" == "5432" ]]; then
                    log_critical "Critical: $sg_name ($sg_id) allows $protocol:$from_port from 0.0.0.0/0"
                    ((critical_open_rules++))
                elif [[ "$from_port" == "80" || "$from_port" == "443" ]]; then
                    log_success "$sg_name ($sg_id) allows web traffic from 0.0.0.0/0 (expected)"
                else
                    log_warning "$sg_name ($sg_id) allows $protocol:$from_port from 0.0.0.0/0"
                    ((open_rules_found++))
                fi
            fi
        done
    done
    
    test_security "Unused Security Groups"
    
    # Find unused security groups
    local all_sgs=$(echo "$security_groups" | jq -r '.[].GroupId')
    local unused_sgs=()
    
    for sg_id in $all_sgs; do
        if [[ "$sg_id" == "sg-"* ]]; then
            local usage=$(aws ec2 describe-network-interfaces \
                --filters "Name=group-id,Values=$sg_id" \
                --query 'NetworkInterfaces | length(@)' \
                --output text 2>/dev/null || echo "0")
            
            if [[ "$usage" == "0" ]]; then
                unused_sgs+=("$sg_id")
            fi
        fi
    done
    
    if [[ ${#unused_sgs[@]} -eq 0 ]]; then
        log_success "No unused security groups found"
    else
        log_warning "Found ${#unused_sgs[@]} unused security groups: ${unused_sgs[*]}"
    fi
}

# Test RDS security
test_rds_security() {
    log_category "RDS Security Configuration"
    
    if [[ "$RDS_INSTANCES" == "[]" ]]; then
        log_warning "No RDS instances found"
        return 0
    fi
    
    echo "$RDS_INSTANCES" | jq -r '.[]' | while read -r instance_id; do
        if [[ -n "$instance_id" ]]; then
            test_security "RDS Instance: $instance_id"
            
            # Get RDS instance details
            local instance_info=$(aws rds describe-db-instances \
                --db-instance-identifier "$instance_id" \
                --query 'DBInstances[0]' \
                --output json 2>/dev/null || echo "{}")
            
            if [[ "$instance_info" != "{}" ]]; then
                # Check public accessibility
                local publicly_accessible=$(echo "$instance_info" | jq -r '.PubliclyAccessible')
                if [[ "$publicly_accessible" == "false" ]]; then
                    log_success "RDS $instance_id is not publicly accessible"
                else
                    log_critical "RDS $instance_id is publicly accessible"
                fi
                
                # Check encryption at rest
                local encrypted=$(echo "$instance_info" | jq -r '.StorageEncrypted')
                if [[ "$encrypted" == "true" ]]; then
                    log_success "RDS $instance_id has encryption at rest enabled"
                else
                    log_error "RDS $instance_id does not have encryption at rest enabled"
                fi
                
                # Check backup retention
                local backup_retention=$(echo "$instance_info" | jq -r '.BackupRetentionPeriod')
                if [[ $backup_retention -ge 7 ]]; then
                    log_success "RDS $instance_id has adequate backup retention ($backup_retention days)"
                else
                    log_warning "RDS $instance_id has short backup retention ($backup_retention days)"
                fi
                
                # Check Multi-AZ
                local multi_az=$(echo "$instance_info" | jq -r '.MultiAZ')
                if [[ "$multi_az" == "true" ]]; then
                    log_success "RDS $instance_id has Multi-AZ enabled"
                else
                    log_warning "RDS $instance_id does not have Multi-AZ enabled"
                fi
            fi
        fi
    done
}

# Test S3 bucket security
test_s3_security() {
    log_category "S3 Bucket Security"
    
    if [[ "$S3_BUCKETS" == "[]" ]]; then
        log_info "No S3 buckets found"
        return 0
    fi
    
    echo "$S3_BUCKETS" | jq -r '.[]' | while read -r bucket_name; do
        if [[ -n "$bucket_name" ]]; then
            test_security "S3 Bucket: $bucket_name"
            
            # Check public access block
            local public_access_block=$(aws s3api get-public-access-block \
                --bucket "$bucket_name" \
                --query 'PublicAccessBlockConfiguration' \
                --output json 2>/dev/null || echo "{}")
            
            if [[ "$public_access_block" != "{}" ]]; then
                local block_public_acls=$(echo "$public_access_block" | jq -r '.BlockPublicAcls')
                local block_public_policy=$(echo "$public_access_block" | jq -r '.BlockPublicPolicy')
                local ignore_public_acls=$(echo "$public_access_block" | jq -r '.IgnorePublicAcls')
                local restrict_public_buckets=$(echo "$public_access_block" | jq -r '.RestrictPublicBuckets')
                
                if [[ "$block_public_acls" == "true" && "$block_public_policy" == "true" && 
                      "$ignore_public_acls" == "true" && "$restrict_public_buckets" == "true" ]]; then
                    log_success "S3 $bucket_name has proper public access restrictions"
                else
                    log_warning "S3 $bucket_name may have public access enabled"
                fi
            else
                log_warning "S3 $bucket_name public access block not configured"
            fi
            
            # Check encryption
            local encryption=$(aws s3api get-bucket-encryption \
                --bucket "$bucket_name" \
                --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
                --output text 2>/dev/null || echo "None")
            
            if [[ "$encryption" != "None" ]]; then
                log_success "S3 $bucket_name has encryption enabled ($encryption)"
            else
                log_error "S3 $bucket_name does not have encryption enabled"
            fi
            
            # Check versioning
            local versioning=$(aws s3api get-bucket-versioning \
                --bucket "$bucket_name" \
                --query 'Status' \
                --output text 2>/dev/null || echo "Disabled")
            
            if [[ "$versioning" == "Enabled" ]]; then
                log_success "S3 $bucket_name has versioning enabled"
            else
                log_warning "S3 $bucket_name does not have versioning enabled"
            fi
        fi
    done
}

# Test SSL/TLS configuration
test_ssl_configuration() {
    log_category "SSL/TLS Security"
    
    if [[ -z "$SSL_CERT_ARN" || "$SSL_CERT_ARN" == "Not configured" ]]; then
        log_warning "SSL certificate not configured"
        return 0
    fi
    
    test_security "SSL Certificate Validation"
    
    # Check certificate status
    local cert_status=$(aws acm describe-certificate \
        --certificate-arn "$SSL_CERT_ARN" \
        --region "$AWS_REGION" \
        --query 'Certificate.Status' \
        --output text 2>/dev/null || echo "UNKNOWN")
    
    if [[ "$cert_status" == "ISSUED" ]]; then
        log_success "SSL certificate is properly issued"
    else
        log_error "SSL certificate status: $cert_status"
    fi
    
    # Check certificate transparency logging
    local cert_transparency=$(aws acm describe-certificate \
        --certificate-arn "$SSL_CERT_ARN" \
        --region "$AWS_REGION" \
        --query 'Certificate.Options.CertificateTransparencyLoggingPreference' \
        --output text 2>/dev/null || echo "UNKNOWN")
    
    if [[ "$cert_transparency" == "ENABLED" ]]; then
        log_success "Certificate transparency logging is enabled"
    else
        log_warning "Certificate transparency logging preference: $cert_transparency"
    fi
    
    # Test SSL endpoints
    if [[ -n "$DOMAIN_NAME" && "$DOMAIN_NAME" != "Not configured" ]]; then
        test_security "SSL Endpoint Security"
        
        local ssl_endpoints=("app.$DOMAIN_NAME" "bi.$DOMAIN_NAME" "api.$DOMAIN_NAME")
        
        for endpoint in "${ssl_endpoints[@]}"; do
            # Test SSL connection
            local ssl_test=$(echo | openssl s_client -servername "$endpoint" \
                -connect "$endpoint:443" -verify_return_error 2>&1 || echo "FAILED")
            
            if echo "$ssl_test" | grep -q "Verify return code: 0"; then
                log_success "SSL verification passed for $endpoint"
                
                # Check TLS version
                local tls_version=$(echo "$ssl_test" | grep "Protocol" | awk '{print $3}')
                if [[ "$tls_version" =~ TLSv1\.[23] ]]; then
                    log_success "$endpoint uses secure TLS version: $tls_version"
                else
                    log_warning "$endpoint TLS version: $tls_version (consider upgrading)"
                fi
            else
                log_error "SSL verification failed for $endpoint"
            fi
        done
    fi
}

# Test ALB security configuration
test_alb_security() {
    log_category "Application Load Balancer Security"
    
    if [[ -z "$ALB_ARN" ]]; then
        log_warning "ALB ARN not available"
        return 0
    fi
    
    test_security "ALB Configuration"
    
    # Get ALB details
    local alb_info=$(aws elbv2 describe-load-balancers \
        --load-balancer-arns "$ALB_ARN" \
        --query 'LoadBalancers[0]' \
        --output json 2>/dev/null || echo "{}")
    
    if [[ "$alb_info" != "{}" ]]; then
        # Check if ALB is internet-facing
        local scheme=$(echo "$alb_info" | jq -r '.Scheme')
        if [[ "$scheme" == "internet-facing" ]]; then
            log_success "ALB is properly configured as internet-facing"
        else
            log_warning "ALB scheme: $scheme"
        fi
        
        # Check ALB attributes
        local alb_attributes=$(aws elbv2 describe-load-balancer-attributes \
            --load-balancer-arn "$ALB_ARN" \
            --query 'Attributes' \
            --output json 2>/dev/null || echo "[]")
        
        # Check access logs
        local access_logs_enabled=$(echo "$alb_attributes" | jq -r '.[] | select(.Key=="access_logs.s3.enabled") | .Value')
        if [[ "$access_logs_enabled" == "true" ]]; then
            log_success "ALB access logs are enabled"
        else
            log_warning "ALB access logs are not enabled"
        fi
        
        # Check deletion protection
        local deletion_protection=$(echo "$alb_attributes" | jq -r '.[] | select(.Key=="deletion_protection.enabled") | .Value')
        if [[ "$deletion_protection" == "true" ]]; then
            log_success "ALB deletion protection is enabled"
        else
            log_warning "ALB deletion protection is not enabled"
        fi
    fi
    
    # Check listeners
    local listeners=$(aws elbv2 describe-listeners \
        --load-balancer-arn "$ALB_ARN" \
        --query 'Listeners[*]' \
        --output json 2>/dev/null || echo "[]")
    
    echo "$listeners" | jq -c '.[]' | while read -r listener; do
        local port=$(echo "$listener" | jq -r '.Port')
        local protocol=$(echo "$listener" | jq -r '.Protocol')
        local ssl_policy=$(echo "$listener" | jq -r '.SslPolicy // "N/A"')
        
        if [[ "$protocol" == "HTTPS" ]]; then
            log_success "HTTPS listener found on port $port"
            
            if [[ "$ssl_policy" =~ ELBSecurityPolicy-TLS-1-[23] ]]; then
                log_success "Secure SSL policy in use: $ssl_policy"
            else
                log_warning "SSL policy may be outdated: $ssl_policy"
            fi
        elif [[ "$protocol" == "HTTP" && "$port" == "80" ]]; then
            # Check if HTTP redirects to HTTPS
            local actions=$(echo "$listener" | jq '.DefaultActions[0].Type')
            if echo "$actions" | grep -q "redirect"; then
                log_success "HTTP listener properly redirects to HTTPS"
            else
                log_warning "HTTP listener on port 80 does not redirect to HTTPS"
            fi
        fi
    done
}

# Test IAM permissions and roles
test_iam_security() {
    log_category "IAM Security Analysis"
    
    test_security "IAM Password Policy"
    
    # Check account password policy
    local password_policy=$(aws iam get-account-password-policy \
        --query 'PasswordPolicy' \
        --output json 2>/dev/null || echo "{}")
    
    if [[ "$password_policy" != "{}" ]]; then
        local min_length=$(echo "$password_policy" | jq -r '.MinimumPasswordLength')
        local require_uppercase=$(echo "$password_policy" | jq -r '.RequireUppercaseCharacters')
        local require_lowercase=$(echo "$password_policy" | jq -r '.RequireLowercaseCharacters')
        local require_numbers=$(echo "$password_policy" | jq -r '.RequireNumbers')
        local require_symbols=$(echo "$password_policy" | jq -r '.RequireSymbols')
        
        if [[ $min_length -ge 8 && "$require_uppercase" == "true" && 
              "$require_lowercase" == "true" && "$require_numbers" == "true" ]]; then
            log_success "Strong password policy is configured"
        else
            log_warning "Password policy could be strengthened"
        fi
    else
        log_warning "No password policy configured"
    fi
    
    test_security "Root Account Usage"
    
    # Check for recent root account usage (CloudTrail)
    local root_usage=$(aws logs filter-log-events \
        --log-group-name CloudTrail/Management \
        --start-time $(date -d '30 days ago' +%s)000 \
        --filter-pattern '{ $.userIdentity.type = "Root" }' \
        --query 'events | length(@)' \
        --output text 2>/dev/null || echo "0")
    
    if [[ "$root_usage" == "0" ]]; then
        log_success "No recent root account usage detected"
    else
        log_warning "Root account usage detected in last 30 days: $root_usage events"
    fi
}

# Test network security
test_network_security() {
    log_category "Network Security"
    
    test_security "Network ACLs"
    
    if [[ -n "$VPC_ID" ]]; then
        # Check Network ACLs
        local nacls=$(aws ec2 describe-network-acls \
            --filters "Name=vpc-id,Values=$VPC_ID" \
            --query 'NetworkAcls[*]' \
            --output json 2>/dev/null || echo "[]")
        
        local overly_permissive_nacls=0
        
        echo "$nacls" | jq -c '.[]' | while read -r nacl; do
            local nacl_id=$(echo "$nacl" | jq -r '.NetworkAclId')
            local is_default=$(echo "$nacl" | jq -r '.IsDefault')
            
            # Check for overly permissive rules
            local entries=$(echo "$nacl" | jq -c '.Entries[]?')
            echo "$entries" | while read -r entry; do
                local cidr=$(echo "$entry" | jq -r '.CidrBlock // "N/A"')
                local rule_action=$(echo "$entry" | jq -r '.RuleAction')
                
                if [[ "$cidr" == "0.0.0.0/0" && "$rule_action" == "allow" ]]; then
                    if [[ "$is_default" == "true" ]]; then
                        log_success "Default NACL $nacl_id allows 0.0.0.0/0 (expected)"
                    else
                        log_warning "Custom NACL $nacl_id allows 0.0.0.0/0"
                        ((overly_permissive_nacls++))
                    fi
                fi
            done
        done
    fi
    
    test_security "Internet Gateway Access"
    
    # Check for proper internet gateway usage
    local igws=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --query 'InternetGateways | length(@)' \
        --output text 2>/dev/null || echo "0")
    
    if [[ $igws -eq 1 ]]; then
        log_success "Single internet gateway found (expected)"
    elif [[ $igws -eq 0 ]]; then
        log_warning "No internet gateway found"
    else
        log_warning "Multiple internet gateways found: $igws"
    fi
}

# Test compliance and best practices
test_compliance() {
    log_category "Compliance and Best Practices"
    
    test_security "CloudTrail Logging"
    
    # Check CloudTrail configuration
    local trails=$(aws cloudtrail describe-trails \
        --query 'trailList[*]' \
        --output json 2>/dev/null || echo "[]")
    
    local active_trails=0
    echo "$trails" | jq -c '.[]' | while read -r trail; do
        local trail_name=$(echo "$trail" | jq -r '.Name')
        local is_logging=$(aws cloudtrail get-trail-status \
            --name "$trail_name" \
            --query 'IsLogging' \
            --output text 2>/dev/null || echo "false")
        
        if [[ "$is_logging" == "true" ]]; then
            ((active_trails++))
            log_success "CloudTrail $trail_name is active"
        else
            log_warning "CloudTrail $trail_name is not logging"
        fi
    done
    
    test_security "GuardDuty Status"
    
    # Check GuardDuty
    local guardduty_detectors=$(aws guardduty list-detectors \
        --query 'DetectorIds | length(@)' \
        --output text 2>/dev/null || echo "0")
    
    if [[ $guardduty_detectors -gt 0 ]]; then
        log_success "GuardDuty is enabled"
    else
        log_warning "GuardDuty is not enabled"
    fi
    
    test_security "Config Service"
    
    # Check AWS Config
    local config_recorders=$(aws configservice describe-configuration-recorders \
        --query 'ConfigurationRecorders | length(@)' \
        --output text 2>/dev/null || echo "0")
    
    if [[ $config_recorders -gt 0 ]]; then
        log_success "AWS Config is configured"
    else
        log_warning "AWS Config is not configured"
    fi
}

# Generate security report
generate_security_report() {
    log_info "Generating security report..."
    
    local report_file="$RESULTS_DIR/security-report-$(date +%Y%m%d_%H%M%S).html"
    local json_report="$RESULTS_DIR/security-report-$(date +%Y%m%d_%H%M%S).json"
    
    # Calculate security score
    local total_checks=$((PASSED_TESTS + FAILED_TESTS + WARNINGS))
    local security_score=0
    
    if [[ $total_checks -gt 0 ]]; then
        security_score=$(( (PASSED_TESTS * 100) / total_checks ))
    fi
    
    # Create JSON report
    cat > "$json_report" << EOF
{
    "security_scan": {
        "timestamp": "$(date -Iseconds)",
        "region": "$AWS_REGION",
        "total_tests": $SECURITY_TESTS,
        "passed_tests": $PASSED_TESTS,
        "failed_tests": $FAILED_TESTS,
        "warnings": $WARNINGS,
        "security_score": $security_score
    }
}
EOF
    
    # Create HTML report
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>DevOps Dashboard - Security Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .summary { background: #ecf0f1; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .security-score { font-size: 2em; font-weight: bold; }
        .score-excellent { color: #27ae60; }
        .score-good { color: #f39c12; }
        .score-poor { color: #e74c3c; }
        .test-pass { color: #27ae60; }
        .test-fail { color: #e74c3c; }
        .test-warn { color: #f39c12; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔐 DevOps Dashboard - Security Report</h1>
        <p>Generated: $(date)</p>
    </div>
    
    <div class="summary">
        <h2>🛡️ Security Score</h2>
        <div class="security-score $(if [[ $security_score -ge 80 ]]; then echo "score-excellent"; elif [[ $security_score -ge 60 ]]; then echo "score-good"; else echo "score-poor"; fi)">
            $security_score/100
        </div>
        <p><strong>Total Tests:</strong> $SECURITY_TESTS</p>
        <p><strong>Passed:</strong> <span class="test-pass">$PASSED_TESTS</span></p>
        <p><strong>Failed:</strong> <span class="test-fail">$FAILED_TESTS</span></p>
        <p><strong>Warnings:</strong> <span class="test-warn">$WARNINGS</span></p>
    </div>
</body>
</html>
EOF
    
    log_success "Security report generated:"
    log_info "  HTML Report: $report_file"
    log_info "  JSON Report: $json_report"
}

# Show security summary
show_security_summary() {
    echo
    echo "=================================================================="
    echo "             Security Scan Summary"
    echo "=================================================================="
    echo
    echo "🔐 Security Results:"
    echo "   Total Tests:     $SECURITY_TESTS"
    echo "   Passed:          $PASSED_TESTS"
    echo "   Failed:          $FAILED_TESTS"
    echo "   Warnings:        $WARNINGS"
    
    local total_checks=$((PASSED_TESTS + FAILED_TESTS + WARNINGS))
    local security_score=0
    
    if [[ $total_checks -gt 0 ]]; then
        security_score=$(( (PASSED_TESTS * 100) / total_checks ))
    fi
    
    echo "   Security Score:  $security_score/100"
    echo
    
    if [[ $security_score -ge 80 ]]; then
        echo "🎉 Excellent security posture!"
        echo "   Your infrastructure follows security best practices."
    elif [[ $security_score -ge 60 ]]; then
        echo "⚠️  Good security with room for improvement."
        echo "   Consider addressing warnings to enhance security."
    else
        echo "❌ Security improvements needed."
        echo "   Please address critical security issues before production."
    fi
    
    echo
    echo "📁 Generated Files:"
    echo "   Security Reports: $RESULTS_DIR/"
    echo "   Security Logs:    $LOG_FILE"
    echo
    echo "=================================================================="
}

# Main security scan function
main() {
    local test_categories=()
    local skip_compliance=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --category)
                test_categories+=("$2")
                shift 2
                ;;
            --skip-compliance)
                skip_compliance=true
                shift
                ;;
            --severity)
                SEVERITY_THRESHOLD="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --category CATEGORY    Run specific security category"
                echo "  --skip-compliance      Skip compliance checks"
                echo "  --severity LEVEL       Set severity threshold (low|medium|high)"
                echo "  --help                Show this help message"
                echo
                echo "Available categories:"
                echo "  vpc, security-groups, rds, s3, ssl, alb, iam, network, compliance"
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
        test_categories=(vpc security-groups rds s3 ssl alb iam network)
        if [[ "$skip_compliance" == false ]]; then
            test_categories+=(compliance)
        fi
    fi
    
    # Setup
    echo "🔐 Starting Security Scan..."
    setup_security_environment
    load_terraform_outputs
    
    # Run selected security test categories
    for category in "${test_categories[@]}"; do
        case "$category" in
            vpc) test_vpc_security ;;
            security-groups) test_security_groups ;;
            rds) test_rds_security ;;
            s3) test_s3_security ;;
            ssl) test_ssl_configuration ;;
            alb) test_alb_security ;;
            iam) test_iam_security ;;
            network) test_network_security ;;
            compliance) test_compliance ;;
            *)
                log_warning "Unknown security category: $category"
                ;;
        esac
    done
    
    # Generate reports and summary
    generate_security_report
    show_security_summary
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Handle script interruption
trap 'log_error "Security scan interrupted"; exit 1' INT TERM

# Run main function
main "$@"

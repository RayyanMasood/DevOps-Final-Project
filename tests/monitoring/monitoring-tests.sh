#!/bin/bash

# Monitoring and Alerting Validation Script
# Comprehensive testing for CloudWatch, Route53 health checks, and alerting systems

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
LOG_FILE="/tmp/monitoring-tests.log"
RESULTS_DIR="$SCRIPT_DIR/results"

# Monitoring test configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
ALERT_THRESHOLD_MINUTES="${ALERT_THRESHOLD_MINUTES:-5}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-30}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Test tracking
MONITORING_TESTS=0
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

log_category() {
    echo -e "${PURPLE}[CATEGORY]${NC} $1" | tee -a "$LOG_FILE"
}

test_monitoring() {
    local test_name="$1"
    ((MONITORING_TESTS++))
    log_info "Testing: $test_name"
}

# Setup monitoring test environment
setup_monitoring_environment() {
    log_info "Setting up monitoring test environment..."
    
    mkdir -p "$RESULTS_DIR"
    
    # Initialize results file
    cat > "$RESULTS_DIR/monitoring-test-results.json" << EOF
{
    "monitoring_test": {
        "timestamp": "$(date -Iseconds)",
        "region": "$AWS_REGION",
        "alert_threshold_minutes": $ALERT_THRESHOLD_MINUTES
    },
    "results": {}
}
EOF
    
    log_success "Monitoring test environment ready"
}

# Load Terraform outputs for monitoring testing
load_terraform_outputs() {
    log_info "Loading infrastructure information for monitoring tests..."
    
    cd "$PROJECT_ROOT/terraform"
    
    # Extract monitoring-relevant outputs
    export VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
    export ALB_ARN=$(terraform output -raw load_balancer_arn 2>/dev/null || echo "")
    export ALB_DNS_NAME=$(terraform output -raw load_balancer_dns_name 2>/dev/null || echo "")
    export DOMAIN_NAME=$(terraform output -raw domain_name 2>/dev/null || echo "")
    export APP_URL=$(terraform output -raw app_url 2>/dev/null || echo "")
    export BI_URL=$(terraform output -raw bi_url 2>/dev/null || echo "")
    export API_URL=$(terraform output -raw api_url 2>/dev/null || echo "")
    export RDS_INSTANCES=$(terraform output -json rds_instance_ids 2>/dev/null || echo "[]")
    export ASG_NAME=$(terraform output -raw auto_scaling_group_name 2>/dev/null || echo "")
    
    log_success "Infrastructure information loaded for monitoring tests"
}

# Test CloudWatch metrics collection
test_cloudwatch_metrics() {
    log_category "CloudWatch Metrics Collection"
    
    test_monitoring "CloudWatch Agent Status"
    
    # Check if EC2 instances are sending metrics
    if [[ -n "$ASG_NAME" ]]; then
        local instance_ids=$(aws autoscaling describe-auto-scaling-groups \
            --auto-scaling-group-names "$ASG_NAME" \
            --query 'AutoScalingGroups[0].Instances[].InstanceId' \
            --output text 2>/dev/null || echo "")
        
        if [[ -n "$instance_ids" ]]; then
            local instances_with_metrics=0
            local total_instances=0
            
            for instance_id in $instance_ids; do
                ((total_instances++))
                
                # Check for recent CPU metrics
                local cpu_metrics=$(aws cloudwatch get-metric-statistics \
                    --namespace "AWS/EC2" \
                    --metric-name "CPUUtilization" \
                    --dimensions Name=InstanceId,Value="$instance_id" \
                    --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)" \
                    --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
                    --period 300 \
                    --statistics Average \
                    --query 'Datapoints | length(@)' \
                    --output text 2>/dev/null || echo "0")
                
                if [[ $cpu_metrics -gt 0 ]]; then
                    ((instances_with_metrics++))
                fi
            done
            
            if [[ $instances_with_metrics -eq $total_instances ]]; then
                log_success "All $total_instances EC2 instances sending CloudWatch metrics"
            elif [[ $instances_with_metrics -gt 0 ]]; then
                log_warning "$instances_with_metrics/$total_instances EC2 instances sending metrics"
            else
                log_error "No EC2 instances sending CloudWatch metrics"
            fi
        else
            log_warning "No EC2 instances found in Auto Scaling Group"
        fi
    else
        log_warning "Auto Scaling Group name not available"
    fi
    
    test_monitoring "Application Load Balancer Metrics"
    
    # Check ALB metrics
    if [[ -n "$ALB_ARN" ]]; then
        local alb_name=$(basename "$ALB_ARN")
        
        local alb_metrics=$(aws cloudwatch get-metric-statistics \
            --namespace "AWS/ApplicationELB" \
            --metric-name "RequestCount" \
            --dimensions Name=LoadBalancer,Value="$alb_name" \
            --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)" \
            --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
            --period 300 \
            --statistics Sum \
            --query 'Datapoints | length(@)' \
            --output text 2>/dev/null || echo "0")
        
        if [[ $alb_metrics -gt 0 ]]; then
            log_success "Application Load Balancer sending metrics to CloudWatch"
        else
            log_warning "No recent ALB metrics found in CloudWatch"
        fi
    else
        log_warning "ALB ARN not available"
    fi
    
    test_monitoring "RDS Metrics"
    
    # Check RDS metrics
    if [[ "$RDS_INSTANCES" != "[]" ]]; then
        echo "$RDS_INSTANCES" | jq -r '.[]' | while read -r instance_id; do
            if [[ -n "$instance_id" ]]; then
                local rds_metrics=$(aws cloudwatch get-metric-statistics \
                    --namespace "AWS/RDS" \
                    --metric-name "CPUUtilization" \
                    --dimensions Name=DBInstanceIdentifier,Value="$instance_id" \
                    --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)" \
                    --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
                    --period 300 \
                    --statistics Average \
                    --query 'Datapoints | length(@)' \
                    --output text 2>/dev/null || echo "0")
                
                if [[ $rds_metrics -gt 0 ]]; then
                    log_success "RDS instance $instance_id sending metrics"
                else
                    log_warning "No recent metrics for RDS instance $instance_id"
                fi
            fi
        done
    else
        log_warning "No RDS instances found"
    fi
}

# Test CloudWatch alarms
test_cloudwatch_alarms() {
    log_category "CloudWatch Alarms"
    
    test_monitoring "Application Alarms"
    
    # Find alarms related to the infrastructure
    local all_alarms=$(aws cloudwatch describe-alarms \
        --query 'MetricAlarms[*]' \
        --output json 2>/dev/null || echo "[]")
    
    if [[ "$all_alarms" == "[]" ]]; then
        log_error "No CloudWatch alarms found"
        return 1
    fi
    
    # Check for essential alarms
    local alarm_types=("CPUUtilization" "TargetResponseTime" "UnHealthyHostCount" "DatabaseConnections")
    local found_alarms=()
    local missing_alarms=()
    
    for alarm_type in "${alarm_types[@]}"; do
        local alarm_found=$(echo "$all_alarms" | jq -r ".[] | select(.MetricName == \"$alarm_type\") | .AlarmName" | head -1)
        
        if [[ -n "$alarm_found" ]]; then
            found_alarms+=("$alarm_type")
        else
            missing_alarms+=("$alarm_type")
        fi
    done
    
    if [[ ${#missing_alarms[@]} -eq 0 ]]; then
        log_success "All essential alarm types found: ${found_alarms[*]}"
    else
        log_warning "Missing alarm types: ${missing_alarms[*]}"
    fi
    
    test_monitoring "Alarm States"
    
    # Check alarm states
    local ok_alarms=0
    local alarm_alarms=0
    local insufficient_data_alarms=0
    
    echo "$all_alarms" | jq -c '.[]' | while read -r alarm; do
        local alarm_name=$(echo "$alarm" | jq -r '.AlarmName')
        local alarm_state=$(echo "$alarm" | jq -r '.StateValue')
        
        case "$alarm_state" in
            "OK") ((ok_alarms++)) ;;
            "ALARM") ((alarm_alarms++)) ;;
            "INSUFFICIENT_DATA") ((insufficient_data_alarms++)) ;;
        esac
    done
    
    local total_alarms=$(echo "$all_alarms" | jq length)
    
    if [[ $alarm_alarms -eq 0 ]]; then
        log_success "No alarms in ALARM state ($ok_alarms OK, $insufficient_data_alarms insufficient data)"
    else
        log_warning "$alarm_alarms alarms in ALARM state (total: $total_alarms)"
    fi
    
    test_monitoring "Alarm Actions"
    
    # Check if alarms have actions configured
    local alarms_with_actions=0
    local alarms_without_actions=0
    
    echo "$all_alarms" | jq -c '.[]' | while read -r alarm; do
        local alarm_actions=$(echo "$alarm" | jq -r '.AlarmActions | length')
        local ok_actions=$(echo "$alarm" | jq -r '.OKActions | length')
        
        if [[ $alarm_actions -gt 0 || $ok_actions -gt 0 ]]; then
            ((alarms_with_actions++))
        else
            ((alarms_without_actions++))
        fi
    done
    
    if [[ $alarms_without_actions -eq 0 ]]; then
        log_success "All alarms have actions configured"
    else
        log_warning "$alarms_without_actions alarms without actions configured"
    fi
}

# Test Route53 health checks
test_route53_health_checks() {
    log_category "Route53 Health Checks"
    
    test_monitoring "Health Check Configuration"
    
    if [[ -n "$DOMAIN_NAME" && "$DOMAIN_NAME" != "Not configured" ]]; then
        # Get health checks
        local health_checks=$(aws route53 list-health-checks \
            --query 'HealthChecks[*]' \
            --output json 2>/dev/null || echo "[]")
        
        if [[ "$health_checks" == "[]" ]]; then
            log_warning "No Route53 health checks configured"
            return 0
        fi
        
        # Check health checks related to our domain
        local domain_health_checks=$(echo "$health_checks" | jq -r ".[] | select(.Config.FullyQualifiedDomainName | contains(\"$DOMAIN_NAME\")) | .Id")
        
        if [[ -n "$domain_health_checks" ]]; then
            log_success "Route53 health checks found for domain $DOMAIN_NAME"
            
            test_monitoring "Health Check Status"
            
            # Check status of each health check
            local healthy_checks=0
            local unhealthy_checks=0
            local total_checks=0
            
            echo "$domain_health_checks" | while read -r health_check_id; do
                if [[ -n "$health_check_id" ]]; then
                    ((total_checks++))
                    
                    local status=$(aws route53 get-health-check-status \
                        --health-check-id "$health_check_id" \
                        --query 'StatusChecker.Status' \
                        --output text 2>/dev/null || echo "UNKNOWN")
                    
                    if [[ "$status" == "Success" ]]; then
                        ((healthy_checks++))
                    else
                        ((unhealthy_checks++))
                        log_warning "Health check $health_check_id status: $status"
                    fi
                fi
            done
            
            if [[ $unhealthy_checks -eq 0 ]]; then
                log_success "All $total_checks health checks are healthy"
            else
                log_error "$unhealthy_checks/$total_checks health checks are unhealthy"
            fi
        else
            log_warning "No Route53 health checks found for domain $DOMAIN_NAME"
        fi
    else
        log_warning "Domain not configured, skipping Route53 health checks"
    fi
}

# Test endpoint availability monitoring
test_endpoint_monitoring() {
    log_category "Endpoint Availability Monitoring"
    
    # Test application endpoints
    local endpoints=("$APP_URL" "$API_URL" "$BI_URL")
    local endpoint_names=("Application" "API" "BI Tool")
    
    for i in "${!endpoints[@]}"; do
        local endpoint="${endpoints[$i]}"
        local name="${endpoint_names[$i]}"
        
        if [[ -n "$endpoint" && "$endpoint" != "Not configured" ]]; then
            test_monitoring "$name Endpoint Availability"
            
            # Test endpoint response
            local response_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$endpoint" 2>/dev/null || echo "000")
            local response_time=$(curl -s -o /dev/null -w "%{time_total}" --max-time 10 "$endpoint" 2>/dev/null || echo "999")
            
            if [[ "$response_code" =~ ^[23][0-9][0-9]$ ]]; then
                log_success "$name endpoint healthy (HTTP $response_code, ${response_time}s)"
            else
                log_error "$name endpoint unhealthy (HTTP $response_code)"
            fi
            
            # Test endpoint health check if available
            local health_endpoint=""
            case "$endpoint" in
                *api*) health_endpoint="$endpoint/health" ;;
                *) health_endpoint="$endpoint/health" ;;
            esac
            
            local health_response=$(curl -s --max-time 5 "$health_endpoint" 2>/dev/null || echo "")
            if [[ -n "$health_response" ]]; then
                if echo "$health_response" | grep -qi "healthy\|ok\|success"; then
                    log_success "$name health endpoint responding correctly"
                else
                    log_warning "$name health endpoint response unclear"
                fi
            fi
        else
            log_warning "$name endpoint not configured"
        fi
    done
}

# Test log aggregation and analysis
test_log_monitoring() {
    log_category "Log Monitoring and Analysis"
    
    test_monitoring "CloudWatch Logs Configuration"
    
    # Check for log groups
    local log_groups=$(aws logs describe-log-groups \
        --query 'logGroups[*].logGroupName' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$log_groups" ]]; then
        local app_log_groups=()
        
        # Look for application-related log groups
        for log_group in $log_groups; do
            if [[ "$log_group" =~ (devops|dashboard|app|api|metabase|nginx) ]]; then
                app_log_groups+=("$log_group")
            fi
        done
        
        if [[ ${#app_log_groups[@]} -gt 0 ]]; then
            log_success "Application log groups found: ${app_log_groups[*]}"
            
            test_monitoring "Recent Log Activity"
            
            # Check for recent log activity
            local active_log_groups=0
            for log_group in "${app_log_groups[@]}"; do
                local recent_events=$(aws logs filter-log-events \
                    --log-group-name "$log_group" \
                    --start-time $(($(date +%s) - 3600))000 \
                    --query 'events | length(@)' \
                    --output text 2>/dev/null || echo "0")
                
                if [[ $recent_events -gt 0 ]]; then
                    ((active_log_groups++))
                fi
            done
            
            if [[ $active_log_groups -gt 0 ]]; then
                log_success "$active_log_groups log groups have recent activity"
            else
                log_warning "No recent log activity in application log groups"
            fi
        else
            log_warning "No application-specific log groups found"
        fi
    else
        log_warning "No CloudWatch log groups found"
    fi
    
    test_monitoring "Error Log Detection"
    
    # Search for error patterns in logs
    if [[ ${#app_log_groups[@]} -gt 0 ]]; then
        local error_patterns=("ERROR" "CRITICAL" "FATAL" "Exception" "failed")
        local errors_found=0
        
        for log_group in "${app_log_groups[@]::2}"; do  # Check first 2 log groups to avoid timeout
            for pattern in "${error_patterns[@]}"; do
                local error_count=$(aws logs filter-log-events \
                    --log-group-name "$log_group" \
                    --start-time $(($(date +%s) - 3600))000 \
                    --filter-pattern "$pattern" \
                    --query 'events | length(@)' \
                    --output text 2>/dev/null || echo "0")
                
                if [[ $error_count -gt 0 ]]; then
                    ((errors_found += error_count))
                fi
            done
        done
        
        if [[ $errors_found -eq 0 ]]; then
            log_success "No recent errors found in application logs"
        else
            log_warning "$errors_found error entries found in recent logs"
        fi
    fi
}

# Test notification systems
test_notification_systems() {
    log_category "Notification Systems"
    
    test_monitoring "SNS Topics Configuration"
    
    # Check SNS topics
    local sns_topics=$(aws sns list-topics \
        --query 'Topics[*].TopicArn' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$sns_topics" ]]; then
        local alert_topics=()
        
        # Look for alerting-related topics
        for topic in $sns_topics; do
            if [[ "$topic" =~ (alert|alarm|notification|devops|dashboard) ]]; then
                alert_topics+=("$topic")
            fi
        done
        
        if [[ ${#alert_topics[@]} -gt 0 ]]; then
            log_success "SNS alert topics found: ${#alert_topics[@]} topics"
            
            test_monitoring "SNS Topic Subscriptions"
            
            # Check subscriptions for each topic
            local topics_with_subscriptions=0
            for topic in "${alert_topics[@]}"; do
                local subscription_count=$(aws sns list-subscriptions-by-topic \
                    --topic-arn "$topic" \
                    --query 'Subscriptions | length(@)' \
                    --output text 2>/dev/null || echo "0")
                
                if [[ $subscription_count -gt 0 ]]; then
                    ((topics_with_subscriptions++))
                fi
            done
            
            if [[ $topics_with_subscriptions -gt 0 ]]; then
                log_success "$topics_with_subscriptions SNS topics have subscriptions"
            else
                log_warning "No SNS topics have subscriptions configured"
            fi
        else
            log_warning "No alerting-related SNS topics found"
        fi
    else
        log_warning "No SNS topics found"
    fi
}

# Test monitoring dashboard functionality
test_monitoring_dashboards() {
    log_category "Monitoring Dashboards"
    
    test_monitoring "CloudWatch Dashboards"
    
    # Check for CloudWatch dashboards
    local dashboards=$(aws cloudwatch list-dashboards \
        --query 'DashboardEntries[*].DashboardName' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$dashboards" ]]; then
        local app_dashboards=()
        
        # Look for application-related dashboards
        for dashboard in $dashboards; do
            if [[ "$dashboard" =~ (devops|dashboard|app|infra|monitoring) ]]; then
                app_dashboards+=("$dashboard")
            fi
        done
        
        if [[ ${#app_dashboards[@]} -gt 0 ]]; then
            log_success "CloudWatch dashboards found: ${app_dashboards[*]}"
            
            test_monitoring "Dashboard Widget Validation"
            
            # Check dashboard content
            local dashboards_with_widgets=0
            for dashboard in "${app_dashboards[@]::2}"; do  # Check first 2 dashboards
                local widget_count=$(aws cloudwatch get-dashboard \
                    --dashboard-name "$dashboard" \
                    --query 'DashboardBody' \
                    --output text 2>/dev/null | jq '.widgets | length' 2>/dev/null || echo "0")
                
                if [[ $widget_count -gt 0 ]]; then
                    ((dashboards_with_widgets++))
                fi
            done
            
            if [[ $dashboards_with_widgets -gt 0 ]]; then
                log_success "$dashboards_with_widgets dashboards have widgets configured"
            else
                log_warning "Dashboards found but no widgets configured"
            fi
        else
            log_warning "No application-related CloudWatch dashboards found"
        fi
    else
        log_warning "No CloudWatch dashboards found"
    fi
}

# Generate monitoring test report
generate_monitoring_report() {
    log_info "Generating monitoring test report..."
    
    local report_file="$RESULTS_DIR/monitoring-report-$(date +%Y%m%d_%H%M%S).html"
    local json_report="$RESULTS_DIR/monitoring-report-$(date +%Y%m%d_%H%M%S).json"
    
    # Calculate monitoring score
    local total_checks=$((PASSED_TESTS + FAILED_TESTS + WARNINGS))
    local monitoring_score=0
    
    if [[ $total_checks -gt 0 ]]; then
        monitoring_score=$(( (PASSED_TESTS * 100) / total_checks ))
    fi
    
    # Create JSON report
    cat > "$json_report" << EOF
{
    "monitoring_test": {
        "timestamp": "$(date -Iseconds)",
        "region": "$AWS_REGION",
        "total_tests": $MONITORING_TESTS,
        "passed_tests": $PASSED_TESTS,
        "failed_tests": $FAILED_TESTS,
        "warnings": $WARNINGS,
        "monitoring_score": $monitoring_score
    }
}
EOF
    
    # Create HTML report
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>DevOps Dashboard - Monitoring Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #34495e; color: white; padding: 20px; border-radius: 5px; }
        .summary { background: #ecf0f1; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .monitoring-score { font-size: 2em; font-weight: bold; }
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
        <h1>📊 DevOps Dashboard - Monitoring Report</h1>
        <p>Generated: $(date)</p>
    </div>
    
    <div class="summary">
        <h2>📈 Monitoring Score</h2>
        <div class="monitoring-score $(if [[ $monitoring_score -ge 80 ]]; then echo "score-excellent"; elif [[ $monitoring_score -ge 60 ]]; then echo "score-good"; else echo "score-poor"; fi)">
            $monitoring_score/100
        </div>
        <p><strong>Total Tests:</strong> $MONITORING_TESTS</p>
        <p><strong>Passed:</strong> <span class="test-pass">$PASSED_TESTS</span></p>
        <p><strong>Failed:</strong> <span class="test-fail">$FAILED_TESTS</span></p>
        <p><strong>Warnings:</strong> <span class="test-warn">$WARNINGS</span></p>
    </div>
</body>
</html>
EOF
    
    log_success "Monitoring report generated:"
    log_info "  HTML Report: $report_file"
    log_info "  JSON Report: $json_report"
}

# Show monitoring summary
show_monitoring_summary() {
    echo
    echo "=================================================================="
    echo "             Monitoring Test Summary"
    echo "=================================================================="
    echo
    echo "📊 Monitoring Results:"
    echo "   Total Tests:     $MONITORING_TESTS"
    echo "   Passed:          $PASSED_TESTS"
    echo "   Failed:          $FAILED_TESTS"
    echo "   Warnings:        $WARNINGS"
    
    local total_checks=$((PASSED_TESTS + FAILED_TESTS + WARNINGS))
    local monitoring_score=0
    
    if [[ $total_checks -gt 0 ]]; then
        monitoring_score=$(( (PASSED_TESTS * 100) / total_checks ))
    fi
    
    echo "   Monitoring Score: $monitoring_score/100"
    echo
    
    if [[ $monitoring_score -ge 80 ]]; then
        echo "🎉 Excellent monitoring and alerting setup!"
        echo "   Your monitoring systems are well-configured."
    elif [[ $monitoring_score -ge 60 ]]; then
        echo "⚠️  Good monitoring with room for improvement."
        echo "   Consider addressing warnings to enhance monitoring."
    else
        echo "❌ Monitoring improvements needed."
        echo "   Please address monitoring issues for production readiness."
    fi
    
    echo
    echo "📁 Generated Files:"
    echo "   Monitoring Reports: $RESULTS_DIR/"
    echo "   Monitoring Logs:    $LOG_FILE"
    echo
    echo "=================================================================="
}

# Main monitoring test function
main() {
    local test_categories=()
    local skip_health_checks=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --category)
                test_categories+=("$2")
                shift 2
                ;;
            --skip-health-checks)
                skip_health_checks=true
                shift
                ;;
            --alert-threshold)
                ALERT_THRESHOLD_MINUTES="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --category CATEGORY       Run specific monitoring category"
                echo "  --skip-health-checks      Skip Route53 health check tests"
                echo "  --alert-threshold MIN     Set alert threshold in minutes"
                echo "  --help                    Show this help message"
                echo
                echo "Available categories:"
                echo "  metrics, alarms, health-checks, endpoints, logs, notifications, dashboards"
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
        test_categories=(metrics alarms endpoints logs notifications dashboards)
        if [[ "$skip_health_checks" == false ]]; then
            test_categories+=(health-checks)
        fi
    fi
    
    # Setup
    echo "📊 Starting Monitoring Tests..."
    setup_monitoring_environment
    load_terraform_outputs
    
    # Run selected monitoring test categories
    for category in "${test_categories[@]}"; do
        case "$category" in
            metrics) test_cloudwatch_metrics ;;
            alarms) test_cloudwatch_alarms ;;
            health-checks) test_route53_health_checks ;;
            endpoints) test_endpoint_monitoring ;;
            logs) test_log_monitoring ;;
            notifications) test_notification_systems ;;
            dashboards) test_monitoring_dashboards ;;
            *)
                log_warning "Unknown monitoring category: $category"
                ;;
        esac
    done
    
    # Generate reports and summary
    generate_monitoring_report
    show_monitoring_summary
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Handle script interruption
trap 'log_error "Monitoring tests interrupted"; exit 1' INT TERM

# Run main function
main "$@"

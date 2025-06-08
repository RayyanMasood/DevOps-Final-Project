#!/bin/bash

# Test Orchestration Script for DevOps Dashboard
# Comprehensive end-to-end testing orchestration and reporting

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$TESTS_ROOT")"
LOG_FILE="/tmp/test-orchestrator.log"
RESULTS_DIR="$TESTS_ROOT/results"
REPORTS_DIR="$TESTS_ROOT/reports"

# Test configuration
PARALLEL_TESTS="${PARALLEL_TESTS:-true}"
CONTINUE_ON_FAILURE="${CONTINUE_ON_FAILURE:-false}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
CLEANUP_AFTER_TESTS="${CLEANUP_AFTER_TESTS:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test suite results
declare -A TEST_SUITE_RESULTS
declare -A TEST_SUITE_DURATIONS
declare -A TEST_SUITE_DETAILS

# Test execution order and dependencies
TEST_SUITES=(
    "infrastructure:terraform_infrastructure_validation"
    "security:security_baseline_scan"
    "database:database_connectivity_integrity"
    "application:application_functionality"
    "bi:metabase_functionality"
    "performance:load_performance_testing"
    "integration:end_to_end_integration"
    "monitoring:monitoring_alerting_validation"
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

log_category() {
    echo -e "${CYAN}[CATEGORY]${NC} $1" | tee -a "$LOG_FILE"
}

# Print orchestrator banner
print_banner() {
    echo
    echo "=================================================================="
    echo "    DevOps Dashboard - Test Orchestration Framework"
    echo "=================================================================="
    echo "Comprehensive end-to-end testing and validation"
    echo "Environment: $ENVIRONMENT"
    echo "Parallel Execution: $PARALLEL_TESTS"
    echo "Continue on Failure: $CONTINUE_ON_FAILURE"
    echo "$(date)"
    echo "=================================================================="
    echo
}

# Setup test orchestration environment
setup_orchestration_environment() {
    log_info "Setting up test orchestration environment..."
    
    # Create directories
    mkdir -p "$RESULTS_DIR" "$REPORTS_DIR"
    mkdir -p "$RESULTS_DIR/suites" "$RESULTS_DIR/artifacts"
    
    # Initialize orchestration results
    cat > "$RESULTS_DIR/orchestration-run.json" << EOF
{
    "orchestration_run": {
        "id": "$(date +%Y%m%d_%H%M%S)",
        "started_at": "$(date -Iseconds)",
        "environment": "$ENVIRONMENT",
        "parallel_tests": $PARALLEL_TESTS,
        "continue_on_failure": $CONTINUE_ON_FAILURE,
        "test_suites": $(printf '%s\n' "${TEST_SUITES[@]}" | jq -R . | jq -s .)
    },
    "suite_results": {},
    "summary": {
        "total_suites": ${#TEST_SUITES[@]},
        "completed_suites": 0,
        "passed_suites": 0,
        "failed_suites": 0,
        "skipped_suites": 0
    }
}
EOF
    
    log_success "Test orchestration environment ready"
}

# Load environment configuration
load_environment_config() {
    log_info "Loading environment configuration..."
    
    # Load Terraform outputs
    if [[ -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]]; then
        cd "$PROJECT_ROOT/terraform"
        
        export APP_URL=$(terraform output -raw app_url 2>/dev/null || echo "")
        export BI_URL=$(terraform output -raw bi_url 2>/dev/null || echo "")
        export API_URL=$(terraform output -raw api_url 2>/dev/null || echo "")
        export MYSQL_ENDPOINT=$(terraform output -raw mysql_endpoint 2>/dev/null || echo "")
        export POSTGRES_ENDPOINT=$(terraform output -raw postgres_endpoint 2>/dev/null || echo "")
        export DOMAIN_NAME=$(terraform output -raw domain_name 2>/dev/null || echo "")
        
        # Set database connection details
        export MYSQL_HOST="$MYSQL_ENDPOINT"
        export POSTGRES_HOST="$POSTGRES_ENDPOINT"
        export MYSQL_USER="${MYSQL_USER:-devops_user}"
        export POSTGRES_USER="${POSTGRES_USER:-devops_user}"
        export MYSQL_PASSWORD="${MYSQL_PASSWORD:-secure_password}"
        export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-secure_password}"
        export MYSQL_DATABASE="${MYSQL_DATABASE:-devops_dashboard}"
        export POSTGRES_DATABASE="${POSTGRES_DATABASE:-devops_analytics}"
        
        log_success "Environment configuration loaded from Terraform"
    else
        log_warning "Terraform state not found. Using environment variables."
    fi
    
    # Validate required environment variables
    local required_vars=("APP_URL" "API_URL")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    log_info "Using URLs: APP=$APP_URL, API=$API_URL, BI=$BI_URL"
}

# Execute infrastructure tests
run_infrastructure_tests() {
    local suite_name="infrastructure"
    log_category "Running Infrastructure Tests"
    
    local start_time=$(date +%s)
    local result_file="$RESULTS_DIR/suites/infrastructure-results.csv"
    
    if [[ -x "$TESTS_ROOT/test-framework.sh" ]]; then
        if "$TESTS_ROOT/test-framework.sh" --category infrastructure > "$result_file" 2>&1; then
            TEST_SUITE_RESULTS[$suite_name]="PASS"
            log_success "Infrastructure tests completed successfully"
        else
            TEST_SUITE_RESULTS[$suite_name]="FAIL"
            log_error "Infrastructure tests failed"
        fi
    else
        TEST_SUITE_RESULTS[$suite_name]="SKIP"
        log_warning "Infrastructure test framework not found or not executable"
    fi
    
    local end_time=$(date +%s)
    TEST_SUITE_DURATIONS[$suite_name]=$((end_time - start_time))
    TEST_SUITE_DETAILS[$suite_name]="Infrastructure validation and Terraform state verification"
}

# Execute security tests
run_security_tests() {
    local suite_name="security"
    log_category "Running Security Tests"
    
    local start_time=$(date +%s)
    local result_file="$RESULTS_DIR/suites/security-results.json"
    
    if [[ -x "$TESTS_ROOT/security/security-scan.sh" ]]; then
        if "$TESTS_ROOT/security/security-scan.sh" --severity medium > "$result_file" 2>&1; then
            TEST_SUITE_RESULTS[$suite_name]="PASS"
            log_success "Security tests completed successfully"
        else
            TEST_SUITE_RESULTS[$suite_name]="FAIL"
            log_error "Security tests failed"
        fi
    else
        TEST_SUITE_RESULTS[$suite_name]="SKIP"
        log_warning "Security test framework not found or not executable"
    fi
    
    local end_time=$(date +%s)
    TEST_SUITE_DURATIONS[$suite_name]=$((end_time - start_time))
    TEST_SUITE_DETAILS[$suite_name]="Security configuration and compliance validation"
}

# Execute database tests
run_database_tests() {
    local suite_name="database"
    log_category "Running Database Tests"
    
    local start_time=$(date +%s)
    local result_file="$RESULTS_DIR/suites/database-results.json"
    
    if [[ -x "$TESTS_ROOT/database/database-tests.py" ]] && command -v python3 >/dev/null 2>&1; then
        # Install required Python packages
        python3 -m pip install -q asyncpg pymysql aiohttp 2>/dev/null || true
        
        if python3 "$TESTS_ROOT/database/database-tests.py" --output "$result_file"; then
            TEST_SUITE_RESULTS[$suite_name]="PASS"
            log_success "Database tests completed successfully"
        else
            TEST_SUITE_RESULTS[$suite_name]="FAIL"
            log_error "Database tests failed"
        fi
    else
        TEST_SUITE_RESULTS[$suite_name]="SKIP"
        log_warning "Database test framework not found or Python3 not available"
    fi
    
    local end_time=$(date +%s)
    TEST_SUITE_DURATIONS[$suite_name]=$((end_time - start_time))
    TEST_SUITE_DETAILS[$suite_name]="Database connectivity, integrity, and performance testing"
}

# Execute application tests
run_application_tests() {
    local suite_name="application"
    log_category "Running Application Tests"
    
    local start_time=$(date +%s)
    local result_file="$RESULTS_DIR/suites/application-results.csv"
    
    if [[ -x "$TESTS_ROOT/test-framework.sh" ]]; then
        if "$TESTS_ROOT/test-framework.sh" --category application > "$result_file" 2>&1; then
            TEST_SUITE_RESULTS[$suite_name]="PASS"
            log_success "Application tests completed successfully"
        else
            TEST_SUITE_RESULTS[$suite_name]="FAIL"
            log_error "Application tests failed"
        fi
    else
        TEST_SUITE_RESULTS[$suite_name]="SKIP"
        log_warning "Application test framework not found"
    fi
    
    local end_time=$(date +%s)
    TEST_SUITE_DURATIONS[$suite_name]=$((end_time - start_time))
    TEST_SUITE_DETAILS[$suite_name]="Application functionality and API endpoint testing"
}

# Execute BI tests
run_bi_tests() {
    local suite_name="bi"
    log_category "Running BI/Metabase Tests"
    
    local start_time=$(date +%s)
    local result_file="$RESULTS_DIR/suites/bi-results.json"
    
    if [[ -n "$BI_URL" && "$BI_URL" != "Not configured" ]]; then
        if [[ -x "$TESTS_ROOT/bi/metabase-tests.py" ]] && command -v python3 >/dev/null 2>&1; then
            # Install required Python packages
            python3 -m pip install -q aiohttp 2>/dev/null || true
            
            if python3 "$TESTS_ROOT/bi/metabase-tests.py" --url "$BI_URL" --output "$result_file"; then
                TEST_SUITE_RESULTS[$suite_name]="PASS"
                log_success "BI tests completed successfully"
            else
                TEST_SUITE_RESULTS[$suite_name]="FAIL"
                log_error "BI tests failed"
            fi
        else
            TEST_SUITE_RESULTS[$suite_name]="SKIP"
            log_warning "BI test framework not found or Python3 not available"
        fi
    else
        TEST_SUITE_RESULTS[$suite_name]="SKIP"
        log_warning "BI URL not configured"
    fi
    
    local end_time=$(date +%s)
    TEST_SUITE_DURATIONS[$suite_name]=$((end_time - start_time))
    TEST_SUITE_DETAILS[$suite_name]="Metabase functionality and dashboard testing"
}

# Execute performance tests
run_performance_tests() {
    local suite_name="performance"
    log_category "Running Performance Tests"
    
    local start_time=$(date +%s)
    local result_file="$RESULTS_DIR/suites/performance-results.json"
    
    if [[ -n "$APP_URL" ]]; then
        if [[ -x "$TESTS_ROOT/performance/load-test.py" ]] && command -v python3 >/dev/null 2>&1; then
            # Install required Python packages
            python3 -m pip install -q aiohttp 2>/dev/null || true
            
            if python3 "$TESTS_ROOT/performance/load-test.py" \
                --url "$APP_URL" \
                --users 5 \
                --duration 30 \
                --output "$result_file"; then
                TEST_SUITE_RESULTS[$suite_name]="PASS"
                log_success "Performance tests completed successfully"
            else
                TEST_SUITE_RESULTS[$suite_name]="FAIL"
                log_error "Performance tests failed"
            fi
        else
            TEST_SUITE_RESULTS[$suite_name]="SKIP"
            log_warning "Performance test framework not found or Python3 not available"
        fi
    else
        TEST_SUITE_RESULTS[$suite_name]="SKIP"
        log_warning "Application URL not configured"
    fi
    
    local end_time=$(date +%s)
    TEST_SUITE_DURATIONS[$suite_name]=$((end_time - start_time))
    TEST_SUITE_DETAILS[$suite_name]="Load testing and performance validation"
}

# Execute integration tests
run_integration_tests() {
    local suite_name="integration"
    log_category "Running Integration Tests"
    
    local start_time=$(date +%s)
    local result_file="$RESULTS_DIR/suites/integration-results.csv"
    
    if [[ -x "$TESTS_ROOT/test-framework.sh" ]]; then
        if "$TESTS_ROOT/test-framework.sh" --category integration > "$result_file" 2>&1; then
            TEST_SUITE_RESULTS[$suite_name]="PASS"
            log_success "Integration tests completed successfully"
        else
            TEST_SUITE_RESULTS[$suite_name]="FAIL"
            log_error "Integration tests failed"
        fi
    else
        TEST_SUITE_RESULTS[$suite_name]="SKIP"
        log_warning "Integration test framework not found"
    fi
    
    local end_time=$(date +%s)
    TEST_SUITE_DURATIONS[$suite_name]=$((end_time - start_time))
    TEST_SUITE_DETAILS[$suite_name]="End-to-end integration and workflow testing"
}

# Execute monitoring tests
run_monitoring_tests() {
    local suite_name="monitoring"
    log_category "Running Monitoring Tests"
    
    local start_time=$(date +%s)
    local result_file="$RESULTS_DIR/suites/monitoring-results.csv"
    
    if [[ -x "$TESTS_ROOT/test-framework.sh" ]]; then
        if "$TESTS_ROOT/test-framework.sh" --category monitoring > "$result_file" 2>&1; then
            TEST_SUITE_RESULTS[$suite_name]="PASS"
            log_success "Monitoring tests completed successfully"
        else
            TEST_SUITE_RESULTS[$suite_name]="FAIL"
            log_error "Monitoring tests failed"
        fi
    else
        TEST_SUITE_RESULTS[$suite_name]="SKIP"
        log_warning "Monitoring test framework not found"
    fi
    
    local end_time=$(date +%s)
    TEST_SUITE_DURATIONS[$suite_name]=$((end_time - start_time))
    TEST_SUITE_DETAILS[$suite_name]="Monitoring and alerting system validation"
}

# Execute all test suites
execute_test_suites() {
    log_info "Executing test suites..."
    
    if [[ "$PARALLEL_TESTS" == "true" ]]; then
        log_info "Running test suites in parallel..."
        
        # Run independent test suites in parallel
        (run_infrastructure_tests) &
        (run_security_tests) &
        wait
        
        # Check if we should continue
        if [[ "$CONTINUE_ON_FAILURE" == "false" ]]; then
            if [[ "${TEST_SUITE_RESULTS[infrastructure]}" == "FAIL" || "${TEST_SUITE_RESULTS[security]}" == "FAIL" ]]; then
                log_error "Critical test suites failed. Stopping execution."
                return 1
            fi
        fi
        
        # Run dependent test suites
        (run_database_tests) &
        (run_application_tests) &
        wait
        
        # Final test suites
        (run_bi_tests) &
        (run_performance_tests) &
        (run_integration_tests) &
        (run_monitoring_tests) &
        wait
        
    else
        log_info "Running test suites sequentially..."
        
        # Sequential execution with dependency checking
        run_infrastructure_tests
        if [[ "$CONTINUE_ON_FAILURE" == "false" && "${TEST_SUITE_RESULTS[infrastructure]}" == "FAIL" ]]; then
            log_error "Infrastructure tests failed. Stopping execution."
            return 1
        fi
        
        run_security_tests
        run_database_tests
        run_application_tests
        run_bi_tests
        run_performance_tests
        run_integration_tests
        run_monitoring_tests
    fi
    
    log_success "Test suite execution completed"
}

# Generate comprehensive test report
generate_comprehensive_report() {
    log_info "Generating comprehensive test report..."
    
    local report_file="$REPORTS_DIR/comprehensive-test-report-$(date +%Y%m%d_%H%M%S).html"
    local json_report="$REPORTS_DIR/comprehensive-test-report-$(date +%Y%m%d_%H%M%S).json"
    
    # Calculate summary statistics
    local total_suites=${#TEST_SUITES[@]}
    local passed_suites=0
    local failed_suites=0
    local skipped_suites=0
    local total_duration=0
    
    for suite in "${!TEST_SUITE_RESULTS[@]}"; do
        case "${TEST_SUITE_RESULTS[$suite]}" in
            "PASS") ((passed_suites++)) ;;
            "FAIL") ((failed_suites++)) ;;
            "SKIP") ((skipped_suites++)) ;;
        esac
        total_duration=$((total_duration + ${TEST_SUITE_DURATIONS[$suite]:-0}))
    done
    
    local success_rate=0
    if [[ $total_suites -gt 0 ]]; then
        success_rate=$(( passed_suites * 100 / total_suites ))
    fi
    
    # Create JSON report
    cat > "$json_report" << EOF
{
    "test_orchestration": {
        "id": "$(date +%Y%m%d_%H%M%S)",
        "timestamp": "$(date -Iseconds)",
        "environment": "$ENVIRONMENT",
        "total_duration_seconds": $total_duration
    },
    "summary": {
        "total_suites": $total_suites,
        "passed_suites": $passed_suites,
        "failed_suites": $failed_suites,
        "skipped_suites": $skipped_suites,
        "success_rate": $success_rate
    },
    "suite_results": $(echo '{}' | jq '. + $ARGS.named' \
        $(for suite in "${!TEST_SUITE_RESULTS[@]}"; do
            echo "--arg $suite ${TEST_SUITE_RESULTS[$suite]}"
        done)),
    "suite_durations": $(echo '{}' | jq '. + $ARGS.named' \
        $(for suite in "${!TEST_SUITE_DURATIONS[@]}"; do
            echo "--arg $suite ${TEST_SUITE_DURATIONS[$suite]}"
        done))
}
EOF
    
    # Create HTML report
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>DevOps Dashboard - Comprehensive Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; text-align: center; }
        .summary { background: white; padding: 25px; margin: 20px 0; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .suite-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 20px 0; }
        .suite-card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .suite-pass { border-left: 5px solid #27ae60; }
        .suite-fail { border-left: 5px solid #e74c3c; }
        .suite-skip { border-left: 5px solid #f39c12; }
        .progress-circle { width: 120px; height: 120px; border-radius: 50%; margin: 0 auto 20px; display: flex; align-items: center; justify-content: center; font-size: 24px; font-weight: bold; color: white; }
        .progress-excellent { background: linear-gradient(135deg, #27ae60, #2ecc71); }
        .progress-good { background: linear-gradient(135deg, #f39c12, #e67e22); }
        .progress-poor { background: linear-gradient(135deg, #e74c3c, #c0392b); }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; }
        .metric { text-align: center; padding: 15px; background: #ecf0f1; border-radius: 8px; }
        .metric-value { font-size: 24px; font-weight: bold; color: #2c3e50; }
        .metric-label { font-size: 12px; color: #7f8c8d; text-transform: uppercase; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 DevOps Dashboard Test Report</h1>
        <p>Comprehensive End-to-End Testing Results</p>
        <p>Generated: $(date) | Environment: $ENVIRONMENT</p>
    </div>
    
    <div class="summary">
        <div style="text-align: center;">
            <div class="progress-circle $(if [[ $success_rate -ge 80 ]]; then echo "progress-excellent"; elif [[ $success_rate -ge 60 ]]; then echo "progress-good"; else echo "progress-poor"; fi)">
                $success_rate%
            </div>
            <h2>Overall Success Rate</h2>
        </div>
        
        <div class="metrics">
            <div class="metric">
                <div class="metric-value">$total_suites</div>
                <div class="metric-label">Total Suites</div>
            </div>
            <div class="metric">
                <div class="metric-value">$passed_suites</div>
                <div class="metric-label">Passed</div>
            </div>
            <div class="metric">
                <div class="metric-value">$failed_suites</div>
                <div class="metric-label">Failed</div>
            </div>
            <div class="metric">
                <div class="metric-value">$skipped_suites</div>
                <div class="metric-label">Skipped</div>
            </div>
            <div class="metric">
                <div class="metric-value">$((total_duration / 60))m</div>
                <div class="metric-label">Duration</div>
            </div>
        </div>
    </div>
    
    <div class="suite-grid">
EOF
    
    # Add suite cards
    for suite in "${!TEST_SUITE_RESULTS[@]}"; do
        local status="${TEST_SUITE_RESULTS[$suite]}"
        local duration="${TEST_SUITE_DURATIONS[$suite]:-0}"
        local details="${TEST_SUITE_DETAILS[$suite]:-No details available}"
        local css_class=""
        local icon=""
        
        case "$status" in
            "PASS") css_class="suite-pass"; icon="✅" ;;
            "FAIL") css_class="suite-fail"; icon="❌" ;;
            "SKIP") css_class="suite-skip"; icon="⏭️" ;;
        esac
        
        cat >> "$report_file" << EOF
        <div class="suite-card $css_class">
            <h3>$icon $(echo "$suite" | tr '[:lower:]' '[:upper:]') Tests</h3>
            <p><strong>Status:</strong> $status</p>
            <p><strong>Duration:</strong> ${duration}s</p>
            <p><strong>Description:</strong> $details</p>
        </div>
EOF
    done
    
    cat >> "$report_file" << EOF
    </div>
    
    <div class="summary">
        <h2>🎯 Test Execution Summary</h2>
        <ul>
EOF

    for suite in "${!TEST_SUITE_RESULTS[@]}"; do
        local status="${TEST_SUITE_RESULTS[$suite]}"
        local icon=""
        
        case "$status" in
            "PASS") icon="✅" ;;
            "FAIL") icon="❌" ;;
            "SKIP") icon="⏭️" ;;
        esac
        
        cat >> "$report_file" << EOF
            <li>$icon <strong>$(echo "$suite" | tr '[:lower:]' '[:upper:]')</strong>: $status (${TEST_SUITE_DURATIONS[$suite]:-0}s)</li>
EOF
    done
    
    cat >> "$report_file" << EOF
        </ul>
        
        <h3>📊 Recommendations</h3>
EOF
    
    if [[ $success_rate -ge 90 ]]; then
        cat >> "$report_file" << EOF
        <p style="color: #27ae60;">🎉 <strong>Excellent!</strong> Your DevOps Dashboard is production-ready with outstanding test results.</p>
EOF
    elif [[ $success_rate -ge 75 ]]; then
        cat >> "$report_file" << EOF
        <p style="color: #f39c12;">⚠️ <strong>Good</strong> test results with some areas for improvement. Address failed tests before production deployment.</p>
EOF
    else
        cat >> "$report_file" << EOF
        <p style="color: #e74c3c;">❌ <strong>Critical issues detected.</strong> Multiple test failures require attention before production deployment.</p>
EOF
    fi
    
    cat >> "$report_file" << EOF
    </div>
</body>
</html>
EOF
    
    log_success "Comprehensive test report generated:"
    log_info "  HTML Report: $report_file"
    log_info "  JSON Report: $json_report"
    
    return $success_rate
}

# Show final summary
show_final_summary() {
    echo
    echo "=================================================================="
    echo "             TEST ORCHESTRATION SUMMARY"
    echo "=================================================================="
    echo
    echo "🎯 Test Suite Results:"
    
    for suite in "${!TEST_SUITE_RESULTS[@]}"; do
        local status="${TEST_SUITE_RESULTS[$suite]}"
        local duration="${TEST_SUITE_DURATIONS[$suite]:-0}"
        local icon=""
        
        case "$status" in
            "PASS") icon="✅" ;;
            "FAIL") icon="❌" ;;
            "SKIP") icon="⏭️" ;;
        esac
        
        printf "   %-15s %s %s (%ds)\n" "$(echo "$suite" | tr '[:lower:]' '[:upper:]'):" "$icon" "$status" "$duration"
    done
    
    echo
    echo "📊 Summary:"
    local total_suites=${#TEST_SUITE_RESULTS[@]}
    local passed_suites=0
    local failed_suites=0
    local skipped_suites=0
    
    for suite in "${!TEST_SUITE_RESULTS[@]}"; do
        case "${TEST_SUITE_RESULTS[$suite]}" in
            "PASS") ((passed_suites++)) ;;
            "FAIL") ((failed_suites++)) ;;
            "SKIP") ((skipped_suites++)) ;;
        esac
    done
    
    echo "   Total Suites:    $total_suites"
    echo "   Passed:          $passed_suites"
    echo "   Failed:          $failed_suites"
    echo "   Skipped:         $skipped_suites"
    echo "   Success Rate:    $(( passed_suites * 100 / total_suites ))%"
    echo
    
    if [[ $failed_suites -eq 0 ]]; then
        echo "🎉 All test suites completed successfully!"
        echo "   Your DevOps Dashboard is ready for demonstration."
    elif [[ $failed_suites -le 2 ]]; then
        echo "⚠️  Most test suites passed with $failed_suites failure(s)."
        echo "   Review failed tests and consider if they impact demonstration."
    else
        echo "❌ Multiple test suite failures detected ($failed_suites)."
        echo "   Please review and fix issues before demonstration."
    fi
    
    echo
    echo "📁 Generated Files:"
    echo "   Test Results: $RESULTS_DIR/"
    echo "   Test Reports: $REPORTS_DIR/"
    echo "   Logs:         $LOG_FILE"
    echo
    echo "=================================================================="
}

# Cleanup test artifacts
cleanup_test_artifacts() {
    if [[ "$CLEANUP_AFTER_TESTS" == "true" ]]; then
        log_info "Cleaning up test artifacts..."
        
        # Clean up temporary files but keep results and reports
        find /tmp -name "*test*" -mtime +1 -delete 2>/dev/null || true
        
        log_success "Test artifacts cleaned up"
    fi
}

# Main orchestration function
main() {
    local selected_suites=()
    local skip_setup=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --suite)
                selected_suites+=("$2")
                shift 2
                ;;
            --parallel)
                PARALLEL_TESTS="$2"
                shift 2
                ;;
            --continue-on-failure)
                CONTINUE_ON_FAILURE="$2"
                shift 2
                ;;
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --skip-setup)
                skip_setup=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --suite SUITE              Run specific test suite"
                echo "  --parallel true|false      Enable/disable parallel execution"
                echo "  --continue-on-failure      Continue execution on test failures"
                echo "  --environment ENV          Set environment (dev|staging|prod)"
                echo "  --skip-setup              Skip environment setup"
                echo "  --help                     Show this help message"
                echo
                echo "Available test suites:"
                echo "  infrastructure, security, database, application, bi, performance, integration, monitoring"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Setup
    print_banner
    setup_orchestration_environment
    
    if [[ "$skip_setup" == false ]]; then
        load_environment_config || exit 1
    fi
    
    # Execute test suites
    if [[ ${#selected_suites[@]} -gt 0 ]]; then
        log_info "Running selected test suites: ${selected_suites[*]}"
        
        for suite in "${selected_suites[@]}"; do
            case "$suite" in
                infrastructure) run_infrastructure_tests ;;
                security) run_security_tests ;;
                database) run_database_tests ;;
                application) run_application_tests ;;
                bi) run_bi_tests ;;
                performance) run_performance_tests ;;
                integration) run_integration_tests ;;
                monitoring) run_monitoring_tests ;;
                *)
                    log_warning "Unknown test suite: $suite"
                    ;;
            esac
        done
    else
        log_info "Running all test suites..."
        execute_test_suites
    fi
    
    # Generate comprehensive report
    local success_rate
    success_rate=$(generate_comprehensive_report)
    
    # Show summary
    show_final_summary
    
    # Cleanup
    cleanup_test_artifacts
    
    # Exit with appropriate code
    local failed_suites=0
    for suite in "${!TEST_SUITE_RESULTS[@]}"; do
        if [[ "${TEST_SUITE_RESULTS[$suite]}" == "FAIL" ]]; then
            ((failed_suites++))
        fi
    done
    
    if [[ $failed_suites -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Handle script interruption
trap 'log_error "Test orchestration interrupted"; exit 1' INT TERM

# Run main function
main "$@"

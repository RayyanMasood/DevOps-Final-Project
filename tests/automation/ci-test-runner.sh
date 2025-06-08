#!/bin/bash

# CI/CD Test Runner for DevOps Dashboard
# Automated testing pipeline for continuous integration

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$TESTS_ROOT")"

# CI/CD Configuration
CI_ENVIRONMENT="${CI_ENVIRONMENT:-pipeline}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d_%H%M%S)}"
BRANCH_NAME="${BRANCH_NAME:-main}"
COMMIT_SHA="${COMMIT_SHA:-unknown}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
EMAIL_NOTIFICATIONS="${EMAIL_NOTIFICATIONS:-false}"

# Test Configuration
PARALLEL_EXECUTION="${PARALLEL_EXECUTION:-true}"
CONTINUE_ON_FAILURE="${CONTINUE_ON_FAILURE:-false}"
PERFORMANCE_TESTS="${PERFORMANCE_TESTS:-true}"
SECURITY_TESTS="${SECURITY_TESTS:-true}"
INTEGRATION_TESTS="${INTEGRATION_TESTS:-true}"

# Artifact Configuration
ARTIFACTS_DIR="$TESTS_ROOT/artifacts/build-$BUILD_NUMBER"
REPORTS_BUCKET="${REPORTS_BUCKET:-}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Pipeline tracking
PIPELINE_START_TIME=""
PIPELINE_END_TIME=""
PIPELINE_STATUS="UNKNOWN"
FAILED_STAGES=()
PASSED_STAGES=()

# Logging functions
log_info() {
    echo -e "${BLUE}[CI-INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[CI-SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[CI-WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[CI-ERROR]${NC} $1"
}

log_stage() {
    echo -e "${CYAN}[CI-STAGE]${NC} $1"
}

# Print CI banner
print_ci_banner() {
    echo
    echo "=================================================================="
    echo "    DevOps Dashboard - CI/CD Test Pipeline"
    echo "=================================================================="
    echo "Build Number:     $BUILD_NUMBER"
    echo "Branch:           $BRANCH_NAME"
    echo "Commit:           $COMMIT_SHA"
    echo "Environment:      $CI_ENVIRONMENT"
    echo "Parallel Tests:   $PARALLEL_EXECUTION"
    echo "$(date)"
    echo "=================================================================="
    echo
}

# Setup CI environment
setup_ci_environment() {
    log_stage "Setting up CI environment"
    
    # Create artifacts directory
    mkdir -p "$ARTIFACTS_DIR"
    mkdir -p "$ARTIFACTS_DIR/reports"
    mkdir -p "$ARTIFACTS_DIR/logs"
    mkdir -p "$ARTIFACTS_DIR/test-results"
    
    # Initialize pipeline metadata
    cat > "$ARTIFACTS_DIR/pipeline-metadata.json" << EOF
{
    "pipeline": {
        "build_number": "$BUILD_NUMBER",
        "branch": "$BRANCH_NAME",
        "commit_sha": "$COMMIT_SHA",
        "environment": "$CI_ENVIRONMENT",
        "started_at": "$(date -Iseconds)",
        "parallel_execution": $PARALLEL_EXECUTION,
        "performance_tests": $PERFORMANCE_TESTS,
        "security_tests": $SECURITY_TESTS,
        "integration_tests": $INTEGRATION_TESTS
    },
    "stages": {}
}
EOF
    
    # Set up environment variables for tests
    export ENVIRONMENT="$CI_ENVIRONMENT"
    export PARALLEL_TESTS="$PARALLEL_EXECUTION"
    export CONTINUE_ON_FAILURE="$CONTINUE_ON_FAILURE"
    
    log_success "CI environment setup complete"
}

# Install test dependencies
install_dependencies() {
    log_stage "Installing test dependencies"
    
    # Check and install required tools
    local dependencies=("curl" "jq" "aws" "python3" "pip3")
    local missing_deps=()
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warning "Missing dependencies: ${missing_deps[*]}"
        
        # Install missing dependencies (Ubuntu/Debian)
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update -qq
            for dep in "${missing_deps[@]}"; do
                case "$dep" in
                    aws) pip3 install awscli ;;
                    pip3) sudo apt-get install -y python3-pip ;;
                    *) sudo apt-get install -y "$dep" ;;
                esac
            done
        fi
    fi
    
    # Install Python dependencies
    python3 -m pip install -q --upgrade pip
    python3 -m pip install -q asyncpg pymysql aiohttp boto3
    
    log_success "Dependencies installed"
}

# Run pre-deployment validation
run_pre_deployment_validation() {
    log_stage "Pre-deployment validation"
    
    local validation_file="$ARTIFACTS_DIR/pre-deployment-validation.json"
    local start_time=$(date +%s)
    
    # Check Terraform configuration
    cd "$PROJECT_ROOT/terraform"
    
    if terraform validate > "$ARTIFACTS_DIR/logs/terraform-validate.log" 2>&1; then
        log_success "Terraform configuration is valid"
    else
        log_error "Terraform validation failed"
        FAILED_STAGES+=("pre-deployment")
        return 1
    fi
    
    # Check Terraform plan
    if terraform plan -out="$ARTIFACTS_DIR/terraform.plan" > "$ARTIFACTS_DIR/logs/terraform-plan.log" 2>&1; then
        log_success "Terraform plan completed successfully"
    else
        log_error "Terraform plan failed"
        FAILED_STAGES+=("pre-deployment")
        return 1
    fi
    
    # Validate application configuration
    if [[ -f "$PROJECT_ROOT/application/docker-compose.yml" ]]; then
        cd "$PROJECT_ROOT/application"
        if docker-compose config > "$ARTIFACTS_DIR/logs/docker-compose-validate.log" 2>&1; then
            log_success "Docker Compose configuration is valid"
        else
            log_warning "Docker Compose validation issues detected"
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Record validation results
    cat > "$validation_file" << EOF
{
    "pre_deployment_validation": {
        "status": "PASSED",
        "duration_seconds": $duration,
        "terraform_valid": true,
        "docker_compose_valid": true,
        "timestamp": "$(date -Iseconds)"
    }
}
EOF
    
    PASSED_STAGES+=("pre-deployment")
    log_success "Pre-deployment validation completed"
}

# Run infrastructure tests
run_infrastructure_tests() {
    log_stage "Running infrastructure tests"
    
    local start_time=$(date +%s)
    local log_file="$ARTIFACTS_DIR/logs/infrastructure-tests.log"
    local results_file="$ARTIFACTS_DIR/test-results/infrastructure-results.csv"
    
    if "$TESTS_ROOT/test-framework.sh" --category infrastructure > "$log_file" 2>&1; then
        cp "$TESTS_ROOT/results/test-results.csv" "$results_file" 2>/dev/null || true
        log_success "Infrastructure tests passed"
        PASSED_STAGES+=("infrastructure")
    else
        log_error "Infrastructure tests failed"
        FAILED_STAGES+=("infrastructure")
        
        if [[ "$CONTINUE_ON_FAILURE" == "false" ]]; then
            return 1
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Update pipeline metadata
    jq ".stages.infrastructure = {\"status\": \"$(if [[ " ${FAILED_STAGES[*]} " =~ " infrastructure " ]]; then echo "FAILED"; else echo "PASSED"; fi)\", \"duration\": $duration}" \
       "$ARTIFACTS_DIR/pipeline-metadata.json" > "$ARTIFACTS_DIR/pipeline-metadata.tmp" && \
       mv "$ARTIFACTS_DIR/pipeline-metadata.tmp" "$ARTIFACTS_DIR/pipeline-metadata.json"
}

# Run security tests
run_security_tests() {
    if [[ "$SECURITY_TESTS" == "false" ]]; then
        log_warning "Security tests disabled"
        return 0
    fi
    
    log_stage "Running security tests"
    
    local start_time=$(date +%s)
    local log_file="$ARTIFACTS_DIR/logs/security-tests.log"
    local results_file="$ARTIFACTS_DIR/test-results/security-results.json"
    
    if "$TESTS_ROOT/security/security-scan.sh" > "$log_file" 2>&1; then
        cp "$TESTS_ROOT/security/results/"*.json "$ARTIFACTS_DIR/test-results/" 2>/dev/null || true
        log_success "Security tests passed"
        PASSED_STAGES+=("security")
    else
        log_error "Security tests failed"
        FAILED_STAGES+=("security")
        
        if [[ "$CONTINUE_ON_FAILURE" == "false" ]]; then
            return 1
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Update pipeline metadata
    jq ".stages.security = {\"status\": \"$(if [[ " ${FAILED_STAGES[*]} " =~ " security " ]]; then echo "FAILED"; else echo "PASSED"; fi)\", \"duration\": $duration}" \
       "$ARTIFACTS_DIR/pipeline-metadata.json" > "$ARTIFACTS_DIR/pipeline-metadata.tmp" && \
       mv "$ARTIFACTS_DIR/pipeline-metadata.tmp" "$ARTIFACTS_DIR/pipeline-metadata.json"
}

# Run database tests
run_database_tests() {
    log_stage "Running database tests"
    
    local start_time=$(date +%s)
    local log_file="$ARTIFACTS_DIR/logs/database-tests.log"
    local results_file="$ARTIFACTS_DIR/test-results/database-results.json"
    
    if python3 "$TESTS_ROOT/database/database-tests.py" --output "$results_file" > "$log_file" 2>&1; then
        log_success "Database tests passed"
        PASSED_STAGES+=("database")
    else
        log_error "Database tests failed"
        FAILED_STAGES+=("database")
        
        if [[ "$CONTINUE_ON_FAILURE" == "false" ]]; then
            return 1
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Update pipeline metadata
    jq ".stages.database = {\"status\": \"$(if [[ " ${FAILED_STAGES[*]} " =~ " database " ]]; then echo "FAILED"; else echo "PASSED"; fi)\", \"duration\": $duration}" \
       "$ARTIFACTS_DIR/pipeline-metadata.json" > "$ARTIFACTS_DIR/pipeline-metadata.tmp" && \
       mv "$ARTIFACTS_DIR/pipeline-metadata.tmp" "$ARTIFACTS_DIR/pipeline-metadata.json"
}

# Run application tests
run_application_tests() {
    log_stage "Running application tests"
    
    local start_time=$(date +%s)
    local log_file="$ARTIFACTS_DIR/logs/application-tests.log"
    local results_file="$ARTIFACTS_DIR/test-results/application-results.csv"
    
    if "$TESTS_ROOT/test-framework.sh" --category application > "$log_file" 2>&1; then
        cp "$TESTS_ROOT/results/test-results.csv" "$results_file" 2>/dev/null || true
        log_success "Application tests passed"
        PASSED_STAGES+=("application")
    else
        log_error "Application tests failed"
        FAILED_STAGES+=("application")
        
        if [[ "$CONTINUE_ON_FAILURE" == "false" ]]; then
            return 1
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Update pipeline metadata
    jq ".stages.application = {\"status\": \"$(if [[ " ${FAILED_STAGES[*]} " =~ " application " ]]; then echo "FAILED"; else echo "PASSED"; fi)\", \"duration\": $duration}" \
       "$ARTIFACTS_DIR/pipeline-metadata.json" > "$ARTIFACTS_DIR/pipeline-metadata.tmp" && \
       mv "$ARTIFACTS_DIR/pipeline-metadata.tmp" "$ARTIFACTS_DIR/pipeline-metadata.json"
}

# Run performance tests
run_performance_tests() {
    if [[ "$PERFORMANCE_TESTS" == "false" ]]; then
        log_warning "Performance tests disabled"
        return 0
    fi
    
    log_stage "Running performance tests"
    
    local start_time=$(date +%s)
    local log_file="$ARTIFACTS_DIR/logs/performance-tests.log"
    local results_file="$ARTIFACTS_DIR/test-results/performance-results.json"
    
    # Get application URL
    local app_url="${APP_URL:-}"
    if [[ -z "$app_url" && -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]]; then
        cd "$PROJECT_ROOT/terraform"
        app_url=$(terraform output -raw app_url 2>/dev/null || echo "")
    fi
    
    if [[ -n "$app_url" ]]; then
        if python3 "$TESTS_ROOT/performance/load-test.py" \
            --url "$app_url" \
            --users 10 \
            --duration 60 \
            --output "$results_file" > "$log_file" 2>&1; then
            log_success "Performance tests passed"
            PASSED_STAGES+=("performance")
        else
            log_error "Performance tests failed"
            FAILED_STAGES+=("performance")
        fi
    else
        log_warning "Application URL not available, skipping performance tests"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Update pipeline metadata
    jq ".stages.performance = {\"status\": \"$(if [[ " ${FAILED_STAGES[*]} " =~ " performance " ]]; then echo "FAILED"; else echo "PASSED"; fi)\", \"duration\": $duration}" \
       "$ARTIFACTS_DIR/pipeline-metadata.json" > "$ARTIFACTS_DIR/pipeline-metadata.tmp" && \
       mv "$ARTIFACTS_DIR/pipeline-metadata.tmp" "$ARTIFACTS_DIR/pipeline-metadata.json"
}

# Run integration tests
run_integration_tests() {
    if [[ "$INTEGRATION_TESTS" == "false" ]]; then
        log_warning "Integration tests disabled"
        return 0
    fi
    
    log_stage "Running integration tests"
    
    local start_time=$(date +%s)
    local log_file="$ARTIFACTS_DIR/logs/integration-tests.log"
    local results_file="$ARTIFACTS_DIR/test-results/integration-results.csv"
    
    if "$TESTS_ROOT/integration/test-orchestrator.sh" --environment "$CI_ENVIRONMENT" > "$log_file" 2>&1; then
        cp "$TESTS_ROOT/results/"*.csv "$ARTIFACTS_DIR/test-results/" 2>/dev/null || true
        cp "$TESTS_ROOT/reports/"*.html "$ARTIFACTS_DIR/reports/" 2>/dev/null || true
        log_success "Integration tests passed"
        PASSED_STAGES+=("integration")
    else
        log_error "Integration tests failed"
        FAILED_STAGES+=("integration")
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Update pipeline metadata
    jq ".stages.integration = {\"status\": \"$(if [[ " ${FAILED_STAGES[*]} " =~ " integration " ]]; then echo "FAILED"; else echo "PASSED"; fi)\", \"duration\": $duration}" \
       "$ARTIFACTS_DIR/pipeline-metadata.json" > "$ARTIFACTS_DIR/pipeline-metadata.tmp" && \
       mv "$ARTIFACTS_DIR/pipeline-metadata.tmp" "$ARTIFACTS_DIR/pipeline-metadata.json"
}

# Upload artifacts to S3
upload_artifacts() {
    if [[ -n "$REPORTS_BUCKET" ]]; then
        log_stage "Uploading artifacts to S3"
        
        local s3_path="s3://$REPORTS_BUCKET/ci-reports/$BUILD_NUMBER/"
        
        if aws s3 sync "$ARTIFACTS_DIR" "$s3_path" --quiet; then
            log_success "Artifacts uploaded to $s3_path"
            
            # Set up lifecycle policy for cleanup
            if [[ -n "$RETENTION_DAYS" ]]; then
                aws s3api put-object-lifecycle-configuration \
                    --bucket "$REPORTS_BUCKET" \
                    --lifecycle-configuration file://<(cat << EOF
{
    "Rules": [
        {
            "ID": "CI-Report-Cleanup",
            "Status": "Enabled",
            "Filter": {"Prefix": "ci-reports/"},
            "Expiration": {"Days": $RETENTION_DAYS}
        }
    ]
}
EOF
) 2>/dev/null || log_warning "Could not set lifecycle policy"
            fi
        else
            log_warning "Failed to upload artifacts to S3"
        fi
    fi
}

# Send notifications
send_notifications() {
    local pipeline_status="$1"
    local pipeline_duration="$2"
    
    # Slack notification
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        log_info "Sending Slack notification"
        
        local color=""
        local emoji=""
        case "$pipeline_status" in
            "SUCCESS") color="good"; emoji=":white_check_mark:" ;;
            "FAILURE") color="danger"; emoji=":x:" ;;
            "PARTIAL") color="warning"; emoji=":warning:" ;;
        esac
        
        local slack_payload=$(cat << EOF
{
    "attachments": [
        {
            "color": "$color",
            "fields": [
                {
                    "title": "Pipeline Status",
                    "value": "$emoji $pipeline_status",
                    "short": true
                },
                {
                    "title": "Build Number",
                    "value": "$BUILD_NUMBER",
                    "short": true
                },
                {
                    "title": "Branch",
                    "value": "$BRANCH_NAME",
                    "short": true
                },
                {
                    "title": "Duration",
                    "value": "${pipeline_duration}s",
                    "short": true
                },
                {
                    "title": "Passed Stages",
                    "value": "${PASSED_STAGES[*]}",
                    "short": false
                },
                {
                    "title": "Failed Stages",
                    "value": "${FAILED_STAGES[*]:-None}",
                    "short": false
                }
            ]
        }
    ]
}
EOF
)
        
        curl -X POST -H 'Content-type: application/json' \
             --data "$slack_payload" \
             "$SLACK_WEBHOOK_URL" >/dev/null 2>&1 || log_warning "Failed to send Slack notification"
    fi
    
    # Email notification (if configured)
    if [[ "$EMAIL_NOTIFICATIONS" == "true" && -n "${EMAIL_RECIPIENTS:-}" ]]; then
        log_info "Sending email notification"
        
        local subject="DevOps Dashboard CI/CD Pipeline - $pipeline_status (Build #$BUILD_NUMBER)"
        local body="Pipeline completed with status: $pipeline_status\n\nBuild: $BUILD_NUMBER\nBranch: $BRANCH_NAME\nDuration: ${pipeline_duration}s\n\nPassed: ${PASSED_STAGES[*]}\nFailed: ${FAILED_STAGES[*]:-None}"
        
        echo -e "$body" | aws ses send-email \
            --source "${EMAIL_FROM:-devops@example.com}" \
            --destination "ToAddresses=$EMAIL_RECIPIENTS" \
            --message "Subject={Data='$subject'},Body={Text={Data='$body'}}" \
            >/dev/null 2>&1 || log_warning "Failed to send email notification"
    fi
}

# Generate CI report
generate_ci_report() {
    log_stage "Generating CI report"
    
    local report_file="$ARTIFACTS_DIR/reports/ci-pipeline-report.html"
    local total_stages=$((${#PASSED_STAGES[@]} + ${#FAILED_STAGES[@]}))
    local success_rate=0
    
    if [[ $total_stages -gt 0 ]]; then
        success_rate=$(( ${#PASSED_STAGES[@]} * 100 / total_stages ))
    fi
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>CI/CD Pipeline Report - Build #$BUILD_NUMBER</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f8f9fa; }
        .header { background: linear-gradient(135deg, #007bff, #6610f2); color: white; padding: 30px; border-radius: 10px; text-align: center; }
        .summary { background: white; padding: 20px; margin: 20px 0; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .stage-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 15px; margin: 20px 0; }
        .stage-card { background: white; padding: 15px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .stage-pass { border-left: 5px solid #28a745; }
        .stage-fail { border-left: 5px solid #dc3545; }
        .badge { padding: 5px 10px; border-radius: 15px; color: white; font-weight: bold; }
        .badge-success { background: #28a745; }
        .badge-danger { background: #dc3545; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 15px; }
        .metric { text-align: center; padding: 15px; background: #e9ecef; border-radius: 8px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 CI/CD Pipeline Report</h1>
        <p>Build #$BUILD_NUMBER | Branch: $BRANCH_NAME</p>
        <p>$(date)</p>
    </div>
    
    <div class="summary">
        <h2>📊 Pipeline Summary</h2>
        <div class="metrics">
            <div class="metric">
                <h3>$total_stages</h3>
                <p>Total Stages</p>
            </div>
            <div class="metric">
                <h3>${#PASSED_STAGES[@]}</h3>
                <p>Passed</p>
            </div>
            <div class="metric">
                <h3>${#FAILED_STAGES[@]}</h3>
                <p>Failed</p>
            </div>
            <div class="metric">
                <h3>$success_rate%</h3>
                <p>Success Rate</p>
            </div>
        </div>
    </div>
    
    <div class="summary">
        <h2>📋 Stage Results</h2>
        <div class="stage-grid">
EOF
    
    # Add passed stages
    for stage in "${PASSED_STAGES[@]}"; do
        cat >> "$report_file" << EOF
            <div class="stage-card stage-pass">
                <h4>$(echo "$stage" | tr '[:lower:]' '[:upper:]')</h4>
                <span class="badge badge-success">PASSED</span>
            </div>
EOF
    done
    
    # Add failed stages
    for stage in "${FAILED_STAGES[@]}"; do
        cat >> "$report_file" << EOF
            <div class="stage-card stage-fail">
                <h4>$(echo "$stage" | tr '[:lower:]' '[:upper:]')</h4>
                <span class="badge badge-danger">FAILED</span>
            </div>
EOF
    done
    
    cat >> "$report_file" << EOF
        </div>
    </div>
</body>
</html>
EOF
    
    log_success "CI report generated: $report_file"
}

# Main CI pipeline function
main() {
    PIPELINE_START_TIME=$(date +%s)
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --build-number)
                BUILD_NUMBER="$2"
                shift 2
                ;;
            --branch)
                BRANCH_NAME="$2"
                shift 2
                ;;
            --commit)
                COMMIT_SHA="$2"
                shift 2
                ;;
            --skip-performance)
                PERFORMANCE_TESTS="false"
                shift
                ;;
            --skip-security)
                SECURITY_TESTS="false"
                shift
                ;;
            --skip-integration)
                INTEGRATION_TESTS="false"
                shift
                ;;
            --reports-bucket)
                REPORTS_BUCKET="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --build-number NUM       Set build number"
                echo "  --branch NAME           Set branch name"
                echo "  --commit SHA            Set commit SHA"
                echo "  --skip-performance      Skip performance tests"
                echo "  --skip-security         Skip security tests"
                echo "  --skip-integration      Skip integration tests"
                echo "  --reports-bucket NAME   S3 bucket for reports"
                echo "  --help                  Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Pipeline execution
    print_ci_banner
    setup_ci_environment
    install_dependencies
    
    # Run pipeline stages
    run_pre_deployment_validation
    
    if [[ "$PARALLEL_EXECUTION" == "true" ]]; then
        # Run independent tests in parallel
        run_infrastructure_tests &
        run_security_tests &
        run_database_tests &
        wait
        
        # Run dependent tests
        run_application_tests &
        run_performance_tests &
        wait
        
        # Final integration tests
        run_integration_tests
    else
        # Sequential execution
        run_infrastructure_tests
        run_security_tests
        run_database_tests
        run_application_tests
        run_performance_tests
        run_integration_tests
    fi
    
    PIPELINE_END_TIME=$(date +%s)
    local pipeline_duration=$((PIPELINE_END_TIME - PIPELINE_START_TIME))
    
    # Determine overall pipeline status
    if [[ ${#FAILED_STAGES[@]} -eq 0 ]]; then
        PIPELINE_STATUS="SUCCESS"
    elif [[ ${#PASSED_STAGES[@]} -gt ${#FAILED_STAGES[@]} ]]; then
        PIPELINE_STATUS="PARTIAL"
    else
        PIPELINE_STATUS="FAILURE"
    fi
    
    # Generate reports and artifacts
    generate_ci_report
    upload_artifacts
    send_notifications "$PIPELINE_STATUS" "$pipeline_duration"
    
    # Show final status
    echo
    echo "=================================================================="
    echo "                CI/CD PIPELINE SUMMARY"
    echo "=================================================================="
    echo "Build Number:     $BUILD_NUMBER"
    echo "Status:           $PIPELINE_STATUS"
    echo "Duration:         ${pipeline_duration}s"
    echo "Passed Stages:    ${PASSED_STAGES[*]}"
    echo "Failed Stages:    ${FAILED_STAGES[*]:-None}"
    echo "Artifacts:        $ARTIFACTS_DIR"
    echo "=================================================================="
    
    # Exit with appropriate code
    case "$PIPELINE_STATUS" in
        "SUCCESS") exit 0 ;;
        "PARTIAL") exit 2 ;;
        "FAILURE") exit 1 ;;
    esac
}

# Handle script interruption
trap 'log_error "CI pipeline interrupted"; exit 1' INT TERM

# Run main function
main "$@"

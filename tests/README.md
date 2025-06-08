# DevOps Dashboard - End-to-End Testing Framework

A comprehensive testing and validation framework for the DevOps Dashboard infrastructure and applications.

## 🎯 Overview

This testing framework provides complete end-to-end validation of:
- Infrastructure components (Terraform, AWS resources)
- Database connectivity and integrity (MySQL, PostgreSQL)
- Application functionality (Backend API, Frontend)
- BI tool integration (Metabase)
- Security configuration and compliance
- Performance and load testing
- Monitoring and alerting systems
- Integration workflows

## 📁 Framework Structure

```
tests/
├── README.md                          # This file
├── config/
│   └── test-config.yaml              # Comprehensive test configuration
├── automation/
│   └── ci-test-runner.sh             # CI/CD pipeline automation
├── integration/
│   └── test-orchestrator.sh          # Main test orchestration
├── database/
│   └── database-tests.py             # Database testing suite
├── bi/
│   └── metabase-tests.py             # Metabase/BI testing
├── performance/
│   └── load-test.py                  # Performance and load testing
├── security/
│   └── security-scan.sh              # Security validation
├── monitoring/
│   └── monitoring-tests.sh           # Monitoring system validation
├── test-framework.sh                 # Main testing framework
├── results/                          # Test results (generated)
├── reports/                          # HTML/JSON reports (generated)
└── artifacts/                        # CI/CD artifacts (generated)
```

## 🚀 Quick Start

### Prerequisites

1. **Infrastructure Deployed**: Ensure your Terraform infrastructure is deployed
2. **AWS CLI Configured**: AWS credentials and region set
3. **Required Tools**: Install dependencies
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install -y curl jq python3 python3-pip
   
   # Install Python dependencies
   pip3 install asyncpg pymysql aiohttp boto3
   ```

### Basic Usage

1. **Run All Tests**:
   ```bash
   cd /workspace/tests
   ./test-framework.sh
   ```

2. **Run Specific Test Categories**:
   ```bash
   # Infrastructure tests only
   ./test-framework.sh --category infrastructure
   
   # Database and application tests
   ./test-framework.sh --category database --category application
   ```

3. **Run Complete Integration Suite**:
   ```bash
   ./integration/test-orchestrator.sh
   ```

## 📊 Test Categories

### 1. Infrastructure Tests
**File**: `test-framework.sh --category infrastructure`

Tests AWS infrastructure components:
- VPC and subnet configuration
- Auto Scaling Groups and EC2 instances
- RDS database instances
- Application Load Balancer
- Security groups and network ACLs

### 2. Database Tests
**File**: `database/database-tests.py`

Validates database functionality:
- MySQL and PostgreSQL connectivity
- Schema integrity and validation
- Query performance testing
- Connection pooling and concurrent access
- Cross-database data consistency

**Usage**:
```bash
python3 database/database-tests.py --output results/database-results.json
```

### 3. Application Tests
**File**: `test-framework.sh --category application`

Tests application functionality:
- API endpoint availability
- Health check endpoints
- Data retrieval and processing
- Response time validation
- Error handling

### 4. BI Tool Tests
**File**: `bi/metabase-tests.py`

Validates Metabase functionality:
- Service availability and authentication
- Database connections
- Dashboard accessibility
- Query execution
- User management and permissions

**Usage**:
```bash
python3 bi/metabase-tests.py --url https://bi.yourdomain.com --output results/bi-results.json
```

### 5. Security Tests
**File**: `security/security-scan.sh`

Comprehensive security validation:
- Security group configurations
- RDS security settings
- S3 bucket policies
- SSL/TLS configuration
- IAM permissions
- Network security
- Compliance checks

**Usage**:
```bash
./security/security-scan.sh --severity medium
```

### 6. Performance Tests
**File**: `performance/load-test.py`

Load and performance testing:
- Concurrent user simulation
- Response time measurement
- Throughput analysis
- Error rate monitoring
- Performance bottleneck identification

**Usage**:
```bash
python3 performance/load-test.py --url https://app.yourdomain.com --users 10 --duration 60
```

### 7. Monitoring Tests
**File**: `monitoring/monitoring-tests.sh`

Monitoring system validation:
- CloudWatch metrics collection
- Alarm configuration and status
- Route53 health checks
- Log aggregation
- Notification systems
- Dashboard functionality

**Usage**:
```bash
./monitoring/monitoring-tests.sh
```

### 8. Integration Tests
**File**: `integration/test-orchestrator.sh`

End-to-end integration testing:
- Complete user journeys
- Data flow validation
- Cross-system integration
- Workflow testing

## 🔧 Configuration

### Environment Variables

Set these environment variables for your testing environment:

```bash
# Database Configuration
export MYSQL_HOST="your-mysql-endpoint"
export POSTGRES_HOST="your-postgres-endpoint"
export MYSQL_USER="devops_user"
export POSTGRES_USER="devops_user"
export MYSQL_PASSWORD="your-mysql-password"
export POSTGRES_PASSWORD="your-postgres-password"

# Application URLs
export APP_URL="https://app.yourdomain.com"
export API_URL="https://api.yourdomain.com"
export BI_URL="https://bi.yourdomain.com"

# AWS Configuration
export AWS_REGION="us-east-1"
export AWS_PROFILE="default"

# Metabase Configuration
export METABASE_USERNAME="admin@devops.local"
export METABASE_PASSWORD="MetabaseAdmin123!"

# CI/CD Configuration
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
export REPORTS_BUCKET="your-reports-bucket"
```

### Test Configuration File

Customize testing behavior using `config/test-config.yaml`:

```yaml
environments:
  dev:
    thresholds:
      response_time_ms: 1000
      performance_rps: 50
      success_rate_percent: 95

test_suites:
  performance:
    load_testing:
      concurrent_users: 10
      duration_seconds: 60
```

## 🤖 CI/CD Integration

### GitHub Actions Example

```yaml
name: DevOps Dashboard Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Test Suite
        run: |
          cd tests
          ./automation/ci-test-runner.sh \
            --build-number ${{ github.run_number }} \
            --branch ${{ github.ref_name }} \
            --commit ${{ github.sha }}
```

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    stages {
        stage('Test') {
            steps {
                sh '''
                    cd tests
                    ./automation/ci-test-runner.sh \
                        --build-number ${BUILD_NUMBER} \
                        --branch ${BRANCH_NAME} \
                        --commit ${GIT_COMMIT}
                '''
            }
        }
    }
    post {
        always {
            publishHTML([
                allowMissing: false,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'tests/reports',
                reportFiles: '*.html',
                reportName: 'Test Reports'
            ])
        }
    }
}
```

## 📈 Reporting

### Generated Reports

The framework generates multiple report formats:

1. **HTML Reports**: Interactive reports with charts and detailed results
2. **JSON Reports**: Machine-readable results for integration
3. **CSV Reports**: Tabular data for analysis

### Report Locations

- `results/`: Raw test results and data
- `reports/`: Formatted HTML and JSON reports
- `artifacts/`: CI/CD build artifacts

### Sample Report Structure

```
reports/
├── comprehensive-test-report-20231201_143025.html
├── comprehensive-test-report-20231201_143025.json
├── security-report-20231201_143025.html
├── performance-report-20231201_143025.html
└── monitoring-report-20231201_143025.html
```

## 🔍 Troubleshooting

### Common Issues

1. **Database Connection Failures**:
   ```bash
   # Check security groups allow access
   # Verify database endpoints are correct
   # Confirm credentials are valid
   ```

2. **Application URL Not Accessible**:
   ```bash
   # Verify Terraform deployment completed
   # Check ALB health checks
   # Confirm DNS resolution
   ```

3. **SSL Certificate Issues**:
   ```bash
   # Check ACM certificate status
   # Verify domain validation
   # Confirm ALB listener configuration
   ```

### Debug Mode

Enable verbose logging:

```bash
export DEBUG=true
./test-framework.sh --category application
```

### Test Result Analysis

Check test logs for detailed error information:

```bash
# View main test log
cat /tmp/test-framework.log

# View specific test results
cat results/test-results.csv

# View detailed JSON results
jq . results/comprehensive-test-report.json
```

## 🎛️ Advanced Usage

### Custom Test Scenarios

Create custom test scenarios by modifying the configuration:

```yaml
# config/test-config.yaml
performance:
  load_testing:
    scenarios:
      - path: "/api/custom-endpoint"
        weight: 40
        method: "POST"
        data: {"key": "value"}
```

### Parallel Test Execution

Enable parallel testing for faster execution:

```bash
export PARALLEL_TESTS=true
./integration/test-orchestrator.sh --parallel true
```

### Environment-Specific Testing

Run tests for specific environments:

```bash
./integration/test-orchestrator.sh --environment staging
```

### Selective Test Execution

Run only specific test suites:

```bash
./integration/test-orchestrator.sh \
  --suite infrastructure \
  --suite security \
  --suite performance
```

## 📋 Test Checklist

Use this checklist to ensure comprehensive testing:

- [ ] Infrastructure components deployed and healthy
- [ ] Database connectivity and integrity verified
- [ ] Application endpoints responding correctly
- [ ] BI tool accessible and functional
- [ ] Security configurations validated
- [ ] Performance thresholds met
- [ ] Monitoring and alerting operational
- [ ] End-to-end workflows functional

## 🔗 Integration Points

### Monitoring Integration

The framework integrates with:
- CloudWatch for metrics and alarms
- Route53 for health checks
- SNS for notifications
- S3 for artifact storage

### Security Integration

Security testing includes:
- AWS Config compliance
- Security group analysis
- SSL/TLS validation
- IAM policy review

### Performance Integration

Performance testing covers:
- Load balancer performance
- Database query optimization
- Application response times
- Concurrent user handling

## 📚 Additional Resources

- [Testing Guide](./docs/testing-guide.md) - Detailed testing procedures
- [Troubleshooting Guide](./docs/troubleshooting.md) - Common issues and solutions
- [CI/CD Setup Guide](./docs/ci-cd-setup.md) - Pipeline configuration
- [Monitoring Setup](./docs/monitoring-setup.md) - Monitoring configuration

## 🤝 Contributing

To contribute to the testing framework:

1. Add new test cases to appropriate test files
2. Update configuration in `config/test-config.yaml`
3. Document new tests in this README
4. Ensure all tests pass before submitting

## 📄 License

This testing framework is part of the DevOps Dashboard project and follows the same licensing terms.

---

## 🎉 Success Criteria

Your DevOps Dashboard is ready for production when:

- ✅ All infrastructure tests pass
- ✅ Database connectivity and integrity verified
- ✅ Application endpoints respond within thresholds
- ✅ Security score above 80/100
- ✅ Performance meets requirements (>50 RPS, <1000ms response)
- ✅ Monitoring and alerting functional
- ✅ End-to-end integration workflows operational

**Happy Testing! 🚀**

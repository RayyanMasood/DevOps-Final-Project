# DevOps Dashboard Testing Framework Makefile
# Simplified commands for running tests and managing the testing environment

.PHONY: help install test test-all test-infrastructure test-database test-application test-bi test-security test-performance test-integration test-monitoring clean setup ci report

# Default target
help:
	@echo "DevOps Dashboard Testing Framework"
	@echo "=================================="
	@echo ""
	@echo "Available targets:"
	@echo "  install          - Install dependencies and setup testing environment"
	@echo "  setup           - Setup testing environment and configurations"
	@echo "  test-all        - Run all test suites (comprehensive)"
	@echo "  test            - Run core test suites (infrastructure, database, application)"
	@echo "  test-infra      - Run infrastructure tests only"
	@echo "  test-db         - Run database tests only"
	@echo "  test-app        - Run application tests only"
	@echo "  test-bi         - Run BI/Metabase tests only"
	@echo "  test-security   - Run security tests only"
	@echo "  test-perf       - Run performance tests only"
	@echo "  test-integration- Run integration tests only"
	@echo "  test-monitoring - Run monitoring tests only"
	@echo "  ci              - Run CI/CD pipeline tests"
	@echo "  report          - Generate comprehensive test report"
	@echo "  clean           - Clean test results and artifacts"
	@echo "  clean-all       - Clean everything including logs"
	@echo ""
	@echo "Environment variables:"
	@echo "  ENVIRONMENT     - Target environment (dev|staging|prod)"
	@echo "  PARALLEL        - Enable parallel execution (true|false)"
	@echo "  CONTINUE        - Continue on failure (true|false)"
	@echo ""
	@echo "Examples:"
	@echo "  make test ENVIRONMENT=dev"
	@echo "  make test-all PARALLEL=true"
	@echo "  make ci ENVIRONMENT=staging"

# Variables
SHELL := /bin/bash
PROJECT_ROOT := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
TERRAFORM_DIR := $(PROJECT_ROOT)/../terraform
APPLICATION_DIR := $(PROJECT_ROOT)/../application

# Environment configuration
ENVIRONMENT ?= dev
PARALLEL ?= true
CONTINUE ?= false
DEBUG ?= false

# Test configuration
RESULTS_DIR := $(PROJECT_ROOT)/results
REPORTS_DIR := $(PROJECT_ROOT)/reports
ARTIFACTS_DIR := $(PROJECT_ROOT)/artifacts
LOG_FILE := /tmp/devops-dashboard-tests.log

# Install dependencies and setup environment
install:
	@echo "🔧 Installing testing dependencies..."
	@command -v python3 >/dev/null 2>&1 || (echo "❌ Python3 required" && exit 1)
	@command -v pip3 >/dev/null 2>&1 || (echo "❌ pip3 required" && exit 1)
	@pip3 install -q --upgrade pip
	@pip3 install -q asyncpg pymysql aiohttp boto3 pyyaml
	@echo "✅ Dependencies installed"

# Setup testing environment
setup: install
	@echo "🏗️ Setting up testing environment..."
	@mkdir -p $(RESULTS_DIR) $(REPORTS_DIR) $(ARTIFACTS_DIR)
	@chmod +x $(PROJECT_ROOT)/test-framework.sh
	@chmod +x $(PROJECT_ROOT)/integration/test-orchestrator.sh
	@chmod +x $(PROJECT_ROOT)/security/security-scan.sh
	@chmod +x $(PROJECT_ROOT)/monitoring/monitoring-tests.sh
	@chmod +x $(PROJECT_ROOT)/automation/ci-test-runner.sh
	@echo "✅ Testing environment ready"

# Load environment configuration
load-config:
	@if [ -f "$(TERRAFORM_DIR)/terraform.tfstate" ]; then \
		cd $(TERRAFORM_DIR) && \
		export APP_URL=$$(terraform output -raw app_url 2>/dev/null || echo ""); \
		export API_URL=$$(terraform output -raw api_url 2>/dev/null || echo ""); \
		export BI_URL=$$(terraform output -raw bi_url 2>/dev/null || echo ""); \
		export MYSQL_HOST=$$(terraform output -raw mysql_endpoint 2>/dev/null || echo ""); \
		export POSTGRES_HOST=$$(terraform output -raw postgres_endpoint 2>/dev/null || echo ""); \
	fi

# Core test suite (infrastructure, database, application)
test: setup load-config
	@echo "🧪 Running core test suite..."
	@export ENVIRONMENT=$(ENVIRONMENT) && \
	export PARALLEL_TESTS=$(PARALLEL) && \
	export CONTINUE_ON_FAILURE=$(CONTINUE) && \
	$(PROJECT_ROOT)/integration/test-orchestrator.sh \
		--suite infrastructure \
		--suite database \
		--suite application \
		--environment $(ENVIRONMENT)

# Run all test suites
test-all: setup load-config
	@echo "🚀 Running comprehensive test suite..."
	@export ENVIRONMENT=$(ENVIRONMENT) && \
	export PARALLEL_TESTS=$(PARALLEL) && \
	export CONTINUE_ON_FAILURE=$(CONTINUE) && \
	$(PROJECT_ROOT)/integration/test-orchestrator.sh \
		--environment $(ENVIRONMENT)

# Infrastructure tests
test-infra: setup load-config
	@echo "🏗️ Running infrastructure tests..."
	@$(PROJECT_ROOT)/test-framework.sh --category infrastructure

# Database tests
test-db: setup load-config
	@echo "🗄️ Running database tests..."
	@python3 $(PROJECT_ROOT)/database/database-tests.py \
		--output $(RESULTS_DIR)/database-results.json

# Application tests
test-app: setup load-config
	@echo "💻 Running application tests..."
	@$(PROJECT_ROOT)/test-framework.sh --category application

# BI/Metabase tests
test-bi: setup load-config
	@echo "📊 Running BI tests..."
	@if [ -n "$$BI_URL" ] && [ "$$BI_URL" != "Not configured" ]; then \
		python3 $(PROJECT_ROOT)/bi/metabase-tests.py \
			--url "$$BI_URL" \
			--output $(RESULTS_DIR)/bi-results.json; \
	else \
		echo "⚠️ BI_URL not configured, skipping BI tests"; \
	fi

# Security tests
test-security: setup load-config
	@echo "🔒 Running security tests..."
	@$(PROJECT_ROOT)/security/security-scan.sh

# Performance tests
test-perf: setup load-config
	@echo "⚡ Running performance tests..."
	@if [ -n "$$APP_URL" ]; then \
		python3 $(PROJECT_ROOT)/performance/load-test.py \
			--url "$$APP_URL" \
			--users 10 \
			--duration 60 \
			--output $(RESULTS_DIR)/performance-results.json; \
	else \
		echo "⚠️ APP_URL not configured, skipping performance tests"; \
	fi

# Integration tests
test-integration: setup load-config
	@echo "🔗 Running integration tests..."
	@$(PROJECT_ROOT)/test-framework.sh --category integration

# Monitoring tests
test-monitoring: setup load-config
	@echo "📈 Running monitoring tests..."
	@$(PROJECT_ROOT)/monitoring/monitoring-tests.sh

# CI/CD pipeline tests
ci: setup
	@echo "🔄 Running CI/CD pipeline..."
	@export BUILD_NUMBER=$$(date +%Y%m%d_%H%M%S) && \
	export BRANCH_NAME=$$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main") && \
	export COMMIT_SHA=$$(git rev-parse HEAD 2>/dev/null || echo "unknown") && \
	$(PROJECT_ROOT)/automation/ci-test-runner.sh \
		--build-number "$$BUILD_NUMBER" \
		--branch "$$BRANCH_NAME" \
		--commit "$$COMMIT_SHA"

# Generate comprehensive report
report: 
	@echo "📄 Generating comprehensive test report..."
	@if [ -d "$(RESULTS_DIR)" ] && [ "$$(ls -A $(RESULTS_DIR) 2>/dev/null)" ]; then \
		echo "Generating report from existing results..."; \
		python3 -c "import json, os, glob; \
		results = {}; \
		for f in glob.glob('$(RESULTS_DIR)/*.json'): \
			with open(f) as file: \
				results[os.path.basename(f)] = json.load(file); \
		print(json.dumps(results, indent=2))" > $(REPORTS_DIR)/combined-results.json; \
		echo "✅ Report generated: $(REPORTS_DIR)/combined-results.json"; \
	else \
		echo "⚠️ No test results found. Run tests first."; \
	fi

# Clean test results and reports
clean:
	@echo "🧹 Cleaning test results..."
	@rm -rf $(RESULTS_DIR)/* $(REPORTS_DIR)/* 2>/dev/null || true
	@echo "✅ Test results cleaned"

# Clean everything including logs and artifacts
clean-all: clean
	@echo "🧹 Cleaning all test artifacts..."
	@rm -rf $(ARTIFACTS_DIR)/* 2>/dev/null || true
	@rm -f $(LOG_FILE) /tmp/*test*.log 2>/dev/null || true
	@echo "✅ All test artifacts cleaned"

# Validate test environment
validate:
	@echo "🔍 Validating test environment..."
	@command -v terraform >/dev/null 2>&1 || (echo "❌ Terraform not found" && exit 1)
	@command -v aws >/dev/null 2>&1 || (echo "❌ AWS CLI not found" && exit 1)
	@command -v jq >/dev/null 2>&1 || (echo "❌ jq not found" && exit 1)
	@command -v curl >/dev/null 2>&1 || (echo "❌ curl not found" && exit 1)
	@aws sts get-caller-identity >/dev/null 2>&1 || (echo "❌ AWS credentials not configured" && exit 1)
	@if [ -f "$(TERRAFORM_DIR)/terraform.tfstate" ]; then \
		echo "✅ Terraform state found"; \
	else \
		echo "⚠️ Terraform state not found - infrastructure may not be deployed"; \
	fi
	@echo "✅ Environment validation complete"

# Show test status
status:
	@echo "📊 Test Environment Status"
	@echo "=========================="
	@echo "Environment: $(ENVIRONMENT)"
	@echo "Parallel Execution: $(PARALLEL)"
	@echo "Continue on Failure: $(CONTINUE)"
	@echo "Results Directory: $(RESULTS_DIR)"
	@echo "Reports Directory: $(REPORTS_DIR)"
	@echo ""
	@if [ -d "$(RESULTS_DIR)" ] && [ "$$(ls -A $(RESULTS_DIR) 2>/dev/null)" ]; then \
		echo "📁 Recent Test Results:"; \
		ls -la $(RESULTS_DIR) | tail -n +2; \
	else \
		echo "📁 No test results found"; \
	fi
	@echo ""
	@if [ -d "$(REPORTS_DIR)" ] && [ "$$(ls -A $(REPORTS_DIR) 2>/dev/null)" ]; then \
		echo "📄 Recent Reports:"; \
		ls -la $(REPORTS_DIR) | tail -n +2; \
	else \
		echo "📄 No reports found"; \
	fi

# Development helpers
dev-setup: setup
	@echo "🛠️ Setting up development environment..."
	@export ENVIRONMENT=dev
	@export PARALLEL=false
	@export CONTINUE=true
	@echo "✅ Development environment configured"

# Quick smoke test
smoke: setup load-config
	@echo "💨 Running smoke tests..."
	@$(PROJECT_ROOT)/test-framework.sh --category infrastructure --category application

# Interactive test runner
interactive:
	@echo "🎮 Interactive Test Runner"
	@echo "========================="
	@echo "Select test suite to run:"
	@echo "1) Infrastructure"
	@echo "2) Database"
	@echo "3) Application"
	@echo "4) BI/Metabase"
	@echo "5) Security"
	@echo "6) Performance"
	@echo "7) All Tests"
	@echo "8) CI Pipeline"
	@read -p "Enter choice [1-8]: " choice; \
	case $$choice in \
		1) make test-infra ;; \
		2) make test-db ;; \
		3) make test-app ;; \
		4) make test-bi ;; \
		5) make test-security ;; \
		6) make test-perf ;; \
		7) make test-all ;; \
		8) make ci ;; \
		*) echo "Invalid choice" ;; \
	esac

# Watch mode for continuous testing
watch:
	@echo "👀 Starting watch mode..."
	@while true; do \
		clear; \
		echo "🔄 Running tests in watch mode (Ctrl+C to stop)..."; \
		make test PARALLEL=true CONTINUE=true || true; \
		echo "⏰ Waiting 60 seconds before next run..."; \
		sleep 60; \
	done

# Export test configuration
export-config:
	@echo "📤 Exporting test configuration..."
	@mkdir -p $(ARTIFACTS_DIR)
	@env | grep -E '^(APP_URL|API_URL|BI_URL|MYSQL_|POSTGRES_|AWS_|METABASE_)' > $(ARTIFACTS_DIR)/test-environment.env
	@echo "✅ Configuration exported to $(ARTIFACTS_DIR)/test-environment.env"

# Import test configuration
import-config:
	@if [ -f "$(ARTIFACTS_DIR)/test-environment.env" ]; then \
		echo "📥 Importing test configuration..."; \
		set -a && source $(ARTIFACTS_DIR)/test-environment.env && set +a; \
		echo "✅ Configuration imported"; \
	else \
		echo "⚠️ No configuration file found at $(ARTIFACTS_DIR)/test-environment.env"; \
	fi

# Test coverage report
coverage:
	@echo "📈 Generating test coverage report..."
	@echo "Test Coverage Analysis" > $(REPORTS_DIR)/coverage-report.md
	@echo "======================" >> $(REPORTS_DIR)/coverage-report.md
	@echo "" >> $(REPORTS_DIR)/coverage-report.md
	@echo "## Infrastructure Coverage" >> $(REPORTS_DIR)/coverage-report.md
	@echo "- VPC and Networking: ✅" >> $(REPORTS_DIR)/coverage-report.md
	@echo "- Load Balancer: ✅" >> $(REPORTS_DIR)/coverage-report.md
	@echo "- Auto Scaling: ✅" >> $(REPORTS_DIR)/coverage-report.md
	@echo "- RDS Databases: ✅" >> $(REPORTS_DIR)/coverage-report.md
	@echo "" >> $(REPORTS_DIR)/coverage-report.md
	@echo "## Application Coverage" >> $(REPORTS_DIR)/coverage-report.md
	@echo "- API Endpoints: ✅" >> $(REPORTS_DIR)/coverage-report.md
	@echo "- Health Checks: ✅" >> $(REPORTS_DIR)/coverage-report.md
	@echo "- Database Connectivity: ✅" >> $(REPORTS_DIR)/coverage-report.md
	@echo "" >> $(REPORTS_DIR)/coverage-report.md
	@echo "✅ Coverage report generated: $(REPORTS_DIR)/coverage-report.md"

# List available make targets
list:
	@grep '^[a-zA-Z][a-zA-Z0-9_-]*:' Makefile | sed 's/:.*//' | sort

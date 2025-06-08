#!/bin/bash

# Terraform Backend Initialization Script
# This script creates the S3 bucket and DynamoDB table for Terraform state management

set -e

# Configuration
PROJECT_NAME="${PROJECT_NAME:-devops-final-project}"
ENVIRONMENT="${ENVIRONMENT:-shared}"
AWS_REGION="${AWS_REGION:-us-east-1}"
BUCKET_NAME="${PROJECT_NAME}-terraform-state-${ENVIRONMENT}"
DYNAMODB_TABLE="${PROJECT_NAME}-terraform-lock-${ENVIRONMENT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install AWS CLI first."
        exit 1
    fi
}

# Check if AWS credentials are configured
check_aws_credentials() {
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
}

# Create S3 bucket for Terraform state
create_s3_bucket() {
    log_info "Creating S3 bucket: ${BUCKET_NAME}"
    
    # Check if bucket already exists
    if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
        log_warn "S3 bucket ${BUCKET_NAME} already exists."
        return 0
    fi
    
    # Create bucket
    if [ "${AWS_REGION}" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${AWS_REGION}"
    else
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}" \
            --create-bucket-configuration LocationConstraint="${AWS_REGION}"
    fi
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled
    
    # Enable server-side encryption
    aws s3api put-bucket-encryption \
        --bucket "${BUCKET_NAME}" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket "${BUCKET_NAME}" \
        --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    
    log_info "S3 bucket ${BUCKET_NAME} created successfully."
}

# Create DynamoDB table for state locking
create_dynamodb_table() {
    log_info "Creating DynamoDB table: ${DYNAMODB_TABLE}"
    
    # Check if table already exists
    if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}" &> /dev/null; then
        log_warn "DynamoDB table ${DYNAMODB_TABLE} already exists."
        return 0
    fi
    
    # Create table
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "${AWS_REGION}"
    
    # Wait for table to be created
    log_info "Waiting for DynamoDB table to be created..."
    aws dynamodb wait table-exists --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}"
    
    log_info "DynamoDB table ${DYNAMODB_TABLE} created successfully."
}

# Generate backend configuration
generate_backend_config() {
    local backend_file="backend-config.tf"
    
    log_info "Generating backend configuration file: ${backend_file}"
    
    cat > "${backend_file}" << EOF
# Terraform Backend Configuration
# This file configures the S3 backend for Terraform state storage

terraform {
  backend "s3" {
    bucket         = "${BUCKET_NAME}"
    key            = "terraform.tfstate"
    region         = "${AWS_REGION}"
    encrypt        = true
    dynamodb_table = "${DYNAMODB_TABLE}"
    
    # Optional: Additional security
    # acl            = "bucket-owner-full-control"
    # versioning     = true
  }
}
EOF
    
    log_info "Backend configuration saved to ${backend_file}"
    log_info "To use this backend, copy the content to your main.tf or run:"
    log_info "terraform init -backend-config=\"bucket=${BUCKET_NAME}\" -backend-config=\"key=terraform.tfstate\" -backend-config=\"region=${AWS_REGION}\" -backend-config=\"dynamodb_table=${DYNAMODB_TABLE}\""
}

# Display usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Initialize Terraform backend with S3 bucket and DynamoDB table."
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -p, --project NAME  Set project name (default: devops-final-project)"
    echo "  -e, --env ENV       Set environment (default: shared)"
    echo "  -r, --region REGION Set AWS region (default: us-east-1)"
    echo ""
    echo "Environment Variables:"
    echo "  PROJECT_NAME        Project name for resource naming"
    echo "  ENVIRONMENT         Environment name (dev, staging, prod, shared)"
    echo "  AWS_REGION          AWS region for resources"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Use defaults"
    echo "  $0 -p myproject -e dev -r us-west-2  # Custom settings"
    echo "  PROJECT_NAME=myapp $0                # Using environment variable"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -p|--project)
                PROJECT_NAME="$2"
                shift 2
                ;;
            -e|--env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -r|--region)
                AWS_REGION="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Update derived variables
    BUCKET_NAME="${PROJECT_NAME}-terraform-state-${ENVIRONMENT}"
    DYNAMODB_TABLE="${PROJECT_NAME}-terraform-lock-${ENVIRONMENT}"
}

# Main function
main() {
    log_info "Starting Terraform backend initialization..."
    log_info "Project: ${PROJECT_NAME}"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Region: ${AWS_REGION}"
    log_info "Bucket: ${BUCKET_NAME}"
    log_info "DynamoDB Table: ${DYNAMODB_TABLE}"
    echo ""
    
    # Checks
    check_aws_cli
    check_aws_credentials
    
    # Get AWS account info
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local current_region=$(aws configure get region)
    
    log_info "AWS Account ID: ${account_id}"
    log_info "Current AWS Region: ${current_region}"
    echo ""
    
    # Confirm before proceeding
    read -p "Do you want to proceed with creating the backend resources? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled by user."
        exit 0
    fi
    
    # Create resources
    create_s3_bucket
    create_dynamodb_table
    generate_backend_config
    
    echo ""
    log_info "Backend initialization completed successfully!"
    log_info ""
    log_info "Next steps:"
    log_info "1. Copy the backend configuration to your main.tf file"
    log_info "2. Run 'terraform init' to initialize with the new backend"
    log_info "3. Run 'terraform plan' to verify your configuration"
    echo ""
    log_info "Resources created:"
    log_info "- S3 Bucket: ${BUCKET_NAME}"
    log_info "- DynamoDB Table: ${DYNAMODB_TABLE}"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi

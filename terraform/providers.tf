# Provider Configuration
# This file configures the AWS provider and any additional providers required

# Configure the AWS Provider with default settings
provider "aws" {
  region = var.aws_region

  # Default tags applied to all resources
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
    }
  }

  # Optional: Configure assume role if needed
  # assume_role {
  #   role_arn = "arn:aws:iam::ACCOUNT-ID:role/ROLE-NAME"
  # }
}

# Additional AWS provider for ACM certificate validation in us-east-1
# This is required because CloudFront and some other services require certificates in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
    }
  }
}

# Data source for AWS caller identity
data "aws_caller_identity" "current" {}

# Data source for AWS region
data "aws_region" "current" {}

# Data source for AWS partition (useful for ARN construction)
data "aws_partition" "current" {}

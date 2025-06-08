# Terraform and Provider Version Constraints
# This file specifies minimum versions for Terraform and required providers

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1"
    }
    
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Backend configuration for state management
  # This is configured in main.tf but can also be defined here
  # Uncomment and configure as needed for your environment
  
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
  
  # For HCP Terraform (Terraform Cloud)
  # cloud {
  #   organization = "your-organization"
  #   workspaces {
  #     name = "devops-infrastructure"
  #   }
  # }
}

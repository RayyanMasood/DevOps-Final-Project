# Terraform DevOps Project Makefile
# This Makefile provides convenient commands for managing the Terraform infrastructure

.PHONY: help init plan apply destroy validate format check clean install-tools

# Default target
help: ## Show this help message
	@echo "DevOps Final Project - Terraform Commands"
	@echo "========================================="
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup Commands

install-tools: ## Install required tools (Terraform, AWS CLI)
	@echo "Installing required tools..."
	@if ! command -v terraform &> /dev/null; then \
		echo "Installing Terraform..."; \
		curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -; \
		sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $$(lsb_release -cs) main"; \
		sudo apt-get update && sudo apt-get install terraform; \
	else \
		echo "Terraform is already installed"; \
	fi
	@if ! command -v aws &> /dev/null; then \
		echo "Installing AWS CLI..."; \
		curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; \
		unzip awscliv2.zip; \
		sudo ./aws/install; \
		rm -rf aws awscliv2.zip; \
	else \
		echo "AWS CLI is already installed"; \
	fi

init: ## Initialize Terraform configuration
	@echo "Initializing Terraform..."
	@terraform init
	@echo "Terraform initialized successfully!"

##@ Development Commands

validate: ## Validate Terraform configuration
	@echo "Validating Terraform configuration..."
	@terraform validate
	@echo "Configuration is valid!"

format: ## Format Terraform configuration files
	@echo "Formatting Terraform files..."
	@terraform fmt -recursive
	@echo "Files formatted successfully!"

check: format validate ## Run format and validate checks
	@echo "All checks passed!"

##@ Environment Commands

plan: ## Create and show execution plan
	@echo "Creating Terraform execution plan..."
	@terraform plan
	@echo "Plan created successfully!"

plan-dev: ## Create execution plan for development environment
	@echo "Creating Terraform execution plan for development..."
	@terraform plan -var-file="environments/dev.tfvars"

plan-staging: ## Create execution plan for staging environment
	@echo "Creating Terraform execution plan for staging..."
	@terraform plan -var-file="environments/staging.tfvars"

plan-prod: ## Create execution plan for production environment
	@echo "Creating Terraform execution plan for production..."
	@terraform plan -var-file="environments/prod.tfvars"

apply: ## Apply Terraform configuration
	@echo "Applying Terraform configuration..."
	@terraform apply
	@echo "Infrastructure deployed successfully!"

apply-dev: ## Apply configuration for development environment
	@echo "Applying Terraform configuration for development..."
	@terraform apply -var-file="environments/dev.tfvars"

apply-staging: ## Apply configuration for staging environment
	@echo "Applying Terraform configuration for staging..."
	@terraform apply -var-file="environments/staging.tfvars"

apply-prod: ## Apply configuration for production environment
	@echo "Applying Terraform configuration for production..."
	@terraform apply -var-file="environments/prod.tfvars"

##@ Maintenance Commands

refresh: ## Refresh Terraform state
	@echo "Refreshing Terraform state..."
	@terraform refresh
	@echo "State refreshed successfully!"

show: ## Show current state
	@echo "Showing current Terraform state..."
	@terraform show

state-list: ## List all resources in state
	@echo "Listing all resources in Terraform state..."
	@terraform state list

output: ## Show output values
	@echo "Showing Terraform output values..."
	@terraform output

##@ Cleanup Commands

destroy: ## Destroy all infrastructure
	@echo "WARNING: This will destroy ALL infrastructure!"
	@echo "Are you sure you want to continue? [y/N]"
	@read -r REPLY; \
	if [ "$$REPLY" = "y" ] || [ "$$REPLY" = "Y" ]; then \
		terraform destroy; \
		echo "Infrastructure destroyed!"; \
	else \
		echo "Destruction cancelled."; \
	fi

destroy-dev: ## Destroy development environment
	@echo "WARNING: This will destroy the development environment!"
	@echo "Are you sure you want to continue? [y/N]"
	@read -r REPLY; \
	if [ "$$REPLY" = "y" ] || [ "$$REPLY" = "Y" ]; then \
		terraform destroy -var-file="environments/dev.tfvars"; \
		echo "Development environment destroyed!"; \
	else \
		echo "Destruction cancelled."; \
	fi

clean: ## Clean temporary files
	@echo "Cleaning temporary files..."
	@rm -rf .terraform/
	@rm -f *.tfplan
	@rm -f *.tfstate.backup
	@rm -f crash.log
	@echo "Cleanup completed!"

##@ Security Commands

security-scan: ## Run security scan with checkov
	@echo "Running security scan..."
	@if command -v checkov &> /dev/null; then \
		checkov -f .; \
	else \
		echo "Installing checkov..."; \
		pip3 install checkov; \
		checkov -f .; \
	fi

lint: ## Run TFLint for code quality
	@echo "Running TFLint..."
	@if command -v tflint &> /dev/null; then \
		tflint; \
	else \
		echo "Installing TFLint..."; \
		curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash; \
		tflint; \
	fi

##@ Utility Commands

graph: ## Generate dependency graph
	@echo "Generating dependency graph..."
	@terraform graph > graph.dot
	@echo "Dependency graph saved to graph.dot"
	@echo "To visualize: dot -Tpng graph.dot > graph.png"

docs: ## Generate documentation
	@echo "Generating Terraform documentation..."
	@if command -v terraform-docs &> /dev/null; then \
		terraform-docs markdown table --output-file README-auto.md .; \
		echo "Documentation generated in README-auto.md"; \
	else \
		echo "Installing terraform-docs..."; \
		curl -sSLo ./terraform-docs.tar.gz https://terraform-docs.io/dl/v0.16.0/terraform-docs-v0.16.0-$$(uname)-amd64.tar.gz; \
		tar -xzf terraform-docs.tar.gz; \
		chmod +x terraform-docs; \
		sudo mv terraform-docs /usr/local/bin/; \
		rm terraform-docs.tar.gz; \
		terraform-docs markdown table --output-file README-auto.md .; \
		echo "Documentation generated in README-auto.md"; \
	fi

cost-estimate: ## Estimate infrastructure costs
	@echo "Estimating infrastructure costs..."
	@if command -v infracost &> /dev/null; then \
		infracost breakdown --path .; \
	else \
		echo "Infracost not installed. Visit: https://www.infracost.io/docs/"; \
	fi

##@ Troubleshooting Commands

debug: ## Enable debug logging
	@echo "Running Terraform with debug logging..."
	@export TF_LOG=DEBUG && terraform plan

unlock: ## Force unlock state (use with caution)
	@echo "WARNING: This will force unlock the Terraform state!"
	@echo "Only use this if you're sure no other operations are running."
	@echo "Enter the lock ID to unlock:"
	@read -r LOCK_ID; \
	terraform force-unlock $$LOCK_ID

import: ## Import existing resource (requires resource address and ID)
	@echo "Enter resource address (e.g., aws_instance.example):"
	@read -r RESOURCE_ADDRESS; \
	echo "Enter resource ID:"; \
	read -r RESOURCE_ID; \
	terraform import $$RESOURCE_ADDRESS $$RESOURCE_ID

##@ Information Commands

version: ## Show Terraform version
	@terraform version

providers: ## Show provider requirements
	@terraform providers

workspace: ## Show current workspace
	@terraform workspace show

aws-info: ## Show AWS account information
	@echo "AWS Account Information:"
	@aws sts get-caller-identity
	@echo ""
	@echo "AWS Region:"
	@aws configure get region

##@ Quick Start

quick-dev: init validate plan apply ## Quick deployment for development
	@echo "Development environment deployed successfully!"
	@terraform output

quick-destroy: ## Quick destruction with confirmation
	@echo "This will destroy all infrastructure in 10 seconds..."
	@echo "Press Ctrl+C to cancel"
	@sleep 10
	@terraform destroy -auto-approve

##@ Environment Setup Examples

setup-dev: ## Setup development environment variables
	@echo "Setting up development environment..."
	@echo "export TF_VAR_environment=dev" > .env.dev
	@echo "export TF_VAR_instance_type=t3.micro" >> .env.dev
	@echo "export TF_VAR_asg_min_size=1" >> .env.dev
	@echo "export TF_VAR_asg_max_size=3" >> .env.dev
	@echo "export TF_VAR_asg_desired_capacity=2" >> .env.dev
	@echo "Source with: source .env.dev"

setup-prod: ## Setup production environment variables
	@echo "Setting up production environment..."
	@echo "export TF_VAR_environment=prod" > .env.prod
	@echo "export TF_VAR_instance_type=t3.large" >> .env.prod
	@echo "export TF_VAR_asg_min_size=3" >> .env.prod
	@echo "export TF_VAR_asg_max_size=10" >> .env.prod
	@echo "export TF_VAR_asg_desired_capacity=5" >> .env.prod
	@echo "Source with: source .env.prod"

##@ Examples

example-tfvars: ## Create example terraform.tfvars file
	@echo "Creating terraform.tfvars from example..."
	@cp terraform.tfvars.example terraform.tfvars
	@echo "Edit terraform.tfvars with your specific values"

example-backend: ## Show example backend configuration
	@echo "Example backend configuration for S3:"
	@echo ""
	@echo "terraform {"
	@echo "  backend \"s3\" {"
	@echo "    bucket         = \"your-terraform-state-bucket\""
	@echo "    key            = \"terraform.tfstate\""
	@echo "    region         = \"us-east-1\""
	@echo "    encrypt        = true"
	@echo "    dynamodb_table = \"terraform-state-lock\""
	@echo "  }"
	@echo "}"

# Set default shell to bash for better compatibility
SHELL := /bin/bash

# Main Terraform Configuration
# This file serves as the primary entry point for the DevOps infrastructure project
# It orchestrates all modules and resources to create a complete AWS environment

# Backend configuration for remote state storage (optional)
# Uncomment and configure if you want remote state storage
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }

# Data sources (must be defined before locals.tf references them)
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Networking Module
module "networking" {
  source = "./modules/networking"
  
  # Required variables
  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = local.availability_zones
  
  # Optional variables with defaults
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  enable_nat_gateway   = var.enable_nat_gateway
  
  # Tags
  tags = local.common_tags
}

# Security Module
module "security" {
  source = "./modules/security"
  
  # Dependencies
  vpc_id              = module.networking.vpc_id
  vpc_cidr            = var.vpc_cidr
  
  # Configuration
  project_name        = var.project_name
  environment         = var.environment
  allowed_cidr_blocks = var.allowed_cidr_blocks
  office_ip_addresses = var.office_ip_addresses
  
  # Tags
  tags = local.common_tags
  
  depends_on = [module.networking]
}

# Database Module
module "database" {
  source = "./modules/database"
  
  # Dependencies
  vpc_id               = module.networking.vpc_id
  database_subnet_ids  = module.networking.database_subnet_ids
  database_security_group_id = module.security.database_security_group_id
  db_subnet_group_name = module.networking.db_subnet_group_name
  
  # Database configuration
  project_name         = var.project_name
  environment          = var.environment
  
  # MySQL configuration
  mysql_instance_class = var.mysql_instance_class
  mysql_allocated_storage = var.mysql_allocated_storage
  mysql_engine_version = var.mysql_engine_version
  mysql_database_name  = var.mysql_database_name
  mysql_username       = var.mysql_username
  mysql_password       = var.mysql_password
  
  # PostgreSQL configuration
  postgres_instance_class = var.postgres_instance_class
  postgres_allocated_storage = var.postgres_allocated_storage
  postgres_engine_version = var.postgres_engine_version
  postgres_database_name = var.postgres_database_name
  postgres_username    = var.postgres_username
  postgres_password    = var.postgres_password
  
  # Backup and maintenance
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  enable_monitoring      = var.enable_monitoring
  
  # Tags
  tags = local.common_tags
  
  depends_on = [module.networking, module.security]
}

# Compute Module (Auto Scaling Group)
module "compute" {
  source = "./modules/compute"
  
  # Dependencies
  vpc_id                    = module.networking.vpc_id
  private_subnet_ids        = module.networking.private_subnet_ids
  public_subnet_ids         = module.networking.public_subnet_ids
  app_security_group_id     = module.security.app_security_group_id
  bastion_security_group_id = module.security.bastion_security_group_id
  target_group_arns         = [module.load_balancer.target_group_arn]
  
  # Configuration
  project_name              = var.project_name
  environment               = var.environment
  
  # Instance configuration
  instance_type             = var.instance_type
  ami_id                    = data.aws_ami.amazon_linux.id
  key_name                  = var.key_name
  
  # Auto Scaling configuration
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  health_check_grace_period = var.health_check_grace_period
  health_check_type         = var.health_check_type
  
  # Scaling policies
  target_cpu_utilization    = var.target_cpu_utilization
  target_request_count      = var.target_request_count
  alb_target_group_label     = "${module.load_balancer.load_balancer_arn_suffix}/${module.load_balancer.target_group_arn_suffix}"
  
  # Database connection info
  mysql_endpoint            = module.database.mysql_endpoint
  postgres_endpoint         = module.database.postgres_endpoint
  mysql_secret_arn          = module.database.mysql_secret_arn
  postgres_secret_arn       = module.database.postgres_secret_arn
  
  # Tags
  tags = local.common_tags
  
  depends_on = [module.networking, module.security, module.database]
}

# Load Balancer Module
module "load_balancer" {
  source = "./modules/load_balancer"
  
  # Dependencies
  vpc_id                    = module.networking.vpc_id
  public_subnet_ids         = module.networking.public_subnet_ids
  alb_security_group_id     = module.security.alb_security_group_id
  
  # Configuration
  project_name              = var.project_name
  environment               = var.environment
  
  # SSL Certificate (pass through from variables only)
  domain_name               = var.domain_name
  certificate_arn           = var.certificate_arn
  ssl_policy                = var.ssl_policy
  
  # Health check configuration
  health_check_path         = var.health_check_path
  health_check_interval     = var.health_check_interval
  health_check_timeout      = var.health_check_timeout
  healthy_threshold         = var.healthy_threshold
  unhealthy_threshold       = var.unhealthy_threshold
  
  # Optional features
  enable_waf                = false
  
  # Tags
  tags = local.common_tags
  
  depends_on = [module.networking, module.security]
}

# Domain and SSL Module (Optional - only if domain is provided)
# TEMPORARILY COMMENTED OUT to resolve circular dependency
# Uncomment and configure after load balancer is working
# module "domain" {
#   count  = var.domain_name != "" ? 1 : 0
#   source = "./modules/domain"
#
#   project_name        = var.project_name
#   environment         = var.environment
#   aws_region          = var.aws_region
#   domain_name         = var.domain_name
#   create_hosted_zone  = var.create_hosted_zone
#
#   # ALB configuration for DNS records
#   alb_dns_name = module.load_balancer.load_balancer_dns_name
#   alb_zone_id  = module.load_balancer.load_balancer_zone_id
#
#   # Health check and monitoring
#   enable_health_checks = var.enable_health_checks
#   enable_dns_logging   = var.enable_dns_logging
#   sns_alarm_arn        = var.enable_monitoring ? module.monitoring[0].sns_topic_arn : ""
#
#   # SSL configuration
#   create_metabase_certificate = var.create_metabase_certificate
#   ssl_policy                  = var.ssl_policy
#
#   # Email configuration
#   mx_records              = var.mx_records
#   enable_spf_record       = var.enable_spf_record
#   enable_dmarc_record     = var.enable_dmarc_record
#   domain_verification_txt = var.domain_verification_txt
#
#   common_tags = local.common_tags
#
#   depends_on = [module.load_balancer]
# }

# Monitoring Module (Optional)
module "monitoring" {
  count  = var.enable_monitoring ? 1 : 0
  source = "./modules/monitoring"
  
  # Dependencies
  auto_scaling_group_name   = module.compute.auto_scaling_group_name
  load_balancer_arn_suffix  = module.load_balancer.load_balancer_arn_suffix
  target_group_arn_suffix   = module.load_balancer.target_group_arn_suffix
  
  # Configuration
  project_name              = var.project_name
  environment               = var.environment
  
  # Alarm thresholds
  high_cpu_threshold        = var.high_cpu_threshold
  high_memory_threshold     = var.high_memory_threshold
  alarm_email               = var.alarm_email
  
  # Tags
  tags = local.common_tags
  
  depends_on = [module.compute, module.load_balancer]
}

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

# Dynamic IP detection for automatic SSH access
data "http" "current_ip" {
  url = "https://ipv4.icanhazip.com"
  
  request_headers = {
    Accept = "text/plain"
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
  office_ip_addresses = local.all_office_ips
  
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
  metabase_target_group_arn = module.load_balancer.metabase_target_group_arn
  
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

# SSL Certificate (created independently to avoid circular dependency)
resource "aws_acm_certificate" "main" {
  count             = var.domain_name != "" ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}",
    "app.${var.domain_name}",
    "bi.${var.domain_name}",
    "api.${var.domain_name}",
    "admin.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ssl-certificate"
    Type = "SSL"
  })
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
  
  # SSL Certificate (use validated certificate if domain is configured)
  domain_name               = var.domain_name
  certificate_arn           = var.domain_name != "" ? aws_acm_certificate_validation.main[0].certificate_arn : var.certificate_arn
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

# Route53 DNS records (separate from domain module to avoid circular dependency)
data "aws_route53_zone" "main" {
  count        = var.domain_name != "" && !var.create_hosted_zone ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_zone" "main" {
  count = var.domain_name != "" && var.create_hosted_zone ? 1 : 0
  name  = var.domain_name

  # Prevent accidental destruction of hosted zone (preserves nameservers)
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-hosted-zone"
    Type = "DNS"
  })
}

# Get the hosted zone ID (either existing or newly created)
locals {
  hosted_zone_id = var.domain_name != "" ? (
    var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.main[0].zone_id
  ) : ""
}

# DNS validation records for SSL certificate
resource "aws_route53_record" "ssl_validation" {
  for_each = var.domain_name != "" ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = local.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60

  allow_overwrite = true
}

# Certificate validation
resource "aws_acm_certificate_validation" "main" {
  count           = var.domain_name != "" ? 1 : 0
  certificate_arn = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.ssl_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# DNS A records pointing to ALB
resource "aws_route53_record" "app" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = "app.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.load_balancer.load_balancer_dns_name
    zone_id                = module.load_balancer.load_balancer_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "bi" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = "bi.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.load_balancer.load_balancer_dns_name
    zone_id                = module.load_balancer.load_balancer_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.load_balancer.load_balancer_dns_name
    zone_id                = module.load_balancer.load_balancer_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "admin" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = "admin.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.load_balancer.load_balancer_dns_name
    zone_id                = module.load_balancer.load_balancer_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "root" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.load_balancer.load_balancer_dns_name
    zone_id                = module.load_balancer.load_balancer_zone_id
    evaluate_target_health = true
  }
}

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

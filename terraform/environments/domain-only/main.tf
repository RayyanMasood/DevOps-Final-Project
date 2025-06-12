# Domain-only Terraform configuration
# This creates the hosted zone and SSL certificate separately
# so they persist even if the main infrastructure is destroyed

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Domain name"
  type        = string
  default     = "flomny.com"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "analytics-platform"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "production"
}

# Route53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name        = "${var.project_name}-${var.environment}-hosted-zone"
    Environment = var.environment
    Project     = var.project_name
    Type        = "DNS"
  }
}

# SSL Certificate
resource "aws_acm_certificate" "main" {
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

  tags = {
    Name        = "${var.project_name}-${var.environment}-ssl-certificate"
    Environment = var.environment
    Project     = var.project_name
    Type        = "SSL"
  }
}

# DNS validation records
resource "aws_route53_record" "ssl_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60

  allow_overwrite = true
}

# Certificate validation
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.ssl_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# Outputs for main terraform to reference
output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "hosted_zone_name_servers" {
  description = "Route53 nameservers"
  value       = aws_route53_zone.main.name_servers
}

output "ssl_certificate_arn" {
  description = "SSL certificate ARN"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "domain_name" {
  description = "Domain name"
  value       = var.domain_name
} 
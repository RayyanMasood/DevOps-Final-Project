# Domain and SSL Configuration Module
# Manages Route53 DNS and AWS Certificate Manager for secure HTTPS access

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source for existing hosted zone (if domain is already registered)
data "aws_route53_zone" "main" {
  count        = var.create_hosted_zone ? 0 : 1
  name         = var.domain_name
  private_zone = false
}

# Create hosted zone if requested
resource "aws_route53_zone" "main" {
  count = var.create_hosted_zone ? 1 : 1
  name  = var.domain_name

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-hosted-zone"
    Type = "DNS"
  })
}

# Get the hosted zone ID (either existing or newly created)
locals {
  hosted_zone_id = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.main[0].zone_id
  hosted_zone    = var.create_hosted_zone ? aws_route53_zone.main[0] : data.aws_route53_zone.main[0]
}

# SSL Certificate for main domain and subdomains
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

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-ssl-certificate"
    Type = "SSL"
  })
}

# DNS validation records for SSL certificate
resource "aws_route53_record" "ssl_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.hosted_zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.ssl_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# Main application A record (points to ALB)
resource "aws_route53_record" "app" {
  zone_id = local.hosted_zone_id
  name    = "app.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# BI tool A record (points to EC2 instance or ALB)
resource "aws_route53_record" "bi" {
  zone_id = local.hosted_zone_id
  name    = "bi.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# API subdomain A record
resource "aws_route53_record" "api" {
  zone_id = local.hosted_zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Admin subdomain A record
resource "aws_route53_record" "admin" {
  zone_id = local.hosted_zone_id
  name    = "admin.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Root domain redirect to app subdomain
resource "aws_route53_record" "root" {
  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Health check for main application
resource "aws_route53_health_check" "app" {
  fqdn                            = "app.${var.domain_name}"
  port                            = 443
  type                            = "HTTPS"
  resource_path                   = "/health"
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_logs_region          = var.aws_region
  cloudwatch_alarm_region         = var.aws_region
  measure_latency                 = true
  invert_healthcheck              = false
  enable_sni                      = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-health-check"
    Type = "HealthCheck"
  })
}

# Health check for BI tool
resource "aws_route53_health_check" "bi" {
  fqdn                            = "bi.${var.domain_name}"
  port                            = 443
  type                            = "HTTPS"
  resource_path                   = "/api/health"
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_logs_region          = var.aws_region
  cloudwatch_alarm_region         = var.aws_region
  measure_latency                 = true
  invert_healthcheck              = false
  enable_sni                      = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-bi-health-check"
    Type = "HealthCheck"
  })
}

# CloudWatch alarm for app health check
resource "aws_cloudwatch_metric_alarm" "app_health" {
  alarm_name          = "${var.project_name}-${var.environment}-app-health-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "This metric monitors app health check"
  alarm_actions       = var.sns_alarm_arn != "" ? [var.sns_alarm_arn] : []

  dimensions = {
    HealthCheckId = aws_route53_health_check.app.id
  }

  tags = var.common_tags
}

# CloudWatch alarm for BI health check
resource "aws_cloudwatch_metric_alarm" "bi_health" {
  alarm_name          = "${var.project_name}-${var.environment}-bi-health-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "This metric monitors BI tool health check"
  alarm_actions       = var.sns_alarm_arn != "" ? [var.sns_alarm_arn] : []

  dimensions = {
    HealthCheckId = aws_route53_health_check.bi.id
  }

  tags = var.common_tags
}

# MX record for email (optional)
resource "aws_route53_record" "mx" {
  count   = length(var.mx_records) > 0 ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = 300
  records = var.mx_records
}

# TXT record for domain verification
resource "aws_route53_record" "txt_verification" {
  count   = var.domain_verification_txt != "" ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "TXT"
  ttl     = 300
  records = [var.domain_verification_txt]
}

# SPF record for email security
resource "aws_route53_record" "spf" {
  count   = var.enable_spf_record ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:_spf.google.com ~all"]
}

# DMARC record for email security
resource "aws_route53_record" "dmarc" {
  count   = var.enable_dmarc_record ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = "_dmarc.${var.domain_name}"
  type    = "TXT"
  ttl     = 300
  records = ["v=DMARC1; p=quarantine; rua=mailto:dmarc@${var.domain_name}"]
}

# Certificate for Metabase (separate certificate for EC2 deployment)
resource "aws_acm_certificate" "metabase" {
  count             = var.create_metabase_certificate ? 1 : 0
  domain_name       = "bi.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-metabase-ssl-certificate"
    Type = "SSL"
  })
}

# DNS validation for Metabase certificate
resource "aws_route53_record" "metabase_ssl_validation" {
  for_each = var.create_metabase_certificate ? {
    for dvo in aws_acm_certificate.metabase[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.hosted_zone_id
}

# Metabase certificate validation
resource "aws_acm_certificate_validation" "metabase" {
  count                   = var.create_metabase_certificate ? 1 : 0
  certificate_arn         = aws_acm_certificate.metabase[0].arn
  validation_record_fqdns = [for record in aws_route53_record.metabase_ssl_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# CloudWatch Log Group for DNS query logging
resource "aws_cloudwatch_log_group" "dns_logs" {
  count             = var.enable_dns_logging ? 1 : 0
  name              = "/aws/route53/${var.project_name}-${var.environment}"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-dns-logs"
    Type = "Logging"
  })
}

# DNS query logging configuration
resource "aws_route53_query_log" "main" {
  count                    = var.enable_dns_logging ? 1 : 0
  depends_on               = [aws_cloudwatch_log_group.dns_logs]
  destination_arn          = aws_cloudwatch_log_group.dns_logs[0].arn
  zone_id                  = local.hosted_zone_id
}

# IAM role for Route53 query logging
resource "aws_iam_role" "route53_query_logging" {
  count = var.enable_dns_logging ? 1 : 0
  name  = "${var.project_name}-${var.environment}-route53-query-logging"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "route53.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# IAM policy for Route53 query logging
resource "aws_iam_role_policy" "route53_query_logging" {
  count = var.enable_dns_logging ? 1 : 0
  name  = "${var.project_name}-${var.environment}-route53-query-logging-policy"
  role  = aws_iam_role.route53_query_logging[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = aws_cloudwatch_log_group.dns_logs[0].arn
      }
    ]
  })
}

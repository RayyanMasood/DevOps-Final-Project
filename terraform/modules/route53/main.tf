# Route53 Module
# This module creates DNS records for the application

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  full_domain = var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name
}

# Data source to get the hosted zone
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# A record pointing to the Application Load Balancer
resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.full_domain
  type    = "A"

  alias {
    name                   = var.load_balancer_dns_name
    zone_id                = var.load_balancer_zone_id
    evaluate_target_health = true
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-app-record"
    Type = "Route53 Record"
  })
}

# AAAA record for IPv6 support (optional)
resource "aws_route53_record" "app_ipv6" {
  count = var.enable_ipv6 ? 1 : 0

  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.full_domain
  type    = "AAAA"

  alias {
    name                   = var.load_balancer_dns_name
    zone_id                = var.load_balancer_zone_id
    evaluate_target_health = true
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-app-ipv6-record"
    Type = "Route53 IPv6 Record"
  })
}

# Health check for the domain (optional)
resource "aws_route53_health_check" "app" {
  count = var.enable_health_check ? 1 : 0

  fqdn                            = local.full_domain
  port                            = var.certificate_arn != "" ? 443 : 80
  type                            = var.certificate_arn != "" ? "HTTPS" : "HTTP"
  resource_path                   = var.health_check_path
  failure_threshold               = 3
  request_interval                = 30
  cloudwatch_logs_region          = data.aws_region.current.name
  cloudwatch_alarm_region         = data.aws_region.current.name
  insufficient_data_health_status = "Failure"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-health-check"
    Type = "Route53 Health Check"
  })
}

# CloudWatch Alarm for Route53 Health Check
resource "aws_cloudwatch_metric_alarm" "route53_health_check" {
  count = var.enable_health_check ? 1 : 0

  alarm_name          = "${local.name_prefix}-route53-health-check"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "This metric monitors Route53 health check status"
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.app[0].id
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-route53-health-alarm"
    Type = "CloudWatch Alarm"
  })
}

# Data source for AWS region
data "aws_region" "current" {}

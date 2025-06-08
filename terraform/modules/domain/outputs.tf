# Domain Module Outputs

output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = local.hosted_zone_id
}

output "hosted_zone_name_servers" {
  description = "Name servers for the hosted zone"
  value       = local.hosted_zone.name_servers
}

output "ssl_certificate_arn" {
  description = "ARN of the main SSL certificate"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "metabase_certificate_arn" {
  description = "ARN of the Metabase SSL certificate"
  value       = var.create_metabase_certificate ? aws_acm_certificate_validation.metabase[0].certificate_arn : ""
}

output "domain_name" {
  description = "Primary domain name"
  value       = var.domain_name
}

output "app_fqdn" {
  description = "FQDN for the main application"
  value       = aws_route53_record.app.fqdn
}

output "bi_fqdn" {
  description = "FQDN for the BI tool"
  value       = aws_route53_record.bi.fqdn
}

output "api_fqdn" {
  description = "FQDN for the API"
  value       = aws_route53_record.api.fqdn
}

output "admin_fqdn" {
  description = "FQDN for the admin interface"
  value       = aws_route53_record.admin.fqdn
}

output "health_check_ids" {
  description = "Route53 health check IDs"
  value = {
    app = aws_route53_health_check.app.id
    bi  = aws_route53_health_check.bi.id
  }
}

output "cloudwatch_alarm_arns" {
  description = "CloudWatch alarm ARNs for health checks"
  value = {
    app_health = aws_cloudwatch_metric_alarm.app_health.arn
    bi_health  = aws_cloudwatch_metric_alarm.bi_health.arn
  }
}

output "dns_records" {
  description = "Created DNS records"
  value = {
    app   = aws_route53_record.app.name
    bi    = aws_route53_record.bi.name
    api   = aws_route53_record.api.name
    admin = aws_route53_record.admin.name
    root  = aws_route53_record.root.name
  }
}

output "ssl_certificate_status" {
  description = "SSL certificate validation status"
  value       = aws_acm_certificate_validation.main.certificate_arn != "" ? "validated" : "pending"
}

output "ssl_certificate_domain_validation_options" {
  description = "Domain validation options for SSL certificate"
  value       = aws_acm_certificate.main.domain_validation_options
}

output "dns_log_group_name" {
  description = "CloudWatch log group name for DNS query logging"
  value       = var.enable_dns_logging ? aws_cloudwatch_log_group.dns_logs[0].name : ""
}

output "dns_log_group_arn" {
  description = "CloudWatch log group ARN for DNS query logging"
  value       = var.enable_dns_logging ? aws_cloudwatch_log_group.dns_logs[0].arn : ""
}

output "subdomains" {
  description = "All configured subdomains"
  value = {
    app   = "app.${var.domain_name}"
    bi    = "bi.${var.domain_name}"
    api   = "api.${var.domain_name}"
    admin = "admin.${var.domain_name}"
  }
}

output "certificate_details" {
  description = "SSL certificate details"
  value = {
    main_certificate = {
      arn                = aws_acm_certificate.main.arn
      domain_name        = aws_acm_certificate.main.domain_name
      subject_alternative_names = aws_acm_certificate.main.subject_alternative_names
      validation_method  = aws_acm_certificate.main.validation_method
      status            = aws_acm_certificate.main.status
    }
    metabase_certificate = var.create_metabase_certificate ? {
      arn           = aws_acm_certificate.metabase[0].arn
      domain_name   = aws_acm_certificate.metabase[0].domain_name
      validation_method = aws_acm_certificate.metabase[0].validation_method
      status        = aws_acm_certificate.metabase[0].status
    } : null
  }
}

output "health_check_urls" {
  description = "Health check URLs"
  value = {
    app = "https://app.${var.domain_name}/health"
    bi  = "https://bi.${var.domain_name}/api/health"
  }
}

output "dns_validation_records" {
  description = "DNS validation records for SSL certificates"
  value = {
    for record in aws_route53_record.ssl_validation : record.name => {
      name    = record.name
      type    = record.type
      records = record.records
      ttl     = record.ttl
    }
  }
}

output "route53_zone_arn" {
  description = "Route53 hosted zone ARN"
  value       = local.hosted_zone.arn
}

output "route53_zone_comment" {
  description = "Route53 hosted zone comment"
  value       = local.hosted_zone.comment
}

output "ssl_security_policy" {
  description = "SSL security policy used"
  value       = var.ssl_policy
}

output "domain_configuration_summary" {
  description = "Summary of domain configuration"
  value = {
    domain_name              = var.domain_name
    hosted_zone_created      = var.create_hosted_zone
    ssl_certificates_created = var.create_metabase_certificate ? 2 : 1
    health_checks_enabled    = var.enable_health_checks
    dns_logging_enabled      = var.enable_dns_logging
    subdomains_configured    = 4
  }
}

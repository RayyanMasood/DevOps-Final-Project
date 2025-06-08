# Route53 Module Outputs

output "hosted_zone_id" {
  description = "ID of the Route53 hosted zone"
  value       = data.aws_route53_zone.main.zone_id
}

output "hosted_zone_name" {
  description = "Name of the Route53 hosted zone"
  value       = data.aws_route53_zone.main.name
}

output "record_name" {
  description = "Name of the DNS record created"
  value       = aws_route53_record.app.name
}

output "record_fqdn" {
  description = "FQDN of the DNS record created"
  value       = aws_route53_record.app.fqdn
}

output "record_type" {
  description = "Type of the DNS record created"
  value       = aws_route53_record.app.type
}

output "ipv6_record_name" {
  description = "Name of the IPv6 DNS record created"
  value       = var.enable_ipv6 ? aws_route53_record.app_ipv6[0].name : null
}

output "health_check_id" {
  description = "ID of the Route53 health check"
  value       = var.enable_health_check ? aws_route53_health_check.app[0].id : null
}

output "health_check_arn" {
  description = "ARN of the Route53 health check"
  value       = var.enable_health_check ? aws_route53_health_check.app[0].arn : null
}

output "health_check_alarm_arn" {
  description = "ARN of the health check CloudWatch alarm"
  value       = var.enable_health_check ? aws_cloudwatch_metric_alarm.route53_health_check[0].arn : null
}

output "domain_configuration" {
  description = "Summary of domain configuration"
  value = {
    domain_name      = var.domain_name
    subdomain        = var.subdomain
    full_domain      = local.full_domain
    record_name      = aws_route53_record.app.name
    ipv6_enabled     = var.enable_ipv6
    health_check_enabled = var.enable_health_check
  }
}

# Full domain for easy reference
output "full_domain_name" {
  description = "Full domain name (subdomain.domain)"
  value       = local.full_domain
}

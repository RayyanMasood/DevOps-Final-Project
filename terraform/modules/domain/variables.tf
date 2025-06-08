# Domain Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name for the application"
  type        = string
}

variable "create_hosted_zone" {
  description = "Whether to create a new hosted zone or use existing"
  type        = bool
  default     = true
}

variable "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  type        = string
}

variable "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "sns_alarm_arn" {
  description = "SNS topic ARN for health check alarms"
  type        = string
  default     = ""
}

variable "mx_records" {
  description = "MX records for email (priority value)"
  type        = list(string)
  default     = []
}

variable "domain_verification_txt" {
  description = "TXT record for domain verification"
  type        = string
  default     = ""
}

variable "enable_spf_record" {
  description = "Enable SPF record for email security"
  type        = bool
  default     = false
}

variable "enable_dmarc_record" {
  description = "Enable DMARC record for email security"
  type        = bool
  default     = false
}

variable "create_metabase_certificate" {
  description = "Whether to create a separate certificate for Metabase"
  type        = bool
  default     = false
}

variable "enable_dns_logging" {
  description = "Enable DNS query logging"
  type        = bool
  default     = false
}

variable "subdomain_configurations" {
  description = "Configuration for additional subdomains"
  type = map(object({
    target_type = string # "alb" or "ip"
    target      = string # ALB DNS name or IP address
    zone_id     = string # ALB zone ID (if applicable)
  }))
  default = {}
}

variable "enable_health_checks" {
  description = "Enable Route53 health checks"
  type        = bool
  default     = true
}

variable "health_check_config" {
  description = "Configuration for health checks"
  type = object({
    failure_threshold  = number
    request_interval   = number
    resource_path      = string
    measure_latency    = bool
  })
  default = {
    failure_threshold  = 3
    request_interval   = 30
    resource_path      = "/health"
    measure_latency    = true
  }
}

variable "certificate_transparency_logging" {
  description = "Enable certificate transparency logging"
  type        = bool
  default     = true
}

variable "ssl_policy" {
  description = "SSL security policy for ALB"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

variable "redirect_www_to_apex" {
  description = "Redirect www subdomain to apex domain"
  type        = bool
  default     = true
}

variable "enable_dnssec" {
  description = "Enable DNSSEC for the hosted zone"
  type        = bool
  default     = false
}

variable "ttl_values" {
  description = "TTL values for different record types"
  type = object({
    a_record     = number
    cname_record = number
    txt_record   = number
    mx_record    = number
  })
  default = {
    a_record     = 300
    cname_record = 300
    txt_record   = 300
    mx_record    = 300
  }
}

variable "backup_dns_servers" {
  description = "Backup DNS servers for failover"
  type        = list(string)
  default     = []
}

variable "geo_routing_policy" {
  description = "Enable geo-routing policy for DNS records"
  type        = bool
  default     = false
}

variable "weighted_routing_policy" {
  description = "Enable weighted routing policy for DNS records"
  type        = bool
  default     = false
}

variable "latency_routing_policy" {
  description = "Enable latency-based routing policy"
  type        = bool
  default     = false
}

variable "custom_ssl_certificate_arn" {
  description = "ARN of custom SSL certificate (if not using ACM generated)"
  type        = string
  default     = ""
}

variable "domain_validation_options" {
  description = "Custom domain validation options"
  type = map(object({
    domain_name           = string
    validation_method     = string
    validation_record_ttl = number
  }))
  default = {}
}

variable "enable_caa_record" {
  description = "Enable CAA record for certificate authority authorization"
  type        = bool
  default     = true
}

variable "caa_records" {
  description = "CAA records for certificate authority authorization"
  type        = list(string)
  default = [
    "0 issue \"amazon.com\"",
    "0 issue \"amazontrust.com\"",
    "0 issue \"awstrust.com\"",
    "0 issue \"amazonaws.com\""
  ]
}

variable "monitoring_config" {
  description = "Configuration for domain monitoring and alerting"
  type = object({
    enable_ssl_monitoring     = bool
    ssl_expiry_alarm_days     = number
    enable_dns_monitoring     = bool
    dns_query_alarm_threshold = number
  })
  default = {
    enable_ssl_monitoring     = true
    ssl_expiry_alarm_days     = 30
    enable_dns_monitoring     = true
    dns_query_alarm_threshold = 1000
  }
}

variable "backup_certificates" {
  description = "Configuration for backup SSL certificates"
  type = object({
    enable_backup_certs = bool
    backup_domains      = list(string)
    backup_region       = string
  })
  default = {
    enable_backup_certs = false
    backup_domains      = []
    backup_region       = ""
  }
}

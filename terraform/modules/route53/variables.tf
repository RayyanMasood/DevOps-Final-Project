# Route53 Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "The domain name for the application"
  type        = string
}

variable "subdomain" {
  description = "Subdomain for the application (e.g., 'app' for app.domain.com)"
  type        = string
  default     = "app"
}

variable "load_balancer_dns_name" {
  description = "DNS name of the Application Load Balancer"
  type        = string
}

variable "load_balancer_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate (used to determine protocol for health checks)"
  type        = string
  default     = ""
}

variable "health_check_path" {
  description = "Path for Route53 health checks"
  type        = string
  default     = "/health"
}

variable "enable_health_check" {
  description = "Enable Route53 health check for the domain"
  type        = bool
  default     = false
}

variable "enable_ipv6" {
  description = "Enable IPv6 support (AAAA record)"
  type        = bool
  default     = false
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for health check alarm notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

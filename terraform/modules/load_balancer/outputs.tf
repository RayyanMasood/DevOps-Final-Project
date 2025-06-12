# Load Balancer Module Outputs

output "load_balancer_id" {
  description = "ID of the Application Load Balancer"
  value       = aws_lb.main.id
}

output "load_balancer_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "load_balancer_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer"
  value       = aws_lb.main.arn_suffix
}

output "load_balancer_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "target_group_id" {
  description = "ID of the target group"
  value       = aws_lb_target_group.app.id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.app.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group"
  value       = aws_lb_target_group.app.arn_suffix
}

output "target_group_name" {
  description = "Name of the target group"
  value       = aws_lb_target_group.app.name
}

# Metabase Target Group Outputs
output "metabase_target_group_id" {
  description = "ID of the Metabase target group"
  value       = aws_lb_target_group.metabase.id
}

output "metabase_target_group_arn" {
  description = "ARN of the Metabase target group"
  value       = aws_lb_target_group.metabase.arn
}

output "metabase_target_group_arn_suffix" {
  description = "ARN suffix of the Metabase target group"
  value       = aws_lb_target_group.metabase.arn_suffix
}

output "metabase_target_group_name" {
  description = "Name of the Metabase target group"
  value       = aws_lb_target_group.metabase.name
}

# Listener Outputs
output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = var.certificate_arn != "" ? aws_lb_listener.https[0].arn : null
}

# S3 Bucket for Access Logs
output "alb_logs_bucket_id" {
  description = "ID of the S3 bucket for ALB access logs"
  value       = aws_s3_bucket.alb_logs.id
}

output "alb_logs_bucket_arn" {
  description = "ARN of the S3 bucket for ALB access logs"
  value       = aws_s3_bucket.alb_logs.arn
}

# WAF Outputs (conditional)
output "waf_web_acl_id" {
  description = "ID of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].id : null
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : null
}

# CloudWatch Alarm Outputs
output "response_time_alarm_arn" {
  description = "ARN of the response time CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.alb_target_response_time.arn
}

output "unhealthy_targets_alarm_arn" {
  description = "ARN of the unhealthy targets CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.alb_unhealthy_targets.arn
}

# Load Balancer Configuration Summary
output "load_balancer_summary" {
  description = "Summary of load balancer configuration"
  value = {
    dns_name          = aws_lb.main.dns_name
    zone_id          = aws_lb.main.zone_id
    type             = aws_lb.main.load_balancer_type
    https_enabled    = var.certificate_arn != ""
    waf_enabled      = var.enable_waf
    deletion_protection = aws_lb.main.enable_deletion_protection
  }
}

# Target Group Configuration Summary
output "target_group_summary" {
  description = "Summary of target group configuration"
  value = {
    name                = aws_lb_target_group.app.name
    port                = aws_lb_target_group.app.port
    protocol            = aws_lb_target_group.app.protocol
    health_check_path   = aws_lb_target_group.app.health_check[0].path
    health_check_interval = aws_lb_target_group.app.health_check[0].interval
    healthy_threshold   = aws_lb_target_group.app.health_check[0].healthy_threshold
    unhealthy_threshold = aws_lb_target_group.app.health_check[0].unhealthy_threshold
  }
}

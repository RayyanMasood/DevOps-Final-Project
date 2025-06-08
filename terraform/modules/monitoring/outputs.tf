# Monitoring Module Outputs

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = var.alarm_email != "" ? aws_sns_topic.alerts[0].arn : null
}

output "sns_topic_name" {
  description = "Name of the SNS topic for alerts"
  value       = var.alarm_email != "" ? aws_sns_topic.alerts[0].name : null
}

# CloudWatch Alarm ARNs
output "high_cpu_alarm_arn" {
  description = "ARN of the high CPU utilization alarm"
  value       = aws_cloudwatch_metric_alarm.high_cpu.arn
}

output "high_memory_alarm_arn" {
  description = "ARN of the high memory utilization alarm"
  value       = aws_cloudwatch_metric_alarm.high_memory.arn
}

output "high_4xx_errors_alarm_arn" {
  description = "ARN of the high 4xx errors alarm"
  value       = aws_cloudwatch_metric_alarm.high_4xx_errors.arn
}

output "high_5xx_errors_alarm_arn" {
  description = "ARN of the high 5xx errors alarm"
  value       = aws_cloudwatch_metric_alarm.high_5xx_errors.arn
}

output "low_healthy_hosts_alarm_arn" {
  description = "ARN of the low healthy hosts alarm"
  value       = aws_cloudwatch_metric_alarm.low_healthy_hosts.arn
}

output "high_response_time_alarm_arn" {
  description = "ARN of the high response time alarm"
  value       = aws_cloudwatch_metric_alarm.high_response_time.arn
}

output "overall_health_alarm_arn" {
  description = "ARN of the overall health composite alarm"
  value       = aws_cloudwatch_composite_alarm.overall_health.arn
}

# CloudWatch Log Group ARNs
output "ec2_messages_log_group_arn" {
  description = "ARN of the EC2 messages log group"
  value       = aws_cloudwatch_log_group.ec2_messages.arn
}

output "ec2_user_data_log_group_arn" {
  description = "ARN of the EC2 user data log group"
  value       = aws_cloudwatch_log_group.ec2_user_data.arn
}

output "application_log_group_arn" {
  description = "ARN of the application log group"
  value       = aws_cloudwatch_log_group.application.arn
}

# Monitoring Summary
output "monitoring_summary" {
  description = "Summary of monitoring configuration"
  value = {
    dashboard_name        = aws_cloudwatch_dashboard.main.dashboard_name
    sns_notifications    = var.alarm_email != ""
    alarm_email         = var.alarm_email
    high_cpu_threshold  = var.high_cpu_threshold
    high_memory_threshold = var.high_memory_threshold
    total_alarms        = 7
    log_groups_created  = 3
  }
}

# All alarm names for reference
output "alarm_names" {
  description = "List of all CloudWatch alarm names"
  value = [
    aws_cloudwatch_metric_alarm.high_cpu.alarm_name,
    aws_cloudwatch_metric_alarm.high_memory.alarm_name,
    aws_cloudwatch_metric_alarm.high_4xx_errors.alarm_name,
    aws_cloudwatch_metric_alarm.high_5xx_errors.alarm_name,
    aws_cloudwatch_metric_alarm.low_healthy_hosts.alarm_name,
    aws_cloudwatch_metric_alarm.high_response_time.alarm_name,
    aws_cloudwatch_composite_alarm.overall_health.alarm_name
  ]
}

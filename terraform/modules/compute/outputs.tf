# Compute Module Outputs

output "auto_scaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

output "auto_scaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.arn
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.app.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.app.latest_version
}

output "launch_template_arn" {
  description = "ARN of the launch template"
  value       = aws_launch_template.app.arn
}

output "iam_role_name" {
  description = "Name of the IAM role attached to EC2 instances"
  value       = aws_iam_role.ec2_role.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to EC2 instances"
  value       = aws_iam_role.ec2_role.arn
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "iam_instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = aws_iam_instance_profile.ec2_profile.arn
}

# Scaling Policy Outputs
output "scale_up_policy_arn" {
  description = "ARN of the scale up policy"
  value       = aws_autoscaling_policy.scale_up.arn
}

output "scale_down_policy_arn" {
  description = "ARN of the scale down policy"
  value       = aws_autoscaling_policy.scale_down.arn
}

output "cpu_target_tracking_policy_arn" {
  description = "ARN of the CPU target tracking policy"
  value       = aws_autoscaling_policy.cpu_target_tracking.arn
}

output "request_count_target_tracking_policy_arn" {
  description = "ARN of the request count target tracking policy"
  value       = aws_autoscaling_policy.request_count_target_tracking.arn
}

# CloudWatch Alarm Outputs
output "high_cpu_alarm_arn" {
  description = "ARN of the high CPU alarm"
  value       = aws_cloudwatch_metric_alarm.high_cpu.arn
}

output "low_cpu_alarm_arn" {
  description = "ARN of the low CPU alarm"
  value       = aws_cloudwatch_metric_alarm.low_cpu.arn
}

# Auto Scaling Group Configuration Summary
output "asg_configuration" {
  description = "Auto Scaling Group configuration summary"
  value = {
    name               = aws_autoscaling_group.app.name
    min_size          = aws_autoscaling_group.app.min_size
    max_size          = aws_autoscaling_group.app.max_size
    desired_capacity  = aws_autoscaling_group.app.desired_capacity
    health_check_type = aws_autoscaling_group.app.health_check_type
    health_check_grace_period = aws_autoscaling_group.app.health_check_grace_period
  }
}

# Launch Template Configuration Summary
output "launch_template_configuration" {
  description = "Launch template configuration summary"
  value = {
    id           = aws_launch_template.app.id
    name         = aws_launch_template.app.name
    instance_type = aws_launch_template.app.instance_type
    image_id     = aws_launch_template.app.image_id
    key_name     = aws_launch_template.app.key_name
  }
}

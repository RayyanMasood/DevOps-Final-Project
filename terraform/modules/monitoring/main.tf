# Monitoring Module
# This module creates CloudWatch dashboards, alarms, and SNS notifications

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# SNS Topic for Alarm Notifications
resource "aws_sns_topic" "alerts" {
  count = var.alarm_email != "" ? 1 : 0

  name = "${local.name_prefix}-alerts"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-alerts"
    Type = "SNS Topic"
  })
}

# SNS Topic Subscription
resource "aws_sns_topic_subscription" "email_alerts" {
  count = var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.load_balancer_arn_suffix],
            [".", "TargetResponseTime", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Load Balancer Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/AutoScaling", "GroupMinSize", "AutoScalingGroupName", var.auto_scaling_group_name],
            [".", "GroupMaxSize", ".", "."],
            [".", "GroupDesiredCapacity", ".", "."],
            [".", "GroupInServiceInstances", ".", "."],
            [".", "GroupTotalInstances", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Auto Scaling Group Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.auto_scaling_group_name],
            ["CWAgent", "mem_used_percent", "AutoScalingGroupName", var.auto_scaling_group_name],
            [".", "disk_used_percent", "AutoScalingGroupName", var.auto_scaling_group_name, "device", "/dev/xvda1", "fstype", "xfs", "path", "/"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "EC2 Instance Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.load_balancer_arn_suffix],
            [".", "UnHealthyHostCount", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Target Group Health"
          period  = 300
        }
      }
    ]
  })

  # CloudWatch dashboards don't support tags
}

# High CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${local.name_prefix}-high-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.high_cpu_threshold
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = var.alarm_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    AutoScalingGroupName = var.auto_scaling_group_name
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-high-cpu-alarm"
    Type = "CloudWatch Alarm"
  })
}

# High Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${local.name_prefix}-high-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = var.high_memory_threshold
  alarm_description   = "This metric monitors memory utilization"
  alarm_actions       = var.alarm_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    AutoScalingGroupName = var.auto_scaling_group_name
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-high-memory-alarm"
    Type = "CloudWatch Alarm"
  })
}

# High 4xx Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "high_4xx_errors" {
  alarm_name          = "${local.name_prefix}-high-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "This metric monitors 4xx error rate"
  alarm_actions       = var.alarm_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    LoadBalancer = var.load_balancer_arn_suffix
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-high-4xx-errors-alarm"
    Type = "CloudWatch Alarm"
  })
}

# High 5xx Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "high_5xx_errors" {
  alarm_name          = "${local.name_prefix}-high-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors 5xx error rate"
  alarm_actions       = var.alarm_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    LoadBalancer = var.load_balancer_arn_suffix
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-high-5xx-errors-alarm"
    Type = "CloudWatch Alarm"
  })
}

# Low Healthy Host Count Alarm
resource "aws_cloudwatch_metric_alarm" "low_healthy_hosts" {
  alarm_name          = "${local.name_prefix}-low-healthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "2"
  alarm_description   = "This metric monitors healthy host count"
  alarm_actions       = var.alarm_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.load_balancer_arn_suffix
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-low-healthy-hosts-alarm"
    Type = "CloudWatch Alarm"
  })
}

# High Response Time Alarm
resource "aws_cloudwatch_metric_alarm" "high_response_time" {
  alarm_name          = "${local.name_prefix}-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "2"
  alarm_description   = "This metric monitors target response time"
  alarm_actions       = var.alarm_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    LoadBalancer = var.load_balancer_arn_suffix
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-high-response-time-alarm"
    Type = "CloudWatch Alarm"
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "ec2_messages" {
  name              = "/aws/ec2/${local.name_prefix}/var/log/messages"
  retention_in_days = 14

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ec2-messages-log-group"
    Type = "CloudWatch Log Group"
  })
}

resource "aws_cloudwatch_log_group" "ec2_user_data" {
  name              = "/aws/ec2/${local.name_prefix}/user-data"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ec2-user-data-log-group"
    Type = "CloudWatch Log Group"
  })
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/ec2/${local.name_prefix}/application"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-application-log-group"
    Type = "CloudWatch Log Group"
  })
}

# CloudWatch Composite Alarm for Overall Health
resource "aws_cloudwatch_composite_alarm" "overall_health" {
  alarm_name        = "${local.name_prefix}-overall-health"
  alarm_description = "Composite alarm for overall application health"

  alarm_rule = join(" OR ", [
    "ALARM(${aws_cloudwatch_metric_alarm.high_cpu.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.high_memory.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.high_5xx_errors.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.low_healthy_hosts.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.high_response_time.alarm_name})"
  ])

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-overall-health-alarm"
    Type = "CloudWatch Composite Alarm"
  })
}

# Data source for AWS region
data "aws_region" "current" {}

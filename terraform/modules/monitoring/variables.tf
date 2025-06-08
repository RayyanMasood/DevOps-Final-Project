# Monitoring Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "auto_scaling_group_name" {
  description = "Name of the Auto Scaling Group to monitor"
  type        = string
}

variable "load_balancer_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the Target Group"
  type        = string
}

# Alarm Thresholds
variable "high_cpu_threshold" {
  description = "CPU utilization threshold for high CPU alarm"
  type        = number
  default     = 80
}

variable "high_memory_threshold" {
  description = "Memory utilization threshold for high memory alarm"
  type        = number
  default     = 80
}

variable "alarm_email" {
  description = "Email address to receive alarm notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

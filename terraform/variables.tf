# Variables Definition
# This file contains all input variables for the DevOps infrastructure project
# All variables include descriptions, types, and validation rules where appropriate

# ========================================
# Global Configuration Variables
# ========================================

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be in the format: us-east-1, eu-west-1, etc."
  }
}

variable "project_name" {
  description = "Name of the project used for resource naming and tagging"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
  
  validation {
    condition     = length(var.project_name) >= 3 && length(var.project_name) <= 30
    error_message = "Project name must be between 3 and 30 characters long."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Owner of the resources for tagging purposes"
  type        = string
  default     = "DevOps Team"
}

variable "cost_center" {
  description = "Cost center for billing and resource allocation"
  type        = string
  default     = "Engineering"
}

# ========================================
# Networking Configuration
# ========================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

# ========================================
# Security Configuration
# ========================================

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the infrastructure"
  type        = list(string)
  default     = ["0.0.0.0/0"]
  
  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid IPv4 CIDR blocks."
  }
}

variable "office_ip_addresses" {
  description = "List of office IP addresses for SSH access to bastion host"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for ip in var.office_ip_addresses : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", ip))
    ])
    error_message = "All office IP addresses must be valid CIDR blocks (e.g., 203.0.113.1/32)."
  }
}

variable "key_name" {
  description = "Name of the AWS key pair for EC2 instance access"
  type        = string
  
  validation {
    condition     = length(var.key_name) > 0
    error_message = "Key name cannot be empty."
  }
}

# ========================================
# Compute Configuration (EC2 & Auto Scaling)
# ========================================

variable "instance_type" {
  description = "EC2 instance type for the application servers"
  type        = string
  default     = "t3.medium"
  
  validation {
    condition = contains([
      "t3.micro", "t3.small", "t3.medium", "t3.large", "t3.xlarge",
      "t2.micro", "t2.small", "t2.medium", "t2.large",
      "m5.large", "m5.xlarge", "m5.2xlarge"
    ], var.instance_type)
    error_message = "Instance type must be a valid EC2 instance type suitable for web applications."
  }
}

variable "asg_min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 2
  
  validation {
    condition     = var.asg_min_size >= 1 && var.asg_min_size <= 10
    error_message = "ASG minimum size must be between 1 and 10."
  }
}

variable "asg_max_size" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 6
  
  validation {
    condition     = var.asg_max_size >= 2 && var.asg_max_size <= 20
    error_message = "ASG maximum size must be between 2 and 20."
  }
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
  default     = 3
  
  validation {
    condition     = var.asg_desired_capacity >= 1 && var.asg_desired_capacity <= 15
    error_message = "ASG desired capacity must be between 1 and 15."
  }
}

variable "health_check_grace_period" {
  description = "Time (in seconds) after instance comes into service before checking health"
  type        = number
  default     = 300
  
  validation {
    condition     = var.health_check_grace_period >= 60 && var.health_check_grace_period <= 3600
    error_message = "Health check grace period must be between 60 and 3600 seconds."
  }
}

variable "health_check_type" {
  description = "Type of health check for Auto Scaling Group (EC2 or ELB)"
  type        = string
  default     = "ELB"
  
  validation {
    condition     = contains(["EC2", "ELB"], var.health_check_type)
    error_message = "Health check type must be either 'EC2' or 'ELB'."
  }
}

# ========================================
# Auto Scaling Policies
# ========================================

variable "target_cpu_utilization" {
  description = "Target CPU utilization percentage for auto scaling"
  type        = number
  default     = 70
  
  validation {
    condition     = var.target_cpu_utilization >= 20 && var.target_cpu_utilization <= 90
    error_message = "Target CPU utilization must be between 20 and 90 percent."
  }
}

variable "target_request_count" {
  description = "Target request count per instance for auto scaling"
  type        = number
  default     = 1000
  
  validation {
    condition     = var.target_request_count >= 100 && var.target_request_count <= 5000
    error_message = "Target request count must be between 100 and 5000 requests per minute."
  }
}

# ========================================
# Database Configuration (RDS)
# ========================================

# MySQL Configuration
variable "mysql_instance_class" {
  description = "RDS instance class for MySQL database"
  type        = string
  default     = "db.t3.micro"
  
  validation {
    condition = contains([
      "db.t3.micro", "db.t3.small", "db.t3.medium", "db.t3.large",
      "db.r5.large", "db.r5.xlarge", "db.r5.2xlarge"
    ], var.mysql_instance_class)
    error_message = "MySQL instance class must be a valid RDS instance type."
  }
}

variable "mysql_allocated_storage" {
  description = "Allocated storage for MySQL database in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.mysql_allocated_storage >= 20 && var.mysql_allocated_storage <= 1000
    error_message = "MySQL allocated storage must be between 20 and 1000 GB."
  }
}

variable "mysql_engine_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0"
}

variable "mysql_database_name" {
  description = "Name of the MySQL database"
  type        = string
  default     = "appdb"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.mysql_database_name))
    error_message = "MySQL database name must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "mysql_username" {
  description = "Master username for MySQL database"
  type        = string
  default     = "admin"
  
  validation {
    condition     = length(var.mysql_username) >= 4 && length(var.mysql_username) <= 16
    error_message = "MySQL username must be between 4 and 16 characters."
  }
}

variable "mysql_password" {
  description = "Master password for MySQL database"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.mysql_password) >= 8 && length(var.mysql_password) <= 41
    error_message = "MySQL password must be between 8 and 41 characters."
  }
}

# PostgreSQL Configuration
variable "postgres_instance_class" {
  description = "RDS instance class for PostgreSQL database"
  type        = string
  default     = "db.t3.micro"
  
  validation {
    condition = contains([
      "db.t3.micro", "db.t3.small", "db.t3.medium", "db.t3.large",
      "db.r5.large", "db.r5.xlarge", "db.r5.2xlarge"
    ], var.postgres_instance_class)
    error_message = "PostgreSQL instance class must be a valid RDS instance type."
  }
}

variable "postgres_allocated_storage" {
  description = "Allocated storage for PostgreSQL database in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.postgres_allocated_storage >= 20 && var.postgres_allocated_storage <= 1000
    error_message = "PostgreSQL allocated storage must be between 20 and 1000 GB."
  }
}

variable "postgres_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "postgres_database_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "appdb"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.postgres_database_name))
    error_message = "PostgreSQL database name must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "postgres_username" {
  description = "Master username for PostgreSQL database"
  type        = string
  default     = "postgres"
  
  validation {
    condition     = length(var.postgres_username) >= 4 && length(var.postgres_username) <= 16
    error_message = "PostgreSQL username must be between 4 and 16 characters."
  }
}

variable "postgres_password" {
  description = "Master password for PostgreSQL database"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.postgres_password) >= 8 && length(var.postgres_password) <= 128
    error_message = "PostgreSQL password must be between 8 and 128 characters."
  }
}

# Database Backup and Maintenance
variable "backup_retention_period" {
  description = "Number of days to retain database backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "Backup retention period must be between 1 and 35 days."
  }
}

variable "backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
  
  validation {
    condition     = can(regex("^[0-2][0-9]:[0-5][0-9]-[0-2][0-9]:[0-5][0-9]$", var.backup_window))
    error_message = "Backup window must be in the format HH:MM-HH:MM (24-hour UTC)."
  }
}

variable "maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
  
  validation {
    condition = can(regex("^(sun|mon|tue|wed|thu|fri|sat):[0-2][0-9]:[0-5][0-9]-(sun|mon|tue|wed|thu|fri|sat):[0-2][0-9]:[0-5][0-9]$", var.maintenance_window))
    error_message = "Maintenance window must be in the format ddd:HH:MM-ddd:HH:MM."
  }
}

# ========================================
# Load Balancer Configuration
# ========================================

variable "domain_name" {
  description = "Domain name for the application (leave empty to skip domain setup)"
  type        = string
  default     = ""
}

variable "create_hosted_zone" {
  description = "Whether to create a new hosted zone or use existing"
  type        = bool
  default     = true
}

variable "certificate_arn" {
  description = "ARN of existing SSL certificate (leave empty to auto-generate with ACM)"
  type        = string
  default     = ""
}

variable "enable_health_checks" {
  description = "Enable Route53 health checks"
  type        = bool
  default     = true
}

variable "enable_dns_logging" {
  description = "Enable DNS query logging"
  type        = bool
  default     = false
}

variable "create_metabase_certificate" {
  description = "Whether to create a separate certificate for Metabase"
  type        = bool
  default     = true
}

variable "ssl_policy" {
  description = "SSL security policy for ALB"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

variable "mx_records" {
  description = "MX records for email (priority value)"
  type        = list(string)
  default     = []
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

variable "domain_verification_txt" {
  description = "TXT record for domain verification"
  type        = string
  default     = ""
}

variable "health_check_path" {
  description = "Health check path for the load balancer target group"
  type        = string
  default     = "/health"
  
  validation {
    condition     = can(regex("^/.*", var.health_check_path))
    error_message = "Health check path must start with '/'."
  }
}

variable "health_check_interval" {
  description = "Interval between health checks in seconds"
  type        = number
  default     = 30
  
  validation {
    condition     = var.health_check_interval >= 5 && var.health_check_interval <= 300
    error_message = "Health check interval must be between 5 and 300 seconds."
  }
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
  
  validation {
    condition     = var.health_check_timeout >= 2 && var.health_check_timeout <= 120
    error_message = "Health check timeout must be between 2 and 120 seconds."
  }
}

variable "healthy_threshold" {
  description = "Number of consecutive successful health checks before considering target healthy"
  type        = number
  default     = 2
  
  validation {
    condition     = var.healthy_threshold >= 2 && var.healthy_threshold <= 10
    error_message = "Healthy threshold must be between 2 and 10."
  }
}

variable "unhealthy_threshold" {
  description = "Number of consecutive failed health checks before considering target unhealthy"
  type        = number
  default     = 2
  
  validation {
    condition     = var.unhealthy_threshold >= 2 && var.unhealthy_threshold <= 10
    error_message = "Unhealthy threshold must be between 2 and 10."
  }
}

# ========================================
# Monitoring Configuration
# ========================================

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alarms"
  type        = bool
  default     = true
}

variable "high_cpu_threshold" {
  description = "CPU utilization threshold for high CPU alarm"
  type        = number
  default     = 80
  
  validation {
    condition     = var.high_cpu_threshold >= 50 && var.high_cpu_threshold <= 95
    error_message = "High CPU threshold must be between 50 and 95 percent."
  }
}

variable "high_memory_threshold" {
  description = "Memory utilization threshold for high memory alarm"
  type        = number
  default     = 80
  
  validation {
    condition     = var.high_memory_threshold >= 50 && var.high_memory_threshold <= 95
    error_message = "High memory threshold must be between 50 and 95 percent."
  }
}

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
  default     = ""
  
  validation {
    condition = var.alarm_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.alarm_email))
    error_message = "Alarm email must be a valid email address or empty string."
  }
}

# Staging Environment Configuration
# This file contains staging-specific variable values

# Global Configuration
aws_region   = "us-east-1"
project_name = "devops-final-project"
environment  = "staging"
owner        = "DevOps Team"
cost_center  = "Engineering"

# Networking
vpc_cidr             = "10.1.0.0/16"
enable_dns_hostnames = true
enable_dns_support   = true
enable_nat_gateway   = true  # Enable for staging

# Security
allowed_cidr_blocks = ["0.0.0.0/0"]
office_ip_addresses = [
  # "203.0.113.1/32",  # Add your office IP
]
key_name = "devops-staging-key"  # Update with your key name

# Compute - Medium instances for staging
instance_type        = "t3.medium"
asg_min_size        = 2
asg_max_size        = 4
asg_desired_capacity = 2

# Auto Scaling
health_check_grace_period = 300
health_check_type         = "ELB"
target_cpu_utilization    = 70
target_request_count      = 800

# Database - Small instances for staging
mysql_instance_class        = "db.t3.small"
mysql_allocated_storage     = 20
mysql_engine_version        = "8.0"
mysql_database_name         = "stagingappdb"
mysql_username             = "admin"

postgres_instance_class     = "db.t3.small"
postgres_allocated_storage  = 20
postgres_engine_version     = "15.4"
postgres_database_name      = "stagingappdb"
postgres_username          = "postgres"

# Backup - Standard retention for staging
backup_retention_period = 7
backup_window          = "03:00-04:00"
maintenance_window     = "sun:04:00-sun:05:00"

# Load Balancer
domain_name     = ""  # Set your domain if available
subdomain       = "staging"
certificate_arn = ""  # Set certificate ARN if using HTTPS

# Health Checks
health_check_path     = "/health"
health_check_interval = 30
health_check_timeout  = 5
healthy_threshold     = 2
unhealthy_threshold   = 2

# Monitoring
enable_monitoring     = true
high_cpu_threshold    = 75
high_memory_threshold = 75
alarm_email          = ""  # Set your email for notifications

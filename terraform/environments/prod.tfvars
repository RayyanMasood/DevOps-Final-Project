# Production Environment Configuration
# This file contains production-specific variable values

# Global Configuration
aws_region   = "us-east-1"
project_name = "devops-final-project"
environment  = "prod"
owner        = "DevOps Team"
cost_center  = "Engineering"

# Networking
vpc_cidr             = "10.2.0.0/16"
enable_dns_hostnames = true
enable_dns_support   = true
enable_nat_gateway   = true  # Required for production

# Security
allowed_cidr_blocks = ["0.0.0.0/0"]
office_ip_addresses = [
  # "203.0.113.1/32",  # Office IP
  # "198.51.100.1/32", # Backup office IP
]
key_name = "devops-prod-key"  # Update with your key name

# Compute - Larger instances for production
instance_type        = "t3.large"
asg_min_size        = 3
asg_max_size        = 10
asg_desired_capacity = 5

# Auto Scaling
health_check_grace_period = 300
health_check_type         = "ELB"
target_cpu_utilization    = 70
target_request_count      = 1000

# Database - Production-grade instances
mysql_instance_class        = "db.r5.large"
mysql_allocated_storage     = 100
mysql_engine_version        = "8.0"
mysql_database_name         = "prodappdb"
mysql_username             = "admin"

postgres_instance_class     = "db.r5.large"
postgres_allocated_storage  = 100
postgres_engine_version     = "15.4"
postgres_database_name      = "prodappdb"
postgres_username          = "postgres"

# Backup - Extended retention for production
backup_retention_period = 30
backup_window          = "03:00-04:00"
maintenance_window     = "sun:04:00-sun:05:00"

# Load Balancer
domain_name     = ""  # Set your production domain
subdomain       = "app"
certificate_arn = ""  # Set your SSL certificate ARN

# Health Checks
health_check_path     = "/health"
health_check_interval = 30
health_check_timeout  = 5
healthy_threshold     = 2
unhealthy_threshold   = 2

# Monitoring
enable_monitoring     = true
high_cpu_threshold    = 80
high_memory_threshold = 80
alarm_email          = ""  # Set production admin email

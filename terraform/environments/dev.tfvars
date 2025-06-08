# Development Environment Configuration
# This file contains development-specific variable values

# Global Configuration
aws_region   = "us-east-1"
project_name = "devops-final-project"
environment  = "dev"
owner        = "DevOps Team"
cost_center  = "Engineering"

# Networking
vpc_cidr             = "10.0.0.0/16"
enable_dns_hostnames = true
enable_dns_support   = true
enable_nat_gateway   = false  # Save costs in dev

# Security
allowed_cidr_blocks = ["0.0.0.0/0"]
office_ip_addresses = []  # Add your IP addresses
key_name           = "devops-dev-key"  # Update with your key name

# Compute - Smaller instances for dev
instance_type        = "t3.small"
asg_min_size        = 1
asg_max_size        = 3
asg_desired_capacity = 2

# Auto Scaling
health_check_grace_period = 300
health_check_type         = "ELB"
target_cpu_utilization    = 70
target_request_count      = 500

# Database - Smaller instances for dev
mysql_instance_class        = "db.t3.micro"
mysql_allocated_storage     = 20
mysql_engine_version        = "8.0"
mysql_database_name         = "devappdb"
mysql_username             = "admin"

postgres_instance_class     = "db.t3.micro"
postgres_allocated_storage  = 20
postgres_engine_version     = "15.4"
postgres_database_name      = "devappdb"
postgres_username          = "postgres"

# Backup - Shorter retention for dev
backup_retention_period = 1
backup_window          = "03:00-04:00"
maintenance_window     = "sun:04:00-sun:05:00"

# Load Balancer
domain_name     = ""  # No custom domain for dev
subdomain       = "dev"
certificate_arn = ""  # HTTP only for dev

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
alarm_email          = ""  # Set your email for notifications

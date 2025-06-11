# Output Values
# This file defines output values that will be displayed after successful deployment
# These outputs provide essential information for connecting to and managing the infrastructure

# ========================================
# Networking Outputs
# ========================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.networking.private_subnet_ids
}

output "database_subnet_ids" {
  description = "IDs of the database subnets"
  value       = module.networking.database_subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.networking.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = module.networking.nat_gateway_ids
}

# ========================================
# Security Group Outputs
# ========================================

output "alb_security_group_id" {
  description = "ID of the Application Load Balancer security group"
  value       = module.security.alb_security_group_id
}

output "app_security_group_id" {
  description = "ID of the application (EC2) security group"
  value       = module.security.app_security_group_id
}

output "database_security_group_id" {
  description = "ID of the database security group"
  value       = module.security.database_security_group_id
}

output "bastion_security_group_id" {
  description = "ID of the bastion host security group"
  value       = module.security.bastion_security_group_id
}

# ========================================
# Load Balancer Outputs
# ========================================

output "load_balancer_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.load_balancer.load_balancer_dns_name
}

output "load_balancer_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.load_balancer.load_balancer_arn
}

output "load_balancer_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.load_balancer.load_balancer_zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = module.load_balancer.target_group_arn
}

output "load_balancer_url" {
  description = "URL to access the application via load balancer"
  value       = var.certificate_arn != "" ? "https://${module.load_balancer.load_balancer_dns_name}" : "http://${module.load_balancer.load_balancer_dns_name}"
}

# ========================================
# Auto Scaling Group Outputs
# ========================================

output "auto_scaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.compute.auto_scaling_group_name
}

output "auto_scaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = module.compute.auto_scaling_group_arn
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = module.compute.launch_template_id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = module.compute.launch_template_latest_version
}

# ========================================
# Database Outputs
# ========================================

output "mysql_endpoint" {
  description = "MySQL database endpoint"
  value       = module.database.mysql_endpoint
}

output "mysql_port" {
  description = "MySQL database port"
  value       = module.database.mysql_port
}

output "mysql_database_name" {
  description = "MySQL database name"
  value       = module.database.mysql_database_name
}

output "postgres_endpoint" {
  description = "PostgreSQL database endpoint"
  value       = module.database.postgres_endpoint
}

output "postgres_port" {
  description = "PostgreSQL database port"
  value       = module.database.postgres_port
}

output "postgres_database_name" {
  description = "PostgreSQL database name"
  value       = module.database.postgres_database_name
}

# Database connection strings (without passwords for security)
output "mysql_connection_string" {
  description = "MySQL connection string (without password)"
  value       = "mysql://${var.mysql_username}:PASSWORD@${module.database.mysql_endpoint}:${module.database.mysql_port}/${module.database.mysql_database_name}"
}

output "postgres_connection_string" {
  description = "PostgreSQL connection string (without password)"
  value       = "postgresql://${var.postgres_username}:PASSWORD@${module.database.postgres_endpoint}:${module.database.postgres_port}/${module.database.postgres_database_name}"
}

# Secrets Manager ARNs for database passwords
output "mysql_secret_arn" {
  description = "ARN of the MySQL password secret in AWS Secrets Manager"
  value       = module.database.mysql_secret_arn
  sensitive   = true
}

output "postgres_secret_arn" {
  description = "ARN of the PostgreSQL password secret in AWS Secrets Manager"
  value       = module.database.postgres_secret_arn
  sensitive   = true
}

# ========================================
# Domain and SSL Outputs (Conditional)
# ========================================

output "domain_name" {
  description = "Primary domain name configured"
  value       = var.domain_name != "" ? var.domain_name : "Not configured"
}

output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = "Domain module temporarily disabled"
}

output "ssl_certificate_arn" {
  description = "ARN of the SSL certificate"
  value       = "Domain module temporarily disabled"
}

output "app_url" {
  description = "Main application URL"
  value = var.domain_name != "" ? "https://app.${var.domain_name}" : "http://${module.load_balancer.load_balancer_dns_name}"
}

output "bi_url" {
  description = "BI tool (Metabase) URL"
  value = var.domain_name != "" ? "https://bi.${var.domain_name}" : "Not configured"
}

output "api_url" {
  description = "API endpoint URL"
  value = var.domain_name != "" ? "https://api.${var.domain_name}" : "http://${module.load_balancer.load_balancer_dns_name}/api"
}

output "admin_url" {
  description = "Admin interface URL"
  value = var.domain_name != "" ? "https://admin.${var.domain_name}" : "http://${module.load_balancer.load_balancer_dns_name}/admin"
}

output "subdomains" {
  description = "All configured subdomains"
  value = "Domain module temporarily disabled"
}

output "health_check_urls" {
  description = "Health check URLs for monitoring"
  value = "Domain module temporarily disabled"
}

# ========================================
# Monitoring Outputs (Conditional)
# ========================================

output "cloudwatch_dashboard_url" {
  description = "URL to CloudWatch dashboard for monitoring"
  value = var.enable_monitoring ? (
    "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${var.project_name}-${var.environment}"
  ) : "Monitoring not enabled"
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarm notifications"
  value       = var.enable_monitoring && var.alarm_email != "" ? module.monitoring[0].sns_topic_arn : "Not configured"
}

# ========================================
# Instance Information
# ========================================

output "instance_type" {
  description = "EC2 instance type used for the application servers"
  value       = var.instance_type
}

output "ami_id" {
  description = "AMI ID used for EC2 instances"
  value       = data.aws_ami.amazon_linux.id
}

output "key_name" {
  description = "AWS key pair name used for EC2 instances"
  value       = var.key_name
}

# ========================================
# Bastion Host Information
# ========================================

output "bastion_public_ip" {
  description = "Public IP address of the bastion host for SSH tunneling"
  value       = module.compute.bastion_public_ip
}

output "bastion_ssh_command" {
  description = "SSH command to connect to bastion host"
  value       = "ssh -i ~/.ssh/DevOps-FP-KeyPair.pem ec2-user@${module.compute.bastion_public_ip}"
}

output "mysql_ssh_tunnel_command" {
  description = "SSH tunnel command for MySQL database access"
  value       = "ssh -i ~/.ssh/DevOps-FP-KeyPair.pem -L 3306:${module.database.mysql_endpoint} ec2-user@${module.compute.bastion_public_ip}"
}

output "postgres_ssh_tunnel_command" {
  description = "SSH tunnel command for PostgreSQL database access" 
  value       = "ssh -i ~/.ssh/DevOps-FP-KeyPair.pem -L 5432:${module.database.postgres_endpoint} ec2-user@${module.compute.bastion_public_ip}"
}

# ========================================
# Metabase BI Tool Information (TEMPORARILY DISABLED)
# ========================================

# output "metabase_instance_id" {
#   description = "Instance ID of the dedicated Metabase server"
#   value       = module.compute.metabase_instance_id
# }

# output "metabase_private_ip" {
#   description = "Private IP address of the Metabase instance"
#   value       = module.compute.metabase_private_ip
# }

# output "metabase_access_via_bastion" {
#   description = "SSH tunnel command to access Metabase via bastion host"
#   value       = "ssh -i your-key.pem -L 3000:${module.compute.metabase_private_ip}:3000 ec2-user@${module.compute.bastion_public_ip}"
# }

# ========================================
# Configuration Summary
# ========================================

output "deployment_summary" {
  description = "Summary of the deployed infrastructure"
  value = {
    project_name        = var.project_name
    environment         = var.environment
    aws_region          = var.aws_region
    vpc_cidr           = var.vpc_cidr
    instance_type      = var.instance_type
    asg_min_size       = var.asg_min_size
    asg_max_size       = var.asg_max_size
    asg_desired_capacity = var.asg_desired_capacity
    mysql_instance_class = var.mysql_instance_class
    postgres_instance_class = var.postgres_instance_class
    domain_configured  = var.domain_name != ""
    ssl_enabled        = var.certificate_arn != ""
    monitoring_enabled = var.enable_monitoring
  }
}

# ========================================
# SSH Access Information
# ========================================

output "ssh_access_info" {
  description = "Information about SSH access to EC2 instances"
  value = {
    note = "EC2 instances are in private subnets. Use bastion host or AWS Session Manager for access."
    session_manager_command = "aws ssm start-session --target INSTANCE_ID --region ${var.aws_region}"
    key_name = var.key_name
  }
}

# ========================================
# Cost Estimation
# ========================================

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (USD, approximate)"
  value = {
    note = "These are rough estimates. Actual costs may vary based on usage patterns."
    ec2_instances = "${var.asg_desired_capacity} x ${var.instance_type}"
    rds_mysql = "${var.mysql_instance_class}"
    rds_postgres = "${var.postgres_instance_class}"
    alb = "Application Load Balancer"
    nat_gateway = var.enable_nat_gateway ? "NAT Gateway charges apply" : "No NAT Gateway"
    data_transfer = "Variable based on traffic"
  }
}

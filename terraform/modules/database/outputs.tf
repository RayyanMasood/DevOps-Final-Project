# Database Module Outputs

# MySQL Outputs
output "mysql_instance_id" {
  description = "ID of the MySQL RDS instance"
  value       = aws_db_instance.mysql.id
}

output "mysql_endpoint" {
  description = "MySQL database endpoint"
  value       = aws_db_instance.mysql.endpoint
}

output "mysql_port" {
  description = "MySQL database port"
  value       = aws_db_instance.mysql.port
}

output "mysql_database_name" {
  description = "MySQL database name"
  value       = aws_db_instance.mysql.db_name
}

output "mysql_username" {
  description = "MySQL master username"
  value       = aws_db_instance.mysql.username
}

output "mysql_arn" {
  description = "ARN of the MySQL RDS instance"
  value       = aws_db_instance.mysql.arn
}

# PostgreSQL Outputs
output "postgres_instance_id" {
  description = "ID of the PostgreSQL RDS instance"
  value       = aws_db_instance.postgres.id
}

output "postgres_endpoint" {
  description = "PostgreSQL database endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "postgres_port" {
  description = "PostgreSQL database port"
  value       = aws_db_instance.postgres.port
}

output "postgres_database_name" {
  description = "PostgreSQL database name"
  value       = aws_db_instance.postgres.db_name
}

output "postgres_username" {
  description = "PostgreSQL master username"
  value       = aws_db_instance.postgres.username
}

output "postgres_arn" {
  description = "ARN of the PostgreSQL RDS instance"
  value       = aws_db_instance.postgres.arn
}

# Secrets Manager Outputs
output "mysql_secret_arn" {
  description = "ARN of the MySQL password secret in Secrets Manager"
  value       = aws_secretsmanager_secret.mysql_password.arn
}

output "postgres_secret_arn" {
  description = "ARN of the PostgreSQL password secret in Secrets Manager"
  value       = aws_secretsmanager_secret.postgres_password.arn
}

# KMS Key Output
output "kms_key_id" {
  description = "ID of the KMS key used for RDS encryption"
  value       = aws_kms_key.rds.key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for RDS encryption"
  value       = aws_kms_key.rds.arn
}

# Parameter Groups
output "mysql_parameter_group_name" {
  description = "Name of the MySQL parameter group"
  value       = aws_db_parameter_group.mysql.name
}

output "postgres_parameter_group_name" {
  description = "Name of the PostgreSQL parameter group"
  value       = aws_db_parameter_group.postgres.name
}

# Connection Information (for application configuration)
output "mysql_connection_info" {
  description = "MySQL connection information for applications"
  value = {
    endpoint    = aws_db_instance.mysql.endpoint
    port        = aws_db_instance.mysql.port
    database    = aws_db_instance.mysql.db_name
    username    = aws_db_instance.mysql.username
    secret_arn  = aws_secretsmanager_secret.mysql_password.arn
  }
  sensitive = true
}

output "postgres_connection_info" {
  description = "PostgreSQL connection information for applications"
  value = {
    endpoint    = aws_db_instance.postgres.endpoint
    port        = aws_db_instance.postgres.port
    database    = aws_db_instance.postgres.db_name
    username    = aws_db_instance.postgres.username
    secret_arn  = aws_secretsmanager_secret.postgres_password.arn
  }
  sensitive = true
}

# Database Summary
output "database_summary" {
  description = "Summary of database configuration"
  value = {
    mysql_instance_class    = aws_db_instance.mysql.instance_class
    postgres_instance_class = aws_db_instance.postgres.instance_class
    mysql_storage_gb       = aws_db_instance.mysql.allocated_storage
    postgres_storage_gb    = aws_db_instance.postgres.allocated_storage
    backup_retention_days  = aws_db_instance.mysql.backup_retention_period
    multi_az_enabled      = aws_db_instance.mysql.multi_az
    encrypted            = aws_db_instance.mysql.storage_encrypted
  }
}

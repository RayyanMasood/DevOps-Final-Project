# Database Module
# This module creates RDS instances for MySQL and PostgreSQL

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# Random password generation for databases
resource "random_password" "mysql_password" {
  count   = var.mysql_password == "" ? 1 : 0
  length  = 16
  special = true
}

resource "random_password" "postgres_password" {
  count   = var.postgres_password == "" ? 1 : 0
  length  = 16
  special = true
}

# KMS Key for RDS encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-rds-kms-key"
    Type = "RDS Encryption Key"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# MySQL Database Instance
resource "aws_db_instance" "mysql" {
  # Instance configuration
  identifier     = "${local.name_prefix}-mysql"
  engine         = "mysql"
  engine_version = var.mysql_engine_version
  instance_class = var.mysql_instance_class

  # Storage configuration
  allocated_storage     = var.mysql_allocated_storage
  max_allocated_storage = var.mysql_allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id           = aws_kms_key.rds.arn

  # Database configuration
  db_name  = var.mysql_database_name
  username = var.mysql_username
  password = var.mysql_password != "" ? var.mysql_password : random_password.mysql_password[0].result

  # Network configuration
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.database_security_group_id]
  publicly_accessible    = false

  # Backup configuration
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  copy_tags_to_snapshot  = true

  # Performance and monitoring
  # Performance Insights is not supported on db.t3.micro, db.t3.small, etc.
  performance_insights_enabled = var.enable_monitoring && !can(regex("^db\\.(t3\\.(micro|small)|t2\\.(micro|small))", var.mysql_instance_class))
  monitoring_interval         = var.enable_monitoring ? 60 : 0
  monitoring_role_arn         = var.enable_monitoring ? aws_iam_role.rds_monitoring[0].arn : null

  # Security
  deletion_protection      = var.environment == "prod" ? true : false
  skip_final_snapshot     = var.environment == "prod" ? false : true
  final_snapshot_identifier = var.environment == "prod" ? "${local.name_prefix}-mysql-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  # Additional configurations
  auto_minor_version_upgrade = true
  multi_az                  = var.environment == "prod" ? true : false

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-mysql"
    Type = "MySQL Database"
  })
}

# PostgreSQL Database Instance
resource "aws_db_instance" "postgres" {
  # Instance configuration
  identifier     = "${local.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = var.postgres_engine_version
  instance_class = var.postgres_instance_class

  # Storage configuration
  allocated_storage     = var.postgres_allocated_storage
  max_allocated_storage = var.postgres_allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id           = aws_kms_key.rds.arn

  # Database configuration
  db_name  = var.postgres_database_name
  username = var.postgres_username
  password = var.postgres_password != "" ? var.postgres_password : random_password.postgres_password[0].result

  # Network configuration
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.database_security_group_id]
  publicly_accessible    = false

  # Backup configuration
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  copy_tags_to_snapshot  = true

  # Performance and monitoring
  # Performance Insights is not supported on db.t3.micro, db.t3.small, etc.
  performance_insights_enabled = var.enable_monitoring && !can(regex("^db\\.(t3\\.(micro|small)|t2\\.(micro|small))", var.postgres_instance_class))
  monitoring_interval         = var.enable_monitoring ? 60 : 0
  monitoring_role_arn         = var.enable_monitoring ? aws_iam_role.rds_monitoring[0].arn : null

  # Security
  deletion_protection      = var.environment == "prod" ? true : false
  skip_final_snapshot     = var.environment == "prod" ? false : true
  final_snapshot_identifier = var.environment == "prod" ? "${local.name_prefix}-postgres-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  # Additional configurations
  auto_minor_version_upgrade = true
  multi_az                  = var.environment == "prod" ? true : false

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-postgres"
    Type = "PostgreSQL Database"
  })
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  count = var.enable_monitoring ? 1 : 0

  name = "${local.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-rds-monitoring-role"
    Type = "RDS Monitoring Role"
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.enable_monitoring ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Parameter Groups for custom database configurations
resource "aws_db_parameter_group" "mysql" {
  family = "mysql8.0"
  name   = "${local.name_prefix}-mysql-params"

  parameter {
    name  = "innodb_buffer_pool_size"
    value = "{DBInstanceClassMemory*3/4}"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-mysql-params"
    Type = "MySQL Parameter Group"
  })
}

resource "aws_db_parameter_group" "postgres" {
  family = "postgres15"
  name   = "${local.name_prefix}-postgres-params"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-postgres-params"
    Type = "PostgreSQL Parameter Group"
  })
}

# Store database passwords in AWS Secrets Manager
resource "aws_secretsmanager_secret" "mysql_password" {
  name        = "${local.name_prefix}-mysql-password"
  description = "MySQL database password"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-mysql-password"
    Type = "Database Secret"
  })
}

resource "aws_secretsmanager_secret_version" "mysql_password" {
  secret_id = aws_secretsmanager_secret.mysql_password.id
  secret_string = jsonencode({
    username = var.mysql_username
    password = var.mysql_password != "" ? var.mysql_password : random_password.mysql_password[0].result
    endpoint = aws_db_instance.mysql.endpoint
    port     = aws_db_instance.mysql.port
    dbname   = aws_db_instance.mysql.db_name
  })
}

resource "aws_secretsmanager_secret" "postgres_password" {
  name        = "${local.name_prefix}-postgres-password"
  description = "PostgreSQL database password"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-postgres-password"
    Type = "Database Secret"
  })
}

resource "aws_secretsmanager_secret_version" "postgres_password" {
  secret_id = aws_secretsmanager_secret.postgres_password.id
  secret_string = jsonencode({
    username = var.postgres_username
    password = var.postgres_password != "" ? var.postgres_password : random_password.postgres_password[0].result
    endpoint = aws_db_instance.postgres.endpoint
    port     = aws_db_instance.postgres.port
    dbname   = aws_db_instance.postgres.db_name
  })
}

# CloudWatch Alarms for Database Monitoring
resource "aws_cloudwatch_metric_alarm" "mysql_cpu" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-mysql-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors MySQL CPU utilization"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.mysql.id
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-mysql-cpu-alarm"
    Type = "CloudWatch Alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "postgres_cpu" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-postgres-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors PostgreSQL CPU utilization"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-postgres-cpu-alarm"
    Type = "CloudWatch Alarm"
  })
}

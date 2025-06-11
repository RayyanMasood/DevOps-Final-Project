# Security Module
# This module creates all security groups for the infrastructure

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# Application Load Balancer Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  vpc_id      = var.vpc_id
  description = "Security group for Application Load Balancer"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-alb-sg"
    Type = "ALB Security Group"
  })
}

# ALB Security Group Rules
resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP traffic from internet"
}

resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS traffic from internet"
}

resource "aws_security_group_rule" "alb_egress_app" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.alb.id
  description              = "Allow traffic to application servers on port 80"
}

resource "aws_security_group_rule" "alb_egress_app_8080" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.alb.id
  description              = "Allow traffic to application servers on port 8080"
}

# Application Security Group (EC2 instances)
resource "aws_security_group" "app" {
  name_prefix = "${local.name_prefix}-app-"
  vpc_id      = var.vpc_id
  description = "Security group for application servers"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-app-sg"
    Type = "Application Security Group"
  })
}

# Application Security Group Rules
resource "aws_security_group_rule" "app_ingress_alb_80" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.app.id
  description              = "Allow traffic from ALB on port 80"
}

resource "aws_security_group_rule" "app_ingress_alb_8080" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.app.id
  description              = "Allow traffic from ALB on port 8080"
}

resource "aws_security_group_rule" "app_ingress_ssh_bastion" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = aws_security_group.app.id
  description              = "Allow SSH access from bastion host"
}

resource "aws_security_group_rule" "app_ingress_metabase_bastion" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = aws_security_group.app.id
  description              = "Allow Metabase access from bastion host for SSH tunneling"
}

resource "aws_security_group_rule" "app_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
  description       = "Allow HTTPS traffic to internet for package updates"
}

resource "aws_security_group_rule" "app_egress_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
  description       = "Allow HTTP traffic to internet"
}

resource "aws_security_group_rule" "app_egress_mysql" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.database.id
  security_group_id        = aws_security_group.app.id
  description              = "Allow traffic to MySQL database"
}

resource "aws_security_group_rule" "app_egress_postgres" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.database.id
  security_group_id        = aws_security_group.app.id
  description              = "Allow traffic to PostgreSQL database"
}

# Database Security Group
resource "aws_security_group" "database" {
  name_prefix = "${local.name_prefix}-db-"
  vpc_id      = var.vpc_id
  description = "Security group for RDS databases"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-db-sg"
    Type = "Database Security Group"
  })
}

# Database Security Group Rules
resource "aws_security_group_rule" "db_ingress_mysql_app" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.database.id
  description              = "Allow MySQL access from application servers"
}

resource "aws_security_group_rule" "db_ingress_postgres_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.database.id
  description              = "Allow PostgreSQL access from application servers"
}

resource "aws_security_group_rule" "db_ingress_mysql_bastion" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = aws_security_group.database.id
  description              = "Allow MySQL access from bastion host"
}

resource "aws_security_group_rule" "db_ingress_postgres_bastion" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = aws_security_group.database.id
  description              = "Allow PostgreSQL access from bastion host"
}

# Bastion Host Security Group
resource "aws_security_group" "bastion" {
  name_prefix = "${local.name_prefix}-bastion-"
  vpc_id      = var.vpc_id
  description = "Security group for bastion host"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-bastion-sg"
    Type = "Bastion Security Group"
  })
}

# Bastion Security Group Rules
resource "aws_security_group_rule" "bastion_ingress_ssh" {
  count = length(var.office_ip_addresses) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.office_ip_addresses
  security_group_id = aws_security_group.bastion.id
  description       = "Allow SSH access from office IP addresses"
}

resource "aws_security_group_rule" "bastion_egress_ssh_app" {
  type                     = "egress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.bastion.id
  description              = "Allow SSH access to application servers"
}

resource "aws_security_group_rule" "bastion_egress_metabase" {
  type                     = "egress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.bastion.id
  description              = "Allow Metabase access for SSH tunneling"
}

resource "aws_security_group_rule" "bastion_egress_mysql" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.database.id
  security_group_id        = aws_security_group.bastion.id
  description              = "Allow MySQL access to database"
}

resource "aws_security_group_rule" "bastion_egress_postgres" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.database.id
  security_group_id        = aws_security_group.bastion.id
  description              = "Allow PostgreSQL access to database"
}

resource "aws_security_group_rule" "bastion_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion.id
  description       = "Allow HTTPS traffic to internet"
}

# RDS Proxy Security Group (Optional for connection pooling)
resource "aws_security_group" "rds_proxy" {
  count = var.enable_rds_proxy ? 1 : 0

  name_prefix = "${local.name_prefix}-rds-proxy-"
  vpc_id      = var.vpc_id
  description = "Security group for RDS Proxy"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-rds-proxy-sg"
    Type = "RDS Proxy Security Group"
  })
}

resource "aws_security_group_rule" "rds_proxy_ingress_app" {
  count = var.enable_rds_proxy ? 1 : 0

  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.rds_proxy[0].id
  description              = "Allow access from application servers"
}

resource "aws_security_group_rule" "rds_proxy_egress_db" {
  count = var.enable_rds_proxy ? 1 : 0

  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.database.id
  security_group_id        = aws_security_group.rds_proxy[0].id
  description              = "Allow access to database"
}

# Update database security group to allow RDS Proxy access
resource "aws_security_group_rule" "db_ingress_rds_proxy" {
  count = var.enable_rds_proxy ? 1 : 0

  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds_proxy[0].id
  security_group_id        = aws_security_group.database.id
  description              = "Allow MySQL access from RDS Proxy"
}

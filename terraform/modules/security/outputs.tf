# Security Module Outputs

output "alb_security_group_id" {
  description = "ID of the Application Load Balancer security group"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.app.id
}

output "database_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.database.id
}

output "bastion_security_group_id" {
  description = "ID of the bastion host security group"
  value       = aws_security_group.bastion.id
}

output "rds_proxy_security_group_id" {
  description = "ID of the RDS Proxy security group"
  value       = var.enable_rds_proxy ? aws_security_group.rds_proxy[0].id : null
}

output "alb_security_group_arn" {
  description = "ARN of the Application Load Balancer security group"
  value       = aws_security_group.alb.arn
}

output "app_security_group_arn" {
  description = "ARN of the application security group"
  value       = aws_security_group.app.arn
}

output "database_security_group_arn" {
  description = "ARN of the database security group"
  value       = aws_security_group.database.arn
}

output "bastion_security_group_arn" {
  description = "ARN of the bastion host security group"
  value       = aws_security_group.bastion.arn
}

output "security_groups_summary" {
  description = "Summary of all security groups created"
  value = {
    alb_sg      = aws_security_group.alb.id
    app_sg      = aws_security_group.app.id
    database_sg = aws_security_group.database.id
    bastion_sg  = aws_security_group.bastion.id
    rds_proxy_sg = var.enable_rds_proxy ? aws_security_group.rds_proxy[0].id : "Not enabled"
  }
}

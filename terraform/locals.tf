# Local Values
# This file contains local values used across the configuration

locals {
  # Common tags applied to all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
    CreatedAt   = timestamp()
  }
  
  # Naming convention
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Get first 2 availability zones
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  
  # Dynamic IP address management
  current_ip = "${trimspace(data.http.current_ip.response_body)}/32"

  # Create a comprehensive list of allowed IPs (removes duplicates)
  all_office_ips = distinct(concat(
    var.office_ip_addresses,
    [local.current_ip]
  ))
}

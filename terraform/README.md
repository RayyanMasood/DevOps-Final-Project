# DevOps Final Project - Terraform Infrastructure

This project creates a complete, scalable AWS infrastructure using Terraform, including auto-scaling EC2 instances, RDS databases, load balancer, and a dedicated Metabase BI tool deployment.

## 🏗️ Infrastructure Overview

### Core Components
- **VPC** with multi-AZ public/private subnet design
- **Application Load Balancer** with HTTPS support and health checks  
- **Auto Scaling Group** with 2 EC2 instances for applications
- **Dedicated Metabase Instance** (3rd EC2) for Business Intelligence
- **Bastion Host** for secure database access via SSH tunneling
- **RDS Databases** (MySQL and PostgreSQL) in private subnets
- **Security Groups** with least-privilege access controls
- **Route53** DNS management with SSL certificates

### Key Features
- ✅ **3 EC2 Instances**: 2 for apps (ASG) + 1 dedicated for Metabase
- ✅ **SSH Tunneling**: Bastion host for secure RDS access
- ✅ **Multi-stage Dockerfiles**: Frontend and Backend applications
- ✅ **Sample Data**: Pre-populated databases for dashboard demos
- ✅ **HTTPS Support**: SSL certificates via ACM
- ✅ **Monitoring**: CloudWatch dashboards and alarms

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- SSH key pair created in AWS

### 1. Clone and Configure
```bash
git clone <your-repo-url>
cd terraform/
cp terraform.tfvars.example terraform.tfvars
```

### 2. Update terraform.tfvars
```hcl
project_name = "devops-final"
environment  = "dev"
key_name     = "your-aws-key-pair"
domain_name  = "yourdomain.com"  # optional

# Database passwords
mysql_password    = "SecurePassword123!"
postgres_password = "SecurePassword123!"
```

### 3. Deploy Infrastructure
```bash
# Initialize Terraform
make init

# Plan deployment
make plan

# Apply infrastructure
make apply
```

## 🔗 Access Points After Deployment

### 1. **Bastion Host Access**
```bash
# Get bastion IP from outputs
terraform output bastion_public_ip

# SSH to bastion host
ssh -i your-key.pem ec2-user@<bastion-ip>

# Helper commands on bastion:
db-tunnel         # Show tunnel setup guide
mysql-tunnel      # MySQL connection guide  
postgres-tunnel   # PostgreSQL connection guide
```

### 2. **Database Access via SSH Tunnel**

#### MySQL Connection:
```bash
# Create SSH tunnel (from your local machine)
ssh -i your-key.pem -L 3306:<mysql-endpoint>:3306 ec2-user@<bastion-ip>

# Connect with DBeaver:
# Host: localhost
# Port: 3306
# Database: appdb
# Username: admin
# Password: [from terraform.tfvars]
```

#### PostgreSQL Connection:
```bash
# Create SSH tunnel (from your local machine)  
ssh -i your-key.pem -L 5432:<postgres-endpoint>:5432 ec2-user@<bastion-ip>

# Connect with DBeaver:
# Host: localhost
# Port: 5432
# Database: appdb
# Username: admin
# Password: [from terraform.tfvars]
```

### 3. **Metabase BI Tool Access**
```bash
# Get Metabase private IP
terraform output metabase_private_ip

# Create SSH tunnel to access Metabase
ssh -i your-key.pem -L 3000:<metabase-private-ip>:3000 ec2-user@<bastion-ip>

# Access Metabase at: http://localhost:3000
```

### 4. **Application Access**
```bash
# Get load balancer URL
terraform output app_url

# Access application via load balancer
curl <load-balancer-url>
```

## 📊 Sample Data & Dashboards

### Database Sample Data
The infrastructure automatically populates both databases with sample data:

#### MySQL Tables:
- `products` - Product catalog with pricing
- `customers` - Customer information  
- `orders` - Order history and status
- `order_items` - Detailed order line items
- `user_activity` - User behavior tracking
- `dashboard_metrics` - KPI metrics

#### PostgreSQL Tables:
- `analytics_events` - User interaction events
- `sales_analytics` - Sales performance data
- `user_engagement` - Engagement metrics
- `financial_metrics` - Financial KPIs
- `real_time_metrics` - Live dashboard data

### Metabase Dashboard Setup
1. Access Metabase via SSH tunnel: `http://localhost:3000`
2. Complete initial setup with admin credentials
3. Connect to PostgreSQL database using RDS credentials
4. Import sample dashboards or create new ones
5. Data updates automatically when new records are inserted

### Live Data Updates Demo
```bash
# Connect to PostgreSQL via tunnel
psql -h localhost -p 5432 -U admin -d appdb

# Insert new sales record to trigger updates
INSERT INTO sales_analytics (date, product_name, category, sales_amount, quantity_sold, region, channel) 
VALUES (CURRENT_DATE, 'New Product', 'Electronics', 999.99, 1, 'North America', 'Online');

# Metabase dashboards will reflect the new data
```

## 🛠️ Infrastructure Management

### Terraform Commands
```bash
make init      # Initialize Terraform
make plan      # Show execution plan
make apply     # Apply changes
make destroy   # Destroy infrastructure
make validate  # Validate configuration
make format    # Format code
```

### Scaling Operations
```bash
# Update ASG capacity in terraform.tfvars
asg_desired_capacity = 4
asg_max_size        = 8

# Apply changes
terraform apply
```

### SSL Certificate Setup
```bash
# With custom domain
domain_name = "yourdomain.com"
create_hosted_zone = true

# Certificate will be automatically created via ACM
```

## 🔐 Security Features

- **Encrypted Storage**: All EBS volumes and RDS instances encrypted
- **Private Subnets**: Databases isolated from internet access
- **Security Groups**: Minimal required access rules
- **Secrets Manager**: Database credentials securely stored
- **Bastion Host**: Secure access point for database administration
- **WAF Protection**: Application-layer security (optional)

## 📈 Monitoring & Alerting

- **CloudWatch Dashboards**: Infrastructure and application metrics
- **Automated Alarms**: CPU, memory, and performance thresholds
- **Log Aggregation**: Centralized logging via CloudWatch Logs
- **SNS Notifications**: Email alerts for critical issues

## 🌍 Multi-Environment Support

```bash
# Development
terraform apply -var-file="environments/dev.tfvars"

# Staging  
terraform apply -var-file="environments/staging.tfvars"

# Production
terraform apply -var-file="environments/prod.tfvars"
```

## 🔧 Troubleshooting

### Common Issues

**1. SSH Connection Issues**
```bash
# Verify security group allows SSH from your IP
aws ec2 describe-security-groups --group-ids <bastion-sg-id>

# Check bastion host status
aws ec2 describe-instances --instance-ids <bastion-instance-id>
```

**2. Database Connection Issues**
```bash
# Verify RDS endpoints
terraform output mysql_endpoint
terraform output postgres_endpoint

# Test SSH tunnel
ssh -v -i your-key.pem -L 3306:<mysql-endpoint>:3306 ec2-user@<bastion-ip>
```

**3. Metabase Access Issues**
```bash
# Check Metabase status on instance
ssh -i your-key.pem ec2-user@<bastion-ip>
ssh <metabase-private-ip>
docker ps | grep metabase
```

### Useful Commands
```bash
# View all outputs
terraform output

# Get specific output
terraform output bastion_public_ip

# View infrastructure state
terraform state list

# Import existing resources
terraform import aws_instance.example i-1234567890abcdef0
```

## 📁 File Structure

```
terraform/
├── main.tf                    # Main infrastructure orchestration
├── variables.tf               # Input variables with validation
├── outputs.tf                 # Infrastructure outputs
├── modules/
│   ├── networking/           # VPC, subnets, gateways
│   ├── security/             # Security groups and rules
│   ├── compute/              # ASG, bastion, Metabase instances
│   ├── database/             # RDS MySQL and PostgreSQL
│   ├── load_balancer/        # ALB with HTTPS support
│   └── monitoring/           # CloudWatch dashboards
├── environments/             # Environment-specific configs
└── scripts/                  # Utility scripts
```

## 📋 Requirements Checklist

- ✅ **EC2 Auto Scaling Group**: 3 instances (2 apps + 1 Metabase)
- ✅ **RDS Private Databases**: MySQL + PostgreSQL in private subnets
- ✅ **Load Balancer**: ALB with HTTP/HTTPS support
- ✅ **Multi-stage Dockerfiles**: Frontend and Backend
- ✅ **BI Tool Deployment**: Metabase on dedicated instance
- ✅ **Domain & SSL**: Route53 + ACM certificate support
- ✅ **SSH Tunneling**: Bastion host for secure DB access
- ✅ **Sample Data**: Pre-populated databases
- ✅ **Live Dashboard**: Real-time data updates
- ✅ **Modular Structure**: Clean Terraform organization

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `terraform plan`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📚 Additional Resources

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [AWS Security Best Practices](https://aws.amazon.com/security/security-resources/)
- [Node.js Deployment Guide](https://nodejs.org/en/docs/guides/deployment/)

# DevOps Final Project - Complete Infrastructure & Application Stack

> **Production-Ready AWS Infrastructure with Terraform, Dockerized Applications, and BI Analytics**

A comprehensive DevOps project showcasing cloud infrastructure automation, containerized application deployment, database management, and business intelligence integration on AWS.

## Project Overview

This project demonstrates a complete DevOps pipeline with:

- **Infrastructure as Code** - Terraform-managed AWS infrastructure
- **Containerized Applications** - Multi-stage Docker builds with Node.js & React
- **Security Best Practices** - Encrypted storage, IAM roles, VPC isolation
- **Business Intelligence** - Metabase dashboards with real-time analytics
- **Auto Scaling** - Load-balanced, self-healing application deployment
- **Database Security** - SSH tunneling for secure database access

### Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │    │   Load Balancer │    │    Metabase     │
│  Load Balancer  │◄──►│   (Internet)    │    │   BI Tool       │
│   (nginx:80)    │    │   Gateway       │    │  (Port 3000)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
    ┌────▼────┐             ┌────▼────┐             ┌────▼────┐
    │   EC2   │             │   EC2   │             │   EC2   │
    │Instance │             │Instance │             │ (Metro) │
    │   #1    │             │   #2    │             │Instance │
    └─────────┘             └─────────┘             └─────────┘
         │                       │                       │
         └───────────┬───────────┘                       │
                     │                                   │
              ┌─────────────────┐                ┌──────▼──────┐
              │    Bastion      │                │   Private   │
              │     Host        │                │   Subnet    │
              │  (SSH Access)   │                │             │
              └─────────────────┘                └─────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
┌─────────────────┐    ┌─────────────────┐
│     MySQL       │    │   PostgreSQL    │
│  (RDS Private)  │    │  (RDS Private)  │
└─────────────────┘    └─────────────────┘
```

## Quick Start Guide

### Prerequisites

Before starting, ensure you have:

- **AWS CLI** (v2.0+) configured with appropriate permissions
  ```bash
  aws configure list
  aws sts get-caller-identity  # Verify access
  ```
- **Terraform** (>= 1.0) installed
  ```bash
  terraform version  # Should show v1.0+
  ```
- **Docker** (>= 20.0) and **Docker Compose** (>= 2.0) installed
  ```bash
  docker version
  docker-compose version
  ```
- **Git** for cloning the repository
- **Make** utility (for convenient command execution)

### 1. Clone and Initial Setup

```bash
# Clone the repository
git clone https://github.com/your-username/devops-final-project.git
cd devops-final-project

# Navigate to terraform directory
cd terraform/

# Copy and configure terraform variables
cp terraform.tfvars.example terraform.tfvars

# Create AWS key pair if you don't have one
aws ec2 create-key-pair --key-name DevOps-FP-KeyPair --query 'KeyMaterial' --output text > DevOps-FP-KeyPair.pem
chmod 400 DevOps-FP-KeyPair.pem
```

### 2. Configure Infrastructure Settings

Edit `terraform/terraform.tfvars` with your specific settings:

```hcl
# Project Configuration
project_name = "devops-final"
environment  = "dev"
region      = "us-east-1"

# EC2 Configuration
key_name = "DevOps-FP-KeyPair"       # Created in previous step
instance_type = "t3.medium"

# Auto Scaling Configuration
asg_min_size         = 2
asg_max_size         = 6
asg_desired_capacity = 3

# Database Configuration
mysql_password    = "SecurePassword123!"
postgres_password = "SecurePassword123!"

# Optional: Custom Domain Configuration
domain_name = "yourdomain.com"  # Set to "" if not using custom domain
create_hosted_zone = false      # Set to true for new domains

# Network Configuration
vpc_cidr = "10.0.0.0/16"
```

### 3. Deploy Infrastructure

**Option A: Using Make Commands (Recommended)**
```bash
# Initialize Terraform
make init

# Review the deployment plan
make plan

# Deploy infrastructure (takes ~15-20 minutes)
make apply
```

**Option B: Using Standard Terraform Commands**
```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy infrastructure (takes ~15-20 minutes)
terraform apply
```

> **Why Make Commands?** The Makefile provides convenience wrappers that add helpful output messages, error handling, and additional features like environment-specific deployments (`make apply-dev`, `make apply-prod`) and integrated security scanning.

### 4. Verify Infrastructure Deployment

```bash
# Get important infrastructure information
terraform output

# Expected outputs:
# - alb_dns_name: Load balancer URL
# - bastion_public_ip: SSH access point
# - mysql_endpoint: Database connection
# - postgres_endpoint: Database connection
# - metabase_private_ip: BI tool access
```

## Application Deployment

The application deployment is automated through Terraform user data scripts, but you can also deploy manually or update the application.

### Automated Deployment (Recommended)

The infrastructure automatically deploys the application when EC2 instances start. The process includes:

1. **Container Setup** - Docker and Docker Compose installation
2. **Code Deployment** - Cloning from Git repository
3. **Environment Configuration** - RDS credentials from AWS Secrets Manager
4. **Service Startup** - Multi-container application with load balancing

### Manual Application Deployment

If you need to deploy or update the application manually:

```bash
# Connect to any EC2 instance
ssh -i DevOps-FP-KeyPair.pem ec2-user@$(terraform output -raw bastion_public_ip)

# Navigate to application directory
cd /opt/notes-app

# Update application code
git pull origin main

# Rebuild and restart containers
./deploy-ec2.sh
```

### Local Development Setup

For local development and testing:

```bash
# Navigate to app directory
cd app/

# Start the application locally
docker-compose up --build

# Access points:
# Frontend: http://localhost:3000
# Backend API: http://localhost:3001
# Load Balancer: http://localhost
```

## Database Access & Management

### SSH Tunnel Setup for Database Access

The databases are in private subnets for security. Access them via SSH tunneling:

```bash
# Get connection details
terraform output mysql_endpoint
terraform output postgres_endpoint
terraform output bastion_public_ip

# MySQL SSH Tunnel
ssh -i DevOps-FP-KeyPair.pem -L 3306:$(terraform output -raw mysql_endpoint):3306 ec2-user@$(terraform output -raw bastion_public_ip)

# PostgreSQL SSH Tunnel  
ssh -i DevOps-FP-KeyPair.pem -L 5432:$(terraform output -raw postgres_endpoint):5432 ec2-user@$(terraform output -raw bastion_public_ip)
```

### Database Configuration with DBeaver

1. **Create SSH Tunnel** (commands above)
2. **Configure DBeaver Connection:**
   - **Host:** localhost
   - **Port:** 3306 (MySQL) or 5432 (PostgreSQL)
   - **Database:** appdb
   - **Username:** admin
   - **Password:** [from your terraform.tfvars]

### Sample Data Population

```bash
# Connect via SSH tunnel and run sample data script
ssh -i DevOps-FP-KeyPair.pem ec2-user@$(terraform output -raw bastion_public_ip)

# Run the sample data script
cd /opt/terraform-scripts
chmod +x add-sample-data.sh
./add-sample-data.sh
```

## Business Intelligence with Metabase

### Metabase Access Setup

```bash
# Get Metabase private IP
terraform output metabase_private_ip

# Create SSH tunnel to Metabase (port 3000)
ssh -i DevOps-FP-KeyPair.pem -L 3000:$(terraform output -raw metabase_private_ip):3000 ec2-user@$(terraform output -raw bastion_public_ip)

# Access Metabase at: http://localhost:3000
```

### Metabase Initial Configuration

1. **Open Metabase:** http://localhost:3000
2. **Complete Setup Wizard:**
   - Create admin account
   - Configure email settings (optional)
3. **Add Database Connections:**
   - Use internal RDS endpoints (Metabase is in the same VPC)
   - Connect to both MySQL and PostgreSQL databases
4. **Import Dashboards:**
   - Create dashboards using sample data
   - Set up real-time metrics visualization

### Sample Dashboards

The infrastructure includes sample data for creating dashboards:

- **Sales Analytics** - Revenue trends and product performance
- **User Engagement** - User activity and behavior metrics
- **System Monitoring** - Application performance metrics
- **Financial KPIs** - Business performance indicators

## Security Features

### Network Security

- **VPC Isolation** - Private subnets for databases and internal traffic
- **Security Groups** - Restrictive firewall rules
- **NAT Gateway** - Outbound internet access for private resources
- **Bastion Host** - Secure gateway for administrative access

### Data Security

- **Encryption at Rest** - All EBS volumes and RDS instances encrypted
- **Secrets Management** - Database credentials stored in AWS Secrets Manager
- **SSL/TLS** - HTTPS termination at load balancer
- **IAM Roles** - Least privilege access for EC2 instances

### Access Controls

```bash
# Security group configuration:
# ALB: 80/443 from 0.0.0.0/0
# EC2: 3000/3001 from ALB security group only
# RDS: 3306/5432 from EC2 security group only
# Bastion: 22 from your IP only
```

## Management & Monitoring

### Available Make Commands vs Standard Terraform

| Make Command | Terraform Equivalent | Additional Features |
|--------------|---------------------|-------------------|
| `make init` | `terraform init` | Helpful output messages |
| `make plan` | `terraform plan` | Environment-specific options |
| `make apply` | `terraform apply` | Safety confirmations |
| `make destroy` | `terraform destroy` | Interactive confirmation |
| `make validate` | `terraform validate` | Enhanced error messages |
| `make format` | `terraform fmt -recursive` | Recursive formatting |
| `make output` | `terraform output` | Pretty-printed output |

**Additional Make-Only Features:**
```bash
# Environment Management (not available with standard terraform)
make plan-dev      # terraform plan -var-file="environments/dev.tfvars"
make apply-prod    # terraform apply -var-file="environments/prod.tfvars"
make destroy-dev   # terraform destroy -var-file="environments/dev.tfvars"

# Integrated Tools
make security-scan # Runs checkov security analysis
make lint          # Runs TFLint for code quality
make docs          # Generates terraform-docs documentation
make cost-estimate # Runs infracost for cost estimation
```

**You can use either approach:**
- **Make commands**: More convenient, includes safety features and additional tools
- **Standard Terraform**: Direct control, industry standard, works everywhere

### Monitoring & Alerts

The infrastructure includes comprehensive monitoring:

- **CloudWatch Dashboards** - Infrastructure and application metrics
- **Auto Scaling Alarms** - CPU, memory, and request-based scaling
- **Health Checks** - Application and database health monitoring
- **SNS Notifications** - Critical alert notifications

### Scaling Operations

```bash
# Update Auto Scaling Group capacity
# Edit terraform.tfvars:
asg_desired_capacity = 5
asg_max_size        = 10

# Apply changes
make apply
```

## Domain & SSL Configuration

### Custom Domain Setup

1. **Configure Domain in terraform.tfvars:**
```hcl
domain_name = "yourdomain.com"
create_hosted_zone = true
```

2. **Deploy with Domain:**
```bash
make apply
```

3. **Update DNS Records:**
   - Get Route53 name servers from AWS Console
   - Update your domain registrar's DNS settings

### SSL Certificate

SSL certificates are automatically created and managed by AWS Certificate Manager when a domain is configured.

## Quick Setup Example

For a rapid deployment with default settings:

```bash
# 1. Setup
git clone https://github.com/your-username/devops-final-project.git
cd devops-final-project/terraform
aws ec2 create-key-pair --key-name DevOps-FP-KeyPair --query 'KeyMaterial' --output text > DevOps-FP-KeyPair.pem
chmod 400 DevOps-FP-KeyPair.pem

# 2. Configure (minimal required changes)
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars - set your passwords:
# mysql_password = "MySecurePass123!"
# postgres_password = "MySecurePass123!"

# 3. Deploy (using Make)
make init && make apply

# OR using standard Terraform
terraform init && terraform apply

# 4. Get access info
terraform output

# 5. Test application
curl $(terraform output -raw alb_dns_name)

# 6. Access databases via SSH tunnel (in separate terminals)
ssh -i DevOps-FP-KeyPair.pem -L 3306:$(terraform output -raw mysql_endpoint):3306 ec2-user@$(terraform output -raw bastion_public_ip)
ssh -i DevOps-FP-KeyPair.pem -L 5432:$(terraform output -raw postgres_endpoint):5432 ec2-user@$(terraform output -raw bastion_public_ip)

# 7. Access Metabase BI
ssh -i DevOps-FP-KeyPair.pem -L 3000:$(terraform output -raw metabase_private_ip):3000 ec2-user@$(terraform output -raw bastion_public_ip)
# Then visit: http://localhost:3000
```

## Troubleshooting

### Common Issues

**1. Terraform Permission Errors**
```bash
# Ensure AWS CLI is configured
aws configure list
aws sts get-caller-identity
```

**2. EC2 Instance Access Issues**
```bash
# Verify key pair exists
aws ec2 describe-key-pairs --key-names your-key-name

# Check security group rules
aws ec2 describe-security-groups --group-ids $(terraform output -raw bastion_security_group_id)
```

**3. Database Connection Issues**
```bash
# Test database connectivity from bastion
ssh -i DevOps-FP-KeyPair.pem ec2-user@$(terraform output -raw bastion_public_ip)
mysql -h $(terraform output -raw mysql_endpoint) -u admin -p
```

**4. Application Not Loading**
```bash
# Check application logs on EC2
ssh -i DevOps-FP-KeyPair.pem ec2-user@$(terraform output -raw bastion_public_ip)
docker-compose logs -f
```

### Getting Support

- **Infrastructure Issues** - Check CloudWatch logs and Terraform state
- **Application Issues** - Review Docker container logs
- **Database Issues** - Verify SSH tunnel and credentials
- **Network Issues** - Check security groups and VPC configuration

## Additional Documentation

- [Terraform Infrastructure Details](terraform/README.md)
- [Application Deployment Guide](app/README.md)
- [Database Access Guide](terraform/DATABASE_ACCESS_SSH_TUNNELING.md)
- [Metabase Setup Guide](terraform/METABASE_SETUP.md)
- [Domain & SSL Configuration](terraform/DOMAIN_SSL_SETUP.md)
- [Testing Guide](terraform/TESTING_GUIDE.md)

## Project Features Checklist

- ✅ **Auto Scaling Group** - 3 EC2 instances with auto scaling
- ✅ **RDS Databases** - MySQL and PostgreSQL in private subnets
- ✅ **Security Groups** - Properly configured network security
- ✅ **Application Load Balancer** - With health checks and SSL support
- ✅ **Dockerized Application** - Multi-stage builds and containerization
- ✅ **SSH Tunneling** - Secure database access via bastion host
- ✅ **BI Tool Deployment** - Metabase for analytics and dashboards
- ✅ **Domain & SSL** - Custom domain with automatic SSL certificates


**Monthly AWS costs for this infrastructure (US East 1):**

| Service | Configuration | Estimated Cost |
|---------|---------------|----------------|
| EC2 Instances | 3x t3.medium (24/7) | ~$100 |
| RDS MySQL | db.t3.micro Multi-AZ | ~$35 |
| RDS PostgreSQL | db.t3.micro Multi-AZ | ~$35 |
| Application Load Balancer | 1 ALB | ~$20 |
| NAT Gateway | 2 NAT Gateways | ~$45 |
| EBS Storage | 3x 20GB gp3 | ~$6 |
| Data Transfer | Moderate usage | ~$10 |
| **Total Estimated** | | **~$250/month** |

> **Cost Optimization Tips:**
> - Use `t3.small` instances for development: saves ~$35/month
> - Single AZ for dev environments: saves ~$40/month
> - Use NAT Instance instead of NAT Gateway: saves ~$30/month
> - Spot instances for non-critical workloads: saves ~40-60%

## Next Steps

1. **Scale Your Application** - Adjust Auto Scaling Group parameters
2. **Add Monitoring** - Set up custom CloudWatch dashboards
3. **Implement CI/CD** - Add automated deployment pipelines
4. **Enhance Security** - Implement WAF and additional security measures
5. **Optimize Costs** - Review and optimize resource sizing

## Contributing

Feel free to fork this repository and submit pull requests for improvements.

## License

This project is for educational purposes as part of a DevOps Final Project.

---

**Happy Building!**
# Quick Deployment Guide

This guide will help you deploy the Notes application automatically using Terraform.

## Prerequisites

1. **AWS CLI configured** with appropriate credentials
2. **Terraform installed** (version 1.0+)
3. **EC2 Key Pair** created in your AWS region

## Quick Deploy

1. **Navigate to terraform directory**:
```bash
cd terraform
```

2. **Initialize Terraform**:
```bash
terraform init
```

3. **Create your key pair** (if not exists):
```bash
aws ec2 create-key-pair --key-name DevOps-FP-KeyPair --query 'KeyMaterial' --output text > ~/.ssh/DevOps-FP-KeyPair.pem
chmod 400 ~/.ssh/DevOps-FP-KeyPair.pem
```

4. **Review and apply**:
```bash
terraform plan
terraform apply
```

## What Gets Deployed

- **VPC** with public/private subnets across 2 AZs
- **RDS MySQL and PostgreSQL** databases with the Notes app schema
- **Auto Scaling Group** with 3 EC2 instances running the containerized app
- **Application Load Balancer** distributing traffic
- **Security Groups** with proper access controls
- **CloudWatch** monitoring and alarms

## Application Details

- **Frontend**: React app served via Nginx load balancer
- **Backend**: Node.js API connecting to both databases
- **Databases**: MySQL and PostgreSQL with sample notes data
- **Load Balancer**: Nginx reverse proxy on port 80

## Access Your Application

After deployment completes (5-10 minutes), get the load balancer URL:

```bash
terraform output alb_dns_name
```

Visit the URL in your browser to see your deployed Notes application!

## Clean Up

To destroy all resources:

```bash
terraform destroy
```

## Configuration

The deployment uses `terraform.tfvars` with optimized settings for development. The application will automatically:

1. Clone from GitHub repository
2. Configure database connections to RDS
3. Build and deploy Docker containers
4. Set up health checks and monitoring

## Troubleshooting

If deployment fails:

1. Check AWS credentials: `aws sts get-caller-identity`
2. Verify key pair exists: `aws ec2 describe-key-pairs --key-names DevOps-FP-KeyPair`
3. Check terraform state: `terraform show`
4. View instance logs via AWS Console → EC2 → Instance → System Log 
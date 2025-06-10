#!/bin/bash

# EC2 User Data Script for Notes App
# This script sets up the EC2 instance with required software and deploys the application

# Update system
yum update -y

# Install Docker
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Node.js 20
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs

# Install Git (for cloning repository)
yum install -y git

# Install nginx (as requested in requirements)
amazon-linux-extras install nginx1 -y

# Install MySQL client (for RDS connectivity testing)
yum install -y mysql

# Install PostgreSQL client (for RDS connectivity testing)  
amazon-linux-extras install postgresql11 -y

# Create application directory
mkdir -p /opt/notes-app
cd /opt/notes-app

# Clone your repository (replace with your actual repository URL)
# git clone https://github.com/your-username/your-repository.git .

# Note: You'll need to manually copy your application files to the EC2 instance
# or modify this script to clone from your actual GitHub repository

# Create a sample .env file (to be configured later)
cat > /opt/notes-app/.env.example << 'EOF'
# EC2 Deployment Environment Configuration

# Application Configuration
NODE_ENV=production
PORT=3001

# MySQL RDS Configuration
MYSQL_RDS_ENDPOINT=your-mysql-rds-endpoint.region.rds.amazonaws.com
MYSQL_USER=notes_user
MYSQL_PASSWORD=your-secure-password
MYSQL_DATABASE=notes_db

# PostgreSQL RDS Configuration  
POSTGRES_RDS_ENDPOINT=your-postgres-rds-endpoint.region.rds.amazonaws.com
POSTGRES_USER=notes_user
POSTGRES_PASSWORD=your-secure-password
POSTGRES_DATABASE=notes_db

# Frontend Configuration
REACT_APP_API_URL=/api
EOF

# Set proper permissions
chown -R ec2-user:ec2-user /opt/notes-app

# Log completion
echo "$(date): EC2 User Data script completed" >> /var/log/user-data.log
echo "Docker, Node.js 20, Nginx, and database clients installed" >> /var/log/user-data.log
echo "Application directory created at /opt/notes-app" >> /var/log/user-data.log
echo "Configure .env file and deploy application manually" >> /var/log/user-data.log 
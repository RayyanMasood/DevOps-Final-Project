# Notes App - EC2 Deployment with RDS Integration

This is a simple yet production-ready Notes application designed for deployment on AWS EC2 instances with RDS database integration. Perfect for Auto Scaling Groups and Application Load Balancer setups.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│                 │    │                 │    │                 │
│   EC2 Instance  │    │   EC2 Instance  │    │   EC2 Instance  │
│                 │    │                 │    │                 │
│  ┌─────────────┐│    │  ┌─────────────┐│    │  ┌─────────────┐│
│  │ Notes App   ││    │  │ Notes App   ││    │  │ BI Tool     ││
│  │ (Frontend)  ││    │  │ (Frontend)  ││    │  │ (Metabase/  ││
│  │ Port 3000   ││    │  │ Port 3000   ││    │  │  Redash)    ││
│  │             ││    │  │             ││    │  │             ││
│  │ (Backend)   ││    │  │ (Backend)   ││    │  │             ││
│  │ Port 3001   ││    │  │ Port 3001   ││    │  │             ││
│  └─────────────┘│    │  └─────────────┘│    │  └─────────────┘│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │                 │
                    │ Application     │
                    │ Load Balancer   │
                    │ (ALB)           │
                    │                 │
                    └─────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│                 │    │                 │    │                 │
│  MySQL RDS      │    │ PostgreSQL RDS  │    │   SSH Tunnel    │
│  (Private)      │    │  (Private)      │    │   for DBeaver   │
│  Port 3306      │    │  Port 5432      │    │                 │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Quick Start for EC2 Deployment

### 1. Prepare Your RDS Instances

First, ensure your MySQL and PostgreSQL RDS instances are running and accessible from your EC2 instances.

#### Initialize MySQL RDS:
```bash
# Connect via SSH tunnel or directly from EC2
mysql -h your-mysql-rds-endpoint.region.rds.amazonaws.com -u your-user -p

# Run the initialization script
source database/sql/mysql-init-rds.sql
```

#### Initialize PostgreSQL RDS:
```bash
# Connect via SSH tunnel or directly from EC2
psql -h your-postgres-rds-endpoint.region.rds.amazonaws.com -U your-user -d postgres

# Run the initialization script
\i database/sql/postgres-init-rds.sql
```

### 2. Deploy to EC2 Instance

1. **Upload application files to EC2:**
   ```bash
   # Option 1: Clone from GitHub (recommended)
   git clone https://github.com/your-username/your-repo.git /opt/notes-app
   cd /opt/notes-app
   
   # Option 2: Copy files via SCP
   scp -r ./app ec2-user@your-ec2-ip:/opt/notes-app
   ```

2. **Configure environment:**
   ```bash
   cd /opt/notes-app
   cp env.ec2.example .env
   nano .env  # Edit with your RDS endpoints and credentials
   ```

3. **Deploy the application:**
   ```bash
   chmod +x deploy-ec2.sh
   ./deploy-ec2.sh
   ```

## 📋 Prerequisites

### EC2 Instance Requirements
- Amazon Linux 2 (recommended)
- Docker installed and running
- Docker Compose installed
- Node.js 20 installed
- Security groups allowing:
  - Inbound: Port 3000 (frontend) and 3001 (backend) from ALB
  - Outbound: Port 3306 (MySQL) and 5432 (PostgreSQL) to RDS

### RDS Requirements
- MySQL RDS instance in private subnet
- PostgreSQL RDS instance in private subnet
- Security groups allowing connections from EC2 instances
- Database and user credentials configured

## 🔧 Configuration

### Environment Variables (.env)

```bash
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
```

### Auto Scaling Group Configuration

For Auto Scaling Groups, use the provided `ec2-userdata.sh` script as your Launch Template User Data to automatically setup new instances:

```bash
# In your Launch Template User Data field:
#!/bin/bash
curl -o /tmp/userdata.sh https://raw.githubusercontent.com/your-username/your-repo/main/ec2-userdata.sh
chmod +x /tmp/userdata.sh
/tmp/userdata.sh
```

## 🔍 Health Checks

The application provides health check endpoints for AWS Load Balancer:

- **Frontend Health Check:** `http://instance-ip:3000/health`
- **Backend Health Check:** `http://instance-ip:3001/health`

### ALB Target Group Configuration:
- **Health Check Path:** `/health`
- **Health Check Port:** `3000` (frontend) or `3001` (backend)
- **Health Check Protocol:** `HTTP`
- **Healthy Threshold:** `2`
- **Unhealthy Threshold:** `3`
- **Timeout:** `5 seconds`
- **Interval:** `30 seconds`

## 🛡️ Security Groups

### EC2 Security Group (notes-app-ec2-sg)
```
Inbound Rules:
- Type: HTTP, Protocol: TCP, Port: 3000, Source: ALB Security Group
- Type: Custom TCP, Protocol: TCP, Port: 3001, Source: ALB Security Group
- Type: SSH, Protocol: TCP, Port: 22, Source: Your IP/Bastion Host

Outbound Rules:
- Type: MySQL/Aurora, Protocol: TCP, Port: 3306, Destination: RDS Security Group
- Type: PostgreSQL, Protocol: TCP, Port: 5432, Destination: RDS Security Group
- Type: HTTPS, Protocol: TCP, Port: 443, Destination: 0.0.0.0/0 (for package downloads)
- Type: HTTP, Protocol: TCP, Port: 80, Destination: 0.0.0.0/0 (for package downloads)
```

### RDS Security Group (notes-app-rds-sg)
```
Inbound Rules:
- Type: MySQL/Aurora, Protocol: TCP, Port: 3306, Source: EC2 Security Group
- Type: PostgreSQL, Protocol: TCP, Port: 5432, Source: EC2 Security Group

Outbound Rules:
- None required
```

### ALB Security Group (notes-app-alb-sg)
```
Inbound Rules:
- Type: HTTP, Protocol: TCP, Port: 80, Source: 0.0.0.0/0
- Type: HTTPS, Protocol: TCP, Port: 443, Source: 0.0.0.0/0

Outbound Rules:
- Type: HTTP, Protocol: TCP, Port: 3000, Destination: EC2 Security Group
- Type: Custom TCP, Protocol: TCP, Port: 3001, Destination: EC2 Security Group
```

## 🗄️ Database Access

### Via SSH Tunnel (Recommended for DBeaver)

1. **Setup SSH Tunnel for MySQL:**
   ```bash
   ssh -i your-key.pem -L 3306:mysql-rds-endpoint:3306 ec2-user@your-ec2-ip
   ```

2. **Setup SSH Tunnel for PostgreSQL:**
   ```bash
   ssh -i your-key.pem -L 5432:postgres-rds-endpoint:5432 ec2-user@your-ec2-ip
   ```

3. **Connect with DBeaver:**
   - MySQL: `localhost:3306`
   - PostgreSQL: `localhost:5432`

### Direct Access from EC2

```bash
# MySQL
mysql -h your-mysql-rds-endpoint.region.rds.amazonaws.com -u notes_user -p

# PostgreSQL  
psql -h your-postgres-rds-endpoint.region.rds.amazonaws.com -U notes_user -d notes_db
```

## 🚀 Deployment Commands

### Start Application
```bash
docker-compose -f docker-compose.ec2.yml up -d
```

### Stop Application
```bash
docker-compose -f docker-compose.ec2.yml down
```

### View Logs
```bash
docker-compose -f docker-compose.ec2.yml logs -f
```

### Check Status
```bash
docker-compose -f docker-compose.ec2.yml ps
```

### Update Application
```bash
git pull origin main
docker-compose -f docker-compose.ec2.yml build --no-cache
docker-compose -f docker-compose.ec2.yml up -d
```

## 📊 BI Tool Integration (Third EC2 Instance)

For Metabase deployment on the third EC2 instance:

```yaml
# metabase-docker-compose.yml
services:
  metabase:
    image: metabase/metabase:latest
    container_name: metabase
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      MB_DB_TYPE: postgres
      MB_DB_HOST: your-postgres-rds-endpoint.region.rds.amazonaws.com
      MB_DB_PORT: 5432
      MB_DB_USER: notes_user
      MB_DB_PASS: your-secure-password
      MB_DB_DBNAME: notes_db
```

## 🔧 Troubleshooting

### Common Issues

1. **Cannot connect to RDS:**
   - Check security groups
   - Verify RDS endpoint and credentials
   - Ensure RDS is in same VPC as EC2

2. **Health checks failing:**
   - Verify applications are running on correct ports
   - Check ALB target group configuration
   - Review application logs

3. **Docker issues:**
   - Ensure Docker daemon is running: `sudo systemctl start docker`
   - Check Docker permissions: `sudo usermod -a -G docker ec2-user`
   - Restart session after adding user to docker group

### Logs and Monitoring

```bash
# Application logs
docker-compose -f docker-compose.ec2.yml logs backend
docker-compose -f docker-compose.ec2.yml logs frontend

# System logs
sudo tail -f /var/log/user-data.log
sudo journalctl -u docker.service

# Check application status
curl http://localhost:3000/health
curl http://localhost:3001/health
```

## 🎯 Production Ready Features

- ✅ Multi-stage Docker builds for optimization
- ✅ Health checks for load balancer integration
- ✅ Security hardened containers
- ✅ Environment-based configuration
- ✅ Automatic RDS connectivity testing
- ✅ Comprehensive logging
- ✅ Production-grade error handling
- ✅ No Prisma dependency (direct SQL)
- ✅ Dual database support (MySQL + PostgreSQL)
- ✅ Auto Scaling Group ready
- ✅ Load balancer ready

## 📱 Application Features

- 📝 Create, read, update, delete notes
- 🗄️ Switch between MySQL and PostgreSQL databases
- 📱 Responsive modern UI
- 🔄 Real-time database selection
- 🚀 Production-ready architecture
- 📊 Ready for BI tool integration

Your Notes App is now ready for production deployment on AWS with Auto Scaling, Load Balancing, and RDS integration! 🎉 
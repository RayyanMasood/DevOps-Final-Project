# Deploy Notes App to Your Terraform Infrastructure

## 🎯 **Perfect Match!** 

Your Terraform infrastructure is **exactly** what the Notes App was designed for! Here's how to deploy it to your existing AWS infrastructure.

## 📊 **Your Current Infrastructure:**

```
✅ Auto Scaling Group: devops-final-project-dev-app-asg (3-6 t3.medium instances)
✅ Application Load Balancer: devops-final-project-dev-alb-1346156442.us-east-1.elb.amazonaws.com
✅ MySQL RDS: devops-final-project-dev-mysql.ca5ucs84k9va.us-east-1.rds.amazonaws.com
✅ PostgreSQL RDS: devops-final-project-dev-postgres.ca5ucs84k9va.us-east-1.rds.amazonaws.com
✅ VPC: vpc-0db7251f29bd9fc41 (10.0.0.0/16)
✅ Security Groups: Properly configured for ALB → EC2 → RDS
✅ Health Checks: /health endpoint configured
```

## 🚀 **Quick Deployment (3 Steps)**

### **Step 1: Initialize Databases**

Your RDS instances are ready, but they need the Notes app tables. Connect via SSH tunnel:

```bash
# Connect to any EC2 instance in your Auto Scaling Group
ssh -i DevOps-FP-KeyPair.pem ec2-user@<any-ec2-instance-ip>

# Setup MySQL
mysql -h devops-final-project-dev-mysql.ca5ucs84k9va.us-east-1.rds.amazonaws.com -u admin -pmysqlpass123
```

```sql
-- Run this in MySQL
CREATE DATABASE IF NOT EXISTS notes_db;
USE notes_db;

CREATE TABLE IF NOT EXISTS notes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    database_type VARCHAR(50) DEFAULT 'mysql'
);

INSERT INTO notes (title, content, database_type) VALUES
('Welcome to Production!', 'Your Notes App is now running on AWS with Auto Scaling!', 'mysql'),
('Terraform Infrastructure', 'Successfully deployed using your existing Terraform configuration.', 'mysql');
```

```bash
# Setup PostgreSQL
psql -h devops-final-project-dev-postgres.ca5ucs84k9va.us-east-1.rds.amazonaws.com -U postgres -d devops_dashboard
```

```sql
-- Run this in PostgreSQL
CREATE TABLE IF NOT EXISTS notes (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    database_type VARCHAR(50) DEFAULT 'postgres'
);

INSERT INTO notes (title, content, database_type) VALUES
('PostgreSQL Ready!', 'Your PostgreSQL RDS is now configured for the Notes App.', 'postgres'),
('Dual Database Setup', 'You can now switch between MySQL and PostgreSQL in the app.', 'postgres');
```

### **Step 2: Deploy to EC2 Instances**

Upload the app to any EC2 instance (it will replicate via Auto Scaling):

```bash
# From your local machine
scp -i DevOps-FP-KeyPair.pem -r ./app ec2-user@<ec2-instance-ip>:/opt/notes-app

# SSH into the instance
ssh -i DevOps-FP-KeyPair.pem ec2-user@<ec2-instance-ip>
cd /opt/notes-app

# Use the pre-configured environment file
cp env.terraform-generated .env

# Deploy the application
chmod +x deploy-ec2.sh
./deploy-ec2.sh
```

### **Step 3: Access Your Application**

Your app is now available at:

🌐 **Main Application:** http://devops-final-project-dev-alb-1346156442.us-east-1.elb.amazonaws.com

🔍 **Health Checks:** 
- Frontend: http://devops-final-project-dev-alb-1346156442.us-east-1.elb.amazonaws.com/health
- Backend API: http://devops-final-project-dev-alb-1346156442.us-east-1.elb.amazonaws.com/api/health

## 🎯 **Load Balancer Target Groups**

Your ALB is already configured for health checks at `/health`. The app provides these endpoints:

- **Frontend Health Check:** Port 3000, Path `/health`
- **Backend Health Check:** Port 3001, Path `/health`

Both return `{"status": "healthy", "timestamp": "..."}` for ALB health verification.

## 🔧 **Auto Scaling Integration**

### **Update Launch Template**

To automatically deploy to new instances in your Auto Scaling Group:

1. **Update your Launch Template User Data:**

```bash
#!/bin/bash
yum update -y

# Install Docker (already done in your setup)
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Clone and deploy the application
git clone https://github.com/your-username/your-repo.git /opt/notes-app
cd /opt/notes-app

# Use the Terraform-generated config
cp env.terraform-generated .env

# Deploy
chmod +x deploy-ec2.sh
./deploy-ec2.sh

# Log completion
echo "$(date): Notes App deployed successfully" >> /var/log/user-data.log
```

2. **Update Auto Scaling Group to use new Launch Template version**

## 🗄️ **Database Connection Strings**

Your app is pre-configured with these connection strings:

```bash
# MySQL
mysql://admin:mysqlpass123@devops-final-project-dev-mysql.ca5ucs84k9va.us-east-1.rds.amazonaws.com:3306/notes_db

# PostgreSQL  
postgresql://postgres:postgrespass123@devops-final-project-dev-postgres.ca5ucs84k9va.us-east-1.rds.amazonaws.com:5432/notes_db
```

## 🛡️ **Security Groups (Already Configured)**

Your existing security groups are perfect:

- **App Security Group (sg-0db0671abf986a143):** Allows ALB → EC2 on ports 3000/3001
- **Database Security Group (sg-0ba9db8db9a4a5a9e):** Allows EC2 → RDS on ports 3306/5432
- **ALB Security Group (sg-06b7e145b1f985a46):** Allows Internet → ALB on ports 80/443

## 📊 **Monitoring & Scaling**

Your infrastructure includes:

- ✅ **CloudWatch Dashboard:** Available in AWS Console
- ✅ **Auto Scaling:** 3-6 instances based on CPU (70% threshold)
- ✅ **Health Checks:** ALB monitors application health
- ✅ **Backup:** 7-day retention for both databases

## 🚀 **Application Features**

The Notes App includes:

- 📝 **Full CRUD Operations** for notes
- 🔄 **Database Switching** between MySQL and PostgreSQL
- 📱 **Responsive UI** optimized for production
- 🔍 **Health Endpoints** for load balancer integration
- 🐳 **Multi-stage Docker** builds for optimization
- 🛡️ **Security Hardened** containers

## 🎉 **Next Steps**

1. **Deploy the app** using the steps above
2. **Test database switching** in the UI
3. **Scale up your Auto Scaling Group** to test load balancing
4. **Add your domain** (update `domain_name` in terraform.tfvars)
5. **Deploy BI tool** (Metabase) on the 3rd instance

## 💡 **Pro Tips**

- **Terraform State:** Your infrastructure is already deployed and managed
- **Database Names:** The app creates `notes_db` tables in your existing databases
- **Port Configuration:** Frontend (3000) and Backend (3001) are load-balanced
- **Health Checks:** ALB automatically routes traffic to healthy instances
- **Scaling:** Add more instances during high load, they'll auto-configure

## 🔧 **Troubleshooting**

If you encounter issues:

```bash
# Check application logs
docker-compose -f docker-compose.ec2.yml logs -f

# Test database connectivity
mysql -h devops-final-project-dev-mysql.ca5ucs84k9va.us-east-1.rds.amazonaws.com -u admin -p
psql -h devops-final-project-dev-postgres.ca5ucs84k9va.us-east-1.rds.amazonaws.com -U postgres

# Check health endpoints
curl http://localhost:3000/health
curl http://localhost:3001/health
```

**Your infrastructure is perfect for this application! 🎯**

The Notes App was designed exactly for this type of AWS setup with Auto Scaling Groups, Application Load Balancer, and RDS instances. Everything should work seamlessly! 🚀 
#!/bin/bash
# User Data Script for EC2 Instances
# This script installs and configures the application environment

# Enable logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user data script execution at $(date)"

# Update system packages
yum update -y

# Install required packages
yum install -y \
    docker \
    git \
    htop \
    vim \
    curl \
    wget \
    unzip \
    jq \
    awscli

# Install Node.js 20
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs

# Install PM2 for process management
npm install -g pm2

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create CloudWatch agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "metrics": {
        "namespace": "CWAgent",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60,
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time",
                    "read_bytes",
                    "write_bytes",
                    "reads",
                    "writes"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            },
            "swap": {
                "measurement": [
                    "swap_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/aws/ec2/var/log/messages",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/var/log/user-data.log",
                        "log_group_name": "/aws/ec2/user-data",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/var/log/app.log",
                        "log_group_name": "/aws/ec2/application",
                        "log_stream_name": "{instance_id}"
                    }
                ]
            }
        }
    }
}
EOF

# Start and enable CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Create application directory
mkdir -p /opt/app
chown ec2-user:ec2-user /opt/app

# Create environment file for database connections
cat > /opt/app/.env << EOF
# Database Configuration
MYSQL_HOST=${mysql_endpoint}
MYSQL_PORT=3306
MYSQL_DATABASE=appdb

POSTGRES_HOST=${postgres_endpoint}
POSTGRES_PORT=5432
POSTGRES_DATABASE=appdb

# AWS Configuration
AWS_REGION=${aws_region}
MYSQL_SECRET_ARN=${mysql_secret_arn}
POSTGRES_SECRET_ARN=${postgres_secret_arn}

# Application Configuration
NODE_ENV=production
PORT=8080
LOG_LEVEL=info
EOF

chown ec2-user:ec2-user /opt/app/.env

# Create a sample Node.js application
cat > /opt/app/app.js << 'EOF'
const express = require('express');
const AWS = require('aws-sdk');
const mysql = require('mysql2/promise');
const { Client } = require('pg');

const app = express();
const port = process.env.PORT || 8080;

// AWS Configuration
const secretsManager = new AWS.SecretsManager({
    region: process.env.AWS_REGION
});

let mysqlConnection = null;
let postgresConnection = null;

// Initialize database connections
async function initializeDatabases() {
    try {
        // Get MySQL credentials from Secrets Manager
        const mysqlSecret = await secretsManager.getSecretValue({
            SecretId: process.env.MYSQL_SECRET_ARN
        }).promise();
        
        const mysqlCreds = JSON.parse(mysqlSecret.SecretString);
        
        mysqlConnection = await mysql.createConnection({
            host: mysqlCreds.endpoint,
            port: mysqlCreds.port,
            user: mysqlCreds.username,
            password: mysqlCreds.password,
            database: mysqlCreds.dbname
        });
        
        console.log('MySQL connection established');
        
        // Get PostgreSQL credentials from Secrets Manager
        const postgresSecret = await secretsManager.getSecretValue({
            SecretId: process.env.POSTGRES_SECRET_ARN
        }).promise();
        
        const postgresCreds = JSON.parse(postgresSecret.SecretString);
        
        postgresConnection = new Client({
            host: postgresCreds.endpoint,
            port: postgresCreds.port,
            user: postgresCreds.username,
            password: postgresCreds.password,
            database: postgresCreds.dbname
        });
        
        await postgresConnection.connect();
        console.log('PostgreSQL connection established');
        
    } catch (error) {
        console.error('Database initialization error:', error);
    }
}

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Root endpoint
app.get('/', (req, res) => {
    res.json({
        message: 'DevOps Final Project API',
        version: '1.0.0',
        timestamp: new Date().toISOString()
    });
});

// Database status endpoint
app.get('/db-status', async (req, res) => {
    const status = {
        mysql: 'disconnected',
        postgres: 'disconnected'
    };
    
    try {
        if (mysqlConnection) {
            await mysqlConnection.execute('SELECT 1');
            status.mysql = 'connected';
        }
    } catch (error) {
        console.error('MySQL status check failed:', error.message);
    }
    
    try {
        if (postgresConnection) {
            await postgresConnection.query('SELECT 1');
            status.postgres = 'connected';
        }
    } catch (error) {
        console.error('PostgreSQL status check failed:', error.message);
    }
    
    res.json(status);
});

// Start server
app.listen(port, () => {
    console.log(`Server running on port ${port}`);
    initializeDatabases();
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    if (mysqlConnection) {
        mysqlConnection.end();
    }
    if (postgresConnection) {
        postgresConnection.end();
    }
    process.exit(0);
});
EOF

# Create package.json
cat > /opt/app/package.json << 'EOF'
{
    "name": "devops-final-project",
    "version": "1.0.0",
    "description": "DevOps Final Project Application",
    "main": "app.js",
    "scripts": {
        "start": "node app.js",
        "dev": "nodemon app.js"
    },
    "dependencies": {
        "express": "^4.18.2",
        "mysql2": "^3.6.0",
        "pg": "^8.11.0",
        "aws-sdk": "^2.1449.0"
    },
    "engines": {
        "node": ">=20.0.0"
    }
}
EOF

chown ec2-user:ec2-user /opt/app/package.json /opt/app/app.js

# Install Node.js dependencies
cd /opt/app
sudo -u ec2-user npm install

# Create PM2 ecosystem file
cat > /opt/app/ecosystem.config.js << 'EOF'
module.exports = {
    apps: [{
        name: 'devops-app',
        script: 'app.js',
        instances: 'max',
        exec_mode: 'cluster',
        env: {
            NODE_ENV: 'production',
            PORT: 8080
        },
        log_file: '/var/log/app.log',
        out_file: '/var/log/app-out.log',
        error_file: '/var/log/app-error.log',
        time: true
    }]
};
EOF

chown ec2-user:ec2-user /opt/app/ecosystem.config.js

# Start the application with PM2
sudo -u ec2-user pm2 start /opt/app/ecosystem.config.js
sudo -u ec2-user pm2 save
sudo -u ec2-user pm2 startup

# Install and configure Nginx as reverse proxy
yum install -y nginx

cat > /etc/nginx/conf.d/app.conf << 'EOF'
upstream app_backend {
    server 127.0.0.1:8080;
}

server {
    listen 80;
    server_name _;
    
    # Health check endpoint (bypass proxy for ALB health checks)
    location /health {
        proxy_pass http://app_backend/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Health check specific settings
        proxy_connect_timeout 5s;
        proxy_send_timeout 5s;
        proxy_read_timeout 5s;
    }
    
    # All other requests
    location / {
        proxy_pass http://app_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
}
EOF

# Test nginx configuration and start
nginx -t
systemctl start nginx
systemctl enable nginx

# Create log rotation for application logs
cat > /etc/logrotate.d/app << 'EOF'
/var/log/app*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 ec2-user ec2-user
    postrotate
        sudo -u ec2-user pm2 reloadLogs
    endscript
}
EOF

# Set up automatic security updates
yum install -y yum-cron
systemctl enable yum-cron
systemctl start yum-cron

echo "User data script completed successfully at $(date)"

# Signal that the instance is ready
echo "Instance initialization completed successfully"

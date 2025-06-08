#!/bin/bash
# User Data Script for Docker-based Application Deployment

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting Docker deployment user data script at $(date)"

# Update and install packages
yum update -y
yum install -y docker git curl wget unzip jq awscli

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Start Docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create app directory
mkdir -p /opt/app
cd /opt/app

# Set environment variables
export MYSQL_HOST="${mysql_endpoint}"
export POSTGRES_HOST="${postgres_endpoint}"
export AWS_REGION="${aws_region}"
export MYSQL_SECRET_ARN="${mysql_secret_arn}"
export POSTGRES_SECRET_ARN="${postgres_secret_arn}"

# Create Docker Compose file
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  nginx:
    image: nginx:alpine
    container_name: frontend
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./html:/usr/share/nginx/html:ro
    depends_on:
      - backend
    restart: unless-stopped

  backend:
    image: node:18-alpine
    container_name: backend
    working_dir: /app
    ports:
      - "3001:3001"
    environment:
      - NODE_ENV=production
      - PORT=3001
    volumes:
      - ./backend:/app
    command: ["sh", "-c", "npm install && npm start"]
    restart: unless-stopped
EOF

# Create Nginx config
cat > nginx.conf << 'EOF'
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    charset utf-8;
    
    upstream backend { server backend:3001; }
    
    server {
        listen 80;
        server_name _;
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type "text/plain; charset=utf-8";
        }
        
        location /api/ {
            proxy_pass http://backend/api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files $uri $uri/ /index.html;
            add_header Content-Type "text/html; charset=utf-8";
        }
    }
}
EOF

# Create frontend
mkdir -p html
cat > html/index.html << 'EOF'
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>DevOps Final Project</title>
<style>body{font-family:Arial;margin:0;padding:20px;background:#f4f4f4}
.container{max-width:1200px;margin:0 auto;background:white;padding:20px;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,0.1)}
h1{color:#333;text-align:center}.status{background:#e8f5e8;padding:15px;border-radius:5px;margin:20px 0}
.feature{background:#f8f9fa;padding:15px;margin:10px 0;border-left:4px solid #007bff}</style></head>
<body><div class="container"><h1>🚀 DevOps Final Project - Docker Deployment</h1>
<div class="status"><h3>✅ Deployment Status: Active</h3><p>Multi-tier application running successfully!</p></div>
<div class="feature"><h3>📦 Infrastructure</h3><ul><li>VPC with Public/Private/Database Subnets</li>
<li>Application Load Balancer</li><li>Auto Scaling Group (2 EC2 instances)</li><li>MySQL & PostgreSQL Databases</li>
<li>CloudWatch Monitoring</li><li>Docker Containerized Apps</li></ul></div>
<div class="feature"><h3>🐳 Docker Services</h3><ul><li>Nginx Frontend (Port 80)</li>
<li>Node.js Backend API (Port 3001)</li><li>Multi-stage Dockerfiles</li><li>Container Orchestration</li></ul></div></div>
<script>fetch('/api/health').then(r=>r.text()).then(d=>console.log('Backend:',d)).catch(e=>console.log('Backend loading:',e));</script></body></html>
EOF

# Create backend
mkdir -p backend
cat > backend/package.json << 'EOF'
{"name":"devops-backend","version":"1.0.0","main":"server.js","scripts":{"start":"node server.js"},"dependencies":{"express":"^4.18.2","cors":"^2.8.5"}}
EOF

cat > backend/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

app.get('/api/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/api/info', (req, res) => {
  res.json({
    service: 'DevOps Final Project Backend',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development'
  });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log('Server running on port ' + PORT);
});
EOF

# Start application
chown -R ec2-user:ec2-user /opt/app
docker-compose up -d

# Basic CloudWatch config
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "cpu": {"measurement": ["cpu_usage_idle"], "metrics_collection_interval": 60},
      "mem": {"measurement": ["mem_used_percent"], "metrics_collection_interval": 60}
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {"file_path": "/var/log/user-data.log", "log_group_name": "/aws/ec2/user-data", "log_stream_name": "{instance_id}"},
          {"file_path": "/var/log/messages", "log_group_name": "/aws/ec2/var/log/messages", "log_stream_name": "{instance_id}"}
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

sleep 30
docker-compose ps
echo "Docker deployment completed at $(date)" 
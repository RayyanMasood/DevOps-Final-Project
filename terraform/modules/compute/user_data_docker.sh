#!/bin/bash
# User Data Script for Docker-based Application Deployment

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting Docker deployment user data script at $(date)"

# Update and install packages
yum update -y
yum install -y docker git curl wget unzip jq awscli mysql postgresql15-server postgresql15-devel postgresql15

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

# Set environment variables for database connectivity
export MYSQL_HOST="${mysql_endpoint}"
export POSTGRES_HOST="${postgres_endpoint}"
export AWS_REGION="${aws_region}"
export MYSQL_SECRET_ARN="${mysql_secret_arn}"
export POSTGRES_SECRET_ARN="${postgres_secret_arn}"

# Clone the application from GitHub
echo "Cloning application repository..."
cd /opt
git clone https://github.com/RayyanMasood/DevOps-Final-Project.git app
cd /opt/app/app

# Get database credentials from AWS Secrets Manager
echo "Retrieving database credentials from Secrets Manager..."
MYSQL_SECRET=$(aws secretsmanager get-secret-value --secret-id "${mysql_secret_arn}" --region "${aws_region}" --query SecretString --output text)
POSTGRES_SECRET=$(aws secretsmanager get-secret-value --secret-id "${postgres_secret_arn}" --region "${aws_region}" --query SecretString --output text)

MYSQL_PASSWORD=$(echo $MYSQL_SECRET | jq -r '.password')
POSTGRES_PASSWORD=$(echo $POSTGRES_SECRET | jq -r '.password')

# Extract hostnames without ports
MYSQL_HOST=$(echo "${mysql_endpoint}" | cut -d: -f1)
POSTGRES_HOST=$(echo "${postgres_endpoint}" | cut -d: -f1)

# Update docker-compose.yml with RDS endpoints and credentials
cat > docker-compose.production.yml << EOF
services:
  # Backend API
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
      target: production
    container_name: notes-backend
    restart: unless-stopped
    environment:
      NODE_ENV: production
      PORT: 3001
      # CORS Configuration
      CORS_ORIGIN: "*"
      # MySQL RDS Configuration
      MYSQL_HOST: $MYSQL_HOST
      MYSQL_PORT: 3306
      MYSQL_USER: notes_user
      MYSQL_PASSWORD: $MYSQL_PASSWORD
      MYSQL_DATABASE: notes_db
      # PostgreSQL RDS Configuration  
      POSTGRES_HOST: $POSTGRES_HOST
      POSTGRES_PORT: 5432
      POSTGRES_USER: notes_user
      POSTGRES_PASSWORD: $POSTGRES_PASSWORD
      POSTGRES_DATABASE: notes_db
    ports:
      - "3001:3001"
    networks:
      - notes-network
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3001/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  # Frontend React App
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
      target: production
    container_name: notes-frontend
    restart: unless-stopped
    environment:
      REACT_APP_API_URL: /api
    ports:
      - "3000:3000"
    depends_on:
      - backend
    networks:
      - notes-network
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  # Load Balancer (nginx)
  loadbalancer:
    image: nginx:alpine
    container_name: notes-loadbalancer
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/conf.d:/etc/nginx/conf.d
    depends_on:
      - frontend
      - backend
    networks:
      - notes-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  notes-network:
    driver: bridge
EOF

# Ensure proper permissions
chown -R ec2-user:ec2-user /opt/app

# Wait for Docker to be fully ready
sleep 10

# Build and start the application using production compose file
echo "Building and starting application containers..."
docker-compose -f docker-compose.production.yml up -d --build

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 60

# Initialize database schemas
echo "Initializing database schemas..."

# Wait for databases to be accessible
for i in {1..10}; do
    echo "Checking database connectivity (attempt $i)..."
    
    # Test MySQL connection
    echo "Testing MySQL connection to $MYSQL_HOST:3306..."
    if mysql -h "$MYSQL_HOST" -P 3306 -u notes_user -p"$MYSQL_PASSWORD" -e "SELECT 1;" > /dev/null 2>&1; then
        echo "MySQL connection successful"
        # Initialize MySQL schema
        mysql -h "$MYSQL_HOST" -P 3306 -u notes_user -p"$MYSQL_PASSWORD" notes_db < /opt/app/app/database/mysql/init.sql
        break
    else
        echo "MySQL connection failed, retrying in 30 seconds..."
        sleep 30
    fi
done

for i in {1..10}; do
    echo "Checking PostgreSQL connectivity (attempt $i)..."
    
    # Test PostgreSQL connection
    echo "Testing PostgreSQL connection to $POSTGRES_HOST:5432..."
    if PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p 5432 -U notes_user -d notes_db -c "SELECT 1;" > /dev/null 2>&1; then
        echo "PostgreSQL connection successful"
        # Initialize PostgreSQL schema
        PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p 5432 -U notes_user -d notes_db -f /opt/app/app/database/postgres/init.sql
        break
    else
        echo "PostgreSQL connection failed, retrying in 30 seconds..."
        sleep 30
    fi
done

# Check container status
echo "Container status:"
docker-compose -f docker-compose.production.yml ps

# Test application health
echo "Testing application health..."
for i in {1..5}; do
    if curl -f http://localhost/health > /dev/null 2>&1; then
        echo "Application health check passed"
        break
    else
        echo "Health check attempt $i failed, retrying in 10 seconds..."
        sleep 10
    fi
done

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "metrics": {
    "namespace": "DevOpsApp/EC2",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": ["used_percent"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "diskio": {
        "measurement": ["io_time"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "netstat": {
        "measurement": ["tcp_established", "tcp_time_wait"],
        "metrics_collection_interval": 60
      },
      "swap": {
        "measurement": ["swap_used_percent"],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/ec2/user-data",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/var/log/messages", 
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Create systemd service for the application to ensure it starts on boot
cat > /etc/systemd/system/notes-app.service << 'EOF'
[Unit]
Description=Notes Application
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/app/app
ExecStart=/usr/local/bin/docker-compose -f docker-compose.production.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.production.yml down
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
systemctl enable notes-app.service

# Final status check
echo "Final deployment status check:"
docker-compose -f docker-compose.production.yml logs --tail=20
echo "Docker deployment completed at $(date)" 
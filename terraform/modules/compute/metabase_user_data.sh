#!/bin/bash
# Metabase Instance User Data Script
# Installs and configures Metabase BI tool with Docker

# Enable logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting Metabase instance configuration at $(date)"

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

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Create Metabase application directory
mkdir -p /opt/metabase
chown ec2-user:ec2-user /opt/metabase

# Get PostgreSQL credentials from Secrets Manager
DB_SECRET=$(aws secretsmanager get-secret-value --secret-id ${postgres_secret_arn} --region ${aws_region} --query SecretString --output text)
DB_HOST=$(echo $DB_SECRET | jq -r .endpoint)
DB_USER=$(echo $DB_SECRET | jq -r .username)
DB_PASS=$(echo $DB_SECRET | jq -r .password)
DB_NAME=$(echo $DB_SECRET | jq -r .dbname)

# Create environment file for Metabase
cat > /opt/metabase/.env << EOF
# Metabase Configuration
MB_DB_TYPE=postgres
MB_DB_DBNAME=$DB_NAME
MB_DB_PORT=5432
MB_DB_USER=$DB_USER
MB_DB_PASS=$DB_PASS
MB_DB_HOST=$DB_HOST

# Application Configuration
MB_SITE_NAME=DevOps Analytics Dashboard
MB_SITE_URL=http://$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):3000
MB_ADMIN_EMAIL=admin@devops-project.com

# Performance Settings
JAVA_OPTS=-Xmx2g -Xms1g -XX:+UseG1GC
MB_JETTY_HOST=0.0.0.0
MB_JETTY_PORT=3000

# Security Settings
MB_PASSWORD_COMPLEXITY=strong
MB_PASSWORD_LENGTH=12
MB_ENABLE_PUBLIC_SHARING=false
MB_ENABLE_EMBEDDING=true
MB_SESSION_TIMEOUT=720

# Analytics & Tracking
MB_ANON_TRACKING_ENABLED=false
MB_CHECK_FOR_UPDATES=false
EOF

chown ec2-user:ec2-user /opt/metabase/.env

# Create Metabase Docker Compose file
cat > /opt/metabase/docker-compose.yml << 'EOF'
version: '3.8'

services:
  metabase:
    image: metabase/metabase:v0.47.7
    container_name: metabase
    hostname: metabase
    volumes:
      - metabase-data:/metabase-data
      - ./config:/config
      - ./logs:/logs
    env_file:
      - .env
    ports:
      - "3000:3000"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

volumes:
  metabase-data:
    driver: local
EOF

chown ec2-user:ec2-user /opt/metabase/docker-compose.yml

# Create Metabase startup script
cat > /opt/metabase/start-metabase.sh << 'EOF'
#!/bin/bash
cd /opt/metabase
docker-compose up -d
echo "Metabase starting... Access at http://$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):3000"
EOF

chmod +x /opt/metabase/start-metabase.sh
chown ec2-user:ec2-user /opt/metabase/start-metabase.sh

# Create systemd service for Metabase
cat > /etc/systemd/system/metabase.service << 'EOF'
[Unit]
Description=Metabase BI Tool
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=ec2-user
Group=ec2-user
WorkingDirectory=/opt/metabase
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Metabase service
systemctl daemon-reload
systemctl enable metabase.service

# Wait for docker to be ready then start Metabase
sleep 30
systemctl start metabase.service

# Create sample data initialization script
cat > /opt/metabase/init-sample-data.sql << 'EOF'
-- Sample data for Metabase dashboards
CREATE TABLE IF NOT EXISTS sales_data (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    sales_amount DECIMAL(10,2) NOT NULL,
    quantity_sold INTEGER NOT NULL,
    region VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample sales data
INSERT INTO sales_data (date, product_name, category, sales_amount, quantity_sold, region) VALUES
('2024-01-01', 'Product A', 'Electronics', 1500.00, 5, 'North'),
('2024-01-02', 'Product B', 'Electronics', 2500.00, 10, 'South'),
('2024-01-03', 'Product C', 'Clothing', 800.00, 8, 'East'),
('2024-01-04', 'Product D', 'Books', 300.00, 15, 'West'),
('2024-01-05', 'Product A', 'Electronics', 1200.00, 4, 'North'),
('2024-01-06', 'Product E', 'Home', 950.00, 3, 'South'),
('2024-01-07', 'Product F', 'Electronics', 1800.00, 6, 'East'),
('2024-01-08', 'Product G', 'Clothing', 600.00, 12, 'West'),
('2024-01-09', 'Product H', 'Books', 450.00, 18, 'North'),
('2024-01-10', 'Product I', 'Home', 1100.00, 4, 'South');

-- Create users table for dashboard demo
CREATE TABLE IF NOT EXISTS user_activity (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT
);

-- Insert sample user activity data
INSERT INTO user_activity (user_id, activity_type, ip_address, user_agent) VALUES
(1, 'login', '192.168.1.100', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'),
(2, 'login', '192.168.1.101', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'),
(3, 'page_view', '192.168.1.102', 'Mozilla/5.0 (X11; Linux x86_64)'),
(1, 'purchase', '192.168.1.100', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'),
(4, 'login', '192.168.1.103', 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1)'),
(2, 'logout', '192.168.1.101', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'),
(5, 'signup', '192.168.1.104', 'Mozilla/5.0 (Android 11; Mobile)'),
(3, 'purchase', '192.168.1.102', 'Mozilla/5.0 (X11; Linux x86_64)'),
(6, 'login', '192.168.1.105', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'),
(4, 'page_view', '192.168.1.103', 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1)');
EOF

# Add alias for easy access
echo "alias metabase-logs='docker logs metabase'" >> /home/ec2-user/.bashrc
echo "alias metabase-restart='cd /opt/metabase && docker-compose restart'" >> /home/ec2-user/.bashrc
echo "alias metabase-status='cd /opt/metabase && docker-compose ps'" >> /home/ec2-user/.bashrc

echo "Metabase instance configuration completed at $(date)"
echo "Metabase will be available at http://$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):3000" 
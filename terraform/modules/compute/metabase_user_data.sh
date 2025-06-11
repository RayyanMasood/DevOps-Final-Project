#!/bin/bash
# Metabase Instance User Data Script
# Installs and configures Metabase BI tool with Docker

# Enable logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting Metabase instance configuration at $(date)"

# Update system packages
yum update -y

# Install required packages
yum install -y docker git htop vim curl wget unzip jq awscli at postgresql15

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Start and enable at daemon
systemctl start atd
systemctl enable atd

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
cat > /opt/metabase/.env << ENV_EOF
MB_DB_TYPE=postgres
MB_DB_DBNAME=$DB_NAME
MB_DB_PORT=5432
MB_DB_USER=$DB_USER
MB_DB_PASS=$DB_PASS
MB_DB_HOST=$DB_HOST
MB_SITE_NAME=DevOps Analytics Dashboard
MB_ADMIN_EMAIL=admin@devops-project.com
JAVA_OPTS=-Xmx2g -Xms1g -XX:+UseG1GC
MB_JETTY_HOST=0.0.0.0
MB_JETTY_PORT=3000
MB_PASSWORD_COMPLEXITY=strong
MB_PASSWORD_LENGTH=12
MB_ENABLE_PUBLIC_SHARING=false
MB_ENABLE_EMBEDDING=true
MB_SESSION_TIMEOUT=720
MB_ANON_TRACKING_ENABLED=false
MB_CHECK_FOR_UPDATES=false
ENV_EOF

chown ec2-user:ec2-user /opt/metabase/.env

# Create Docker Compose file
cat > /opt/metabase/docker-compose.yml << COMPOSE_EOF
version: '3.8'
services:
  metabase:
    image: metabase/metabase:v0.47.7
    container_name: metabase
    hostname: metabase
    volumes:
      - metabase-data:/metabase-data
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
COMPOSE_EOF

chown ec2-user:ec2-user /opt/metabase/docker-compose.yml

# Create startup script
cat > /opt/metabase/start-metabase.sh << START_EOF
#!/bin/bash
cd /opt/metabase
docker-compose up -d
echo "Metabase starting..."
START_EOF

chmod +x /opt/metabase/start-metabase.sh
chown ec2-user:ec2-user /opt/metabase/start-metabase.sh

# Create systemd service
cat > /etc/systemd/system/metabase.service << SERVICE_EOF
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
SERVICE_EOF

# Enable and start service
systemctl daemon-reload
systemctl enable metabase.service
sleep 30
systemctl start metabase.service

# Create live data script
cat > /opt/metabase/add-live-data.sh << LIVE_EOF
#!/bin/bash
source /opt/metabase/.env

add_sales_data() {
    local products=("Product A" "Product B" "Product C" "Product D" "Product E")
    local categories=("Electronics" "Clothing" "Books" "Home" "Sports")
    local regions=("North" "South" "East" "West" "Central")
    
    local product=\${products[\$RANDOM % \${#products[@]}]}
    local category=\${categories[\$RANDOM % \${#categories[@]}]}
    local region=\${regions[\$RANDOM % \${#regions[@]}]}
    local amount=\$((\$RANDOM % 3000 + 100))
    local quantity=\$((\$RANDOM % 20 + 1))
    
    PGPASSWORD=\$MB_DB_PASS psql -h \$MB_DB_HOST -U \$MB_DB_USER -d \$MB_DB_DBNAME -c "INSERT INTO sales_data (date, product_name, category, sales_amount, quantity_sold, region) VALUES (CURRENT_DATE, '\$product', '\$category', \$amount.00, \$quantity, '\$region');"
    
    echo "Added: \$product, \$category, \$\${\$amount}, \$quantity units, \$region"
}

case "\$1" in
    "sales")
        add_sales_data
        ;;
    *)
        echo "Usage: \$0 {sales}"
        ;;
esac
LIVE_EOF

chmod +x /opt/metabase/add-live-data.sh
chown ec2-user:ec2-user /opt/metabase/add-live-data.sh

# Create sample data script
cat > /opt/metabase/init-sample-data.sh << SAMPLE_EOF
#!/bin/bash
source /opt/metabase/.env
sleep 60

PGPASSWORD=\$MB_DB_PASS psql -h \$MB_DB_HOST -U \$MB_DB_USER -d \$MB_DB_DBNAME << 'SQL_EOF'
DROP TABLE IF EXISTS sales_data CASCADE;
CREATE TABLE sales_data (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    sales_amount DECIMAL(10,2) NOT NULL,
    quantity_sold INTEGER NOT NULL,
    region VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO sales_data (date, product_name, category, sales_amount, quantity_sold, region) VALUES
('2024-01-01', 'Product A', 'Electronics', 1500.00, 5, 'North'),
('2024-01-02', 'Product B', 'Electronics', 2500.00, 10, 'South'),
('2024-01-03', 'Product C', 'Clothing', 800.00, 8, 'East'),
('2024-01-04', 'Product D', 'Books', 300.00, 15, 'West'),
('2024-01-05', 'Product E', 'Home', 950.00, 3, 'Central');

DROP TABLE IF EXISTS user_activity CASCADE;
CREATE TABLE user_activity (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT
);

INSERT INTO user_activity (user_id, activity_type, ip_address, user_agent) VALUES
(1, 'login', '192.168.1.100', 'Mozilla/5.0 (Windows)'),
(2, 'login', '192.168.1.101', 'Mozilla/5.0 (Mac)'),
(3, 'page_view', '192.168.1.102', 'Mozilla/5.0 (Linux)'),
(1, 'purchase', '192.168.1.100', 'Mozilla/5.0 (Windows)'),
(4, 'login', '192.168.1.103', 'Mozilla/5.0 (iPhone)');
SQL_EOF

echo "Sample data initialized successfully!"
SAMPLE_EOF

chmod +x /opt/metabase/init-sample-data.sh
chown ec2-user:ec2-user /opt/metabase/init-sample-data.sh

# Add aliases
echo "alias add-sales='cd /opt/metabase && ./add-live-data.sh sales'" >> /home/ec2-user/.bashrc
echo "alias init-sample-data='cd /opt/metabase && ./init-sample-data.sh'" >> /home/ec2-user/.bashrc
echo "alias metabase-logs='docker logs metabase'" >> /home/ec2-user/.bashrc
echo "alias metabase-status='cd /opt/metabase && docker-compose ps'" >> /home/ec2-user/.bashrc

# Schedule data initialization
echo "/opt/metabase/init-sample-data.sh" | at now + 3 minutes

echo "Metabase instance configuration completed at $(date)"
echo "Metabase will be available on port 3000"
echo "Sample data will be initialized in 3 minutes" 
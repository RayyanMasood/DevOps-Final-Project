#!/bin/bash
# Bastion Host User Data Script
# Configures bastion host for SSH tunneling to RDS databases

# Enable logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting bastion host configuration at $(date)"

# Update system packages
yum update -y

# Install required packages
yum install -y \
    mysql \
    postgresql15 \
    htop \
    vim \
    curl \
    wget \
    awscli \
    jq

# Create database connection scripts directory
mkdir -p /opt/db-scripts
chown ec2-user:ec2-user /opt/db-scripts

# Create MySQL connection script
cat > /opt/db-scripts/connect-mysql.sh << 'EOF'
#!/bin/bash
# MySQL Connection Script via SSH Tunnel
echo "Setting up SSH tunnel for MySQL..."
echo "MySQL Endpoint: ${mysql_endpoint}"
echo ""
echo "To connect from your local machine:"
echo "1. SSH tunnel: ssh -i your-key.pem -L 3306:${mysql_endpoint}:3306 ec2-user@$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "2. Connect to localhost:3306 in your MySQL client"
echo ""
echo "DBeaver connection settings:"
echo "  Host: localhost"
echo "  Port: 3306"
echo "  Database: appdb"
echo "  Username: admin"
echo "  Password: [from AWS Secrets Manager]"
EOF

# Create PostgreSQL connection script  
cat > /opt/db-scripts/connect-postgres.sh << 'EOF'
#!/bin/bash
# PostgreSQL Connection Script via SSH Tunnel
echo "Setting up SSH tunnel for PostgreSQL..."
echo "PostgreSQL Endpoint: ${postgres_endpoint}"
echo ""
echo "To connect from your local machine:"
echo "1. SSH tunnel: ssh -i your-key.pem -L 5432:${postgres_endpoint}:5432 ec2-user@$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "2. Connect to localhost:5432 in your PostgreSQL client"
echo ""
echo "DBeaver connection settings:"
echo "  Host: localhost"
echo "  Port: 5432"
echo "  Database: appdb"
echo "  Username: admin"
echo "  Password: [from AWS Secrets Manager]"
EOF

# Make scripts executable
chmod +x /opt/db-scripts/*.sh
chown ec2-user:ec2-user /opt/db-scripts/*.sh

# Create SSH tunnel helper script
cat > /opt/db-scripts/tunnel-helper.sh << 'EOF'
#!/bin/bash
# SSH Tunnel Helper Script

echo "====================================="
echo "Database SSH Tunnel Helper"
echo "====================================="
echo ""
echo "Available databases:"
echo "1. MySQL (Port 3306)"
echo "2. PostgreSQL (Port 5432)"
echo ""
echo "Bastion Host IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo ""
echo "SSH Tunnel Commands:"
echo "MySQL:      ssh -i your-key.pem -L 3306:${mysql_endpoint}:3306 ec2-user@$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "PostgreSQL: ssh -i your-key.pem -L 5432:${postgres_endpoint}:5432 ec2-user@$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo ""
echo "After establishing tunnel, connect to localhost on respective ports"
echo "====================================="
EOF

chmod +x /opt/db-scripts/tunnel-helper.sh
chown ec2-user:ec2-user /opt/db-scripts/tunnel-helper.sh

# Add alias for easy access
echo "alias db-tunnel='/opt/db-scripts/tunnel-helper.sh'" >> /home/ec2-user/.bashrc
echo "alias mysql-tunnel='/opt/db-scripts/connect-mysql.sh'" >> /home/ec2-user/.bashrc
echo "alias postgres-tunnel='/opt/db-scripts/connect-postgres.sh'" >> /home/ec2-user/.bashrc

# Create MOTD with connection information
cat > /etc/motd << 'EOF'
========================================
    BASTION HOST - DATABASE ACCESS
========================================

This bastion host provides secure access to RDS databases.

Quick Commands:
  db-tunnel      - Show tunnel setup instructions
  mysql-tunnel   - MySQL connection guide
  postgres-tunnel- PostgreSQL connection guide

Database Endpoints:
  MySQL:      ${mysql_endpoint}:3306
  PostgreSQL: ${postgres_endpoint}:5432

Connection via SSH Tunnel:
1. From your local machine, create SSH tunnel
2. Connect to localhost on forwarded port
3. Use database credentials from AWS Secrets Manager

========================================
EOF

echo "Bastion host configuration completed at $(date)" 
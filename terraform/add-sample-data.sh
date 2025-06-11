#!/bin/bash
# Script to add sample data to Metabase
# Run this after the infrastructure is deployed and Metabase is running

echo "Adding sample data to Metabase..."

# Get connection details from terraform output
METABASE_IP=$(terraform output -raw metabase_private_ip)
BASTION_IP=$(terraform output -raw bastion_public_ip)
POSTGRES_ENDPOINT=$(terraform output -raw postgres_endpoint)

echo "Metabase IP: $METABASE_IP"
echo "Bastion IP: $BASTION_IP"

# Create SQL script for sample data
cat > sample_data.sql << 'SQL_EOF'
-- Sample data for Metabase dashboards
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
('2024-01-05', 'Product A', 'Electronics', 1200.00, 4, 'North'),
('2024-01-06', 'Product E', 'Home', 950.00, 3, 'South'),
('2024-01-07', 'Product F', 'Electronics', 1800.00, 6, 'East'),
('2024-01-08', 'Product G', 'Clothing', 600.00, 12, 'West'),
('2024-01-09', 'Product H', 'Books', 450.00, 18, 'North'),
('2024-01-10', 'Product I', 'Home', 1100.00, 4, 'South');

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
(1, 'login', '192.168.1.100', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'),
(2, 'login', '192.168.1.101', 'Mozilla/5.0 (Macintosh; Intel Mac OS X)'),
(3, 'page_view', '192.168.1.102', 'Mozilla/5.0 (X11; Linux x86_64)'),
(1, 'purchase', '192.168.1.100', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'),
(4, 'login', '192.168.1.103', 'Mozilla/5.0 (iPhone; CPU iPhone OS)'),
(2, 'logout', '192.168.1.101', 'Mozilla/5.0 (Macintosh; Intel Mac OS X)'),
(5, 'signup', '192.168.1.104', 'Mozilla/5.0 (Android 11; Mobile)'),
(3, 'purchase', '192.168.1.102', 'Mozilla/5.0 (X11; Linux x86_64)'),
(6, 'login', '192.168.1.105', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'),
(4, 'page_view', '192.168.1.103', 'Mozilla/5.0 (iPhone; CPU iPhone OS)');
SQL_EOF

echo "Sample data SQL script created: sample_data.sql"
echo ""
echo "To add this data to your database:"
echo "1. Copy the SQL file to the bastion host:"
echo "   scp -i ~/.ssh/DevOps-FP-KeyPair.pem sample_data.sql ec2-user@$BASTION_IP:~/"
echo ""
echo "2. SSH to bastion and run the SQL:"
echo "   ssh -i ~/.ssh/DevOps-FP-KeyPair.pem ec2-user@$BASTION_IP"
echo "   psql -h $POSTGRES_ENDPOINT -U [username] -d [database] -f sample_data.sql"
echo ""
echo "3. Access Metabase via SSH tunnel:"
echo "   ssh -i ~/.ssh/DevOps-FP-KeyPair.pem -L 3000:$METABASE_IP:3000 ec2-user@$BASTION_IP"
echo "   Then open: http://localhost:3000"
echo ""
echo "Note: Replace [username] and [database] with your PostgreSQL credentials from AWS Secrets Manager" 
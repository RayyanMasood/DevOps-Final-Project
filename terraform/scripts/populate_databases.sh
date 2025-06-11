#!/bin/bash

# Database Population Script with SSH Tunneling
# This script creates SSH tunnels and populates both MySQL and PostgreSQL databases with dummy data

set -e  # Exit on any error

echo "🚀 Starting Database Population Script..."

# Configuration
BASTION_IP="54.173.154.28"
SSH_KEY="~/.ssh/DevOps-FP-KeyPair.pem"
DB_USER="notes_user"
DB_PASSWORD="notes_password"
DB_NAME="notes_db"

# MySQL and PostgreSQL endpoints
MYSQL_ENDPOINT="devops-final-project-dev-mysql.ca5ucs84k9va.us-east-1.rds.amazonaws.com"
POSTGRES_ENDPOINT="devops-final-project-dev-postgres.ca5ucs84k9va.us-east-1.rds.amazonaws.com"

echo "📋 Configuration:"
echo "  Bastion Host: $BASTION_IP"
echo "  MySQL Endpoint: $MYSQL_ENDPOINT"
echo "  PostgreSQL Endpoint: $POSTGRES_ENDPOINT"
echo "  Database: $DB_NAME"
echo "  Username: $DB_USER"

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "❌ Port $port is already in use. Please stop the process or use a different port."
        return 1
    fi
    return 0
}

# Function to create SSH tunnel
create_tunnel() {
    local local_port=$1
    local remote_endpoint=$2
    local tunnel_name=$3
    
    echo "🔗 Creating SSH tunnel for $tunnel_name..."
    echo "   Local port $local_port → $remote_endpoint"
    
    # Create SSH tunnel in background
    ssh -i $SSH_KEY -f -N -L $local_port:$remote_endpoint:$local_port ec2-user@$BASTION_IP
    
    # Wait a moment for tunnel to establish
    sleep 3
    
    # Verify tunnel is working
    if lsof -Pi :$local_port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "✅ SSH tunnel for $tunnel_name established successfully"
        return 0
    else
        echo "❌ Failed to establish SSH tunnel for $tunnel_name"
        return 1
    fi
}

# Function to cleanup SSH tunnels
cleanup_tunnels() {
    echo "🧹 Cleaning up SSH tunnels..."
    
    # Kill MySQL tunnel (port 3306)
    if lsof -Pi :3306 -sTCP:LISTEN -t >/dev/null 2>&1; then
        lsof -ti:3306 | xargs kill -9 2>/dev/null || true
        echo "✅ MySQL tunnel cleaned up"
    fi
    
    # Kill PostgreSQL tunnel (port 5432)
    if lsof -Pi :5432 -sTCP:LISTEN -t >/dev/null 2>&1; then
        lsof -ti:5432 | xargs kill -9 2>/dev/null || true
        echo "✅ PostgreSQL tunnel cleaned up"
    fi
}

# Function to populate MySQL
populate_mysql() {
    echo "📊 Populating MySQL database..."
    
    # Create temporary SQL file
    cat > /tmp/mysql_data.sql << 'EOF'
-- Create notes table
CREATE TABLE IF NOT EXISTS notes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Insert dummy data
INSERT INTO notes (title, content) VALUES
('Welcome to MySQL', 'This is your first note in the MySQL database. You can create, read, update, and delete notes through the application.'),
('Database Performance Tips', 'Consider indexing frequently queried columns, normalize your data structure, and monitor query performance regularly.'),
('DevOps Best Practices', 'Infrastructure as Code, Continuous Integration/Deployment, monitoring, logging, and automated testing are key pillars.'),
('AWS RDS Features', 'Automated backups, point-in-time recovery, read replicas, Multi-AZ deployments for high availability.'),
('SSH Tunneling Security', 'SSH tunneling provides encrypted access to databases, ensuring secure connections through bastion hosts.'),
('Terraform Infrastructure', 'This database was created and managed through Terraform, demonstrating Infrastructure as Code principles.'),
('Notes Application Demo', 'This Notes app demonstrates full-stack development with React frontend, Node.js backend, and dual database support.'),
('Monitoring and Alerts', 'CloudWatch alarms monitor database CPU, memory, and connection metrics for proactive management.'),
('Load Balancing', 'Application Load Balancer distributes traffic across multiple EC2 instances for high availability.'),
('Auto Scaling Groups', 'EC2 instances automatically scale based on demand, ensuring optimal performance and cost efficiency.');
EOF

    # Execute SQL file
    if mysql -h localhost -P 3306 -u $DB_USER -p$DB_PASSWORD $DB_NAME < /tmp/mysql_data.sql; then
        echo "✅ MySQL database populated successfully"
        
        # Verify data
        echo "📋 MySQL Data Verification:"
        mysql -h localhost -P 3306 -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "SELECT COUNT(*) as 'Total Notes' FROM notes;"
    else
        echo "❌ Failed to populate MySQL database"
        return 1
    fi
    
    # Cleanup temp file
    rm -f /tmp/mysql_data.sql
}

# Function to populate PostgreSQL
populate_postgresql() {
    echo "📊 Populating PostgreSQL database..."
    
    # Set PGPASSWORD environment variable
    export PGPASSWORD=$DB_PASSWORD
    
    # Create temporary SQL file
    cat > /tmp/postgres_data.sql << 'EOF'
-- Create notes table
CREATE TABLE IF NOT EXISTS notes (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create trigger to auto-update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_notes_updated_at BEFORE UPDATE
    ON notes FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- Insert dummy data
INSERT INTO notes (title, content) VALUES
('PostgreSQL Welcome', 'Welcome to your PostgreSQL database! This demonstrates the dual-database architecture of the Notes application.'),
('Database Comparison', 'PostgreSQL offers advanced features like JSONB, full-text search, and sophisticated indexing compared to MySQL.'),
('ACID Compliance', 'PostgreSQL provides strong ACID compliance, ensuring data integrity and consistency across transactions.'),
('JSON Support', 'Native JSON and JSONB data types in PostgreSQL enable efficient storage and querying of document-style data.'),
('Concurrent Connections', 'PostgreSQL handles concurrent connections efficiently with its multi-version concurrency control (MVCC).'),
('Backup Strategies', 'RDS automated backups, manual snapshots, and point-in-time recovery provide comprehensive data protection.'),
('Query Optimization', 'EXPLAIN ANALYZE helps optimize query performance by showing execution plans and actual runtime statistics.'),
('Security Features', 'Row-level security, SSL connections, and fine-grained access controls protect sensitive data.'),
('Extensions', 'PostgreSQL supports numerous extensions like PostGIS for geospatial data and pg_stat_statements for monitoring.'),
('Scalability Options', 'Read replicas, connection pooling, and horizontal partitioning support growing application demands.');

-- Create categories table
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO categories (name, description) VALUES
('Technical', 'Technical notes and documentation'),
('DevOps', 'DevOps practices and infrastructure'),
('Database', 'Database administration and optimization'),
('Security', 'Security best practices and compliance');

-- Add category reference to notes
ALTER TABLE notes ADD COLUMN IF NOT EXISTS category_id INTEGER REFERENCES categories(id);

-- Update notes with categories
UPDATE notes SET category_id = (SELECT id FROM categories WHERE name = 'Database') WHERE title LIKE '%Database%' OR title LIKE '%PostgreSQL%' OR title LIKE '%MySQL%';
UPDATE notes SET category_id = (SELECT id FROM categories WHERE name = 'DevOps') WHERE title LIKE '%DevOps%' OR title LIKE '%Terraform%' OR title LIKE '%Auto Scaling%' OR title LIKE '%Load Balancing%';
UPDATE notes SET category_id = (SELECT id FROM categories WHERE name = 'Security') WHERE title LIKE '%Security%' OR title LIKE '%SSH%';
UPDATE notes SET category_id = (SELECT id FROM categories WHERE name = 'Technical') WHERE category_id IS NULL;
EOF

    # Execute SQL file
    if psql -h localhost -p 5432 -U $DB_USER -d $DB_NAME -f /tmp/postgres_data.sql; then
        echo "✅ PostgreSQL database populated successfully"
        
        # Verify data
        echo "📋 PostgreSQL Data Verification:"
        psql -h localhost -p 5432 -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) as total_notes FROM notes;"
        psql -h localhost -p 5432 -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) as total_categories FROM categories;"
    else
        echo "❌ Failed to populate PostgreSQL database"
        return 1
    fi
    
    # Cleanup temp file
    rm -f /tmp/postgres_data.sql
    unset PGPASSWORD
}

# Main execution
main() {
    echo "🔍 Pre-flight checks..."
    
    # Check if required tools are installed
    command -v ssh >/dev/null 2>&1 || { echo "❌ SSH is required but not installed."; exit 1; }
    command -v mysql >/dev/null 2>&1 || { echo "❌ MySQL client is required but not installed."; exit 1; }
    command -v psql >/dev/null 2>&1 || { echo "❌ PostgreSQL client is required but not installed."; exit 1; }
    command -v lsof >/dev/null 2>&1 || { echo "❌ lsof is required but not installed."; exit 1; }
    
    # Check if SSH key exists
    if [ ! -f "$SSH_KEY" ]; then
        echo "❌ SSH key not found at $SSH_KEY"
        exit 1
    fi
    
    # Check if ports are available
    check_port 3306 || exit 1
    check_port 5432 || exit 1
    
    echo "✅ Pre-flight checks passed"
    
    # Setup cleanup trap
    trap cleanup_tunnels EXIT
    
    # Create SSH tunnels
    echo ""
    echo "🔗 Setting up SSH tunnels..."
    create_tunnel 3306 "$MYSQL_ENDPOINT" "MySQL" || exit 1
    create_tunnel 5432 "$POSTGRES_ENDPOINT" "PostgreSQL" || exit 1
    
    # Wait for tunnels to stabilize
    echo "⏳ Waiting for tunnels to stabilize..."
    sleep 5
    
    # Populate databases
    echo ""
    echo "📊 Populating databases with dummy data..."
    populate_mysql || exit 1
    echo ""
    populate_postgresql || exit 1
    
    echo ""
    echo "🎉 Database population completed successfully!"
    echo ""
    echo "📋 Summary:"
    echo "  ✅ MySQL: Populated with 10 sample notes"
    echo "  ✅ PostgreSQL: Populated with 10 sample notes + 4 categories"
    echo "  ✅ SSH tunnels: Active and functional"
    echo ""
    echo "💡 Next steps:"
    echo "  1. Open DBeaver and create connections to localhost:3306 (MySQL) and localhost:5432 (PostgreSQL)"
    echo "  2. Use credentials: User='$DB_USER', Password='$DB_PASSWORD', Database='$DB_NAME'"
    echo "  3. Explore the data and test the application integration"
    echo ""
    echo "🔗 Application URL: http://devops-final-project-dev-alb-792083118.us-east-1.elb.amazonaws.com"
}

# Handle script interruption
handle_interrupt() {
    echo ""
    echo "🛑 Script interrupted. Cleaning up..."
    cleanup_tunnels
    exit 1
}

trap handle_interrupt INT TERM

# Run main function
main "$@" 
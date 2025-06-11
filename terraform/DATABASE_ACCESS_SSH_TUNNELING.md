# Database Access via SSH Tunneling

This guide shows how to securely access your RDS databases through SSH tunneling using the bastion host.

## 🔧 **Prerequisites**

1. **SSH Key**: Ensure your `DevOps-FP-KeyPair.pem` file is in `~/.ssh/`
2. **DBeaver**: Download from [https://dbeaver.io/download/](https://dbeaver.io/download/)
3. **Terminal/Command Prompt**: For creating SSH tunnels

## 📋 **Connection Details**

### **Infrastructure Information**
- **Bastion Host IP**: `54.173.154.28`
- **MySQL Endpoint**: `devops-final-project-dev-mysql.ca5ucs84k9va.us-east-1.rds.amazonaws.com:3306`
- **PostgreSQL Endpoint**: `devops-final-project-dev-postgres.ca5ucs84k9va.us-east-1.rds.amazonaws.com:5432`

### **Database Credentials**
- **Database Names**: `notes_db`
- **Username**: `notes_user`
- **Password**: `notes_password`

---

## 🚀 **Step 1: Create SSH Tunnels**

### **For MySQL Access (Port 3306)**

**Command:**
```bash
ssh -i ~/.ssh/DevOps-FP-KeyPair.pem -L 3306:devops-final-project-dev-mysql.ca5ucs84k9va.us-east-1.rds.amazonaws.com:3306 ec2-user@54.173.154.28
```

**What this does:**
- Forwards local port `3306` → MySQL RDS through bastion host
- Keeps the tunnel open (leave this terminal running)

### **For PostgreSQL Access (Port 5432)**

**Command:**
```bash
ssh -i ~/.ssh/DevOps-FP-KeyPair.pem -L 5432:devops-final-project-dev-postgres.ca5ucs84k9va.us-east-1.rds.amazonaws.com:5432 ec2-user@54.173.154.28
```

**What this does:**
- Forwards local port `5432` → PostgreSQL RDS through bastion host
- Keeps the tunnel open (leave this terminal running)

---

## 🗄️ **Step 2: Configure DBeaver Connections**

### **MySQL Connection in DBeaver**

1. **Open DBeaver** → Click **"New Database Connection"**
2. **Select MySQL** from the database list
3. **Configure Connection:**
   ```
   Host: localhost
   Port: 3306
   Database: notes_db
   Username: notes_user
   Password: notes_password
   ```
4. **Test Connection** → Should succeed if SSH tunnel is active
5. **Save** the connection

### **PostgreSQL Connection in DBeaver**

1. **Open DBeaver** → Click **"New Database Connection"**
2. **Select PostgreSQL** from the database list
3. **Configure Connection:**
   ```
   Host: localhost
   Port: 5432
   Database: notes_db
   Username: notes_user
   Password: notes_password
   ```
4. **Test Connection** → Should succeed if SSH tunnel is active
5. **Save** the connection

---

## 📊 **Step 3: Populate with Dummy Data**

### **MySQL Dummy Data**

Connect to MySQL through DBeaver and run:

```sql
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

-- Verify data
SELECT id, title, LEFT(content, 50) as content_preview, created_at FROM notes ORDER BY created_at DESC;
```

### **PostgreSQL Dummy Data**

Connect to PostgreSQL through DBeaver and run:

```sql
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

-- Create additional demonstration tables
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

-- Add category reference to notes (optional)
ALTER TABLE notes ADD COLUMN IF NOT EXISTS category_id INTEGER REFERENCES categories(id);

-- Update some notes with categories
UPDATE notes SET category_id = (SELECT id FROM categories WHERE name = 'Database') WHERE title LIKE '%Database%' OR title LIKE '%PostgreSQL%' OR title LIKE '%MySQL%';
UPDATE notes SET category_id = (SELECT id FROM categories WHERE name = 'DevOps') WHERE title LIKE '%DevOps%' OR title LIKE '%Terraform%' OR title LIKE '%Auto Scaling%' OR title LIKE '%Load Balancing%';
UPDATE notes SET category_id = (SELECT id FROM categories WHERE name = 'Security') WHERE title LIKE '%Security%' OR title LIKE '%SSH%';
UPDATE notes SET category_id = (SELECT id FROM categories WHERE name = 'Technical') WHERE category_id IS NULL;

-- Verify data with joins
SELECT n.id, n.title, c.name as category, LEFT(n.content, 50) as content_preview, n.created_at 
FROM notes n 
LEFT JOIN categories c ON n.category_id = c.id 
ORDER BY n.created_at DESC;
```

---

## 🔍 **Step 4: Verify Application Integration**

### **Test Database Connectivity**

1. **Visit your application**: http://devops-final-project-dev-alb-792083118.us-east-1.elb.amazonaws.com
2. **Create a new note** through the web interface
3. **Select different databases** (MySQL/PostgreSQL) when creating notes
4. **Verify in DBeaver** that notes appear in the respective databases

### **Troubleshooting**

**SSH Tunnel Issues:**
- Ensure your SSH key permissions: `chmod 400 ~/.ssh/DevOps-FP-KeyPair.pem`
- Check bastion host connectivity: `ping 54.173.154.28`
- Verify security group allows SSH from your IP

**DBeaver Connection Issues:**
- Ensure SSH tunnels are active and running
- Check that local ports 3306/5432 aren't used by other services
- Verify credentials match exactly

**Application Issues:**
- Check application logs in CloudWatch
- Verify RDS instances are running and healthy
- Test API endpoints: `/api/notes` and `/api/health`

---

## 📈 **Step 5: Monitor Database Performance**

### **CloudWatch Metrics**
- Navigate to AWS CloudWatch dashboard
- Monitor CPU utilization, connections, and read/write operations
- Set up alarms for unusual activity

### **DBeaver Monitoring**
- Use DBeaver's built-in performance monitoring
- Analyze query execution plans with EXPLAIN
- Monitor active connections and long-running queries

---

## 🎯 **Success Verification**

You've successfully set up SSH tunneling when:

✅ SSH tunnels connect without errors  
✅ DBeaver connects to both databases via localhost  
✅ Dummy data appears in both MySQL and PostgreSQL  
✅ Web application can create/read notes from both databases  
✅ Database queries execute successfully through DBeaver  

## 🔐 **Security Notes**

- **SSH tunnels encrypt** all database traffic
- **RDS instances** are in private subnets, not directly accessible
- **Bastion host** provides the only secure entry point
- **Database passwords** are stored in AWS Secrets Manager
- **Security groups** restrict access to authorized sources only

This setup demonstrates enterprise-grade database security through defense in depth! 
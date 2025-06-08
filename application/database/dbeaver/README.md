# DBeaver Configuration Guide

This guide provides step-by-step instructions for connecting DBeaver to the DevOps project databases through SSH tunnels.

## Prerequisites

1. **DBeaver Community Edition** (version 7.0+) or DBeaver Enterprise
2. **SSH key file** for bastion host access (`.pem` file)
3. **Active SSH tunnels** to RDS instances

## Quick Setup

### 1. Start SSH Tunnels

First, configure and start the SSH tunnels:

```bash
# Navigate to scripts directory
cd application/database/scripts

# Configure tunnel settings (edit tunnel-config.env)
./ssh-tunnel-mysql.sh details
./ssh-tunnel-postgresql.sh details

# Start tunnels
./ssh-tunnel-mysql.sh start
./ssh-tunnel-postgresql.sh start

# Verify tunnels are running
./ssh-tunnel-mysql.sh status
./ssh-tunnel-postgresql.sh status
```

### 2. Import DBeaver Configurations

Import the pre-configured connection profiles:

1. Open DBeaver
2. Go to **File → Import**
3. Select **DBeaver → Connections**
4. Choose the configuration files from this directory:
   - `mysql-connection.json` - MySQL connection via SSH tunnel
   - `postgresql-connection.json` - PostgreSQL connection via SSH tunnel

### 3. Manual Connection Setup

If you prefer manual setup, follow the detailed instructions below.

## Detailed Connection Setup

### MySQL Connection

#### Connection Settings
1. **Database Type**: MySQL
2. **Host**: `localhost`
3. **Port**: `3307` (or your configured LOCAL_MYSQL_PORT)
4. **Database**: `devops_app`
5. **Username**: `app_user`
6. **Password**: [Your MySQL password]

#### SSH Configuration
1. Go to **SSH** tab
2. **Use SSH Tunnel**: ✓ Enabled
3. **Host/IP**: [Your bastion host IP]
4. **Port**: `22`
5. **Username**: `ec2-user`
6. **Authentication**: **Public Key**
7. **Private Key**: Browse to your `.pem` file
8. **Local Port**: `3307` (must match tunnel configuration)
9. **Remote Host**: [Your RDS MySQL endpoint]
10. **Remote Port**: `3306`

#### Test Connection
1. Click **Test Connection**
2. If prompted, accept SSH host key
3. Verify both SSH and database connections succeed

### PostgreSQL Connection

#### Connection Settings
1. **Database Type**: PostgreSQL
2. **Host**: `localhost`
3. **Port**: `5433` (or your configured LOCAL_POSTGRESQL_PORT)
4. **Database**: `devops_analytics`
5. **Username**: `analytics_user`
6. **Password**: [Your PostgreSQL password]

#### SSH Configuration
1. Go to **SSH** tab
2. **Use SSH Tunnel**: ✓ Enabled
3. **Host/IP**: [Your bastion host IP]
4. **Port**: `22`
5. **Username**: `ec2-user`
6. **Authentication**: **Public Key**
7. **Private Key**: Browse to your `.pem` file
8. **Local Port**: `5433` (must match tunnel configuration)
9. **Remote Host**: [Your RDS PostgreSQL endpoint]
10. **Remote Port**: `5432`

#### Test Connection
1. Click **Test Connection**
2. If prompted, accept SSH host key
3. Verify both SSH and database connections succeed

## Connection Profiles

### MySQL Profile Configuration

```json
{
  "id": "devops-mysql",
  "name": "DevOps MySQL (via SSH)",
  "driver": "mysql8",
  "url": "jdbc:mysql://localhost:3307/devops_app",
  "properties": {
    "host": "localhost",
    "port": "3307",
    "database": "devops_app",
    "user": "app_user"
  },
  "ssh": {
    "enabled": true,
    "host": "your-bastion-host",
    "port": 22,
    "username": "ec2-user",
    "authType": "PUBLIC_KEY",
    "keyPath": "~/.ssh/devops-key.pem",
    "localPort": 3307,
    "remoteHost": "your-mysql-rds-endpoint",
    "remotePort": 3306
  }
}
```

### PostgreSQL Profile Configuration

```json
{
  "id": "devops-postgresql",
  "name": "DevOps PostgreSQL (via SSH)",
  "driver": "postgresql",
  "url": "jdbc:postgresql://localhost:5433/devops_analytics",
  "properties": {
    "host": "localhost",
    "port": "5433",
    "database": "devops_analytics",
    "user": "analytics_user"
  },
  "ssh": {
    "enabled": true,
    "host": "your-bastion-host",
    "port": 22,
    "username": "ec2-user",
    "authType": "PUBLIC_KEY",
    "keyPath": "~/.ssh/devops-key.pem",
    "localPort": 5433,
    "remoteHost": "your-postgresql-rds-endpoint",
    "remotePort": 5432
  }
}
```

## Useful Queries

### MySQL - Business Intelligence Queries

```sql
-- Revenue trends by day
SELECT 
    DATE(order_date) as date,
    COUNT(*) as order_count,
    SUM(total_amount) as revenue,
    AVG(total_amount) as avg_order_value
FROM orders 
WHERE order_date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY DATE(order_date)
ORDER BY date;

-- Top selling products
SELECT 
    p.name,
    SUM(oi.quantity) as total_sold,
    SUM(oi.total_price) as revenue,
    COUNT(DISTINCT oi.order_id) as order_count
FROM products p
JOIN order_items oi ON p.id = oi.product_id
JOIN orders o ON oi.order_id = o.id
WHERE o.status = 'delivered'
GROUP BY p.id, p.name
ORDER BY total_sold DESC
LIMIT 10;

-- Customer analysis
SELECT 
    u.id,
    u.username,
    COUNT(DISTINCT o.id) as order_count,
    SUM(o.total_amount) as lifetime_value,
    AVG(o.total_amount) as avg_order_value,
    MAX(o.order_date) as last_order_date
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.username
HAVING order_count > 0
ORDER BY lifetime_value DESC;
```

### PostgreSQL - Analytics Queries

```sql
-- Daily active users
SELECT 
    DATE(timestamp) as date,
    COUNT(DISTINCT user_id) as active_users,
    COUNT(DISTINCT session_id) as sessions,
    COUNT(*) as events
FROM analytics_events 
WHERE timestamp >= NOW() - INTERVAL '30 days'
  AND user_id IS NOT NULL
GROUP BY DATE(timestamp)
ORDER BY date;

-- Page performance metrics
SELECT 
    page_url,
    COUNT(*) as page_views,
    COUNT(DISTINCT session_id) as unique_visitors,
    AVG((event_data->>'load_time')::numeric) as avg_load_time,
    AVG((event_data->>'engagement_time')::numeric) as avg_engagement_time
FROM analytics_events 
WHERE event_type = 'page_view'
  AND timestamp >= NOW() - INTERVAL '7 days'
  AND page_url IS NOT NULL
GROUP BY page_url
ORDER BY page_views DESC;

-- System performance trends
SELECT 
    DATE_TRUNC('hour', timestamp) as hour,
    metric_name,
    AVG(value) as avg_value,
    MIN(value) as min_value,
    MAX(value) as max_value
FROM performance_metrics
WHERE timestamp >= NOW() - INTERVAL '24 hours'
  AND metric_name IN ('cpu_usage', 'memory_usage', 'response_time')
GROUP BY DATE_TRUNC('hour', timestamp), metric_name
ORDER BY hour DESC, metric_name;
```

## Troubleshooting

### Common Issues

#### SSH Connection Failed
1. Verify bastion host IP/DNS is correct
2. Check SSH key permissions: `chmod 600 ~/.ssh/your-key.pem`
3. Ensure security groups allow SSH access from your IP
4. Test SSH connection manually: `ssh -i ~/.ssh/your-key.pem ec2-user@bastion-host`

#### Database Connection Failed
1. Verify SSH tunnel is running
2. Check local port is not in use by another process
3. Verify RDS endpoint and port in tunnel configuration
4. Check database credentials
5. Ensure RDS security groups allow access from bastion host

#### Port Already in Use
```bash
# Find process using the port
lsof -i :3307  # for MySQL
lsof -i :5433  # for PostgreSQL

# Kill the process or stop existing tunnels
./ssh-tunnel-mysql.sh stop
./ssh-tunnel-postgresql.sh stop
```

#### SSH Key Issues
```bash
# Fix SSH key permissions
chmod 600 ~/.ssh/your-key.pem

# Test SSH key
ssh-keygen -y -f ~/.ssh/your-key.pem
```

### Performance Optimization

#### For Large Datasets
1. **Limit Query Results**: Use `LIMIT` for exploratory queries
2. **Use Indexes**: Verify proper indexes exist for your queries
3. **Connection Pooling**: Enable in DBeaver preferences
4. **Timeout Settings**: Increase for long-running queries

#### DBeaver Settings
1. **Memory**: Increase heap size in `dbeaver.ini`
2. **Connection Pool**: Set appropriate pool size
3. **Query Timeout**: Increase for complex analytics queries
4. **Result Set Limit**: Set reasonable default limits

## Security Best Practices

1. **SSH Key Security**:
   - Use separate keys for different environments
   - Rotate keys regularly
   - Never share private keys

2. **Database Credentials**:
   - Use strong passwords
   - Enable SSL connections where possible
   - Rotate credentials regularly

3. **Network Security**:
   - Restrict bastion host access to specific IPs
   - Use VPN when possible
   - Monitor SSH access logs

4. **DBeaver Security**:
   - Enable password protection for connection profiles
   - Don't save passwords in plain text
   - Use encrypted password storage

## Backup Connections

If SSH tunnels are not available, you can temporarily use port forwarding:

```bash
# One-time port forwarding (MySQL)
ssh -i ~/.ssh/your-key.pem -L 3307:mysql-endpoint:3306 ec2-user@bastion-host

# One-time port forwarding (PostgreSQL)
ssh -i ~/.ssh/your-key.pem -L 5433:postgresql-endpoint:5432 ec2-user@bastion-host
```

## Additional Resources

- [DBeaver Documentation](https://dbeaver.io/docs/)
- [SSH Tunneling Guide](https://www.ssh.com/academy/ssh/tunneling/example)
- [AWS RDS Security Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.html)

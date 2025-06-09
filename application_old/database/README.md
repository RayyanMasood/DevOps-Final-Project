# DevOps Database Infrastructure

Complete database setup with SSH tunneling, BI analytics, monitoring, and security for the DevOps Dashboard project.

## 🚀 Quick Start

### 1. Configure SSH Tunnels

```bash
# Navigate to scripts directory
cd application/database/scripts

# Configure connection settings
cp tunnel-config.env.example tunnel-config.env
# Edit tunnel-config.env with your actual values

# Start SSH tunnels
./ssh-tunnel-mysql.sh start
./ssh-tunnel-postgresql.sh start

# Verify connectivity
./ssh-tunnel-mysql.sh status
./ssh-tunnel-postgresql.sh status
```

### 2. Initialize Databases

```bash
# Run migrations to enhance schema for BI
mysql -h localhost -P 3307 -u root -p < migrations/001_enhance_bi_tables.sql
psql -h localhost -p 5433 -U postgres < migrations/002_enhance_postgresql_analytics.sql
```

### 3. Start Data Generation

```bash
# Generate historical data for dashboards
python3 scripts/bi-data-generator.py --mode historical --days 30 \
  --mysql-password YOUR_MYSQL_PASSWORD \
  --postgresql-password YOUR_POSTGRESQL_PASSWORD

# Start real-time data generation
python3 scripts/bi-data-generator.py --mode continuous \
  --mysql-password YOUR_MYSQL_PASSWORD \
  --postgresql-password YOUR_POSTGRESQL_PASSWORD
```

## 📊 Database Structure

### MySQL - Business Data (`devops_app`)
Primary operational database containing:

#### Core Tables
- **users**: User accounts and profiles
- **products**: Product catalog with categories
- **orders**: Order management and tracking
- **order_items**: Order line items and details
- **inventory_movements**: Stock tracking and adjustments
- **customer_reviews**: Product ratings and feedback

#### Enhanced BI Tables
- **sales_targets**: Performance targets and achievements
- **customer_segments**: Customer classification and scoring
- **product_analytics**: Product performance metrics
- **marketing_campaigns**: Campaign tracking and ROI
- **traffic_analytics**: Website traffic patterns
- **financial_metrics**: Daily financial KPIs
- **support_tickets**: Customer service metrics

#### Views & Analytics
- `sales_performance_daily`: Daily sales summaries
- `product_performance`: Product success metrics
- `customer_analytics`: Customer lifetime value and behavior

### PostgreSQL - Analytics Data (`devops_analytics`)
Advanced analytics and real-time metrics:

#### Core Analytics
- **analytics_events**: User behavior tracking
- **performance_metrics**: System performance data
- **real_time_data**: Live dashboard metrics

#### Advanced Analytics
- **user_journeys**: Complete user session tracking
- **conversion_funnels**: Multi-step conversion analysis
- **user_cohorts**: Retention and cohort analysis
- **ab_tests**: A/B testing framework
- **revenue_attribution**: Marketing attribution modeling
- **clv_predictions**: Customer lifetime value forecasting

#### Partitioned Tables
- **performance_metrics_hourly**: High-volume metrics with monthly partitions

## 🔐 Security Features

### SSH Tunneling
- Secure connections through bastion host
- Automated tunnel management
- Connection monitoring and health checks
- Support for multiple database types

### Access Control
- Role-based database permissions
- SSL/TLS encryption support
- Audit logging and monitoring
- Failed login attempt detection

### Network Security
- Private subnet isolation
- Security group restrictions
- VPC-only database access
- Bastion host as single entry point

## 🛠 Available Scripts

### SSH Tunnel Management
```bash
# MySQL tunnel
./ssh-tunnel-mysql.sh [start|stop|restart|status|test|connect|details]

# PostgreSQL tunnel
./ssh-tunnel-postgresql.sh [start|stop|restart|status|test|connect|details]
```

### Data Generation & Population
```bash
# BI data generator
python3 bi-data-generator.py --help

# Generate historical data
python3 bi-data-generator.py --mode historical --days 90

# Continuous real-time generation
python3 bi-data-generator.py --mode continuous --interval 30

# Single batch generation
python3 bi-data-generator.py --mode batch
```

### Monitoring & Health Checks
```bash
# Database monitoring
./database-monitor.sh [report|continuous|health|tunnels|connections]

# Continuous monitoring every 5 minutes
./database-monitor.sh continuous 300

# Health check for external monitoring
./database-monitor.sh health
```

### Backup & Recovery
```bash
# Full backup (MySQL + PostgreSQL)
./database-backup.sh full

# Individual database backups
./database-backup.sh mysql
./database-backup.sh postgresql

# List existing backups
./database-backup.sh list

# Restore from backup
./database-backup.sh restore mysql backup_file.sql.gz
./database-backup.sh restore postgresql backup_file.sql.gz

# Cleanup old backups
./database-backup.sh cleanup
```

### Security Configuration
```bash
# Complete security setup
./database-security.sh setup

# Individual security components
./database-security.sh [ssh|users|monitor|ssl|audit|checklist|report]

# Generate security assessment
./database-security.sh report
```

## 🔌 Connection Configuration

### Connection Parameters

| Database | Host | Port | Local Port | Database Name |
|----------|------|------|------------|---------------|
| MySQL | RDS Endpoint | 3306 | 3307 | devops_app |
| PostgreSQL | RDS Endpoint | 5432 | 5433 | devops_analytics |

### Environment Variables
```bash
# Bastion Host
BASTION_HOST=your-bastion-public-ip
BASTION_USER=ec2-user
BASTION_KEY=/path/to/your/key.pem

# MySQL Configuration
RDS_MYSQL_HOST=your-mysql-endpoint
MYSQL_USER=app_user
MYSQL_PASSWORD=your_mysql_password
MYSQL_DATABASE=devops_app

# PostgreSQL Configuration
RDS_POSTGRESQL_HOST=your-postgresql-endpoint
POSTGRESQL_USER=analytics_user
POSTGRESQL_PASSWORD=your_postgresql_password
POSTGRESQL_DATABASE=devops_analytics
```

## 📈 Business Intelligence Features

### Dashboard-Ready Data
The database schema is optimized for creating impressive BI dashboards with:

#### Real-Time KPIs
- Revenue and sales metrics
- Active user counts
- Conversion rates
- Inventory alerts
- Support ticket status

#### Analytics Insights
- Customer segmentation and lifetime value
- Product performance and recommendations
- Marketing campaign ROI
- A/B testing results
- User journey analysis

#### Performance Monitoring
- System health metrics
- Database performance
- Application response times
- Error rates and alerting

### Sample BI Queries

#### Sales Performance
```sql
-- Daily revenue trend
SELECT 
    DATE(order_date) as date,
    SUM(total_amount) as revenue,
    COUNT(*) as orders,
    AVG(total_amount) as avg_order_value
FROM orders 
WHERE order_date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
  AND status IN ('completed', 'delivered')
GROUP BY DATE(order_date)
ORDER BY date DESC;
```

#### Customer Analytics
```sql
-- Customer segmentation
SELECT 
    segment_type,
    COUNT(*) as customers,
    AVG(lifetime_value) as avg_clv,
    AVG(total_orders) as avg_orders
FROM customer_segments cs
JOIN customer_analytics ca ON cs.user_id = ca.id
WHERE cs.is_active = 1
GROUP BY segment_type;
```

#### Product Performance
```sql
-- Top performing products
SELECT 
    p.name,
    p.category,
    pp.total_sold,
    pp.total_revenue,
    pp.avg_rating,
    pp.review_count
FROM products p
JOIN product_performance pp ON p.id = pp.id
ORDER BY pp.total_revenue DESC
LIMIT 10;
```

## 🔧 DBeaver Integration

### Setup Guide
1. Import connection configurations from `dbeaver/` directory
2. Configure SSH tunnels using provided scripts
3. Test connections and adjust settings as needed

### Connection Profiles
- **MySQL Profile**: `dbeaver/mysql-connection.json`
- **PostgreSQL Profile**: `dbeaver/postgresql-connection.json`
- **Setup Guide**: `dbeaver/README.md`

## 📋 Monitoring & Alerting

### Health Checks
```bash
# Check tunnel status
./ssh-tunnel-mysql.sh status
./ssh-tunnel-postgresql.sh status

# Database connectivity test
./database-monitor.sh connections

# Full health report
./database-monitor.sh report
```

### Performance Metrics
- Connection counts and limits
- Query execution times
- Buffer pool hit ratios
- Cache hit rates
- Disk usage and I/O
- Long-running queries

### Alerting Thresholds
- High connection usage (>80%)
- Slow query count (>10)
- Failed login attempts (>10)
- Low buffer hit ratio (<95%)
- Disk usage (>85%)

## 🔄 Backup Strategy

### Automated Backups
- **MySQL**: Daily compressed dumps with 30-day retention
- **PostgreSQL**: Daily compressed dumps with 30-day retention
- **Archives**: Weekly full archives with 90-day retention

### Backup Types
1. **Database Dumps**: Individual SQL dumps for each database
2. **Compressed Archives**: Full backup archives for disaster recovery
3. **Point-in-time**: RDS automated backups (configured separately)

### Recovery Procedures
1. Identify backup file needed
2. Stop application connections
3. Restore using provided scripts
4. Verify data integrity
5. Resume application operations

## 🚨 Troubleshooting

### Common Issues

#### SSH Tunnel Problems
```bash
# Check if port is in use
lsof -i :3307
lsof -i :5433

# Restart tunnels
./ssh-tunnel-mysql.sh restart
./ssh-tunnel-postgresql.sh restart

# Check SSH key permissions
chmod 600 ~/.ssh/your-key.pem
```

#### Connection Failures
```bash
# Test SSH connectivity to bastion
ssh -i ~/.ssh/your-key.pem ec2-user@bastion-host

# Check security group rules
# Verify RDS endpoints and ports
# Confirm database credentials
```

#### Performance Issues
```bash
# Check database performance
./database-monitor.sh report

# Monitor long-running queries
./database-monitor.sh continuous 60

# Review slow query logs
```

### Log Files
- SSH tunnels: `/tmp/mysql-tunnel.log`, `/tmp/postgresql-tunnel.log`
- Database monitoring: `/tmp/database-monitor.log`
- Data generation: `/tmp/bi-data-generator.log`
- Backup operations: `/tmp/database-backup.log`
- Security auditing: `/tmp/database-audit.log`

## 📚 Additional Resources

### Documentation
- [DBeaver Setup Guide](dbeaver/README.md)
- [Security Checklist](SECURITY_CHECKLIST.md)
- [Migration Scripts](migrations/)

### External Links
- [AWS RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [MySQL Performance Tuning](https://dev.mysql.com/doc/refman/8.0/en/optimization.html)
- [PostgreSQL Performance Tips](https://wiki.postgresql.org/wiki/Performance_Optimization)

## 🤝 Contributing

When modifying database schemas or scripts:

1. Test changes in development environment first
2. Create migration scripts for schema changes
3. Update documentation and README files
4. Verify backup and restore procedures work
5. Update security configurations if needed

## 📄 License

This database infrastructure is part of the DevOps Dashboard project. Refer to the main project license for terms and conditions.

# Metabase BI Deployment for DevOps Dashboard

Complete Metabase Business Intelligence platform deployment with real-time dashboards, database connections, and production-ready infrastructure.

## 🚀 Quick Start

### 1. Deploy to EC2

```bash
# Clone and navigate to metabase directory
cd application/metabase

# Configure environment
cp .env.example .env
# Edit .env with your actual values

# Deploy Metabase
sudo ./scripts/deploy-metabase.sh deploy
```

### 2. Setup Database Connections

```bash
# Setup database connections to RDS instances
./scripts/setup-databases.sh setup

# Test connections
./scripts/setup-databases.sh test
```

### 3. Create BI Dashboards

```bash
# Install Python dependencies
pip3 install requests

# Create comprehensive dashboards
python3 scripts/create-dashboards.py \
  --email admin@yourcompany.com \
  --password your_admin_password \
  --dashboards all
```

## 📊 Architecture Overview

### Infrastructure Components
- **Metabase Application**: Main BI platform with auto-scaling
- **PostgreSQL Database**: Metabase configuration and metadata storage
- **Nginx Reverse Proxy**: SSL termination and load balancing
- **Redis Cache**: Query caching and session storage
- **Backup System**: Automated backup and recovery procedures
- **Monitoring**: Health checks and performance monitoring

### Network Architecture
```
Internet → ALB → EC2 (Nginx) → Metabase → RDS Databases
                     ↓
              PostgreSQL + Redis
```

## 🔧 Configuration

### Environment Variables
Key configuration settings in `.env`:

```bash
# Application Settings
METABASE_SITE_URL=https://metabase.yourcompany.com
METABASE_ADMIN_EMAIL=admin@yourcompany.com
METABASE_ENCRYPTION_KEY=your_32_character_encryption_key

# Database Connections
MYSQL_RDS_HOST=your-mysql-endpoint
POSTGRESQL_RDS_HOST=your-postgresql-endpoint

# Security
SSL_CERT_PATH=/etc/nginx/ssl/metabase.crt
SSL_KEY_PATH=/etc/nginx/ssl/metabase.key
```

### SSL Configuration
The deployment includes SSL/TLS encryption:

1. **Development**: Self-signed certificates (auto-generated)
2. **Production**: Configure with proper CA certificates
3. **Let's Encrypt**: Automatic certificate management (optional)

## 📈 Dashboards Overview

### Executive Overview Dashboard
**Real-time business KPIs and metrics**
- Today's revenue and orders
- Active users and conversion rates
- 30-day revenue trends
- Key performance indicators

**Charts**: Scalar metrics, line charts, trend analysis

### Sales Analytics Dashboard
**Comprehensive sales performance metrics**
- Top-selling products by category
- Sales distribution analysis
- Customer segment performance
- Revenue attribution

**Charts**: Bar charts, pie charts, product performance tables

### Customer Analytics Dashboard
**Customer behavior and lifetime value analysis**
- Customer acquisition trends
- Lifetime value distribution
- User behavior patterns
- Retention analysis

**Charts**: Acquisition funnel, CLV distribution, behavior flow

### Real-time Monitoring Dashboard
**Live system metrics and business data**
- Live user activity (last hour)
- System performance metrics
- Recent orders and transactions
- Real-time alerts and notifications

**Charts**: Live line charts, performance gauges, activity tables
**Refresh**: 30-second auto-refresh

### Marketing Performance Dashboard
**Campaign analytics and attribution**
- Marketing campaign ROI
- Traffic source analysis
- Conversion attribution
- Campaign performance metrics

**Charts**: Campaign tables, traffic pie charts, attribution flow

## 🔐 Security Features

### Authentication & Authorization
- **Admin User Management**: Role-based access control
- **Session Management**: Secure session handling with timeout
- **Password Policy**: Strong password requirements
- **Multi-Factor Authentication**: Optional MFA support

### Network Security
- **SSL/TLS Encryption**: End-to-end encryption
- **Reverse Proxy**: Nginx with security headers
- **Rate Limiting**: API and login rate limiting
- **IP Restrictions**: Admin panel IP restrictions

### Database Security
- **Read-Only Connections**: Separate read-only database users
- **Connection Encryption**: SSL database connections
- **Credential Management**: Secure credential storage
- **Access Logging**: Database access audit logs

## 🛠 Management Commands

### Service Management
```bash
# Start services
sudo systemctl start metabase
# OR
./start.sh

# Stop services
sudo systemctl stop metabase
# OR
./stop.sh

# Restart services
sudo systemctl restart metabase
# OR
./restart.sh

# Check status
sudo systemctl status metabase
# OR
./status.sh
```

### Database Management
```bash
# Setup database connections
./scripts/setup-databases.sh setup

# Test database connections
./scripts/setup-databases.sh test

# Create read-only users
./scripts/setup-databases.sh users
```

### Dashboard Management
```bash
# Create all dashboards
python3 scripts/create-dashboards.py --dashboards all

# Create specific dashboards
python3 scripts/create-dashboards.py --dashboards executive sales

# Update existing dashboards
python3 scripts/create-dashboards.py --dashboards realtime
```

### Backup & Recovery
```bash
# Full backup
./scripts/backup-metabase.sh full

# Database backup only
./scripts/backup-metabase.sh database

# List existing backups
./scripts/backup-metabase.sh list

# Restore from backup
./scripts/backup-metabase.sh restore backup_file.sql.gz database

# Cleanup old backups
./scripts/backup-metabase.sh cleanup
```

### Monitoring & Health Checks
```bash
# Generate health report
./scripts/monitor-metabase.sh report

# Continuous monitoring (5-minute intervals)
./scripts/monitor-metabase.sh continuous 300

# Health check for external monitoring
./scripts/monitor-metabase.sh health

# Check specific components
./scripts/monitor-metabase.sh services
./scripts/monitor-metabase.sh performance
```

## 📊 Data Sources

### MySQL RDS (Business Data)
**Connection**: `devops_app` database
**Tables**:
- `orders`, `order_items`, `products`, `users`
- `customer_segments`, `sales_targets`
- `marketing_campaigns`, `campaign_metrics`
- `financial_metrics`, `support_tickets`

**Use Cases**: Sales analytics, customer insights, financial reporting

### PostgreSQL RDS (Analytics Data)
**Connection**: `devops_analytics` database
**Tables**:
- `analytics_events`, `performance_metrics`
- `user_journeys`, `conversion_funnels`
- `ab_tests`, `revenue_attribution`
- `clv_predictions`, `user_cohorts`

**Use Cases**: User behavior analysis, A/B testing, predictive analytics

## 🔄 Real-time Data Updates

### Automatic Refresh Configuration
- **Real-time Dashboard**: 30-second refresh
- **Executive Dashboard**: 5-minute refresh
- **Sales/Marketing**: 15-minute refresh
- **Database Sync**: Hourly metadata sync

### Live Data Pipeline
1. **Application Events** → PostgreSQL analytics tables
2. **Business Transactions** → MySQL operational tables
3. **Metabase Sync** → Automatic schema updates
4. **Dashboard Refresh** → Real-time visualization updates

## 🚨 Monitoring & Alerting

### Health Monitoring
- **Service Health**: Docker container status
- **Application Health**: API health endpoints
- **Database Health**: Connection and performance
- **System Resources**: CPU, memory, disk usage

### Performance Metrics
- **Response Times**: API and dashboard performance
- **Query Performance**: Database query execution times
- **Resource Usage**: System and container metrics
- **Error Rates**: Application and system errors

### Alert Conditions
- **High CPU/Memory Usage**: >80% threshold
- **Service Failures**: Container crashes or restarts
- **Database Issues**: Connection failures or slow queries
- **SSL Certificate**: Expiration warnings (30 days)

### Notification Channels
- **Slack/Teams**: Webhook notifications
- **Email**: SMTP alert notifications
- **Log Files**: Detailed logging for troubleshooting

## 📋 Backup Strategy

### Automated Backups
- **Database**: Daily PostgreSQL dumps with compression
- **Configuration**: Docker Compose and environment files
- **Volumes**: Docker volume snapshots
- **Logs**: Application and system logs

### Backup Retention
- **Local Backups**: 30 days retention
- **S3 Backups**: 90 days retention (optional)
- **Critical Data**: 1-year retention for compliance

### Recovery Procedures
1. **Service Recovery**: Docker container restart/rebuild
2. **Database Recovery**: Point-in-time recovery from backups
3. **Configuration Recovery**: Restore from configuration backups
4. **Full Disaster Recovery**: Complete infrastructure rebuild

## 🔧 Customization

### Adding Custom Dashboards
1. Create new dashboard collection
2. Define SQL queries for data sources
3. Configure visualization settings
4. Set up automatic refresh schedules
5. Configure user access permissions

### Custom Metrics and KPIs
1. Add new tables/views to source databases
2. Update Metabase schema sync
3. Create new questions and visualizations
4. Add to existing or new dashboards
5. Configure alerts and notifications

### Integration with External Systems
- **API Integration**: Metabase REST API for automation
- **Webhook Integration**: Real-time data updates
- **SSO Integration**: LDAP/SAML authentication
- **Embedding**: Dashboard embedding in applications

## 🚀 Performance Optimization

### Database Optimization
- **Query Optimization**: Indexed columns for fast queries
- **Connection Pooling**: Efficient database connections
- **Read Replicas**: Separate read workloads
- **Caching**: Redis for query result caching

### Application Optimization
- **Memory Settings**: Optimized JVM heap settings
- **Thread Pool**: Configured for concurrent users
- **Static Assets**: Nginx caching for assets
- **Compression**: Gzip compression for responses

### Infrastructure Optimization
- **Auto Scaling**: EC2 auto scaling for high availability
- **Load Balancing**: Application Load Balancer distribution
- **CDN**: CloudFront for static asset delivery
- **Monitoring**: CloudWatch metrics and alarms

## 📚 Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check Docker service
sudo systemctl status docker

# Check logs
docker-compose logs metabase
docker-compose logs metabase-postgres

# Restart services
sudo systemctl restart metabase
```

#### Database Connection Issues
```bash
# Test database connectivity
./scripts/setup-databases.sh test

# Check RDS security groups
# Verify database credentials
# Test network connectivity
```

#### Performance Issues
```bash
# Check system resources
./scripts/monitor-metabase.sh resources

# Analyze slow queries
./scripts/monitor-metabase.sh performance

# Review container logs
docker-compose logs --tail 100 metabase
```

#### SSL Certificate Issues
```bash
# Check certificate validity
./scripts/monitor-metabase.sh

# Regenerate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/metabase.key -out ssl/metabase.crt
```

### Log Files
- **Application**: `/opt/metabase/logs/metabase/`
- **Nginx**: `/opt/metabase/logs/nginx/`
- **PostgreSQL**: `/opt/metabase/logs/postgres/`
- **System**: `/tmp/metabase-*.log`

### Support Resources
- **Metabase Documentation**: [metabase.com/docs](https://metabase.com/docs)
- **Community Forum**: [discourse.metabase.com](https://discourse.metabase.com)
- **Docker Documentation**: [docs.docker.com](https://docs.docker.com)

## 🎯 Production Checklist

### Before Going Live
- [ ] Replace self-signed SSL certificates with CA certificates
- [ ] Configure proper domain and DNS settings
- [ ] Set up automated backups to S3
- [ ] Configure monitoring and alerting
- [ ] Test disaster recovery procedures
- [ ] Security hardening and penetration testing
- [ ] Performance testing under load
- [ ] User acceptance testing
- [ ] Documentation and training

### Post-Deployment
- [ ] Monitor system health and performance
- [ ] Regular security updates
- [ ] Backup verification and testing
- [ ] User feedback and optimization
- [ ] Capacity planning and scaling
- [ ] Regular security audits

## 📄 License

This Metabase deployment configuration is part of the DevOps Dashboard project. Refer to the main project license for terms and conditions.

---

**Ready for Production**: This Metabase deployment provides enterprise-grade BI capabilities with comprehensive monitoring, backup, and security features suitable for production environments.

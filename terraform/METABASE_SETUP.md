# Metabase Business Intelligence Tool Deployment

This project includes a dedicated EC2 instance for running Metabase, a powerful open-source business intelligence tool.

## Overview

- **BI Tool**: Metabase v0.47.7
- **Database**: Connects to the PostgreSQL RDS instance
- **Deployment**: Docker-based on dedicated EC2 instance
- **Sample Data**: Available via manual setup script
- **Access**: SSH tunnel through bastion host

## Deployment

The Metabase instance is automatically deployed with the infrastructure using an enhanced setup process:

```bash
cd terraform
terraform apply --auto-approve
```

### Automated Setup Features

- ✅ **Docker Compose Installation**: Automatically installs docker-compose binary
- ✅ **Database Connection**: Automatically retrieves and configures PostgreSQL credentials
- ✅ **Hostname Cleanup**: Removes port numbers from database hostnames
- ✅ **Systemd Service**: Creates service for automatic startup and management
- ✅ **Retry Logic**: Multiple startup attempts with verification
- ✅ **Auto-start**: Metabase starts automatically on system boot

## Access Information

After deployment, access Metabase via SSH tunnel:

```bash
# Get connection details
terraform output metabase_private_ip
terraform output bastion_public_ip
terraform output metabase_access_via_bastion

# SSH tunnel command (replace IPs with actual values)
ssh -i ~/.ssh/DevOps-FP-KeyPair.pem -L 3000:<METABASE_PRIVATE_IP>:3000 ec2-user@<BASTION_PUBLIC_IP>

# Then access in browser
http://localhost:3000
```

## Initial Setup

1. **Access Metabase** at `http://localhost:3000` via SSH tunnel
2. **Complete setup wizard**:
   - Create admin account
   - Database connection is pre-configured to PostgreSQL RDS
   - Skip additional setup steps

## Adding Sample Data

Use the provided script to add sample data for dashboards:

```bash
# In terraform directory
./add-sample-data.sh
```

This creates sample SQL and provides instructions to:
1. Copy SQL file to bastion host
2. Execute SQL via PostgreSQL connection
3. Build dashboards with the sample data

### Sample Data Includes

**Sales Data Table:**
- Product sales with categories and regions
- Sales amounts and quantities
- Date-based records for time series analysis

**User Activity Table:**
- User login/logout activities  
- Page views and purchases
- IP addresses and user agents
- Device type tracking

## Creating Dashboards

With the sample data, you can create:

1. **Sales Dashboard**:
   - Total sales by region
   - Sales trends over time
   - Top products by revenue
   - Category performance

2. **User Activity Dashboard**:
   - Daily active users
   - Activity type distribution
   - Geographic user distribution
   - User engagement metrics

## Live Data Demonstration

To demonstrate live updates:

1. **SSH to Metabase instance**:
   ```bash
   ssh -i ~/.ssh/DevOps-FP-KeyPair.pem ec2-user@<BASTION_IP>
   ssh ec2-user@<METABASE_PRIVATE_IP>
   ```

2. **Add new data** using PostgreSQL client:
   ```sql
   INSERT INTO sales_data (date, product_name, category, sales_amount, quantity_sold, region) 
   VALUES (CURRENT_DATE, 'New Product', 'Electronics', 999.99, 2, 'North');
   ```

3. **Refresh dashboards** to see live updates

## Security Features

- ✅ **Private subnet deployment** - Metabase not directly accessible from internet
- ✅ **SSH tunnel access** - Secure access via bastion host  
- ✅ **Security groups** - Restricted network access
- ✅ **RDS integration** - Secure database connections via AWS Secrets Manager

## Management Commands

**Check Metabase status:**
```bash
# SSH to Metabase instance
sudo systemctl status metabase  # Service status
docker ps                       # Container status
docker logs metabase           # Container logs
sudo journalctl -u metabase    # Service logs
```

**Restart Metabase:**
```bash
# Via systemd service (recommended)
sudo systemctl restart metabase

# Or via docker-compose directly
cd /opt/metabase
sudo /usr/local/bin/docker-compose restart
```

**Start/Stop Metabase:**
```bash
sudo systemctl start metabase   # Start service
sudo systemctl stop metabase    # Stop service
sudo systemctl enable metabase  # Enable auto-start
sudo systemctl disable metabase # Disable auto-start
```

**View configuration:**
```bash
cat /opt/metabase/.env
cat /opt/metabase/docker-compose.yml
cat /etc/systemd/system/metabase.service
```

## Troubleshooting

1. **Metabase not accessible**:
   - Verify SSH tunnel is active: `netstat -tlnp | grep 3000`
   - Check systemd service: `sudo systemctl status metabase`
   - Check Docker container: `docker ps | grep metabase`
   - Check container logs: `docker logs metabase`
   - Check service logs: `sudo journalctl -u metabase -f`

2. **Database connection issues**:
   - Verify RDS endpoint format: `grep MB_DB_HOST /opt/metabase/.env` (should NOT include :5432)
   - Check security groups allow PostgreSQL access
   - Verify AWS Secrets Manager access
   - Restart service: `sudo systemctl restart metabase`

3. **Docker Compose issues**:
   - Verify installation: `/usr/local/bin/docker-compose --version`
   - Check PATH access: `sudo which docker-compose`
   - Manual container start: `cd /opt/metabase && sudo /usr/local/bin/docker-compose up -d`

4. **Service startup issues**:
   - Check systemd service file: `cat /etc/systemd/system/metabase.service`
   - Reload systemd: `sudo systemctl daemon-reload`
   - Enable service: `sudo systemctl enable metabase`
   - Check dependencies: `sudo systemctl list-dependencies metabase`

5. **Sample data missing**:
   - Manually run the sample data SQL script
   - Check PostgreSQL connection from bastion host

## Cost Considerations

- Dedicated EC2 instance for Metabase
- Additional EBS storage for Docker volumes
- Data transfer costs for SSH tunneling
- Shared PostgreSQL RDS instance

## Architecture Benefits

This setup provides:
- **Scalable BI solution** with dedicated resources
- **Secure access** via SSH tunneling
- **Integration** with existing PostgreSQL database
- **Sample data** for immediate dashboard creation
- **Live update capabilities** for demonstrations

The Metabase deployment is production-ready and can be scaled as needed for your business intelligence requirements. 
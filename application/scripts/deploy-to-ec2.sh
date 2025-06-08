#!/bin/bash

# DevOps Final Project - EC2 Deployment Script
# Deploys the complete application stack to EC2 instances

set -euo pipefail

# Configuration
APP_NAME="devops-dashboard"
PROJECT_DIR="/opt/${APP_NAME}"
DOCKER_COMPOSE_VERSION="2.20.2"
NODE_VERSION="18"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root for security reasons"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS version"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "centos" && "$ID" != "rhel" && "$ID" != "amazon" ]]; then
        log_error "Unsupported OS: $ID"
        exit 1
    fi
    
    log_success "OS check passed: $PRETTY_NAME"
    
    # Check available memory (minimum 2GB)
    MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEMORY_GB=$((MEMORY_KB / 1024 / 1024))
    
    if [[ $MEMORY_GB -lt 2 ]]; then
        log_error "Insufficient memory: ${MEMORY_GB}GB (minimum 2GB required)"
        exit 1
    fi
    
    log_success "Memory check passed: ${MEMORY_GB}GB available"
    
    # Check available disk space (minimum 10GB)
    DISK_AVAILABLE=$(df / | tail -1 | awk '{print $4}')
    DISK_GB=$((DISK_AVAILABLE / 1024 / 1024))
    
    if [[ $DISK_GB -lt 10 ]]; then
        log_error "Insufficient disk space: ${DISK_GB}GB (minimum 10GB required)"
        exit 1
    fi
    
    log_success "Disk space check passed: ${DISK_GB}GB available"
}

# Install system dependencies
install_dependencies() {
    log_info "Installing system dependencies..."
    
    # Update package manager
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -y
        sudo apt-get upgrade -y
        sudo apt-get install -y \
            curl \
            wget \
            git \
            unzip \
            software-properties-common \
            apt-transport-https \
            ca-certificates \
            gnupg \
            lsb-release \
            build-essential \
            htop \
            vim \
            nano \
            jq
    elif command -v yum &> /dev/null; then
        sudo yum update -y
        sudo yum groupinstall -y "Development Tools"
        sudo yum install -y \
            curl \
            wget \
            git \
            unzip \
            htop \
            vim \
            nano \
            jq
    elif command -v dnf &> /dev/null; then
        sudo dnf update -y
        sudo dnf groupinstall -y "Development Tools"
        sudo dnf install -y \
            curl \
            wget \
            git \
            unzip \
            htop \
            vim \
            nano \
            jq
    fi
    
    log_success "System dependencies installed"
}

# Install Docker
install_docker() {
    log_info "Installing Docker..."
    
    if command -v docker &> /dev/null; then
        log_warning "Docker is already installed"
        return 0
    fi
    
    # Install Docker using official script
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    # Enable and start Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
    
    log_success "Docker installed successfully"
}

# Install Docker Compose
install_docker_compose() {
    log_info "Installing Docker Compose..."
    
    if command -v docker-compose &> /dev/null; then
        log_warning "Docker Compose is already installed"
        return 0
    fi
    
    # Download and install Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Create symlink for easier access
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    log_success "Docker Compose installed successfully"
}

# Install Node.js (for development/debugging)
install_nodejs() {
    log_info "Installing Node.js..."
    
    if command -v node &> /dev/null; then
        NODE_CURRENT_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$NODE_CURRENT_VERSION" -ge "$NODE_VERSION" ]]; then
            log_warning "Node.js $NODE_CURRENT_VERSION is already installed"
            return 0
        fi
    fi
    
    # Install Node.js using NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
    
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y nodejs
    elif command -v yum &> /dev/null; then
        sudo yum install -y nodejs npm
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y nodejs npm
    fi
    
    log_success "Node.js installed successfully"
}

# Setup application directory
setup_app_directory() {
    log_info "Setting up application directory..."
    
    # Create project directory
    sudo mkdir -p $PROJECT_DIR
    sudo chown $USER:$USER $PROJECT_DIR
    
    # Create necessary subdirectories
    mkdir -p $PROJECT_DIR/{logs,data,backups,ssl}
    
    log_success "Application directory created: $PROJECT_DIR"
}

# Clone application repository
clone_repository() {
    log_info "Cloning application repository..."
    
    # Note: In a real deployment, this would clone from your Git repository
    # For this demo, we'll copy from the current directory
    if [[ -d "./application" ]]; then
        cp -r ./application/* $PROJECT_DIR/
        log_success "Application files copied to $PROJECT_DIR"
    else
        log_error "Application directory not found. Please ensure you're running this script from the project root."
        exit 1
    fi
}

# Setup environment configuration
setup_environment() {
    log_info "Setting up environment configuration..."
    
    # Create production environment file
    cat > $PROJECT_DIR/.env.production << EOF
# Production Environment Configuration
NODE_ENV=production

# Database Configuration
MYSQL_HOST=mysql
MYSQL_PORT=3306
MYSQL_DATABASE=devops_app
MYSQL_USER=app_user
MYSQL_PASSWORD=\${MYSQL_PASSWORD}
MYSQL_ROOT_PASSWORD=\${MYSQL_ROOT_PASSWORD}

POSTGRESQL_HOST=postgresql
POSTGRESQL_PORT=5432
POSTGRESQL_DATABASE=devops_analytics
POSTGRESQL_USER=analytics_user
POSTGRESQL_PASSWORD=\${POSTGRESQL_PASSWORD}

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379

# Application Configuration
API_PORT=3001
FRONTEND_PORT=80

# Security
JWT_SECRET=\${JWT_SECRET}
SESSION_SECRET=\${SESSION_SECRET}

# CORS
CORS_ORIGIN=*

# Logging
LOG_LEVEL=info

# Features
ENABLE_REAL_TIME_DATA=true
ENABLE_ANALYTICS=true
ENABLE_MONITORING=true

# SSL (for production with custom certificates)
SSL_ENABLED=false
SSL_CERT_PATH=/opt/${APP_NAME}/ssl/cert.pem
SSL_KEY_PATH=/opt/${APP_NAME}/ssl/key.pem
EOF

    # Create secrets file (should be populated with actual secrets)
    cat > $PROJECT_DIR/.env.secrets << 'EOF'
# Security Secrets - CHANGE THESE IN PRODUCTION!
MYSQL_PASSWORD=secure_mysql_password_change_me
MYSQL_ROOT_PASSWORD=secure_root_password_change_me
POSTGRESQL_PASSWORD=secure_postgres_password_change_me
JWT_SECRET=your_super_secure_jwt_secret_change_me_at_least_32_chars
SESSION_SECRET=your_super_secure_session_secret_change_me_at_least_32_chars
EOF

    chmod 600 $PROJECT_DIR/.env.secrets
    
    log_success "Environment configuration created"
    log_warning "Please update the secrets in $PROJECT_DIR/.env.secrets before starting the application"
}

# Setup systemd service
setup_systemd_service() {
    log_info "Setting up systemd service..."
    
    # Create systemd service file
    sudo tee /etc/systemd/system/${APP_NAME}.service > /dev/null << EOF
[Unit]
Description=DevOps Dashboard Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${PROJECT_DIR}
ExecStart=/usr/local/bin/docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.yml -f docker-compose.prod.yml down
ExecReload=/usr/local/bin/docker-compose -f docker-compose.yml -f docker-compose.prod.yml restart
TimeoutStartSec=0
User=${USER}
Group=${USER}

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable ${APP_NAME}.service
    
    log_success "Systemd service created and enabled"
}

# Setup monitoring and logging
setup_monitoring() {
    log_info "Setting up monitoring and logging..."
    
    # Create log rotation configuration
    sudo tee /etc/logrotate.d/${APP_NAME} > /dev/null << EOF
${PROJECT_DIR}/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    create 644 ${USER} ${USER}
    postrotate
        docker-compose -f ${PROJECT_DIR}/docker-compose.yml -f ${PROJECT_DIR}/docker-compose.prod.yml restart backend
    endscript
}
EOF

    # Create monitoring script
    cat > $PROJECT_DIR/scripts/health-check.sh << 'EOF'
#!/bin/bash

# Health check script
PROJECT_DIR="/opt/devops-dashboard"
LOG_FILE="$PROJECT_DIR/logs/health-check.log"

echo "[$(date)] Starting health check..." >> $LOG_FILE

# Check if containers are running
if docker-compose -f $PROJECT_DIR/docker-compose.yml -f $PROJECT_DIR/docker-compose.prod.yml ps | grep -q "Up"; then
    echo "[$(date)] Containers are running" >> $LOG_FILE
else
    echo "[$(date)] ERROR: Some containers are not running" >> $LOG_FILE
    exit 1
fi

# Check application health endpoints
if curl -f http://localhost:3001/api/health > /dev/null 2>&1; then
    echo "[$(date)] Backend health check passed" >> $LOG_FILE
else
    echo "[$(date)] ERROR: Backend health check failed" >> $LOG_FILE
    exit 1
fi

if curl -f http://localhost/health > /dev/null 2>&1; then
    echo "[$(date)] Frontend health check passed" >> $LOG_FILE
else
    echo "[$(date)] ERROR: Frontend health check failed" >> $LOG_FILE
    exit 1
fi

echo "[$(date)] Health check completed successfully" >> $LOG_FILE
EOF

    chmod +x $PROJECT_DIR/scripts/health-check.sh
    
    # Add cron job for health checks
    (crontab -l 2>/dev/null; echo "*/5 * * * * $PROJECT_DIR/scripts/health-check.sh") | crontab -
    
    log_success "Monitoring and logging configured"
}

# Setup firewall
setup_firewall() {
    log_info "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        sudo ufw --force enable
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw allow ssh
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        sudo ufw allow 3001/tcp  # Backend API (can be removed in production)
        log_success "UFW firewall configured"
    elif command -v firewall-cmd &> /dev/null; then
        sudo systemctl enable firewalld
        sudo systemctl start firewalld
        sudo firewall-cmd --permanent --add-service=ssh
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --permanent --add-service=https
        sudo firewall-cmd --permanent --add-port=3001/tcp
        sudo firewall-cmd --reload
        log_success "Firewalld configured"
    else
        log_warning "No supported firewall found. Please configure iptables manually."
    fi
}

# Build and start application
start_application() {
    log_info "Building and starting application..."
    
    cd $PROJECT_DIR
    
    # Load environment variables
    source .env.production
    source .env.secrets
    export $(grep -v '^#' .env.production | xargs)
    export $(grep -v '^#' .env.secrets | xargs)
    
    # Build and start containers
    docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache
    docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
    
    # Wait for services to be ready
    log_info "Waiting for services to start..."
    sleep 30
    
    # Check if services are running
    if docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps | grep -q "Up"; then
        log_success "Application started successfully"
    else
        log_error "Some services failed to start"
        docker-compose -f docker-compose.yml -f docker-compose.prod.yml logs
        exit 1
    fi
}

# Create management scripts
create_management_scripts() {
    log_info "Creating management scripts..."
    
    mkdir -p $PROJECT_DIR/scripts
    
    # Start script
    cat > $PROJECT_DIR/scripts/start.sh << 'EOF'
#!/bin/bash
cd /opt/devops-dashboard
source .env.production
source .env.secrets
export $(grep -v '^#' .env.production | xargs)
export $(grep -v '^#' .env.secrets | xargs)
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
EOF

    # Stop script
    cat > $PROJECT_DIR/scripts/stop.sh << 'EOF'
#!/bin/bash
cd /opt/devops-dashboard
docker-compose -f docker-compose.yml -f docker-compose.prod.yml down
EOF

    # Restart script
    cat > $PROJECT_DIR/scripts/restart.sh << 'EOF'
#!/bin/bash
cd /opt/devops-dashboard
docker-compose -f docker-compose.yml -f docker-compose.prod.yml restart
EOF

    # Update script
    cat > $PROJECT_DIR/scripts/update.sh << 'EOF'
#!/bin/bash
cd /opt/devops-dashboard
git pull origin main
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
EOF

    # Backup script
    cat > $PROJECT_DIR/scripts/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/devops-dashboard/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup databases
docker exec devops-mysql mysqldump -u root -p$MYSQL_ROOT_PASSWORD --all-databases > $BACKUP_DIR/mysql_backup_$DATE.sql
docker exec devops-postgresql pg_dumpall -U analytics_user > $BACKUP_DIR/postgresql_backup_$DATE.sql

# Backup application data
tar -czf $BACKUP_DIR/app_data_$DATE.tar.gz -C /opt/devops-dashboard data logs

# Keep only last 30 days of backups
find $BACKUP_DIR -name "*.sql" -mtime +30 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Backup completed: $DATE"
EOF

    # Make scripts executable
    chmod +x $PROJECT_DIR/scripts/*.sh
    
    log_success "Management scripts created"
}

# Display final instructions
display_instructions() {
    log_success "Deployment completed successfully!"
    echo
    echo "=== NEXT STEPS ==="
    echo
    echo "1. Update secrets in: $PROJECT_DIR/.env.secrets"
    echo "2. Configure SSL certificates (if needed): $PROJECT_DIR/ssl/"
    echo "3. Start the application: sudo systemctl start $APP_NAME"
    echo "4. Check application status: sudo systemctl status $APP_NAME"
    echo
    echo "=== APPLICATION URLS ==="
    echo "Frontend: http://$(curl -s ifconfig.me || echo "YOUR_SERVER_IP")"
    echo "Backend API: http://$(curl -s ifconfig.me || echo "YOUR_SERVER_IP"):3001"
    echo "Database Admin: http://$(curl -s ifconfig.me || echo "YOUR_SERVER_IP"):8080"
    echo
    echo "=== MANAGEMENT COMMANDS ==="
    echo "Start:   $PROJECT_DIR/scripts/start.sh"
    echo "Stop:    $PROJECT_DIR/scripts/stop.sh"
    echo "Restart: $PROJECT_DIR/scripts/restart.sh"
    echo "Update:  $PROJECT_DIR/scripts/update.sh"
    echo "Backup:  $PROJECT_DIR/scripts/backup.sh"
    echo
    echo "=== MONITORING ==="
    echo "Logs: $PROJECT_DIR/logs/"
    echo "Health: $PROJECT_DIR/scripts/health-check.sh"
    echo
    log_warning "Remember to:"
    log_warning "1. Change all default passwords"
    log_warning "2. Configure SSL certificates for production"
    log_warning "3. Set up proper backup procedures"
    log_warning "4. Configure monitoring and alerting"
}

# Main deployment function
main() {
    log_info "Starting DevOps Dashboard deployment..."
    
    check_root
    check_requirements
    install_dependencies
    install_docker
    install_docker_compose
    install_nodejs
    setup_app_directory
    clone_repository
    setup_environment
    setup_systemd_service
    setup_monitoring
    setup_firewall
    create_management_scripts
    start_application
    
    display_instructions
}

# Run main function
main "$@"

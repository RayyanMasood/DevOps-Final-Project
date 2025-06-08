#!/bin/bash

# Metabase Deployment Script for EC2
# Deploys and configures Metabase BI tool with database connections and dashboards

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/tmp/metabase-deploy.log"
INSTALL_DIR="/opt/metabase"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root for security reasons"
        log_info "Please run as a regular user with sudo privileges"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    # Check OS
    if ! grep -q "Amazon Linux\|Ubuntu\|CentOS\|Red Hat" /etc/os-release; then
        log_warning "Unsupported operating system detected"
    fi
    
    # Check memory (minimum 4GB recommended)
    local mem_gb=$(free -g | awk 'NR==2{printf "%.0f", $2}')
    if [[ $mem_gb -lt 4 ]]; then
        log_warning "Less than 4GB RAM detected. Metabase may run slowly."
    else
        log_success "Memory check passed: ${mem_gb}GB RAM"
    fi
    
    # Check disk space (minimum 20GB)
    local disk_gb=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $disk_gb -lt 20 ]]; then
        log_error "Insufficient disk space. At least 20GB required."
        exit 1
    else
        log_success "Disk space check passed: ${disk_gb}GB available"
    fi
    
    # Check required commands
    local required_commands=("docker" "docker-compose" "curl" "openssl" "jq")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done
    
    log_success "System requirements check completed"
}

# Install system dependencies
install_dependencies() {
    log_info "Installing system dependencies..."
    
    # Detect package manager
    if command -v yum >/dev/null 2>&1; then
        # Amazon Linux / CentOS / RHEL
        sudo yum update -y
        sudo yum install -y \
            docker \
            docker-compose \
            curl \
            wget \
            openssl \
            jq \
            htop \
            vim \
            git \
            unzip \
            logrotate
    elif command -v apt-get >/dev/null 2>&1; then
        # Ubuntu / Debian
        sudo apt-get update
        sudo apt-get install -y \
            docker.io \
            docker-compose \
            curl \
            wget \
            openssl \
            jq \
            htop \
            vim \
            git \
            unzip \
            logrotate
    else
        log_error "Unsupported package manager"
        exit 1
    fi
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add current user to docker group
    sudo usermod -aG docker "$USER"
    
    log_success "Dependencies installed successfully"
}

# Setup project directory structure
setup_directories() {
    log_info "Setting up project directories..."
    
    # Create main installation directory
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown "$USER:$USER" "$INSTALL_DIR"
    
    # Create directory structure
    mkdir -p "$INSTALL_DIR"/{data,postgres,redis,backups,logs,ssl,config,scripts}
    mkdir -p "$INSTALL_DIR"/logs/{nginx,metabase,postgres,redis}
    
    # Set proper permissions
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$INSTALL_DIR"/{data,postgres,redis,backups,logs,ssl,config,scripts}
    
    log_success "Directory structure created"
}

# Copy project files
copy_project_files() {
    log_info "Copying project files..."
    
    # Copy Docker Compose configuration
    cp "$PROJECT_DIR/docker-compose.yml" "$INSTALL_DIR/"
    cp "$PROJECT_DIR/.env.example" "$INSTALL_DIR/.env"
    
    # Copy Nginx configuration
    cp -r "$PROJECT_DIR/nginx" "$INSTALL_DIR/"
    
    # Copy scripts
    cp -r "$PROJECT_DIR/scripts" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR"/scripts/*.sh
    
    # Copy configuration files
    cp -r "$PROJECT_DIR/config" "$INSTALL_DIR/" 2>/dev/null || true
    
    log_success "Project files copied"
}

# Generate SSL certificates
generate_ssl_certificates() {
    log_info "Generating SSL certificates..."
    
    local ssl_dir="$INSTALL_DIR/ssl"
    local domain="${METABASE_DOMAIN:-metabase.localhost}"
    
    # Generate self-signed certificate for development
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$ssl_dir/metabase.key" \
        -out "$ssl_dir/metabase.crt" \
        -config <(
        echo '[dn]'
        echo 'CN='$domain
        echo '[req]'
        echo 'distinguished_name = dn'
        echo '[SAN]'
        echo 'subjectAltName=DNS:'$domain',DNS:localhost,IP:127.0.0.1'
        echo '[v3_req]'
        echo 'subjectAltName = @SAN'
        ) \
        -extensions v3_req \
        -subj "/CN=$domain"
    
    # Set proper permissions
    chmod 600 "$ssl_dir/metabase.key"
    chmod 644 "$ssl_dir/metabase.crt"
    
    log_success "SSL certificates generated"
    log_warning "Using self-signed certificates. Replace with proper certificates for production."
}

# Configure environment variables
configure_environment() {
    log_info "Configuring environment variables..."
    
    local env_file="$INSTALL_DIR/.env"
    
    # Generate secure passwords and keys
    local metabase_db_password=$(openssl rand -base64 32 | tr -d '\n')
    local redis_password=$(openssl rand -base64 32 | tr -d '\n')
    local encryption_key=$(openssl rand -hex 32)
    local embedding_key=$(openssl rand -hex 32)
    
    # Update environment file
    sed -i "s/METABASE_DB_PASSWORD=.*/METABASE_DB_PASSWORD=${metabase_db_password}/" "$env_file"
    sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=${redis_password}/" "$env_file"
    sed -i "s/METABASE_ENCRYPTION_KEY=.*/METABASE_ENCRYPTION_KEY=${encryption_key}/" "$env_file"
    sed -i "s/METABASE_EMBEDDING_KEY=.*/METABASE_EMBEDDING_KEY=${embedding_key}/" "$env_file"
    
    # Set proper permissions
    chmod 600 "$env_file"
    
    log_success "Environment variables configured"
    log_info "Generated secure passwords and encryption keys"
}

# Setup systemd service
setup_systemd_service() {
    log_info "Setting up systemd service..."
    
    sudo tee /etc/systemd/system/metabase.service > /dev/null <<EOF
[Unit]
Description=Metabase BI Analytics Platform
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart
TimeoutStartSec=0
User=$USER
Group=$USER

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable metabase.service
    
    log_success "Systemd service configured"
}

# Setup log rotation
setup_log_rotation() {
    log_info "Setting up log rotation..."
    
    sudo tee /etc/logrotate.d/metabase > /dev/null <<EOF
$INSTALL_DIR/logs/*/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    sharedscripts
    postrotate
        docker-compose -f $INSTALL_DIR/docker-compose.yml restart nginx || true
    endscript
}

/tmp/metabase-*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF

    log_success "Log rotation configured"
}

# Start Metabase services
start_services() {
    log_info "Starting Metabase services..."
    
    cd "$INSTALL_DIR"
    
    # Pull latest images
    docker-compose pull
    
    # Start services
    docker-compose up -d
    
    # Wait for services to be ready
    log_info "Waiting for services to start..."
    sleep 30
    
    # Check service health
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f -s http://localhost:3000/api/health >/dev/null 2>&1; then
            log_success "Metabase is running and healthy"
            break
        else
            log_info "Waiting for Metabase to start... (attempt $attempt/$max_attempts)"
            sleep 10
            ((attempt++))
        fi
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        log_error "Metabase failed to start within expected time"
        log_info "Check logs: docker-compose logs -f metabase"
        exit 1
    fi
}

# Setup firewall rules
setup_firewall() {
    log_info "Configuring firewall..."
    
    # Check if ufw is available (Ubuntu)
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        sudo ufw allow 3000/tcp
        sudo ufw allow 9100/tcp  # Node exporter
        log_success "UFW firewall rules configured"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        # firewalld (CentOS/RHEL)
        sudo firewall-cmd --permanent --add-port=80/tcp
        sudo firewall-cmd --permanent --add-port=443/tcp
        sudo firewall-cmd --permanent --add-port=3000/tcp
        sudo firewall-cmd --permanent --add-port=9100/tcp
        sudo firewall-cmd --reload
        log_success "Firewalld rules configured"
    else
        log_warning "No supported firewall found. Please configure manually."
    fi
}

# Create management scripts
create_management_scripts() {
    log_info "Creating management scripts..."
    
    # Create start script
    cat > "$INSTALL_DIR/start.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Starting Metabase services..."
docker-compose up -d
echo "Services started. Access Metabase at: https://$(hostname):3000"
EOF

    # Create stop script
    cat > "$INSTALL_DIR/stop.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Stopping Metabase services..."
docker-compose down
echo "Services stopped."
EOF

    # Create restart script
    cat > "$INSTALL_DIR/restart.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Restarting Metabase services..."
docker-compose restart
echo "Services restarted."
EOF

    # Create backup script
    cat > "$INSTALL_DIR/backup.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Starting backup..."
docker-compose run --rm backup
echo "Backup completed."
EOF

    # Create status script
    cat > "$INSTALL_DIR/status.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "=== Metabase Services Status ==="
docker-compose ps
echo
echo "=== Service Health ==="
curl -s http://localhost:3000/api/health && echo " - Metabase: Healthy" || echo " - Metabase: Unhealthy"
echo
echo "=== Resource Usage ==="
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
EOF

    # Make scripts executable
    chmod +x "$INSTALL_DIR"/*.sh
    
    log_success "Management scripts created"
}

# Display deployment information
show_deployment_info() {
    local public_ip=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}')
    
    echo
    echo "=== Metabase Deployment Complete ==="
    echo "Installation Directory: $INSTALL_DIR"
    echo "Access URL: https://$public_ip:3000"
    echo "Local URL: https://localhost:3000"
    echo
    echo "=== Management Commands ==="
    echo "Start services:   sudo systemctl start metabase"
    echo "Stop services:    sudo systemctl stop metabase"
    echo "Restart services: sudo systemctl restart metabase"
    echo "View status:      sudo systemctl status metabase"
    echo
    echo "=== Manual Management ==="
    echo "Start:    $INSTALL_DIR/start.sh"
    echo "Stop:     $INSTALL_DIR/stop.sh"
    echo "Restart:  $INSTALL_DIR/restart.sh"
    echo "Status:   $INSTALL_DIR/status.sh"
    echo "Backup:   $INSTALL_DIR/backup.sh"
    echo
    echo "=== Next Steps ==="
    echo "1. Access Metabase setup at: https://$public_ip:3000"
    echo "2. Configure database connections using the dashboard setup script"
    echo "3. Import pre-built dashboards"
    echo "4. Configure SSL certificates for production use"
    echo "5. Set up monitoring and alerting"
    echo
    echo "=== Configuration Files ==="
    echo "Environment: $INSTALL_DIR/.env"
    echo "Docker Compose: $INSTALL_DIR/docker-compose.yml"
    echo "Nginx Config: $INSTALL_DIR/nginx/nginx.conf"
    echo "Logs: $INSTALL_DIR/logs/"
    echo
    echo "=== Security Notes ==="
    echo "- Change default passwords in $INSTALL_DIR/.env"
    echo "- Replace self-signed SSL certificates for production"
    echo "- Configure firewall rules for your network"
    echo "- Enable backup procedures"
    echo
}

# Main deployment function
main() {
    local action="${1:-deploy}"
    
    case "$action" in
        deploy)
            log_info "Starting Metabase deployment..."
            check_root
            check_requirements
            install_dependencies
            setup_directories
            copy_project_files
            generate_ssl_certificates
            configure_environment
            setup_systemd_service
            setup_log_rotation
            start_services
            setup_firewall
            create_management_scripts
            show_deployment_info
            log_success "Metabase deployment completed successfully!"
            ;;
        update)
            log_info "Updating Metabase..."
            cd "$INSTALL_DIR"
            docker-compose pull
            docker-compose up -d
            log_success "Metabase updated successfully!"
            ;;
        uninstall)
            log_warning "Uninstalling Metabase..."
            read -p "Are you sure you want to uninstall Metabase? (yes/no): " confirm
            if [[ "$confirm" == "yes" ]]; then
                sudo systemctl stop metabase || true
                sudo systemctl disable metabase || true
                sudo rm -f /etc/systemd/system/metabase.service
                sudo systemctl daemon-reload
                cd "$INSTALL_DIR" && docker-compose down -v || true
                sudo rm -rf "$INSTALL_DIR"
                sudo rm -f /etc/logrotate.d/metabase
                log_success "Metabase uninstalled successfully!"
            else
                log_info "Uninstall cancelled"
            fi
            ;;
        *)
            echo "Usage: $0 [deploy|update|uninstall]"
            echo
            echo "Commands:"
            echo "  deploy     - Full deployment (default)"
            echo "  update     - Update Metabase to latest version"
            echo "  uninstall  - Remove Metabase completely"
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'log_error "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"

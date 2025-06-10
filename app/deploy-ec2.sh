#!/bin/bash

# EC2 Deployment Script for Notes App
# This script deploys the application on EC2 instances to connect with RDS databases

set -e

echo "🚀 Starting EC2 Deployment for Notes App..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running on EC2
if ! curl -s --max-time 2 http://169.254.169.254/latest/meta-data/instance-id > /dev/null 2>&1; then
    print_warning "Not running on EC2 instance. This script is optimized for EC2 deployment."
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    print_info "On Amazon Linux 2: sudo systemctl start docker"
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed."
    print_info "Installing Docker Compose..."
    
    # Install docker-compose for Amazon Linux 2
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Failed to install Docker Compose"
        exit 1
    fi
    print_status "Docker Compose installed successfully"
fi

# Check for environment file
if [ ! -f ".env" ]; then
    if [ -f "env.ec2.example" ]; then
        print_warning "No .env file found. Please copy env.ec2.example to .env and configure it:"
        print_info "cp env.ec2.example .env"
        print_info "nano .env  # Edit with your RDS endpoints and credentials"
        echo
        print_error "Please configure .env file with your RDS endpoints before running this script."
        exit 1
    else
        print_error "No environment configuration found. Please create a .env file."
        exit 1
    fi
fi

print_status "Environment configuration found"

# Source environment variables
set -a
source .env
set +a

# Validate required environment variables
required_vars=(
    "MYSQL_RDS_ENDPOINT"
    "POSTGRES_RDS_ENDPOINT"
    "MYSQL_USER"
    "MYSQL_PASSWORD"
    "POSTGRES_USER" 
    "POSTGRES_PASSWORD"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    print_error "Missing required environment variables:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    print_info "Please configure these in your .env file"
    exit 1
fi

print_status "All required environment variables are set"

# Test RDS connectivity (optional but recommended)
print_status "Testing RDS connectivity..."

# Install mysql client if not present (for testing)
if ! command -v mysql &> /dev/null; then
    print_info "Installing MySQL client for connectivity testing..."
    if command -v yum &> /dev/null; then
        sudo yum install -y mysql
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y mysql-client-core-8.0
    fi
fi

# Test MySQL connection
if command -v mysql &> /dev/null; then
    if mysql -h"$MYSQL_RDS_ENDPOINT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1;" > /dev/null 2>&1; then
        print_status "✅ MySQL RDS connection successful"
    else
        print_warning "⚠️ MySQL RDS connection failed - please check your credentials and security groups"
    fi
fi

# Test PostgreSQL connection
if command -v psql &> /dev/null; then
    if PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_RDS_ENDPOINT" -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" -c "SELECT 1;" > /dev/null 2>&1; then
        print_status "✅ PostgreSQL RDS connection successful"
    else
        print_warning "⚠️ PostgreSQL RDS connection failed - please check your credentials and security groups"
    fi
fi

print_status "Stopping any existing containers..."
docker-compose -f docker-compose.ec2.yml down 2>/dev/null || true

print_status "Building Docker images..."
docker-compose -f docker-compose.ec2.yml build --no-cache

print_status "Starting application services..."
docker-compose -f docker-compose.ec2.yml up -d

print_status "Waiting for services to be ready..."

# Wait for services to be healthy
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    healthy_services=0
    
    # Check Backend
    if curl -f -s http://localhost:3001/health >/dev/null 2>&1; then
        ((healthy_services++))
    fi
    
    # Check Frontend
    if curl -f -s http://localhost:3000/health >/dev/null 2>&1; then
        ((healthy_services++))
    fi
    
    if [ $healthy_services -eq 2 ]; then
        break
    fi
    
    echo -n "."
    sleep 2
    ((attempt++))
done

echo

if [ $healthy_services -eq 2 ]; then
    print_status "✅ All services are healthy!"
else
    print_warning "⚠️ Some services may not be fully ready yet. Check logs if needed."
fi

print_status "🎉 EC2 Deployment completed!"

echo
echo "📱 Application Endpoints:"
echo "   Frontend:                 http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'localhost'):3000"
echo "   Backend API:              http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'localhost'):3001"
echo "   Health Check (Frontend):  http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'localhost'):3000/health"
echo "   Health Check (Backend):   http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'localhost'):3001/health"
echo

echo "🔧 Management Commands:"
echo "   View logs:                docker-compose -f docker-compose.ec2.yml logs -f"
echo "   Check status:             docker-compose -f docker-compose.ec2.yml ps"
echo "   Stop application:         docker-compose -f docker-compose.ec2.yml down"
echo "   Restart:                  docker-compose -f docker-compose.ec2.yml restart"
echo

echo "🗄️ RDS Connections:"
echo "   MySQL Endpoint:           $MYSQL_RDS_ENDPOINT"
echo "   PostgreSQL Endpoint:      $POSTGRES_RDS_ENDPOINT"
echo

print_status "✨ Your Notes App is ready for AWS Load Balancer! ✨"
print_info "Make sure your ALB target group points to port 3000 (frontend) or 3001 (API)" 
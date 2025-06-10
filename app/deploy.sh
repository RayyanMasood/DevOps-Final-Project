#!/bin/bash

# Notes App Deployment Script
# This script builds and deploys the multi-container Notes application

set -e

echo "🚀 Starting Notes App Deployment..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose and try again."
    exit 1
fi

print_status "Checking for port conflicts..."

# Function to check if port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check required ports
ports=(80 3000 3001 3306 5432)
conflicts=false

for port in "${ports[@]}"; do
    if check_port $port; then
        print_warning "Port $port is already in use"
        conflicts=true
    fi
done

if [ "$conflicts" = true ]; then
    echo
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Deployment cancelled due to port conflicts."
        exit 1
    fi
fi

print_status "Stopping any existing containers..."
docker-compose down 2>/dev/null || true

print_status "Building Docker images..."
docker-compose build --no-cache

print_status "Starting services..."
docker-compose up -d

print_status "Waiting for services to be healthy..."

# Wait for services to be ready
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    healthy_services=0
    
    # Check MySQL
    if docker-compose exec -T mysql mysqladmin ping -h localhost --silent 2>/dev/null; then
        ((healthy_services++))
    fi
    
    # Check PostgreSQL
    if docker-compose exec -T postgres pg_isready -U notes_user 2>/dev/null; then
        ((healthy_services++))
    fi
    
    # Check Backend
    if curl -f -s http://localhost:3001/health >/dev/null 2>&1; then
        ((healthy_services++))
    fi
    
    # Check Frontend
    if curl -f -s http://localhost:3000/health >/dev/null 2>&1; then
        ((healthy_services++))
    fi
    
    # Check Load Balancer
    if curl -f -s http://localhost/health >/dev/null 2>&1; then
        ((healthy_services++))
    fi
    
    if [ $healthy_services -eq 5 ]; then
        break
    fi
    
    echo -n "."
    sleep 2
    ((attempt++))
done

echo

if [ $healthy_services -eq 5 ]; then
    print_status "All services are healthy!"
else
    print_warning "Some services may not be fully ready yet. Check logs if needed."
fi

print_status "Deployment completed!"

echo
echo "📱 Application URLs:"
echo "   Frontend (Load Balanced): http://localhost"
echo "   Frontend (Direct):        http://localhost:3000"
echo "   Backend API:              http://localhost:3001"
echo "   Load Balancer Health:     http://localhost/health"
echo

echo "🔧 Management Commands:"
echo "   View logs:                docker-compose logs -f"
echo "   Check status:             docker-compose ps"
echo "   Stop application:         docker-compose down"
echo "   Reset everything:         docker-compose down -v"
echo

echo "🗄️ Database Access:"
echo "   MySQL:                    docker-compose exec mysql mysql -u notes_user -p"
echo "   PostgreSQL:               docker-compose exec postgres psql -U notes_user -d notes_db"
echo

print_status "Enjoy your Notes App! 📝" 
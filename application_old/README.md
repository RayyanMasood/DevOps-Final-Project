# DevOps Final Project - Real-time Dashboard Application

A complete full-stack application demonstrating modern DevOps practices with real-time data visualization, multi-database connectivity, and containerized deployment.

## 🏗️ Architecture Overview

This application showcases a production-ready DevOps infrastructure including:

- **Frontend**: React.js dashboard with real-time updates via WebSockets
- **Backend**: Node.js/Express.js API with dual database connectivity
- **Databases**: MySQL (transactional data) + PostgreSQL (analytics data)
- **Caching**: Redis for session management and caching
- **Infrastructure**: Terraform-managed AWS resources
- **Deployment**: Multi-stage Docker containers with Docker Compose
- **Monitoring**: Real-time metrics, health checks, and system monitoring

## 📊 Features

### Real-time Dashboard
- Live KPI monitoring with animated counters
- Interactive charts (Line, Area, Bar, Pie) using Recharts
- Real-time system metrics and performance monitoring
- WebSocket-powered live data updates
- Responsive design for desktop, tablet, and mobile

### Backend API
- RESTful API with comprehensive CRUD operations
- Dual database connectivity (MySQL + PostgreSQL)
- Real-time data generation and broadcasting
- Health monitoring and metrics collection
- Error handling and logging with Winston
- Input validation and security middleware

### Database Design
- **MySQL**: User management, orders, products, inventory
- **PostgreSQL**: Analytics events, performance metrics, system health
- Database migrations and seed data
- Stored procedures and optimized queries
- Data archiving and cleanup procedures

### DevOps Infrastructure
- **Terraform**: Complete AWS infrastructure as code
- **Docker**: Multi-stage builds for optimized containers
- **Monitoring**: CloudWatch integration and custom dashboards
- **Security**: VPC, security groups, encrypted databases
- **Scalability**: Auto Scaling Groups and Load Balancers

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose
- Node.js 18+ (for local development)
- Git

### Local Development Setup

1. **Clone the repository:**
```bash
git clone <repository-url>
cd devops-final-project/application
```

2. **Start with Docker Compose:**
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

3. **Access the application:**
- Frontend: http://localhost:3000
- Backend API: http://localhost:3001
- Database Admin: http://localhost:8080
- MailHog (email testing): http://localhost:8025

### Production Deployment

#### AWS Deployment with Terraform

1. **Deploy infrastructure:**
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

2. **Deploy application to EC2:**
```bash
cd application
# Copy deployment script to EC2 instance
scp scripts/deploy-to-ec2.sh ec2-user@<instance-ip>:~/
ssh ec2-user@<instance-ip>
chmod +x deploy-to-ec2.sh
./deploy-to-ec2.sh
```

#### Manual EC2 Deployment

```bash
# Run the deployment script
chmod +x scripts/deploy-to-ec2.sh
./scripts/deploy-to-ec2.sh
```

## 📁 Project Structure

```
application/
├── backend/                    # Node.js backend application
│   ├── src/
│   │   ├── server.js          # Main server file
│   │   ├── models/            # Database models (Sequelize)
│   │   ├── routes/            # API routes
│   │   ├── middleware/        # Express middleware
│   │   ├── services/          # Business logic services
│   │   └── utils/             # Utility functions
│   ├── Dockerfile             # Multi-stage Docker build
│   └── package.json           # Dependencies and scripts
├── frontend/                   # React.js frontend application
│   ├── src/
│   │   ├── App.js             # Main application component
│   │   ├── components/        # React components
│   │   └── services/          # API and WebSocket services
│   ├── Dockerfile             # Multi-stage Docker build
│   └── package.json           # Dependencies and scripts
├── database/                   # Database initialization
│   ├── mysql/                 # MySQL schema and seed data
│   └── postgresql/            # PostgreSQL schema and seed data
├── scripts/                    # Deployment and management scripts
├── docker-compose.yml         # Development environment
└── README.md                  # This file
```

## 🛠️ Development

### Backend Development

```bash
cd backend
npm install
npm run dev                    # Start with nodemon
npm test                       # Run tests
npm run lint                   # Lint code
```

### Frontend Development

```bash
cd frontend
npm install
npm start                      # Start development server
npm test                       # Run tests
npm run build                  # Build for production
```

### Database Management

```bash
# Connect to MySQL
docker exec -it devops-mysql mysql -u app_user -p devops_app

# Connect to PostgreSQL
docker exec -it devops-postgresql psql -U analytics_user -d devops_analytics

# View database admin interface
open http://localhost:8080
```

## 📊 API Documentation

### Health Endpoints
- `GET /api/health` - Basic health check
- `GET /api/health/detailed` - Detailed system health
- `GET /api/health/database` - Database connectivity status

### Dashboard Endpoints
- `GET /api/dashboard` - Main dashboard data
- `GET /api/dashboard/kpis` - Key performance indicators
- `GET /api/dashboard/real-time` - Real-time metrics

### Data Management
- `GET /api/users` - User management
- `GET /api/orders` - Order management
- `GET /api/products` - Product catalog
- `POST /api/analytics/events` - Track analytics events
- `POST /api/metrics` - Submit performance metrics

### WebSocket Events
- `join-room` - Join real-time data room
- `dashboard-update` - Receive dashboard updates
- `metrics-update` - Receive system metrics
- `analytics-event` - Receive analytics events

## 🔧 Configuration

### Environment Variables

#### Backend Configuration
```bash
# Database Configuration
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_DATABASE=devops_app
MYSQL_USER=app_user
MYSQL_PASSWORD=your_password

POSTGRESQL_HOST=localhost
POSTGRESQL_PORT=5432
POSTGRESQL_DATABASE=devops_analytics
POSTGRESQL_USER=analytics_user
POSTGRESQL_PASSWORD=your_password

# Application Configuration
NODE_ENV=development
PORT=3001
LOG_LEVEL=debug

# Security
JWT_SECRET=your_jwt_secret
SESSION_SECRET=your_session_secret
CORS_ORIGIN=http://localhost:3000
```

#### Frontend Configuration
```bash
REACT_APP_API_URL=http://localhost:3001/api
REACT_APP_WEBSOCKET_URL=ws://localhost:3001
```

### Docker Configuration

#### Development
```bash
docker-compose up -d
```

#### Production
```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## 📈 Monitoring & Logging

### Application Monitoring
- Real-time system metrics (CPU, Memory, Disk)
- Application performance metrics (Response time, Throughput)
- Error tracking and alerting
- Database performance monitoring

### Health Checks
- Container health checks
- Database connectivity checks
- External service availability
- Automated recovery procedures

### Logging
- Structured logging with Winston
- Log rotation and archival
- Error tracking and alerting
- Performance monitoring

## 🔐 Security

### Security Features
- Input validation and sanitization
- SQL injection prevention
- XSS protection
- CORS configuration
- Rate limiting
- Authentication and authorization
- Encrypted database connections

### Security Best Practices
- Non-root container execution
- Minimal container images
- Secret management
- Network segmentation
- Regular security updates

## 🧪 Testing

### Backend Testing
```bash
cd backend
npm test                       # Run all tests
npm run test:unit             # Unit tests
npm run test:integration      # Integration tests
npm run test:coverage         # Coverage report
```

### Frontend Testing
```bash
cd frontend
npm test                      # Run tests
npm test -- --coverage       # Coverage report
npm run test:e2e             # End-to-end tests
```

### Load Testing
```bash
# API load testing with Artillery
npm install -g artillery
artillery quick --count 100 --num 10 http://localhost:3001/api/health
```

## 📊 Performance Optimization

### Backend Optimizations
- Database connection pooling
- Query optimization and indexing
- Redis caching layer
- Response compression
- API rate limiting

### Frontend Optimizations
- Code splitting and lazy loading
- Image optimization
- Bundle size optimization
- CDN integration
- Service worker caching

### Database Optimizations
- Proper indexing strategy
- Query optimization
- Connection pooling
- Read replicas (PostgreSQL)
- Automated cleanup procedures

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow
```yaml
# .github/workflows/deploy.yml
name: Deploy to AWS
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy Infrastructure
        run: |
          cd terraform
          terraform init
          terraform apply -auto-approve
      - name: Deploy Application
        run: |
          # Deploy to EC2 instances
```

### Deployment Strategies
- Blue-green deployments
- Rolling updates
- Automated rollback procedures
- Database migration handling

## 🛠️ Troubleshooting

### Common Issues

#### Database Connection Issues
```bash
# Check database status
docker-compose ps
docker-compose logs mysql
docker-compose logs postgresql

# Reset databases
docker-compose down -v
docker-compose up -d
```

#### Frontend Not Loading
```bash
# Check frontend build
docker-compose logs frontend
npm run build

# Check API connectivity
curl http://localhost:3001/api/health
```

#### WebSocket Connection Issues
```bash
# Check backend WebSocket server
docker-compose logs backend
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: test" \
  -H "Sec-WebSocket-Version: 13" \
  http://localhost:3001/socket.io/
```

### Performance Issues
```bash
# Monitor resource usage
docker stats

# Check application metrics
curl http://localhost:3001/api/health/detailed

# Database performance
docker exec devops-mysql mysql -e "SHOW PROCESSLIST;"
```

## 📚 Additional Resources

### Documentation
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Docker Best Practices](https://docs.docker.com/develop/best-practices/)
- [React.js Documentation](https://reactjs.org/docs)
- [Node.js Best Practices](https://github.com/goldbergyoni/nodebestpractices)

### Learning Resources
- [DevOps Roadmap](https://roadmap.sh/devops)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Container Security Best Practices](https://www.cisa.gov/uscert/ncas/current-activity/2021/04/28/cisa-and-nsa-release-kubernetes-hardening-guidance)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- **Your Name** - *Initial work* - [YourGitHub](https://github.com/yourusername)

## 🙏 Acknowledgments

- AWS for cloud infrastructure services
- Docker for containerization platform
- React and Node.js communities
- Open source contributors

---

**Note**: This is a demonstration project for educational purposes. For production use, ensure proper security measures, monitoring, and backup procedures are in place.

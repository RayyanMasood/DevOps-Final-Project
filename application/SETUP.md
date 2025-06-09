# DevOps Dashboard - Setup Guide

This document provides step-by-step instructions to set up and run the modernized DevOps Dashboard application.

## 🏗️ What Was Built

### Architecture Overview
- **Backend**: Node.js + TypeScript + Express + Prisma ORM + PostgreSQL
- **Frontend**: React 18 + TypeScript + Vite + Tailwind CSS + TanStack Query
- **Database**: PostgreSQL 16 with Redis for caching
- **Infrastructure**: Docker Compose for development, production-ready configurations
- **Features**: Real-time WebSocket updates, modern UI, comprehensive monitoring

### Key Improvements Over Original
1. **Modern Tech Stack**: 
   - Replaced old dependencies with latest versions
   - TypeScript throughout for type safety
   - Vite instead of Create React App for faster builds
   - Prisma ORM for type-safe database operations

2. **Enhanced DevOps**:
   - Multi-stage Docker builds for optimization
   - Health checks for all services
   - Comprehensive logging and monitoring
   - Environment-based configuration

3. **Better Developer Experience**:
   - Hot reload for both frontend and backend
   - Comprehensive linting and formatting
   - Type safety across the entire stack
   - Modern development tools

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose (recommended)
- Node.js 20+ LTS (for local development)
- Git

### Option 1: Docker Compose (Recommended)

1. **Clone and navigate to the application directory:**
```bash
cd application
```

2. **Start all services:**
```bash
# Copy environment file
cp env.example .env

# Start all services in development mode
docker-compose up -d

# View logs
docker-compose logs -f
```

3. **Access the application:**
- Frontend: http://localhost:3000
- Backend API: http://localhost:3001/api
- Database Admin: http://localhost:8080
- Redis Commander: http://localhost:8081

### Option 2: Local Development

1. **Backend setup:**
```bash
cd backend

# Install dependencies
npm install

# Generate Prisma client
npm run db:generate

# Run database migrations (ensure PostgreSQL is running)
npm run db:migrate

# Start development server
npm run dev
```

2. **Frontend setup:**
```bash
cd frontend

# Install dependencies
npm install

# Start development server
npm run dev
```

3. **Database setup:**
Ensure PostgreSQL is running locally or use Docker:
```bash
docker run -d --name postgres \
  -e POSTGRES_DB=devops_dashboard \
  -e POSTGRES_USER=devops_user \
  -e POSTGRES_PASSWORD=devops_password \
  -p 5432:5432 \
  postgres:16-alpine
```

## 📁 Project Structure

```
application/
├── backend/                    # Node.js TypeScript backend
│   ├── src/
│   │   ├── server.ts          # Main server entry point
│   │   ├── database/          # Database connection & utilities
│   │   ├── routes/            # API route handlers
│   │   ├── services/          # Business logic services
│   │   ├── middleware/        # Express middleware
│   │   ├── utils/             # Utility functions
│   │   └── types/             # TypeScript type definitions
│   ├── prisma/                # Database schema and migrations
│   │   └── schema.prisma      # Prisma schema definition
│   ├── Dockerfile             # Multi-stage Docker build
│   ├── package.json           # Dependencies and scripts
│   └── tsconfig.json          # TypeScript configuration
├── frontend/                   # React TypeScript frontend
│   ├── src/
│   │   ├── App.tsx            # Main application component
│   │   ├── main.tsx           # React entry point
│   │   ├── components/        # React components
│   │   ├── hooks/             # Custom React hooks
│   │   ├── services/          # API and WebSocket services
│   │   ├── utils/             # Utility functions
│   │   ├── types/             # TypeScript types
│   │   └── stores/            # State management
│   ├── public/                # Static assets
│   ├── Dockerfile             # Multi-stage Docker build
│   ├── package.json           # Dependencies and scripts
│   ├── vite.config.ts         # Vite configuration
│   ├── tailwind.config.js     # Tailwind CSS configuration
│   └── tsconfig.json          # TypeScript configuration
├── database/                   # Database configuration
│   ├── init/                  # Database initialization scripts
│   └── redis.conf             # Redis configuration
├── docker-compose.yml         # Development environment
├── docker-compose.prod.yml    # Production environment
├── env.example                # Environment variables template
└── README.md                  # Project documentation
```

## ⚙️ Configuration

### Environment Variables

Copy `env.example` to `.env` and update the values:

```bash
# Database
DATABASE_URL="postgresql://devops_user:devops_password@localhost:5432/devops_dashboard"

# Redis
REDIS_URL="redis://localhost:6379"

# Authentication
JWT_SECRET="your-super-secret-jwt-key-change-in-production"
JWT_EXPIRES_IN="7d"

# Application
NODE_ENV="development"
PORT=3001
CORS_ORIGIN="http://localhost:3000"

# Features
ENABLE_REAL_TIME=true
ENABLE_METRICS=true
ENABLE_WEBSOCKET=true
```

## 🛠️ Development Commands

### Backend Commands
```bash
cd backend

# Development
npm run dev              # Start with hot reload
npm run build           # Build TypeScript
npm run start           # Start production server

# Database
npm run db:generate     # Generate Prisma client
npm run db:migrate      # Run migrations
npm run db:seed         # Seed database
npm run db:studio       # Open Prisma Studio

# Testing & Quality
npm run test            # Run tests
npm run lint            # Lint code
npm run type-check      # Type checking
```

### Frontend Commands
```bash
cd frontend

# Development
npm run dev             # Start development server
npm run build           # Build for production
npm run preview         # Preview production build

# Testing & Quality
npm run test            # Run tests with Vitest
npm run lint            # Lint code
npm run type-check      # Type checking
npm run format          # Format code
```

### Docker Commands
```bash
# Development
docker-compose up -d              # Start all services
docker-compose logs -f            # View logs
docker-compose down               # Stop all services

# Production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Individual services
docker-compose up postgres redis  # Start only database services
```

## 🧪 Testing

### Running Tests
```bash
# Backend tests
cd backend && npm test

# Frontend tests
cd frontend && npm test

# With coverage
npm run test:coverage
```

## 🚀 Production Deployment

### Build Production Images
```bash
# Build all production images
docker-compose -f docker-compose.prod.yml build

# Deploy to production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Environment Setup
1. Set production environment variables
2. Configure secrets for JWT and database passwords
3. Set up SSL certificates for HTTPS
4. Configure monitoring and logging

## 🔍 Monitoring & Health Checks

### Health Endpoints
- `GET /api/health` - Basic health check
- `GET /api/health/detailed` - Detailed system status

### Available Services
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:3001/api
- **Database Admin (Adminer)**: http://localhost:8080
- **Redis Commander**: http://localhost:8081

### Logs
```bash
# View all logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f postgres
```

## 🔧 Troubleshooting

### Common Issues

1. **Port conflicts**: Ensure ports 3000, 3001, 5432, 6379, 8080, 8081 are available
2. **Database connection**: Check PostgreSQL is running and credentials are correct
3. **Dependencies**: Run `npm install` in both backend and frontend directories
4. **Environment variables**: Ensure `.env` file exists with correct values

### Reset Everything
```bash
# Stop all services and remove volumes
docker-compose down -v

# Remove all containers and images
docker system prune -a

# Start fresh
docker-compose up -d --build
```

## 📈 Next Steps

### Features to Implement
1. **Authentication System**: JWT-based user authentication
2. **Real-time Dashboard**: WebSocket-powered live updates
3. **Monitoring Widgets**: KPI cards, charts, and metrics
4. **Event Management**: System events and alerting
5. **User Management**: Role-based access control
6. **API Documentation**: Swagger/OpenAPI integration

### Infrastructure Enhancements
1. **CI/CD Pipeline**: GitHub Actions or GitLab CI
2. **Kubernetes Deployment**: Helm charts and manifests
3. **Monitoring Stack**: Prometheus, Grafana, ELK stack
4. **Security Hardening**: Security scanning, secrets management
5. **Performance Optimization**: Caching strategies, CDN setup

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes and test thoroughly
4. Commit with descriptive messages
5. Push to your fork and submit a pull request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details. 
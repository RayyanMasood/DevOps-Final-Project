# DevOps Real-time Dashboard Application

A modern full-stack application showcasing DevOps best practices with real-time data visualization, multi-database connectivity, and containerized deployment.

## 🏗️ Architecture Overview

This modernized application demonstrates production-ready DevOps infrastructure with:

- **Frontend**: React 18 with TypeScript, Vite for fast builds, TanStack Query for state management
- **Backend**: Node.js/Express with TypeScript, Prisma ORM, WebSocket support
- **Databases**: PostgreSQL (primary) + Redis (caching/sessions)
- **Infrastructure**: Docker Compose for local development, production-ready configurations
- **Monitoring**: Real-time metrics, health checks, and comprehensive logging
- **Security**: JWT authentication, input validation, rate limiting, CORS protection

## 🚀 Features

### Modern Frontend Dashboard
- ⚡ Built with React 18 + TypeScript + Vite
- 📊 Interactive charts using Recharts with real-time updates
- 🎨 Modern UI with Tailwind CSS and Radix UI components
- 📱 Fully responsive design
- 🔄 Real-time WebSocket connections
- 📈 Live KPI monitoring with animated counters
- ⚡ Optimized performance with React Query caching

### Robust Backend API
- 🟢 Node.js + Express + TypeScript
- 🗃️ Prisma ORM with PostgreSQL
- 🔄 Real-time WebSocket support with Socket.IO
- 🔐 JWT authentication and authorization
- 📝 Comprehensive logging with Winston
- 🛡️ Security middleware (helmet, rate limiting)
- ✅ Input validation with Zod
- 🔍 Health monitoring endpoints

### DevOps Infrastructure
- 🐳 Multi-stage Docker builds for optimization
- 🔧 Docker Compose for development and production
- 📊 PostgreSQL with optimized configurations
- ⚡ Redis for caching and session management
- 🏥 Health checks for all services
- 📈 Metrics collection and monitoring
- 🔒 Environment-based configuration management

## 🛠️ Quick Start

### Prerequisites
- Node.js 20+ (LTS recommended)
- Docker and Docker Compose
- Git

### Local Development

1. **Clone and setup:**
```bash
git clone <repository-url>
cd application
```

2. **Start with Docker Compose:**
```bash
# Start all services in development mode
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
- Redis Commander: http://localhost:8081

### Manual Development Setup

1. **Setup environment:**
```bash
cp .env.example .env
# Edit .env with your configurations
```

2. **Backend setup:**
```bash
cd backend
npm install
npm run db:generate
npm run db:migrate
npm run db:seed
npm run dev
```

3. **Frontend setup:**
```bash
cd frontend
npm install
npm run dev
```

## 📁 Project Structure

```
application/
├── backend/                    # Node.js TypeScript backend
│   ├── src/
│   │   ├── server.ts          # Main server file
│   │   ├── routes/            # API routes
│   │   ├── services/          # Business logic
│   │   ├── middleware/        # Express middleware
│   │   ├── utils/             # Utility functions
│   │   └── types/             # TypeScript type definitions
│   ├── prisma/                # Database schema and migrations
│   ├── Dockerfile             # Multi-stage Docker build
│   └── package.json           # Dependencies and scripts
├── frontend/                   # React TypeScript frontend
│   ├── src/
│   │   ├── App.tsx            # Main application component
│   │   ├── components/        # React components
│   │   ├── hooks/             # Custom React hooks
│   │   ├── services/          # API and WebSocket services
│   │   ├── utils/             # Utility functions
│   │   └── types/             # TypeScript types
│   ├── vite.config.ts         # Vite configuration
│   ├── Dockerfile             # Multi-stage Docker build
│   └── package.json           # Dependencies and scripts
├── docker-compose.yml         # Development environment
├── docker-compose.prod.yml    # Production environment
├── .env.example               # Environment variables template
└── README.md                  # This file
```

## 🔧 Technology Stack

### Backend
- **Runtime**: Node.js 20 LTS
- **Framework**: Express.js with TypeScript
- **Database**: PostgreSQL 16 with Prisma ORM
- **Cache**: Redis 7
- **WebSockets**: Socket.IO
- **Authentication**: JWT with bcrypt
- **Validation**: Zod
- **Logging**: Winston
- **Testing**: Jest with Supertest

### Frontend
- **Framework**: React 18 with TypeScript
- **Build Tool**: Vite
- **Styling**: Tailwind CSS
- **UI Components**: Radix UI primitives
- **Charts**: Recharts
- **State Management**: TanStack Query (React Query)
- **Routing**: React Router DOM
- **WebSocket**: Socket.IO client
- **Testing**: Vitest with React Testing Library

### DevOps
- **Containerization**: Docker with multi-stage builds
- **Orchestration**: Docker Compose
- **Database**: PostgreSQL 16 Alpine
- **Cache**: Redis 7 Alpine
- **Monitoring**: Health checks and metrics
- **Security**: Environment-based secrets management

## 🔌 API Endpoints

### Health & System
- `GET /api/health` - Basic health check
- `GET /api/health/detailed` - Detailed system status
- `GET /api/metrics` - System metrics

### Authentication
- `POST /api/auth/login` - User login
- `POST /api/auth/register` - User registration
- `POST /api/auth/refresh` - Refresh JWT token
- `POST /api/auth/logout` - User logout

### Dashboard
- `GET /api/dashboard` - Dashboard overview data
- `GET /api/dashboard/kpis` - Key performance indicators
- `GET /api/dashboard/metrics` - Real-time metrics

### WebSocket Events
- `connection` - Client connection
- `join-dashboard` - Join dashboard updates
- `dashboard-update` - Real-time dashboard data
- `metrics-update` - System metrics update

## ⚙️ Configuration

### Environment Variables

```bash
# Database
DATABASE_URL="postgresql://username:password@localhost:5432/devops_dashboard"

# Redis
REDIS_URL="redis://localhost:6379"

# Authentication
JWT_SECRET="your-super-secret-jwt-key"
JWT_EXPIRES_IN="7d"

# Application
NODE_ENV="development"
PORT=3001
CORS_ORIGIN="http://localhost:3000"

# Logging
LOG_LEVEL="debug"

# Features
ENABLE_REAL_TIME=true
ENABLE_METRICS=true
```

## 🧪 Testing

```bash
# Backend tests
cd backend
npm test
npm run test:watch
npm run test:coverage

# Frontend tests
cd frontend
npm test
npm run test:coverage
```

## 🚀 Production Deployment

### Docker Production Build
```bash
# Build production images
docker-compose -f docker-compose.prod.yml build

# Run in production mode
docker-compose -f docker-compose.prod.yml up -d
```

### Performance Optimizations
- Multi-stage Docker builds for minimal image sizes
- PostgreSQL connection pooling
- Redis caching strategies
- Frontend code splitting and lazy loading
- Gzip compression for static assets

## 📊 Monitoring & Observability

- Health check endpoints for all services
- Structured logging with Winston
- Real-time metrics collection
- Database query performance monitoring
- WebSocket connection monitoring

## 🔒 Security Features

- JWT-based authentication
- Password hashing with bcrypt
- Rate limiting on API endpoints
- CORS protection
- Input validation with Zod
- SQL injection prevention with Prisma
- Security headers with Helmet

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Commit changes: `git commit -am 'Add feature'`
4. Push to branch: `git push origin feature-name`
5. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built with modern DevOps practices
- Inspired by real-world production applications
- Designed for scalability and maintainability 
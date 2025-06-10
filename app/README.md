# Notes App - Dockerized Multi-Database Application

A simple note-taking application built with React frontend, Node.js backend, and supporting both MySQL and PostgreSQL databases. This application demonstrates multi-stage Docker deployment with load balancing.

## Features

- ✅ **Modern React Frontend** - Beautiful, responsive UI with modern design
- ✅ **Node.js Backend API** - RESTful API without Prisma dependency
- ✅ **Dual Database Support** - Works with both MySQL and PostgreSQL
- ✅ **Multi-stage Dockerfiles** - Optimized production builds
- ✅ **Load Balancer** - Nginx reverse proxy for high availability
- ✅ **Health Checks** - Comprehensive container health monitoring
- ✅ **CRUD Operations** - Create, Read, Update, Delete notes
- ✅ **Database Selection** - Choose which database to save notes to

## Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │    │    Frontend     │
│    (nginx:80)   │◄──►│   (React:3000)  │
└─────────────────┘    └─────────────────┘
         │                       │
         │              ┌─────────────────┐
         └─────────────►│    Backend      │
                        │  (Node.js:3001) │
                        └─────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
            ┌─────────────────┐    ┌─────────────────┐
            │     MySQL       │    │   PostgreSQL    │
            │   (Port 3306)   │    │   (Port 5432)   │
            └─────────────────┘    └─────────────────┘
```

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Ports 80, 3000, 3001, 3306, 5432 available

### 1. Clone and Navigate

```bash
cd app
```

### 2. Build and Run

```bash
# Build and start all services
docker-compose up --build

# Or run in detached mode
docker-compose up -d --build
```

### 3. Access Application

- **Frontend (via Load Balancer)**: http://localhost
- **Frontend (Direct)**: http://localhost:3000
- **Backend API**: http://localhost:3001
- **Load Balancer Health**: http://localhost/health

### 4. Stop Application

```bash
docker-compose down

# Remove volumes (database data)
docker-compose down -v
```

## API Endpoints

### Notes API

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/notes` | Get all notes from both databases |
| GET | `/api/notes/:id?db=mysql` | Get specific note by ID and database |
| POST | `/api/notes` | Create new note |
| PUT | `/api/notes/:id?db=postgres` | Update note by ID and database |
| DELETE | `/api/notes/:id?db=mysql` | Delete note by ID and database |

### Health Checks

| Service | Endpoint | Description |
|---------|----------|-------------|
| Backend | `/health` | Backend service health |
| Frontend | `/health` | Frontend service health |
| Load Balancer | `/health` | Load balancer health |

## Database Configuration

### MySQL
- **Host**: mysql (container) / localhost (external)
- **Port**: 3306
- **Database**: notes_db
- **User**: notes_user
- **Password**: notes_password

### PostgreSQL
- **Host**: postgres (container) / localhost (external)
- **Port**: 5432
- **Database**: notes_db
- **User**: notes_user
- **Password**: notes_password

## Development

### Local Development Setup

1. **Backend Development**:
```bash
cd backend
npm install
npm run dev
```

2. **Frontend Development**:
```bash
cd frontend
npm install
npm start
```

### Environment Variables

Copy `env.example` to `.env` and modify as needed:

```bash
cp env.example .env
```

## Docker Images

### Multi-stage Builds

Both frontend and backend use multi-stage Dockerfiles for optimization:

- **Frontend**: Node.js build → Nginx production
- **Backend**: Node.js dependencies → Production runtime

### Image Sizes (Approximate)

- Frontend: ~50MB (nginx + built React app)
- Backend: ~200MB (Node.js + dependencies)

## Deployment for EC2

### For AWS EC2 Deployment:

1. **Update Load Balancer Configuration**:
   - Modify `nginx/conf.d/default.conf`
   - Set proper server names and SSL certificates

2. **Environment Variables**:
   - Update database hosts to EC2 internal IPs
   - Configure proper networking

3. **Security Groups**:
   - Port 80/443 for Load Balancer
   - Port 3000 for Frontend
   - Port 3001 for Backend
   - Ports 3306/5432 for databases (internal only)

### Production Deployment Commands

```bash
# Production build and deployment
docker-compose -f docker-compose.yml up -d --build

# View logs
docker-compose logs -f

# Scale services
docker-compose up --scale backend=2 --scale frontend=2
```

## Monitoring

### Container Health Status

```bash
# Check container health
docker-compose ps

# View logs
docker-compose logs [service-name]

# Execute commands in containers
docker-compose exec backend sh
docker-compose exec mysql mysql -u notes_user -p notes_db
```

### Database Access

```bash
# MySQL
docker-compose exec mysql mysql -u notes_user -p

# PostgreSQL
docker-compose exec postgres psql -U notes_user -d notes_db
```

## Troubleshooting

### Common Issues

1. **Port Conflicts**:
   - Ensure ports 80, 3000, 3001, 3306, 5432 are available
   - Modify docker-compose.yml port mappings if needed

2. **Database Connection Issues**:
   - Wait for database health checks to pass
   - Check logs: `docker-compose logs mysql` or `docker-compose logs postgres`

3. **Frontend API Connection**:
   - Verify `REACT_APP_API_URL` environment variable
   - Check backend health: http://localhost:3001/health

### Reset Everything

```bash
# Stop and remove everything
docker-compose down -v --rmi all

# Rebuild from scratch
docker-compose up --build
```

## Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## License

MIT License - see LICENSE file for details. 
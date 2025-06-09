# Database Setup Instructions

## Quick Setup

1. **Start the services:**
   ```bash
   cd application
   docker-compose up -d
   ```

2. **Set up PostgreSQL (Prisma):**
   ```bash
   # Push schema to PostgreSQL
   docker-compose exec backend npx prisma db push
   
   # Generate Prisma client
   docker-compose exec backend npx prisma generate
   ```

3. **Test the endpoints:**
   ```bash
   # Test notes health check
   curl http://localhost:3001/api/notes/health
   
   # Test notes API
   curl http://localhost:3001/api/notes
   ```

4. **Create a sample note via API:**
   ```bash
   curl -X POST http://localhost:3001/api/notes \
     -H "Content-Type: application/json" \
     -d '{
       "title": "My First Note",
       "content": "This is a test note from the API",
       "tags": ["test", "api"],
       "isPublic": true,
       "database": "postgresql"
     }'
   ```

## Troubleshooting

- If backend fails to start, check logs: `docker-compose logs backend`
- If database connection fails, restart services: `docker-compose restart`
- If Prisma client errors occur, regenerate: `docker-compose exec backend npx prisma generate`

## Access Points

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:3001
- **Notes API**: http://localhost:3001/api/notes
- **Adminer (DB Admin)**: http://localhost:8080
- **Redis Commander**: http://localhost:8081 
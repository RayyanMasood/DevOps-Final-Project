import { Router, Request, Response } from 'express';
import { db } from '../database/connection';
// import { testMySQLConnection } from '../database/mysql'; // Temporarily disabled

const router = Router();

router.get('/', (req: Request, res: Response) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
  });
});

router.get('/detailed', async (req: Request, res: Response) => {
  try {
    // Test PostgreSQL connection
    const postgresHealthy = await db.checkConnection();
    
    // Test MySQL connection - temporarily disabled
    const mysqlHealthy = false; // await testMySQLConnection();

    const health = {
      status: 'OK',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: process.env.NODE_ENV || 'development',
      memory: process.memoryUsage(),
      version: process.version,
      databases: {
        postgresql: {
          status: postgresHealthy ? 'healthy' : 'unhealthy',
          connected: postgresHealthy
        },
        mysql: {
          status: mysqlHealthy ? 'healthy' : 'unhealthy', 
          connected: mysqlHealthy
        }
      }
    };

    res.json(health);
  } catch (error) {
    res.status(500).json({
      status: 'ERROR',
      timestamp: new Date().toISOString(),
      error: 'Health check failed'
    });
  }
});

export default router; 
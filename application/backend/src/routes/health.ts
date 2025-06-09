import { Router, Request, Response } from 'express';
import { db } from '../database/connection';
// import { testMySQLConnection } from '../database/mysql'; // Using dynamic import in notes route

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
    
    // Test MySQL connection with dynamic import
    let mysqlHealthy = false;
    try {
      const mysql = require('mysql2');
      const mysqlConn = mysql.createConnection({
        host: process.env.MYSQL_HOST || 'mysql',
        port: parseInt(process.env.MYSQL_PORT || '3306'),
        user: process.env.MYSQL_USER || 'devops_user',
        password: process.env.MYSQL_PASSWORD || 'devops_password',
        database: process.env.MYSQL_DATABASE || 'devops_dashboard',
      });
      
      mysqlHealthy = await new Promise((resolve) => {
        mysqlConn.ping((err: any) => {
          mysqlConn.end();
          resolve(!err);
        });
      });
    } catch (error) {
      mysqlHealthy = false;
    }

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
import { PrismaClient } from '@prisma/client';
import { logger } from '../utils/logger';

// Extend PrismaClient with custom methods if needed
export class DatabaseClient extends PrismaClient {
  constructor() {
    super({
      errorFormat: 'pretty',
    });
  }

  // Custom method to check database connection
  async checkConnection(): Promise<boolean> {
    try {
      await this.$queryRaw`SELECT 1`;
      return true;
    } catch (error) {
      logger.error('Database connection check failed', { error });
      return false;
    }
  }

  // Custom method to get database statistics
  async getDatabaseStats() {
    try {
      const userCount = await this.user.count();
      const dashboardCount = await this.dashboard.count();
      const kpiCount = await this.kPI.count();
      const eventCount = await this.event.count();
      const sessionCount = await this.session.count();

      return {
        users: userCount,
        dashboards: dashboardCount,
        kpis: kpiCount,
        events: eventCount,
        activeSessions: sessionCount,
      };
    } catch (error) {
      logger.error('Failed to get database statistics', { error });
      throw error;
    }
  }

  // Graceful shutdown
  async gracefulShutdown(): Promise<void> {
    try {
      await this.$disconnect();
      logger.info('Database connection closed gracefully');
    } catch (error) {
      logger.error('Error during database shutdown', { error });
    }
  }
}

// Create singleton instance
export const db = new DatabaseClient();

// Connection management
export async function connectDatabase(): Promise<void> {
  try {
    // Test the connection
    await db.$connect();
    
    // Verify with a simple query
    const isConnected = await db.checkConnection();
    
    if (!isConnected) {
      throw new Error('Database connection verification failed');
    }

    logger.info('Database connected successfully');
    
    // Log database statistics in development
    if (process.env.NODE_ENV === 'development') {
      try {
        const stats = await db.getDatabaseStats();
        logger.info('Database statistics', stats);
      } catch (error) {
        logger.warn('Could not retrieve database statistics', { error });
      }
    }

  } catch (error) {
    logger.error('Failed to connect to database', { error });
    throw error;
  }
}

// Graceful disconnection
export async function disconnectDatabase(): Promise<void> {
  await db.gracefulShutdown();
}

// Handle application shutdown
process.on('SIGINT', disconnectDatabase);
process.on('SIGTERM', disconnectDatabase);
process.on('beforeExit', disconnectDatabase); 
import mysql from 'mysql2';
import { logger } from '../utils/logger';

let mysqlConnection: mysql.Connection | null = null;

export const initializeMySQLConnection = async (): Promise<void> => {
  try {
    const connection = mysql.createConnection({
      host: process.env.MYSQL_HOST || 'mysql',
      port: parseInt(process.env.MYSQL_PORT || '3306'),
      user: process.env.MYSQL_USER || 'devops_user',
      password: process.env.MYSQL_PASSWORD || 'devops_password',
      database: process.env.MYSQL_DATABASE || 'devops_dashboard',
      connectTimeout: 60000,
      acquireTimeout: 60000,
      timeout: 60000,
    });

    // Test the connection
    connection.ping((err: any) => {
      if (err) {
        logger.error('MySQL connection failed:', err);
      } else {
        logger.info('Connected to MySQL database successfully');
        mysqlConnection = connection;
      }
    });

  } catch (error) {
    logger.error('Error initializing MySQL connection:', error);
  }
};

export const getMySQLConnection = (): mysql.Connection | null => {
  return mysqlConnection;
};

export const testMySQLConnection = async (): Promise<boolean> => {
  try {
    if (!mysqlConnection) {
      return false;
    }

    return new Promise((resolve) => {
      mysqlConnection!.ping((err: any) => {
        if (err) {
          logger.error('MySQL ping failed:', err);
          resolve(false);
        } else {
          resolve(true);
        }
      });
    });
  } catch (error) {
    logger.error('Error testing MySQL connection:', error);
    return false;
  }
};

export const closeMySQLConnection = (): void => {
  if (mysqlConnection) {
    mysqlConnection.end();
    mysqlConnection = null;
    logger.info('MySQL connection closed');
  }
}; 
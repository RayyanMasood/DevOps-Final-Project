import mysql from 'mysql2/promise';
import { logger } from '../utils/logger';

let mysqlConnection: mysql.Connection | null = null;

export const connectMySQL = async (): Promise<mysql.Connection> => {
  if (mysqlConnection) {
    return mysqlConnection;
  }

  try {
    const mysqlUrl = process.env.MYSQL_URL;
    
    if (!mysqlUrl) {
      throw new Error('MYSQL_URL environment variable is not set');
    }

    // Parse MySQL URL
    const url = new URL(mysqlUrl);
    
    mysqlConnection = await mysql.createConnection({
      host: url.hostname,
      port: parseInt(url.port) || 3306,
      user: url.username,
      password: url.password,
      database: url.pathname.slice(1), // Remove leading slash
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0,
      acquireTimeout: 60000,
      timeout: 60000,
      reconnect: true,
    });

    logger.info('MySQL connected successfully');
    return mysqlConnection;
  } catch (error) {
    logger.error('Failed to connect to MySQL:', error);
    throw error;
  }
};

export const getMySQLConnection = (): mysql.Connection | null => {
  return mysqlConnection;
};

export const disconnectMySQL = async (): Promise<void> => {
  if (mysqlConnection) {
    await mysqlConnection.end();
    mysqlConnection = null;
    logger.info('MySQL connection closed');
  }
};

// Test MySQL connection
export const testMySQLConnection = async (): Promise<boolean> => {
  try {
    const connection = await connectMySQL();
    const [rows] = await connection.execute('SELECT 1 as test');
    return Array.isArray(rows) && rows.length > 0;
  } catch (error) {
    logger.error('MySQL connection test failed:', error);
    return false;
  }
}; 
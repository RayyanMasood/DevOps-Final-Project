/**
 * Database Connection Configuration
 * Handles connections to both MySQL and PostgreSQL databases
 */

const { Sequelize } = require('sequelize');
const logger = require('../utils/logger');

// Database configurations
const mysqlConfig = {
  dialect: 'mysql',
  host: process.env.MYSQL_HOST || 'localhost',
  port: process.env.MYSQL_PORT || 3306,
  database: process.env.MYSQL_DATABASE || 'devops_mysql',
  username: process.env.MYSQL_USERNAME || 'admin',
  password: process.env.MYSQL_PASSWORD || 'password',
  logging: process.env.NODE_ENV === 'development' ? logger.debug : false,
  pool: {
    max: parseInt(process.env.DB_POOL_MAX) || 10,
    min: parseInt(process.env.DB_POOL_MIN) || 0,
    acquire: parseInt(process.env.DB_POOL_ACQUIRE) || 30000,
    idle: parseInt(process.env.DB_POOL_IDLE) || 10000,
  },
  dialectOptions: {
    connectTimeout: 30000,
    acquireTimeout: 30000,
    timeout: 30000,
    charset: 'utf8mb4',
    collate: 'utf8mb4_unicode_ci',
    // SSL configuration for RDS
    ssl: process.env.NODE_ENV === 'production' ? {
      require: true,
      rejectUnauthorized: false
    } : false
  },
  define: {
    timestamps: true,
    underscored: true,
    paranoid: true, // Soft deletes
    charset: 'utf8mb4',
    collate: 'utf8mb4_unicode_ci'
  },
  timezone: '+00:00', // UTC
};

const postgresConfig = {
  dialect: 'postgres',
  host: process.env.POSTGRES_HOST || 'localhost',
  port: process.env.POSTGRES_PORT || 5432,
  database: process.env.POSTGRES_DATABASE || 'devops_postgres',
  username: process.env.POSTGRES_USERNAME || 'postgres',
  password: process.env.POSTGRES_PASSWORD || 'password',
  logging: process.env.NODE_ENV === 'development' ? logger.debug : false,
  pool: {
    max: parseInt(process.env.DB_POOL_MAX) || 10,
    min: parseInt(process.env.DB_POOL_MIN) || 0,
    acquire: parseInt(process.env.DB_POOL_ACQUIRE) || 30000,
    idle: parseInt(process.env.DB_POOL_IDLE) || 10000,
  },
  dialectOptions: {
    connectTimeout: 30000,
    // SSL configuration for RDS
    ssl: process.env.NODE_ENV === 'production' ? {
      require: true,
      rejectUnauthorized: false
    } : false
  },
  define: {
    timestamps: true,
    underscored: true,
    paranoid: true, // Soft deletes
  },
  timezone: '+00:00', // UTC
};

// Initialize Sequelize instances
const mysqlSequelize = new Sequelize(mysqlConfig);
const postgresSequelize = new Sequelize(postgresConfig);

// Export sequelize instances
const sequelize = {
  mysql: mysqlSequelize,
  postgresql: postgresSequelize
};

/**
 * Test database connections
 */
async function testConnections() {
  const results = {
    mysql: { status: 'disconnected', error: null },
    postgresql: { status: 'disconnected', error: null }
  };

  // Test MySQL connection
  try {
    await mysqlSequelize.authenticate();
    results.mysql.status = 'connected';
    logger.info('MySQL database connection established successfully');
  } catch (error) {
    results.mysql.status = 'error';
    results.mysql.error = error.message;
    logger.error('Unable to connect to MySQL database:', error.message);
  }

  // Test PostgreSQL connection
  try {
    await postgresSequelize.authenticate();
    results.postgresql.status = 'connected';
    logger.info('PostgreSQL database connection established successfully');
  } catch (error) {
    results.postgresql.status = 'error';
    results.postgresql.error = error.message;
    logger.error('Unable to connect to PostgreSQL database:', error.message);
  }

  return results;
}

/**
 * Connect to all databases
 */
async function connectDatabases() {
  logger.info('Connecting to databases...');
  
  const results = await testConnections();
  
  // Check if both databases are connected
  const mysqlConnected = results.mysql.status === 'connected';
  const postgresConnected = results.postgresql.status === 'connected';
  
  if (!mysqlConnected || !postgresConnected) {
    const errors = [];
    if (!mysqlConnected) errors.push(`MySQL: ${results.mysql.error}`);
    if (!postgresConnected) errors.push(`PostgreSQL: ${results.postgresql.error}`);
    
    throw new Error(`Database connection failed: ${errors.join(', ')}`);
  }
  
  logger.info('All database connections established successfully');
  return results;
}

/**
 * Close all database connections
 */
async function closeDatabases() {
  logger.info('Closing database connections...');
  
  try {
    await mysqlSequelize.close();
    logger.info('MySQL connection closed');
  } catch (error) {
    logger.error('Error closing MySQL connection:', error.message);
  }
  
  try {
    await postgresSequelize.close();
    logger.info('PostgreSQL connection closed');
  } catch (error) {
    logger.error('Error closing PostgreSQL connection:', error.message);
  }
}

/**
 * Get database health status
 */
async function getDatabaseHealth() {
  const health = {
    mysql: { status: 'unknown', latency: 0, error: null },
    postgresql: { status: 'unknown', latency: 0, error: null }
  };

  // Check MySQL health
  try {
    const start = Date.now();
    await mysqlSequelize.query('SELECT 1 as health_check');
    health.mysql.latency = Date.now() - start;
    health.mysql.status = 'healthy';
  } catch (error) {
    health.mysql.status = 'unhealthy';
    health.mysql.error = error.message;
  }

  // Check PostgreSQL health
  try {
    const start = Date.now();
    await postgresSequelize.query('SELECT 1 as health_check');
    health.postgresql.latency = Date.now() - start;
    health.postgresql.status = 'healthy';
  } catch (error) {
    health.postgresql.status = 'unhealthy';
    health.postgresql.error = error.message;
  }

  return health;
}

/**
 * Execute raw SQL query on specified database
 */
async function executeQuery(database, query, options = {}) {
  const db = database === 'mysql' ? mysqlSequelize : postgresSequelize;
  
  try {
    const [results, metadata] = await db.query(query, {
      type: Sequelize.QueryTypes.SELECT,
      ...options
    });
    
    return { success: true, data: results, metadata };
  } catch (error) {
    logger.error(`Query execution failed on ${database}:`, error.message);
    return { success: false, error: error.message };
  }
}

/**
 * Get database statistics
 */
async function getDatabaseStats() {
  const stats = {
    mysql: {},
    postgresql: {}
  };

  // MySQL statistics
  try {
    const [mysqlStats] = await mysqlSequelize.query(`
      SELECT 
        table_schema as 'database_name',
        COUNT(*) as 'total_tables',
        SUM(table_rows) as 'total_rows',
        SUM(data_length + index_length) as 'total_size_bytes'
      FROM information_schema.tables 
      WHERE table_schema = :database
      GROUP BY table_schema
    `, {
      replacements: { database: mysqlConfig.database },
      type: Sequelize.QueryTypes.SELECT
    });
    
    stats.mysql = mysqlStats || {};
  } catch (error) {
    logger.error('Failed to get MySQL statistics:', error.message);
    stats.mysql.error = error.message;
  }

  // PostgreSQL statistics
  try {
    const [postgresStats] = await postgresSequelize.query(`
      SELECT 
        schemaname as schema_name,
        COUNT(*) as total_tables,
        SUM(n_tup_ins + n_tup_upd + n_tup_del) as total_operations
      FROM pg_stat_user_tables 
      WHERE schemaname = 'public'
      GROUP BY schemaname
    `, {
      type: Sequelize.QueryTypes.SELECT
    });
    
    stats.postgresql = postgresStats || {};
  } catch (error) {
    logger.error('Failed to get PostgreSQL statistics:', error.message);
    stats.postgresql.error = error.message;
  }

  return stats;
}

module.exports = {
  sequelize,
  connectDatabases,
  closeDatabases,
  testConnections,
  getDatabaseHealth,
  getDatabaseStats,
  executeQuery,
  mysqlSequelize,
  postgresSequelize
};

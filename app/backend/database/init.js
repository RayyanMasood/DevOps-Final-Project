const mysql = require('mysql2/promise');
const { Pool } = require('pg');

let mysqlConnection = null;
let postgresPool = null;

// MySQL configuration
const mysqlConfig = {
  host: process.env.MYSQL_HOST || 'localhost',
  port: process.env.MYSQL_PORT || 3306,
  user: process.env.MYSQL_USER || 'root',
  password: process.env.MYSQL_PASSWORD || 'password',
  database: process.env.MYSQL_DATABASE || 'notes_db',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

// PostgreSQL configuration
const postgresConfig = {
  host: process.env.POSTGRES_HOST || 'localhost',
  port: process.env.POSTGRES_PORT || 5432,
  user: process.env.POSTGRES_USER || 'postgres',
  password: process.env.POSTGRES_PASSWORD || 'password',
  database: process.env.POSTGRES_DATABASE || 'notes_db',
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 60000,
  statement_timeout: 60000,
  query_timeout: 60000,
  ssl: {
    rejectUnauthorized: false
  },
};

async function initializeMysql() {
  try {
    console.log('Connecting to MySQL...');
    mysqlConnection = await mysql.createPool(mysqlConfig);
    
    // Test connection
    await mysqlConnection.execute('SELECT 1');
    
    // Create notes table if it doesn't exist
    await mysqlConnection.execute(`
      CREATE TABLE IF NOT EXISTS notes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        content TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        database_type VARCHAR(50) DEFAULT 'mysql'
      )
    `);
    
    console.log('MySQL connected and initialized successfully');
    return mysqlConnection;
  } catch (error) {
    console.error('MySQL connection failed:', error);
    throw error;
  }
}

async function initializePostgres() {
  try {
    console.log('Connecting to PostgreSQL...');
    console.log('PostgreSQL config:', {
      host: postgresConfig.host,
      port: postgresConfig.port,
      user: postgresConfig.user,
      database: postgresConfig.database,
      connectionTimeoutMillis: postgresConfig.connectionTimeoutMillis
    });
    
    postgresPool = new Pool(postgresConfig);
    
    // Test connection with detailed error logging
    console.log('Testing PostgreSQL connection...');
    const client = await postgresPool.connect();
    console.log('PostgreSQL client connected successfully');
    
    await client.query('SELECT 1');
    console.log('PostgreSQL test query successful');
    
    // Create notes table if it doesn't exist
    console.log('Creating PostgreSQL notes table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS notes (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        content TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        database_type VARCHAR(50) DEFAULT 'postgres'
      )
    `);
    console.log('PostgreSQL notes table created/verified');
    
    // Create update trigger for updated_at
    console.log('Creating PostgreSQL trigger...');
    await client.query(`
      CREATE OR REPLACE FUNCTION update_updated_at_column()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.updated_at = CURRENT_TIMESTAMP;
        RETURN NEW;
      END;
      $$ language 'plpgsql';
      
      DROP TRIGGER IF EXISTS update_notes_updated_at ON notes;
      CREATE TRIGGER update_notes_updated_at 
        BEFORE UPDATE ON notes 
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    `);
    console.log('PostgreSQL trigger created successfully');
    
    client.release();
    console.log('PostgreSQL connected and initialized successfully');
    return postgresPool;
  } catch (error) {
    console.error('PostgreSQL connection failed with detailed error:', {
      message: error.message,
      code: error.code,
      errno: error.errno,
      sqlState: error.sqlState,
      sqlMessage: error.sqlMessage,
      stack: error.stack
    });
    throw error;
  }
}

async function initializeDatabases() {
  const results = await Promise.allSettled([
    initializeMysql(),
    initializePostgres()
  ]);
  
  const failedConnections = results.filter(result => result.status === 'rejected');
  if (failedConnections.length > 0) {
    console.warn('Some database connections failed:', failedConnections);
  }
  
  return {
    mysql: mysqlConnection,
    postgres: postgresPool
  };
}

function getMysqlConnection() {
  return mysqlConnection;
}

function getPostgresPool() {
  return postgresPool;
}

module.exports = {
  initializeDatabases,
  getMysqlConnection,
  getPostgresPool
}; 
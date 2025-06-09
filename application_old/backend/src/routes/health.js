/**
 * Health Check Routes
 * Endpoints for monitoring application and infrastructure health
 */

const express = require('express');
const { getDatabaseHealth, getDatabaseStats } = require('../database/connection');
const logger = require('../utils/logger');

const router = express.Router();

// Basic health check
router.get('/', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.npm_package_version || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    node_version: process.version,
    memory: {
      used: process.memoryUsage(),
      free: require('os').freemem(),
      total: require('os').totalmem(),
    },
    cpu: {
      count: require('os').cpus().length,
      load_average: require('os').loadavg(),
    },
  });
});

// Detailed health check including database status
router.get('/detailed', async (req, res) => {
  try {
    const [databaseHealth, databaseStats] = await Promise.all([
      getDatabaseHealth(),
      getDatabaseStats(),
    ]);

    const systemInfo = {
      hostname: require('os').hostname(),
      platform: require('os').platform(),
      arch: require('os').arch(),
      uptime: require('os').uptime(),
      memory: {
        used: process.memoryUsage(),
        free: require('os').freemem(),
        total: require('os').totalmem(),
        usage_percent: ((require('os').totalmem() - require('os').freemem()) / require('os').totalmem() * 100).toFixed(2),
      },
      cpu: {
        count: require('os').cpus().length,
        model: require('os').cpus()[0]?.model,
        load_average: require('os').loadavg(),
      },
      network: require('os').networkInterfaces(),
    };

    // Calculate overall health status
    const isHealthy = Object.values(databaseHealth).every(db => db.status === 'healthy');

    res.json({
      status: isHealthy ? 'healthy' : 'degraded',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      version: process.env.npm_package_version || '1.0.0',
      environment: process.env.NODE_ENV || 'development',
      system: systemInfo,
      databases: {
        health: databaseHealth,
        statistics: databaseStats,
      },
      performance: {
        response_time: Date.now() - req.startTime,
        active_connections: process.getActiveResourcesInfo?.() || 'N/A',
      },
    });
  } catch (error) {
    logger.error('Detailed health check failed:', error);
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message,
      uptime: process.uptime(),
    });
  }
});

// Database-specific health check
router.get('/database', async (req, res) => {
  try {
    const startTime = Date.now();
    const [health, stats] = await Promise.all([
      getDatabaseHealth(),
      getDatabaseStats(),
    ]);
    const responseTime = Date.now() - startTime;

    const isHealthy = Object.values(health).every(db => db.status === 'healthy');

    res.json({
      status: isHealthy ? 'healthy' : 'degraded',
      timestamp: new Date().toISOString(),
      response_time_ms: responseTime,
      databases: {
        mysql: {
          status: health.mysql.status,
          latency_ms: health.mysql.latency,
          error: health.mysql.error,
          statistics: stats.mysql,
        },
        postgresql: {
          status: health.postgresql.status,
          latency_ms: health.postgresql.latency,
          error: health.postgresql.error,
          statistics: stats.postgresql,
        },
      },
    });
  } catch (error) {
    logger.error('Database health check failed:', error);
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message,
      databases: {
        mysql: { status: 'unknown', error: error.message },
        postgresql: { status: 'unknown', error: error.message },
      },
    });
  }
});

// Liveness probe (for Kubernetes)
router.get('/live', (req, res) => {
  res.json({
    status: 'alive',
    timestamp: new Date().toISOString(),
    pid: process.pid,
  });
});

// Readiness probe (for Kubernetes)
router.get('/ready', async (req, res) => {
  try {
    // Check if application is ready to serve traffic
    const health = await getDatabaseHealth();
    const isReady = Object.values(health).every(db => db.status === 'healthy');

    if (isReady) {
      res.json({
        status: 'ready',
        timestamp: new Date().toISOString(),
        databases: health,
      });
    } else {
      res.status(503).json({
        status: 'not ready',
        timestamp: new Date().toISOString(),
        databases: health,
      });
    }
  } catch (error) {
    logger.error('Readiness check failed:', error);
    res.status(503).json({
      status: 'not ready',
      timestamp: new Date().toISOString(),
      error: error.message,
    });
  }
});

// Startup probe (for Kubernetes)
router.get('/startup', (req, res) => {
  // Check if application has started successfully
  const isStarted = process.uptime() > 10; // Consider started after 10 seconds

  if (isStarted) {
    res.json({
      status: 'started',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    });
  } else {
    res.status(503).json({
      status: 'starting',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    });
  }
});

// Metrics endpoint (Prometheus format)
router.get('/metrics', async (req, res) => {
  try {
    const health = await getDatabaseHealth();
    const memUsage = process.memoryUsage();
    const cpus = require('os').cpus();
    const loadAvg = require('os').loadavg();

    // Simple Prometheus-style metrics
    const metrics = [
      `# HELP nodejs_version_info Node.js version info`,
      `# TYPE nodejs_version_info gauge`,
      `nodejs_version_info{version="${process.version}"} 1`,
      '',
      `# HELP process_uptime_seconds Process uptime in seconds`,
      `# TYPE process_uptime_seconds counter`,
      `process_uptime_seconds ${process.uptime()}`,
      '',
      `# HELP process_memory_usage_bytes Process memory usage in bytes`,
      `# TYPE process_memory_usage_bytes gauge`,
      `process_memory_usage_bytes{type="rss"} ${memUsage.rss}`,
      `process_memory_usage_bytes{type="heapTotal"} ${memUsage.heapTotal}`,
      `process_memory_usage_bytes{type="heapUsed"} ${memUsage.heapUsed}`,
      `process_memory_usage_bytes{type="external"} ${memUsage.external}`,
      '',
      `# HELP system_cpu_count Number of CPU cores`,
      `# TYPE system_cpu_count gauge`,
      `system_cpu_count ${cpus.length}`,
      '',
      `# HELP system_load_average System load average`,
      `# TYPE system_load_average gauge`,
      `system_load_average{period="1m"} ${loadAvg[0]}`,
      `system_load_average{period="5m"} ${loadAvg[1]}`,
      `system_load_average{period="15m"} ${loadAvg[2]}`,
      '',
      `# HELP database_status Database connection status (1=healthy, 0=unhealthy)`,
      `# TYPE database_status gauge`,
      `database_status{database="mysql"} ${health.mysql.status === 'healthy' ? 1 : 0}`,
      `database_status{database="postgresql"} ${health.postgresql.status === 'healthy' ? 1 : 0}`,
      '',
      `# HELP database_latency_milliseconds Database query latency in milliseconds`,
      `# TYPE database_latency_milliseconds gauge`,
      `database_latency_milliseconds{database="mysql"} ${health.mysql.latency || 0}`,
      `database_latency_milliseconds{database="postgresql"} ${health.postgresql.latency || 0}`,
      '',
    ].join('\n');

    res.set('Content-Type', 'text/plain; version=0.0.4; charset=utf-8');
    res.send(metrics);
  } catch (error) {
    logger.error('Metrics endpoint failed:', error);
    res.status(500).text('Error generating metrics');
  }
});

module.exports = router;

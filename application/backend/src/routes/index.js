/**
 * API Routes Index
 * Main router configuration with all API endpoints
 */

const express = require('express');
const { body, query, param } = require('express-validator');

// Import route modules
const healthRoutes = require('./health');
const usersRoutes = require('./users');
const ordersRoutes = require('./orders');
const productsRoutes = require('./products');
const analyticsRoutes = require('./analytics');
const metricsRoutes = require('./metrics');
const dashboardRoutes = require('./dashboard');

// Import middleware
const validateRequest = require('../middleware/validateRequest');
const logger = require('../utils/logger');

const router = express.Router();

// Request logging middleware
router.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    query: req.query,
    body: req.method !== 'GET' ? req.body : undefined,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
  });
  next();
});

// API Documentation endpoint
router.get('/docs', (req, res) => {
  res.json({
    title: 'DevOps Final Project API',
    version: '1.0.0',
    description: 'RESTful API with real-time data updates for BI dashboard',
    endpoints: {
      health: {
        'GET /api/health': 'API health check',
        'GET /api/health/detailed': 'Detailed health information including database status',
        'GET /api/health/database': 'Database connection status',
      },
      users: {
        'GET /api/users': 'Get all users with pagination',
        'GET /api/users/:id': 'Get user by ID',
        'POST /api/users': 'Create new user',
        'PUT /api/users/:id': 'Update user',
        'DELETE /api/users/:id': 'Delete user',
        'GET /api/users/stats': 'User statistics for dashboard',
      },
      orders: {
        'GET /api/orders': 'Get all orders with pagination and filtering',
        'GET /api/orders/:id': 'Get order by ID',
        'POST /api/orders': 'Create new order',
        'PUT /api/orders/:id': 'Update order',
        'DELETE /api/orders/:id': 'Delete order',
        'GET /api/orders/stats': 'Order statistics and analytics',
      },
      products: {
        'GET /api/products': 'Get all products with pagination and filtering',
        'GET /api/products/:id': 'Get product by ID',
        'POST /api/products': 'Create new product',
        'PUT /api/products/:id': 'Update product',
        'DELETE /api/products/:id': 'Delete product',
        'GET /api/products/stats': 'Product statistics',
      },
      analytics: {
        'GET /api/analytics/events': 'Get analytics events',
        'POST /api/analytics/events': 'Track new analytics event',
        'GET /api/analytics/dashboard': 'Analytics dashboard data',
        'GET /api/analytics/reports/:type': 'Generate analytics reports',
      },
      metrics: {
        'GET /api/metrics': 'Get performance metrics',
        'POST /api/metrics': 'Submit performance metric',
        'GET /api/metrics/dashboard': 'Metrics dashboard data',
        'GET /api/metrics/real-time': 'Real-time metrics stream',
      },
      dashboard: {
        'GET /api/dashboard': 'Main dashboard data',
        'GET /api/dashboard/real-time': 'Real-time dashboard updates',
        'GET /api/dashboard/kpis': 'Key Performance Indicators',
        'GET /api/dashboard/charts/:type': 'Chart data for dashboard widgets',
      },
    },
    websocket: {
      events: [
        'dashboard:update',
        'metrics:real-time',
        'analytics:event',
        'system:status',
      ],
    },
    authentication: {
      note: 'Authentication is optional for this demo. Include Authorization header for user-specific data.',
    },
    pagination: {
      default_limit: 50,
      max_limit: 1000,
      parameters: ['page', 'limit', 'sort', 'order'],
    },
    filtering: {
      operators: ['eq', 'ne', 'gt', 'gte', 'lt', 'lte', 'like', 'in'],
      examples: {
        'status=active': 'Filter by exact match',
        'created_at[gte]=2023-01-01': 'Filter by date range',
        'name[like]=%search%': 'Filter by partial match',
        'id[in]=1,2,3': 'Filter by multiple values',
      },
    },
  });
});

// Mount route modules
router.use('/health', healthRoutes);
router.use('/users', usersRoutes);
router.use('/orders', ordersRoutes);
router.use('/products', productsRoutes);
router.use('/analytics', analyticsRoutes);
router.use('/metrics', metricsRoutes);
router.use('/dashboard', dashboardRoutes);

// Root API endpoint
router.get('/', (req, res) => {
  res.json({
    message: 'DevOps Final Project API',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development',
    uptime: process.uptime(),
    documentation: '/api/docs',
    health: '/api/health',
    websocket: {
      url: process.env.WEBSOCKET_URL || 'ws://localhost:3001',
      documentation: 'Connect to receive real-time updates',
    },
  });
});

// Test endpoint for load testing
router.get('/test/load', [
  query('delay').optional().isInt({ min: 0, max: 5000 }),
  query('error').optional().isBoolean(),
  validateRequest,
], async (req, res) => {
  const delay = parseInt(req.query.delay) || 0;
  const shouldError = req.query.error === 'true';

  if (delay > 0) {
    await new Promise(resolve => setTimeout(resolve, delay));
  }

  if (shouldError) {
    return res.status(500).json({
      error: 'Simulated error for testing',
      timestamp: new Date().toISOString(),
    });
  }

  res.json({
    message: 'Load test endpoint',
    delay: delay,
    timestamp: new Date().toISOString(),
    random: Math.random(),
  });
});

// Database test endpoint
router.get('/test/database', async (req, res) => {
  const { getDatabaseHealth } = require('../database/connection');
  
  try {
    const health = await getDatabaseHealth();
    res.json({
      message: 'Database test endpoint',
      timestamp: new Date().toISOString(),
      databases: health,
    });
  } catch (error) {
    logger.error('Database test failed:', error);
    res.status(500).json({
      error: 'Database test failed',
      message: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Error simulation endpoint (for testing error handling)
router.get('/test/error/:type', [
  param('type').isIn(['sync', 'async', 'validation', 'timeout']),
  validateRequest,
], async (req, res, next) => {
  const { type } = req.params;

  switch (type) {
    case 'sync':
      throw new Error('Synchronous error simulation');

    case 'async':
      setTimeout(() => {
        throw new Error('Asynchronous error simulation');
      }, 100);
      break;

    case 'validation':
      return res.status(400).json({
        error: 'Validation error simulation',
        details: ['Field A is required', 'Field B must be a number'],
      });

    case 'timeout':
      // Simulate a long-running operation
      await new Promise(resolve => setTimeout(resolve, 10000));
      break;

    default:
      return res.status(400).json({ error: 'Invalid error type' });
  }

  res.json({ message: `${type} error test completed` });
});

module.exports = router;

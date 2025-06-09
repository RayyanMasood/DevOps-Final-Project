import express from 'express';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';

import { logger } from './utils/logger';
import { connectDatabase } from './database/connection';
import { initializeMySQLConnection } from './database/mysql';
import { connectRedis } from './services/redis';
import { errorHandler } from './middleware/errorHandler';
import { notFoundHandler } from './middleware/notFoundHandler';
import { authMiddleware } from './middleware/auth';
import { validateEnvironment } from './utils/environment';

// Route imports
import healthRoutes from './routes/health';
import authRoutes from './routes/auth';
import dashboardRoutes from './routes/dashboard';
import metricsRoutes from './routes/metrics';
import kpiRoutes from './routes/kpi';
import eventsRoutes from './routes/events';
import notesRoutes from './routes/notes-simple';

// WebSocket handlers
import { setupWebSocketHandlers } from './services/websocket';

// Load environment variables
dotenv.config();

// Validate environment variables
validateEnvironment();

const app = express();
const server = createServer(app);
const io = new SocketIOServer(server, {
  cors: {
    origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
    methods: ['GET', 'POST'],
    credentials: true,
  },
  transports: ['websocket', 'polling'],
});

const PORT = process.env.PORT || 3001;
const NODE_ENV = process.env.NODE_ENV || 'development';

// Trust proxy for rate limiting and security
if (process.env.TRUST_PROXY === 'true') {
  app.set('trust proxy', 1);
}

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000'), // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100'),
  message: {
    error: 'Too many requests from this IP, please try again later.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Security middleware
app.use(helmet({
  contentSecurityPolicy: NODE_ENV !== 'production' ? false : true,
  crossOriginEmbedderPolicy: false,
}));

// CORS configuration
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
}));

// Compression and parsing
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging
if (NODE_ENV !== 'test') {
  app.use(morgan('combined', {
    stream: {
      write: (message: string) => logger.info(message.trim()),
    },
  }));
}

// Apply rate limiting to all routes except health checks
app.use('/api', (req, res, next) => {
  if (req.path.startsWith('/health')) {
    return next();
  }
  return limiter(req, res, next);
});

// Health routes (no auth required)
app.use('/api/health', healthRoutes);

// Authentication routes
app.use('/api/auth', authRoutes);

// Protected routes (require authentication)
app.use('/api/dashboard', authMiddleware, dashboardRoutes);
app.use('/api/metrics', authMiddleware, metricsRoutes);
app.use('/api/kpi', authMiddleware, kpiRoutes);
app.use('/api/events', authMiddleware, eventsRoutes);

// Notes routes - temporarily bypass auth for testing
app.use('/api/notes', notesRoutes);

// API info endpoint
app.get('/api', (req, res) => {
  res.json({
    name: 'DevOps Dashboard API',
    version: '2.0.0',
    status: 'operational',
    timestamp: new Date().toISOString(),
    environment: NODE_ENV,
    features: {
      realTime: process.env.ENABLE_REAL_TIME === 'true',
      metrics: process.env.ENABLE_METRICS === 'true',
      websocket: process.env.ENABLE_WEBSOCKET === 'true',
    },
    endpoints: {
      health: '/api/health',
      auth: '/api/auth',
      dashboard: '/api/dashboard',
      metrics: '/api/metrics',
      kpi: '/api/kpi',
      events: '/api/events',
    },
  });
});

// WebSocket setup
if (process.env.ENABLE_WEBSOCKET === 'true') {
  setupWebSocketHandlers(io);
  logger.info('WebSocket server configured');
}

// Error handling middleware (must be last)
app.use(notFoundHandler);
app.use(errorHandler);

// Graceful shutdown handling
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
});

// Unhandled rejection handling
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  if (NODE_ENV === 'production') {
    process.exit(1);
  }
});

process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  process.exit(1);
});

// Start server
async function startServer() {
  try {
    // Initialize PostgreSQL database connection
    await connectDatabase();
    logger.info('PostgreSQL database connected successfully');

    // Initialize MySQL database connection
    await initializeMySQLConnection();
    logger.info('MySQL database connection initialized');

    // Initialize Redis connection
    if (process.env.REDIS_URL) {
      await connectRedis();
      logger.info('Redis connected successfully');
    }

    // Start listening
    server.listen(PORT, () => {
      logger.info(`Server running on port ${PORT} in ${NODE_ENV} mode`);
      logger.info(`API available at http://localhost:${PORT}/api`);
      
      if (process.env.ENABLE_WEBSOCKET === 'true') {
        logger.info(`WebSocket server running on ws://localhost:${PORT}`);
      }
    });

  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Start the server
if (require.main === module) {
  startServer();
}

export { app, server, io }; 
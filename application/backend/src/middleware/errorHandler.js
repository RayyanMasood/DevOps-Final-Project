/**
 * Global Error Handler Middleware
 * Handles all uncaught errors in the application
 */

const logger = require('../utils/logger');

/**
 * Global error handling middleware
 */
function errorHandler(err, req, res, next) {
  // Log the error
  logger.error('Unhandled error:', {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
    body: req.body,
    query: req.query,
    params: req.params,
    headers: req.headers,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
  });

  // Default error response
  let statusCode = 500;
  let message = 'Internal server error';
  let details = null;

  // Handle specific error types
  if (err.name === 'SequelizeValidationError') {
    statusCode = 400;
    message = 'Validation error';
    details = err.errors.map(error => ({
      field: error.path,
      message: error.message,
      value: error.value,
    }));
  } else if (err.name === 'SequelizeUniqueConstraintError') {
    statusCode = 409;
    message = 'Resource already exists';
    details = err.errors.map(error => ({
      field: error.path,
      message: error.message,
      value: error.value,
    }));
  } else if (err.name === 'SequelizeForeignKeyConstraintError') {
    statusCode = 400;
    message = 'Referenced resource does not exist';
    details = {
      table: err.table,
      constraint: err.index,
    };
  } else if (err.name === 'SequelizeConnectionError') {
    statusCode = 503;
    message = 'Database connection error';
  } else if (err.name === 'SequelizeTimeoutError') {
    statusCode = 504;
    message = 'Database timeout error';
  } else if (err.name === 'JsonWebTokenError') {
    statusCode = 401;
    message = 'Invalid authentication token';
  } else if (err.name === 'TokenExpiredError') {
    statusCode = 401;
    message = 'Authentication token expired';
  } else if (err.name === 'SyntaxError' && err.message.includes('JSON')) {
    statusCode = 400;
    message = 'Invalid JSON format';
  } else if (err.code === 'ECONNREFUSED') {
    statusCode = 503;
    message = 'Service unavailable';
  } else if (err.code === 'ETIMEDOUT') {
    statusCode = 504;
    message = 'Request timeout';
  } else if (err.status || err.statusCode) {
    statusCode = err.status || err.statusCode;
    message = err.message || message;
  }

  // Prepare error response
  const errorResponse = {
    error: message,
    timestamp: new Date().toISOString(),
    path: req.path,
    method: req.method,
  };

  // Add details in development mode or for validation errors
  if (process.env.NODE_ENV === 'development' || details) {
    errorResponse.details = details;
  }

  // Add stack trace in development mode
  if (process.env.NODE_ENV === 'development') {
    errorResponse.stack = err.stack;
  }

  // Add request ID if available
  if (req.id) {
    errorResponse.requestId = req.id;
  }

  // Send error response
  res.status(statusCode).json(errorResponse);

  // Emit error event for monitoring (if socket.io is available)
  if (global.io && statusCode >= 500) {
    global.io.to('monitoring').emit('error-occurred', {
      error: {
        message: err.message,
        status: statusCode,
        path: req.path,
        method: req.method,
      },
      timestamp: new Date().toISOString(),
    });
  }
}

module.exports = errorHandler;

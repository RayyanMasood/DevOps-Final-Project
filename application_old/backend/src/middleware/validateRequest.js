/**
 * Request Validation Middleware
 * Validates request data using express-validator
 */

const { validationResult } = require('express-validator');
const logger = require('../utils/logger');

/**
 * Middleware to validate request based on validation rules
 */
function validateRequest(req, res, next) {
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    const formattedErrors = errors.array().map(error => ({
      field: error.path || error.param,
      message: error.msg,
      value: error.value,
      location: error.location,
    }));

    logger.warn('Request validation failed:', {
      path: req.path,
      method: req.method,
      errors: formattedErrors,
      body: req.body,
      query: req.query,
      params: req.params,
    });

    return res.status(400).json({
      error: 'Validation failed',
      message: 'The request contains invalid data',
      details: formattedErrors,
      timestamp: new Date().toISOString(),
    });
  }

  next();
}

module.exports = validateRequest;

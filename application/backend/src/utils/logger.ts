import winston from 'winston';
import path from 'path';

// Custom log format
const logFormat = winston.format.combine(
  winston.format.timestamp({
    format: 'YYYY-MM-DD HH:mm:ss.SSS',
  }),
  winston.format.errors({ stack: true }),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    let log = `${timestamp} [${level.toUpperCase()}]: ${message}`;
    
    // Add metadata if present
    if (Object.keys(meta).length > 0) {
      log += ` ${JSON.stringify(meta, null, 2)}`;
    }
    
    return log;
  })
);

// Create logs directory if it doesn't exist
const logsDir = path.join(process.cwd(), 'logs');

// Configure transports
const transports: winston.transport[] = [
  // Console transport
  new winston.transports.Console({
    level: process.env.LOG_LEVEL || 'debug',
    format: winston.format.combine(
      winston.format.colorize(),
      logFormat
    ),
  }),
];

// Add file transports in production or when explicitly enabled
if (process.env.NODE_ENV === 'production' || process.env.ENABLE_FILE_LOGGING === 'true') {
  transports.push(
    // Combined log file
    new winston.transports.File({
      filename: path.join(logsDir, 'combined.log'),
      level: 'info',
      format: logFormat,
      maxsize: 10 * 1024 * 1024, // 10MB
      maxFiles: 5,
      tailable: true,
    }),
    
    // Error log file
    new winston.transports.File({
      filename: path.join(logsDir, 'error.log'),
      level: 'error',
      format: logFormat,
      maxsize: 10 * 1024 * 1024, // 10MB
      maxFiles: 5,
      tailable: true,
    })
  );
}

// Create logger instance
export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'debug',
  format: logFormat,
  transports,
  exitOnError: false,
  handleExceptions: true,
  handleRejections: true,
});

// Add HTTP request logging helper
export const logRequest = (req: any, res: any, duration: number) => {
  const { method, url, ip, headers } = req;
  const { statusCode } = res;
  
  logger.info('HTTP Request', {
    method,
    url,
    ip,
    statusCode,
    duration: `${duration}ms`,
    userAgent: headers['user-agent'],
    referer: headers.referer,
  });
};

// Add error logging helper
export const logError = (error: Error, context?: Record<string, any>) => {
  logger.error('Application Error', {
    message: error.message,
    stack: error.stack,
    name: error.name,
    ...context,
  });
};

// Add performance logging helper
export const logPerformance = (operation: string, duration: number, metadata?: Record<string, any>) => {
  logger.info('Performance Metric', {
    operation,
    duration: `${duration}ms`,
    ...metadata,
  });
};

// Development helper
if (process.env.NODE_ENV !== 'production') {
  logger.debug('Logger initialized in development mode');
} 
import { z } from 'zod';

// Define the environment schema
const envSchema = z.object({
  // Database
  DATABASE_URL: z.string().url('Invalid DATABASE_URL format'),
  
  // Redis (optional)
  REDIS_URL: z.string().url('Invalid REDIS_URL format').optional(),
  
  // Authentication
  JWT_SECRET: z.string().min(32, 'JWT_SECRET must be at least 32 characters'),
  JWT_EXPIRES_IN: z.string().default('7d'),
  BCRYPT_ROUNDS: z.string().transform(Number).pipe(z.number().min(10).max(15)).default('12'),
  
  // Application
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.string().transform(Number).pipe(z.number().min(1).max(65535)).default('3001'),
  CORS_ORIGIN: z.string().url('Invalid CORS_ORIGIN format').default('http://localhost:3000'),
  
  // Logging
  LOG_LEVEL: z.enum(['error', 'warn', 'info', 'debug']).default('debug'),
  ENABLE_FILE_LOGGING: z.string().transform(val => val === 'true').default('false'),
  
  // Features
  ENABLE_REAL_TIME: z.string().transform(val => val === 'true').default('true'),
  ENABLE_METRICS: z.string().transform(val => val === 'true').default('true'),
  ENABLE_WEBSOCKET: z.string().transform(val => val === 'true').default('true'),
  
  // Rate Limiting
  RATE_LIMIT_WINDOW_MS: z.string().transform(Number).pipe(z.number().min(60000)).default('900000'), // 15 minutes
  RATE_LIMIT_MAX_REQUESTS: z.string().transform(Number).pipe(z.number().min(1)).default('100'),
  
  // Security
  HELMET_ENABLED: z.string().transform(val => val === 'true').default('true'),
  TRUST_PROXY: z.string().transform(val => val === 'true').default('false'),
  
  // Health Checks
  HEALTH_CHECK_TIMEOUT: z.string().transform(Number).pipe(z.number().min(1000)).default('30000'),
});

export type Environment = z.infer<typeof envSchema>;

let validatedEnv: Environment;

export function validateEnvironment(): Environment {
  try {
    validatedEnv = envSchema.parse(process.env);
    return validatedEnv;
  } catch (error) {
    if (error instanceof z.ZodError) {
      const errorMessages = error.errors.map(err => 
        `${err.path.join('.')}: ${err.message}`
      );
      
      console.error('Environment validation failed:');
      errorMessages.forEach(message => console.error(`  - ${message}`));
      
      // Check for required variables that are missing
      const missingRequired = error.errors
        .filter(err => err.code === 'invalid_type' && err.received === 'undefined')
        .map(err => err.path.join('.'));
      
      if (missingRequired.length > 0) {
        console.error('\nRequired environment variables are missing:');
        missingRequired.forEach(variable => console.error(`  - ${variable}`));
        console.error('\nPlease check your .env file or environment configuration.');
      }
      
      process.exit(1);
    }
    
    throw error;
  }
}

export function getEnvironment(): Environment {
  if (!validatedEnv) {
    return validateEnvironment();
  }
  return validatedEnv;
}

// Helper functions for common environment checks
export const isDevelopment = () => getEnvironment().NODE_ENV === 'development';
export const isProduction = () => getEnvironment().NODE_ENV === 'production';
export const isTest = () => getEnvironment().NODE_ENV === 'test';

// Helper to check if a feature is enabled
export const isFeatureEnabled = (feature: keyof Pick<Environment, 'ENABLE_REAL_TIME' | 'ENABLE_METRICS' | 'ENABLE_WEBSOCKET'>) => {
  return getEnvironment()[feature];
};

// Database URL helpers
export const getDatabaseUrl = () => getEnvironment().DATABASE_URL;
export const getRedisUrl = () => getEnvironment().REDIS_URL;

// Security helpers
export const getJwtConfig = () => {
  const env = getEnvironment();
  return {
    secret: env.JWT_SECRET,
    expiresIn: env.JWT_EXPIRES_IN,
    bcryptRounds: env.BCRYPT_ROUNDS,
  };
};

// Rate limiting configuration
export const getRateLimitConfig = () => {
  const env = getEnvironment();
  return {
    windowMs: env.RATE_LIMIT_WINDOW_MS,
    max: env.RATE_LIMIT_MAX_REQUESTS,
  };
}; 
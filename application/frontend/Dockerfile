# Multi-stage build for React TypeScript frontend
ARG NODE_VERSION=20-alpine

# Stage 1: Base image with common dependencies
FROM node:${NODE_VERSION} AS base

# Set working directory
WORKDIR /app

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Copy package files
COPY package.json package-lock.json* ./

# Stage 2: Development dependencies and build
FROM base AS deps

# Install all dependencies
RUN npm ci --include=dev

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Stage 3: Production dependencies only
FROM base AS production-deps

# Install production dependencies only
RUN npm ci --only=production && npm cache clean --force

# Stage 4: Development image
FROM base AS development

# Install development dependencies
RUN npm ci

# Copy source code
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000 || exit 1

# Start development server
CMD ["dumb-init", "npm", "run", "dev"]

# Stage 5: Production build with Nginx
FROM nginx:1.25-alpine AS production

# Install dumb-init
RUN apk add --no-cache dumb-init

# Copy built application from deps stage
COPY --from=deps /app/dist /usr/share/nginx/html

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy additional nginx configurations
COPY nginx-default.conf /etc/nginx/conf.d/default.conf

# Create non-root user for nginx
RUN addgroup -g 1001 -S nginx-app && \
    adduser -S nginx-app -u 1001

# Set proper permissions
RUN chown -R nginx-app:nginx-app /usr/share/nginx/html && \
    chown -R nginx-app:nginx-app /var/cache/nginx && \
    chown -R nginx-app:nginx-app /var/log/nginx && \
    chown -R nginx-app:nginx-app /etc/nginx/conf.d

# Make nginx directories writable
RUN chmod -R 755 /var/cache/nginx && \
    chmod -R 755 /var/log/nginx

# Create pid file directory
RUN mkdir -p /var/run/nginx && \
    chown -R nginx-app:nginx-app /var/run/nginx

USER nginx-app

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:80/health || exit 1

# Start nginx
CMD ["dumb-init", "nginx", "-g", "daemon off;"] 
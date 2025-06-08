/**
 * Socket.IO Service
 * Handles real-time WebSocket connections and events for dashboard updates
 */

const logger = require('../utils/logger');

// Store connected clients and their metadata
const connectedClients = new Map();
const rooms = new Set(['dashboard', 'analytics', 'monitoring']);

/**
 * Initialize Socket.IO event handlers
 */
function initializeSocketHandlers(io) {
  io.on('connection', (socket) => {
    logger.info(`Client connected: ${socket.id} from ${socket.handshake.address}`);
    
    // Store client metadata
    connectedClients.set(socket.id, {
      id: socket.id,
      connectedAt: new Date(),
      rooms: new Set(),
      userAgent: socket.handshake.headers['user-agent'],
      ip: socket.handshake.address,
      lastActivity: new Date(),
    });

    // Send welcome message with available channels
    socket.emit('welcome', {
      message: 'Connected to DevOps Dashboard WebSocket',
      clientId: socket.id,
      timestamp: new Date().toISOString(),
      availableRooms: Array.from(rooms),
      serverInfo: {
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development',
      },
    });

    // Handle room joining
    socket.on('join-room', (roomName) => {
      if (rooms.has(roomName)) {
        socket.join(roomName);
        const client = connectedClients.get(socket.id);
        if (client) {
          client.rooms.add(roomName);
          client.lastActivity = new Date();
        }
        
        socket.emit('room-joined', {
          room: roomName,
          timestamp: new Date().toISOString(),
        });
        
        logger.info(`Client ${socket.id} joined room: ${roomName}`);
        
        // Send initial data for the room
        sendInitialRoomData(socket, roomName);
      } else {
        socket.emit('error', {
          message: `Invalid room: ${roomName}`,
          availableRooms: Array.from(rooms),
        });
      }
    });

    // Handle room leaving
    socket.on('leave-room', (roomName) => {
      socket.leave(roomName);
      const client = connectedClients.get(socket.id);
      if (client) {
        client.rooms.delete(roomName);
        client.lastActivity = new Date();
      }
      
      socket.emit('room-left', {
        room: roomName,
        timestamp: new Date().toISOString(),
      });
      
      logger.info(`Client ${socket.id} left room: ${roomName}`);
    });

    // Handle dashboard data requests
    socket.on('request-dashboard-data', async (options = {}) => {
      try {
        updateClientActivity(socket.id);
        const dashboardData = await getDashboardData(options);
        socket.emit('dashboard-data', dashboardData);
      } catch (error) {
        logger.error('Dashboard data request failed:', error);
        socket.emit('error', {
          message: 'Failed to fetch dashboard data',
          error: error.message,
        });
      }
    });

    // Handle analytics data requests
    socket.on('request-analytics-data', async (options = {}) => {
      try {
        updateClientActivity(socket.id);
        const analyticsData = await getAnalyticsData(options);
        socket.emit('analytics-data', analyticsData);
      } catch (error) {
        logger.error('Analytics data request failed:', error);
        socket.emit('error', {
          message: 'Failed to fetch analytics data',
          error: error.message,
        });
      }
    });

    // Handle real-time metrics subscription
    socket.on('subscribe-metrics', (metrics = []) => {
      updateClientActivity(socket.id);
      const client = connectedClients.get(socket.id);
      if (client) {
        client.subscribedMetrics = new Set(metrics);
      }
      
      socket.emit('metrics-subscribed', {
        metrics,
        timestamp: new Date().toISOString(),
      });
      
      logger.info(`Client ${socket.id} subscribed to metrics:`, metrics);
    });

    // Handle ping/pong for connection health
    socket.on('ping', () => {
      updateClientActivity(socket.id);
      socket.emit('pong', { timestamp: new Date().toISOString() });
    });

    // Handle custom dashboard filter updates
    socket.on('update-dashboard-filters', (filters) => {
      updateClientActivity(socket.id);
      const client = connectedClients.get(socket.id);
      if (client) {
        client.dashboardFilters = filters;
      }
      
      // Broadcast filter changes to other clients in the same room (if needed)
      socket.to('dashboard').emit('dashboard-filters-updated', {
        clientId: socket.id,
        filters,
        timestamp: new Date().toISOString(),
      });
    });

    // Handle disconnection
    socket.on('disconnect', (reason) => {
      logger.info(`Client disconnected: ${socket.id}, reason: ${reason}`);
      
      const client = connectedClients.get(socket.id);
      if (client) {
        const sessionDuration = new Date() - client.connectedAt;
        logger.info(`Session duration for ${socket.id}: ${sessionDuration}ms`);
      }
      
      connectedClients.delete(socket.id);
      
      // Broadcast disconnection to monitoring room
      socket.to('monitoring').emit('client-disconnected', {
        clientId: socket.id,
        reason,
        timestamp: new Date().toISOString(),
      });
    });

    // Handle errors
    socket.on('error', (error) => {
      logger.error(`Socket error for client ${socket.id}:`, error);
    });

    // Broadcast new connection to monitoring room
    socket.to('monitoring').emit('client-connected', {
      clientId: socket.id,
      timestamp: new Date().toISOString(),
      metadata: connectedClients.get(socket.id),
    });
  });

  // Store io instance globally for use in other parts of the application
  global.io = io;
  
  logger.info('Socket.IO handlers initialized');
  return io;
}

/**
 * Send initial data when a client joins a room
 */
async function sendInitialRoomData(socket, roomName) {
  try {
    switch (roomName) {
      case 'dashboard':
        const dashboardData = await getDashboardData();
        socket.emit('initial-dashboard-data', dashboardData);
        break;
        
      case 'analytics':
        const analyticsData = await getAnalyticsData();
        socket.emit('initial-analytics-data', analyticsData);
        break;
        
      case 'monitoring':
        const monitoringData = await getMonitoringData();
        socket.emit('initial-monitoring-data', monitoringData);
        break;
        
      default:
        logger.warn(`No initial data handler for room: ${roomName}`);
    }
  } catch (error) {
    logger.error(`Failed to send initial data for room ${roomName}:`, error);
    socket.emit('error', {
      message: `Failed to load initial data for ${roomName}`,
      error: error.message,
    });
  }
}

/**
 * Update client activity timestamp
 */
function updateClientActivity(socketId) {
  const client = connectedClients.get(socketId);
  if (client) {
    client.lastActivity = new Date();
  }
}

/**
 * Broadcast data to all clients in a room
 */
function broadcastToRoom(roomName, event, data) {
  if (global.io) {
    global.io.to(roomName).emit(event, {
      ...data,
      timestamp: new Date().toISOString(),
    });
  }
}

/**
 * Broadcast dashboard updates
 */
function broadcastDashboardUpdate(data) {
  broadcastToRoom('dashboard', 'dashboard-update', data);
}

/**
 * Broadcast analytics events
 */
function broadcastAnalyticsEvent(event) {
  broadcastToRoom('analytics', 'analytics-event', event);
}

/**
 * Broadcast system metrics
 */
function broadcastMetrics(metrics) {
  broadcastToRoom('monitoring', 'metrics-update', metrics);
  
  // Send specific metrics to subscribed clients
  connectedClients.forEach((client, socketId) => {
    if (client.subscribedMetrics && client.subscribedMetrics.size > 0) {
      const filteredMetrics = metrics.filter(metric => 
        client.subscribedMetrics.has(metric.name)
      );
      
      if (filteredMetrics.length > 0 && global.io) {
        global.io.to(socketId).emit('subscribed-metrics', {
          metrics: filteredMetrics,
          timestamp: new Date().toISOString(),
        });
      }
    }
  });
}

/**
 * Get current connection statistics
 */
function getConnectionStats() {
  const now = new Date();
  const stats = {
    total_connections: connectedClients.size,
    rooms: {},
    client_locations: {},
    average_session_duration: 0,
  };

  // Calculate room distribution
  connectedClients.forEach((client) => {
    client.rooms.forEach((room) => {
      stats.rooms[room] = (stats.rooms[room] || 0) + 1;
    });
  });

  // Calculate average session duration
  if (connectedClients.size > 0) {
    const totalDuration = Array.from(connectedClients.values())
      .reduce((sum, client) => sum + (now - client.connectedAt), 0);
    stats.average_session_duration = totalDuration / connectedClients.size;
  }

  return stats;
}

/**
 * Clean up inactive connections
 */
function cleanupInactiveConnections() {
  const inactivityThreshold = 30 * 60 * 1000; // 30 minutes
  const now = new Date();
  
  connectedClients.forEach((client, socketId) => {
    const inactiveDuration = now - client.lastActivity;
    if (inactiveDuration > inactivityThreshold) {
      logger.info(`Cleaning up inactive connection: ${socketId}`);
      if (global.io) {
        global.io.sockets.sockets.get(socketId)?.disconnect(true);
      }
      connectedClients.delete(socketId);
    }
  });
}

// Data fetching functions (would integrate with actual services)
async function getDashboardData(options = {}) {
  // This would fetch real dashboard data
  return {
    kpis: {
      total_users: Math.floor(Math.random() * 10000),
      active_sessions: Math.floor(Math.random() * 1000),
      revenue_today: Math.random() * 50000,
      orders_today: Math.floor(Math.random() * 500),
    },
    charts: {
      user_activity: generateMockChartData(24),
      order_trends: generateMockChartData(7),
    },
    timestamp: new Date().toISOString(),
    ...options,
  };
}

async function getAnalyticsData(options = {}) {
  return {
    events: {
      page_views: Math.floor(Math.random() * 10000),
      unique_visitors: Math.floor(Math.random() * 1000),
      bounce_rate: Math.random() * 100,
    },
    real_time: {
      active_users: Math.floor(Math.random() * 100),
      current_page_views: Math.floor(Math.random() * 50),
    },
    timestamp: new Date().toISOString(),
    ...options,
  };
}

async function getMonitoringData() {
  return {
    system: {
      cpu_usage: Math.random() * 100,
      memory_usage: Math.random() * 100,
      disk_usage: Math.random() * 100,
    },
    connections: getConnectionStats(),
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  };
}

function generateMockChartData(points) {
  return Array.from({ length: points }, (_, i) => ({
    timestamp: new Date(Date.now() - (points - i) * 3600000).toISOString(),
    value: Math.random() * 100,
  }));
}

// Start periodic cleanup
setInterval(cleanupInactiveConnections, 5 * 60 * 1000); // Every 5 minutes

module.exports = {
  initializeSocketHandlers,
  broadcastDashboardUpdate,
  broadcastAnalyticsEvent,
  broadcastMetrics,
  getConnectionStats,
  cleanupInactiveConnections,
};

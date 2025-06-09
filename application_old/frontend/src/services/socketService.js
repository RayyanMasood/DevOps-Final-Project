/**
 * WebSocket Service
 * Handles real-time communication with the backend via Socket.IO
 */

import io from 'socket.io-client';

class SocketService {
  constructor() {
    this.socket = null;
    this.isConnected = false;
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 5;
    this.listeners = new Map();
  }

  /**
   * Connect to WebSocket server
   */
  connect(url = 'ws://localhost:3001') {
    if (this.socket) {
      console.warn('Socket already connected');
      return;
    }

    console.log('Connecting to WebSocket server:', url);

    this.socket = io(url, {
      transports: ['websocket', 'polling'],
      timeout: 20000,
      reconnection: true,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
      maxReconnectionAttempts: this.maxReconnectAttempts,
    });

    this.setupEventListeners();
  }

  /**
   * Setup default event listeners
   */
  setupEventListeners() {
    if (!this.socket) return;

    // Connection events
    this.socket.on('connect', () => {
      console.log('WebSocket connected:', this.socket.id);
      this.isConnected = true;
      this.reconnectAttempts = 0;
      this.emit('connect');
    });

    this.socket.on('disconnect', (reason) => {
      console.log('WebSocket disconnected:', reason);
      this.isConnected = false;
      this.emit('disconnect', reason);
    });

    this.socket.on('reconnect', (attemptNumber) => {
      console.log('WebSocket reconnected after', attemptNumber, 'attempts');
      this.isConnected = true;
      this.reconnectAttempts = 0;
      this.emit('reconnect');
    });

    this.socket.on('reconnect_attempt', (attemptNumber) => {
      console.log('WebSocket reconnection attempt:', attemptNumber);
      this.reconnectAttempts = attemptNumber;
    });

    this.socket.on('reconnect_error', (error) => {
      console.error('WebSocket reconnection error:', error);
    });

    this.socket.on('reconnect_failed', () => {
      console.error('WebSocket reconnection failed');
      this.emit('reconnect_failed');
    });

    // Welcome message
    this.socket.on('welcome', (data) => {
      console.log('Welcome message received:', data);
      this.emit('welcome', data);
    });

    // Error handling
    this.socket.on('error', (error) => {
      console.error('WebSocket error:', error);
      this.emit('error', error);
    });

    // Room events
    this.socket.on('room-joined', (data) => {
      console.log('Joined room:', data.room);
      this.emit('room-joined', data);
    });

    this.socket.on('room-left', (data) => {
      console.log('Left room:', data.room);
      this.emit('room-left', data);
    });

    // Dashboard events
    this.socket.on('dashboard-data', (data) => {
      this.emit('dashboard-data', data);
    });

    this.socket.on('dashboard-update', (data) => {
      this.emit('dashboard-update', data);
    });

    this.socket.on('initial-dashboard-data', (data) => {
      this.emit('initial-dashboard-data', data);
    });

    this.socket.on('real-time-update', (data) => {
      this.emit('real-time-update', data);
    });

    this.socket.on('kpi-update', (data) => {
      this.emit('kpi-update', data);
    });

    // Analytics events
    this.socket.on('analytics-data', (data) => {
      this.emit('analytics-data', data);
    });

    this.socket.on('analytics-event', (data) => {
      this.emit('analytics-event', data);
    });

    this.socket.on('analytics-events', (data) => {
      this.emit('analytics-events', data);
    });

    // Monitoring events
    this.socket.on('metrics-update', (data) => {
      this.emit('metrics-update', data);
    });

    this.socket.on('subscribed-metrics', (data) => {
      this.emit('subscribed-metrics', data);
    });

    this.socket.on('system-health', (data) => {
      this.emit('system-health', data);
    });

    // Ping/Pong for connection health
    this.socket.on('pong', (data) => {
      this.emit('pong', data);
    });

    // Alerts and notifications
    this.socket.on('alert', (data) => {
      this.emit('alert', data);
    });
  }

  /**
   * Disconnect from WebSocket server
   */
  disconnect() {
    if (this.socket) {
      console.log('Disconnecting from WebSocket server');
      this.socket.disconnect();
      this.socket = null;
      this.isConnected = false;
    }
  }

  /**
   * Emit event to server
   */
  emit(event, data) {
    if (this.socket && this.isConnected) {
      this.socket.emit(event, data);
    } else {
      console.warn('Cannot emit event, socket not connected:', event);
    }
  }

  /**
   * Listen for events
   */
  on(event, callback) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event).add(callback);

    // Also add to socket if connected
    if (this.socket) {
      this.socket.on(event, callback);
    }
  }

  /**
   * Remove event listener
   */
  off(event, callback) {
    if (this.listeners.has(event)) {
      this.listeners.get(event).delete(callback);
    }

    // Also remove from socket if connected
    if (this.socket) {
      this.socket.off(event, callback);
    }
  }

  /**
   * Remove all listeners for an event
   */
  removeAllListeners(event) {
    if (this.listeners.has(event)) {
      this.listeners.get(event).clear();
    }

    if (this.socket) {
      this.socket.removeAllListeners(event);
    }
  }

  /**
   * Join a room
   */
  joinRoom(roomName) {
    this.emit('join-room', roomName);
  }

  /**
   * Leave a room
   */
  leaveRoom(roomName) {
    this.emit('leave-room', roomName);
  }

  /**
   * Subscribe to specific metrics
   */
  subscribeToMetrics(metrics) {
    this.emit('subscribe-metrics', metrics);
  }

  /**
   * Request dashboard data
   */
  requestDashboardData(options = {}) {
    this.emit('request-dashboard-data', options);
  }

  /**
   * Request analytics data
   */
  requestAnalyticsData(options = {}) {
    this.emit('request-analytics-data', options);
  }

  /**
   * Update dashboard filters
   */
  updateDashboardFilters(filters) {
    this.emit('update-dashboard-filters', filters);
  }

  /**
   * Send ping to check connection
   */
  ping() {
    this.emit('ping');
  }

  /**
   * Get connection status
   */
  getConnectionStatus() {
    return {
      connected: this.isConnected,
      reconnectAttempts: this.reconnectAttempts,
      socketId: this.socket?.id,
    };
  }

  /**
   * Check if connected
   */
  isSocketConnected() {
    return this.isConnected && this.socket && this.socket.connected;
  }
}

// Create singleton instance
const socketService = new SocketService();

export { socketService };
export default socketService;

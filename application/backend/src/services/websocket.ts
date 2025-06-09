import { Server as SocketIOServer } from 'socket.io';
import { logger } from '../utils/logger';

export const setupWebSocketHandlers = (io: SocketIOServer) => {
  io.on('connection', (socket) => {
    logger.info('Client connected', { socketId: socket.id });

    socket.on('disconnect', () => {
      logger.info('Client disconnected', { socketId: socket.id });
    });

    // TODO: Add more WebSocket event handlers as needed
    socket.on('ping', (callback) => {
      callback('pong');
    });
  });
}; 
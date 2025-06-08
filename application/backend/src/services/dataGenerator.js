/**
 * Data Generator Service
 * Generates real-time sample data for dashboard demonstrations
 */

const cron = require('node-cron');
const { postgresql } = require('../models');
const logger = require('../utils/logger');

let isGeneratorRunning = false;

/**
 * Start the real-time data generator
 */
function startDataGenerator(io) {
  if (isGeneratorRunning) {
    logger.warn('Data generator is already running');
    return;
  }

  isGeneratorRunning = true;
  logger.info('Starting real-time data generator');

  // Generate metrics every 30 seconds
  cron.schedule('*/30 * * * * *', () => {
    generateMetrics(io);
  });

  // Generate analytics events every minute
  cron.schedule('0 * * * * *', () => {
    generateAnalyticsEvents(io);
  });

  // Generate real-time data every 10 seconds
  cron.schedule('*/10 * * * * *', () => {
    generateRealTimeData(io);
  });

  logger.info('Data generator scheduled tasks started');
}

/**
 * Generate sample performance metrics
 */
async function generateMetrics(io) {
  try {
    const metrics = [
      {
        metric_name: 'cpu_usage',
        metric_type: 'gauge',
        value: Math.random() * 100,
        unit: 'percent',
        source: 'system',
        tags: { hostname: 'web-server-1' },
      },
      {
        metric_name: 'memory_usage',
        metric_type: 'gauge',
        value: Math.random() * 100,
        unit: 'percent',
        source: 'system',
        tags: { hostname: 'web-server-1' },
      },
      {
        metric_name: 'response_time',
        metric_type: 'histogram',
        value: Math.random() * 1000 + 50,
        unit: 'milliseconds',
        source: 'application',
        tags: { endpoint: '/api/dashboard' },
      },
      {
        metric_name: 'request_count',
        metric_type: 'counter',
        value: Math.floor(Math.random() * 100),
        unit: 'requests',
        source: 'application',
        tags: { status_code: '200' },
      },
    ];

    for (const metric of metrics) {
      await postgresql.PerformanceMetric.create(metric);
    }

    // Broadcast to connected clients
    io.to('monitoring').emit('metrics-update', {
      metrics,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    logger.error('Failed to generate metrics:', error);
  }
}

/**
 * Generate sample analytics events
 */
async function generateAnalyticsEvents(io) {
  try {
    const events = [
      {
        session_id: generateUUID(),
        event_type: 'page_view',
        event_name: 'dashboard_view',
        page_url: '/dashboard',
        device_type: getRandomChoice(['desktop', 'mobile', 'tablet']),
        browser: getRandomChoice(['Chrome', 'Firefox', 'Safari', 'Edge']),
        country: getRandomChoice(['US', 'CA', 'GB', 'DE', 'FR']),
        event_data: {
          page_load_time: Math.random() * 3000 + 500,
          user_agent: 'Mozilla/5.0...',
        },
      },
      {
        session_id: generateUUID(),
        event_type: 'user_action',
        event_name: 'button_click',
        page_url: '/dashboard',
        device_type: getRandomChoice(['desktop', 'mobile', 'tablet']),
        browser: getRandomChoice(['Chrome', 'Firefox', 'Safari', 'Edge']),
        country: getRandomChoice(['US', 'CA', 'GB', 'DE', 'FR']),
        event_data: {
          button_id: 'refresh_dashboard',
          element_text: 'Refresh',
        },
      },
    ];

    for (const event of events) {
      await postgresql.AnalyticsEvent.create(event);
    }

    // Broadcast to connected clients
    io.to('analytics').emit('analytics-events', {
      events,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    logger.error('Failed to generate analytics events:', error);
  }
}

/**
 * Generate real-time dashboard data
 */
async function generateRealTimeData(io) {
  try {
    const realTimeData = [
      {
        data_type: 'kpi',
        data_source: 'sales',
        value: {
          revenue: Math.random() * 10000 + 5000,
          orders: Math.floor(Math.random() * 100) + 50,
          conversion_rate: Math.random() * 5 + 2,
        },
      },
      {
        data_type: 'status',
        data_source: 'system',
        value: {
          active_users: Math.floor(Math.random() * 1000) + 100,
          server_load: Math.random() * 100,
          error_rate: Math.random() * 5,
        },
      },
    ];

    for (const data of realTimeData) {
      await postgresql.RealTimeData.create(data);
    }

    // Broadcast to dashboard clients
    io.to('dashboard').emit('real-time-update', {
      data: realTimeData,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    logger.error('Failed to generate real-time data:', error);
  }
}

/**
 * Generate a simple UUID
 */
function generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

/**
 * Get random choice from array
 */
function getRandomChoice(array) {
  return array[Math.floor(Math.random() * array.length)];
}

/**
 * Stop the data generator
 */
function stopDataGenerator() {
  isGeneratorRunning = false;
  logger.info('Data generator stopped');
}

module.exports = {
  startDataGenerator,
  stopDataGenerator,
};

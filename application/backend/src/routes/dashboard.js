/**
 * Dashboard Routes
 * Endpoints for BI dashboard data and real-time updates
 */

const express = require('express');
const { query, param } = require('express-validator');
const { Op, QueryTypes } = require('sequelize');
const moment = require('moment');

const { mysql, postgresql, sequelize } = require('../models');
const validateRequest = require('../middleware/validateRequest');
const logger = require('../utils/logger');

const router = express.Router();

// Main dashboard endpoint with aggregated data
router.get('/', [
  query('period').optional().isIn(['1h', '6h', '24h', '7d', '30d']).withMessage('Period must be 1h, 6h, 24h, 7d, or 30d'),
  query('timezone').optional().isString(),
  validateRequest,
], async (req, res) => {
  try {
    const period = req.query.period || '24h';
    const timezone = req.query.timezone || 'UTC';
    const periodMap = {
      '1h': { hours: 1 },
      '6h': { hours: 6 },
      '24h': { hours: 24 },
      '7d': { days: 7 },
      '30d': { days: 30 },
    };

    const startTime = moment().subtract(periodMap[period]).toDate();
    const now = new Date();

    // Parallel data fetching for better performance
    const [
      userStats,
      orderStats,
      productStats,
      analyticsStats,
      performanceStats,
      realtimeData
    ] = await Promise.all([
      getUserStats(startTime, now),
      getOrderStats(startTime, now),
      getProductStats(),
      getAnalyticsStats(startTime, now),
      getPerformanceStats(startTime, now),
      getRealTimeData()
    ]);

    // Calculate KPIs
    const kpis = {
      total_users: userStats.total_users,
      new_users_period: userStats.new_users,
      total_orders: orderStats.total_orders,
      orders_period: orderStats.orders_period,
      revenue_period: parseFloat(orderStats.revenue_period || 0),
      average_order_value: parseFloat(orderStats.average_order_value || 0),
      total_products: productStats.total_products,
      low_stock_products: productStats.low_stock_count,
      total_events: analyticsStats.total_events,
      unique_sessions: analyticsStats.unique_sessions,
      avg_response_time: performanceStats.avg_response_time,
      error_rate: performanceStats.error_rate,
    };

    // Growth calculations
    const growth = await calculateGrowthMetrics(period);

    res.json({
      timestamp: new Date().toISOString(),
      period,
      timezone,
      kpis,
      growth,
      charts: {
        user_activity: userStats.activity_chart,
        order_trends: orderStats.trends_chart,
        revenue_chart: orderStats.revenue_chart,
        analytics_events: analyticsStats.events_chart,
        performance_metrics: performanceStats.metrics_chart,
      },
      real_time: realtimeData,
      summary: {
        total_records: {
          users: userStats.total_users,
          orders: orderStats.total_orders,
          products: productStats.total_products,
          events: analyticsStats.total_events,
          metrics: performanceStats.total_metrics,
        },
        health_status: await getSystemHealthSummary(),
      },
    });
  } catch (error) {
    logger.error('Dashboard data fetch failed:', error);
    res.status(500).json({
      error: 'Failed to fetch dashboard data',
      message: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Real-time dashboard updates endpoint
router.get('/real-time', async (req, res) => {
  try {
    const data = await getRealTimeData();
    const currentMetrics = await getCurrentMetrics();
    
    res.json({
      timestamp: new Date().toISOString(),
      real_time_data: data,
      current_metrics: currentMetrics,
      system_status: await getSystemHealthSummary(),
      active_connections: getActiveConnectionsCount(),
    });
  } catch (error) {
    logger.error('Real-time dashboard data fetch failed:', error);
    res.status(500).json({
      error: 'Failed to fetch real-time data',
      message: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// KPIs endpoint
router.get('/kpis', [
  query('period').optional().isIn(['1h', '6h', '24h', '7d', '30d']),
  validateRequest,
], async (req, res) => {
  try {
    const period = req.query.period || '24h';
    const periodMap = {
      '1h': { hours: 1 },
      '6h': { hours: 6 },
      '24h': { hours: 24 },
      '7d': { days: 7 },
      '30d': { days: 30 },
    };

    const startTime = moment().subtract(periodMap[period]).toDate();
    const previousPeriodStart = moment(startTime).subtract(periodMap[period]).toDate();

    // Current period KPIs
    const currentKPIs = await calculateKPIs(startTime, new Date());
    
    // Previous period KPIs for comparison
    const previousKPIs = await calculateKPIs(previousPeriodStart, startTime);

    // Calculate percentage changes
    const kpisWithGrowth = Object.keys(currentKPIs).reduce((acc, key) => {
      const current = currentKPIs[key] || 0;
      const previous = previousKPIs[key] || 0;
      const change = previous === 0 ? 0 : ((current - previous) / previous * 100);
      
      acc[key] = {
        current,
        previous,
        change: parseFloat(change.toFixed(2)),
        trend: change > 0 ? 'up' : change < 0 ? 'down' : 'stable',
      };
      return acc;
    }, {});

    res.json({
      timestamp: new Date().toISOString(),
      period,
      kpis: kpisWithGrowth,
    });
  } catch (error) {
    logger.error('KPIs fetch failed:', error);
    res.status(500).json({
      error: 'Failed to fetch KPIs',
      message: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Chart data endpoint
router.get('/charts/:type', [
  param('type').isIn(['users', 'orders', 'revenue', 'analytics', 'performance']),
  query('period').optional().isIn(['1h', '6h', '24h', '7d', '30d']),
  query('interval').optional().isIn(['5m', '15m', '1h', '6h', '1d']),
  validateRequest,
], async (req, res) => {
  try {
    const { type } = req.params;
    const period = req.query.period || '24h';
    const interval = req.query.interval || getDefaultInterval(period);

    const chartData = await getChartData(type, period, interval);

    res.json({
      timestamp: new Date().toISOString(),
      type,
      period,
      interval,
      data: chartData,
    });
  } catch (error) {
    logger.error(`Chart data fetch failed for type ${req.params.type}:`, error);
    res.status(500).json({
      error: `Failed to fetch ${req.params.type} chart data`,
      message: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Export dashboard data
router.get('/export', [
  query('format').optional().isIn(['json', 'csv']).withMessage('Format must be json or csv'),
  query('period').optional().isIn(['24h', '7d', '30d']),
  validateRequest,
], async (req, res) => {
  try {
    const format = req.query.format || 'json';
    const period = req.query.period || '24h';
    
    const data = await getExportData(period);
    
    if (format === 'csv') {
      const csv = convertToCSV(data);
      res.set({
        'Content-Type': 'text/csv',
        'Content-Disposition': `attachment; filename="dashboard-export-${period}-${moment().format('YYYY-MM-DD')}.csv"`,
      });
      res.send(csv);
    } else {
      res.set({
        'Content-Type': 'application/json',
        'Content-Disposition': `attachment; filename="dashboard-export-${period}-${moment().format('YYYY-MM-DD')}.json"`,
      });
      res.json(data);
    }
  } catch (error) {
    logger.error('Dashboard export failed:', error);
    res.status(500).json({
      error: 'Failed to export dashboard data',
      message: error.message,
    });
  }
});

// Helper functions

async function getUserStats(startTime, endTime) {
  try {
    const [totalUsers] = await sequelize.mysql.query(`
      SELECT COUNT(*) as total_users FROM users WHERE deleted_at IS NULL
    `, { type: QueryTypes.SELECT });

    const [newUsers] = await sequelize.mysql.query(`
      SELECT COUNT(*) as new_users FROM users 
      WHERE created_at BETWEEN :startTime AND :endTime AND deleted_at IS NULL
    `, {
      replacements: { startTime, endTime },
      type: QueryTypes.SELECT
    });

    const activityChart = await sequelize.mysql.query(`
      SELECT 
        DATE_FORMAT(created_at, '%Y-%m-%d %H:00:00') as hour,
        COUNT(*) as count
      FROM users 
      WHERE created_at BETWEEN :startTime AND :endTime AND deleted_at IS NULL
      GROUP BY hour
      ORDER BY hour
    `, {
      replacements: { startTime, endTime },
      type: QueryTypes.SELECT
    });

    return {
      total_users: totalUsers.total_users,
      new_users: newUsers.new_users,
      activity_chart: activityChart,
    };
  } catch (error) {
    logger.error('getUserStats failed:', error);
    return { total_users: 0, new_users: 0, activity_chart: [] };
  }
}

async function getOrderStats(startTime, endTime) {
  try {
    const [totalOrders] = await sequelize.mysql.query(`
      SELECT COUNT(*) as total_orders FROM orders WHERE deleted_at IS NULL
    `, { type: QueryTypes.SELECT });

    const [periodStats] = await sequelize.mysql.query(`
      SELECT 
        COUNT(*) as orders_period,
        SUM(total_amount) as revenue_period,
        AVG(total_amount) as average_order_value
      FROM orders 
      WHERE order_date BETWEEN :startTime AND :endTime AND deleted_at IS NULL
    `, {
      replacements: { startTime, endTime },
      type: QueryTypes.SELECT
    });

    const trendsChart = await sequelize.mysql.query(`
      SELECT 
        DATE_FORMAT(order_date, '%Y-%m-%d') as date,
        COUNT(*) as orders,
        SUM(total_amount) as revenue
      FROM orders 
      WHERE order_date BETWEEN :startTime AND :endTime AND deleted_at IS NULL
      GROUP BY date
      ORDER BY date
    `, {
      replacements: { startTime, endTime },
      type: QueryTypes.SELECT
    });

    return {
      total_orders: totalOrders.total_orders,
      orders_period: periodStats.orders_period || 0,
      revenue_period: periodStats.revenue_period || 0,
      average_order_value: periodStats.average_order_value || 0,
      trends_chart: trendsChart,
      revenue_chart: trendsChart.map(item => ({
        date: item.date,
        revenue: parseFloat(item.revenue || 0),
      })),
    };
  } catch (error) {
    logger.error('getOrderStats failed:', error);
    return {
      total_orders: 0,
      orders_period: 0,
      revenue_period: 0,
      average_order_value: 0,
      trends_chart: [],
      revenue_chart: [],
    };
  }
}

async function getProductStats() {
  try {
    const [stats] = await sequelize.mysql.query(`
      SELECT 
        COUNT(*) as total_products,
        SUM(CASE WHEN stock_quantity < 10 THEN 1 ELSE 0 END) as low_stock_count,
        AVG(price) as average_price
      FROM products 
      WHERE deleted_at IS NULL AND is_active = 1
    `, { type: QueryTypes.SELECT });

    return stats;
  } catch (error) {
    logger.error('getProductStats failed:', error);
    return { total_products: 0, low_stock_count: 0, average_price: 0 };
  }
}

async function getAnalyticsStats(startTime, endTime) {
  try {
    const [totalEvents] = await sequelize.postgresql.query(`
      SELECT COUNT(*) as total_events FROM analytics_events
    `, { type: QueryTypes.SELECT });

    const [periodStats] = await sequelize.postgresql.query(`
      SELECT 
        COUNT(*) as events_period,
        COUNT(DISTINCT session_id) as unique_sessions
      FROM analytics_events 
      WHERE timestamp BETWEEN :startTime AND :endTime
    `, {
      replacements: { startTime, endTime },
      type: QueryTypes.SELECT
    });

    const eventsChart = await sequelize.postgresql.query(`
      SELECT 
        DATE_TRUNC('hour', timestamp) as hour,
        COUNT(*) as count,
        event_type
      FROM analytics_events 
      WHERE timestamp BETWEEN :startTime AND :endTime
      GROUP BY hour, event_type
      ORDER BY hour
    `, {
      replacements: { startTime, endTime },
      type: QueryTypes.SELECT
    });

    return {
      total_events: totalEvents.total_events,
      events_period: periodStats.events_period || 0,
      unique_sessions: periodStats.unique_sessions || 0,
      events_chart: eventsChart,
    };
  } catch (error) {
    logger.error('getAnalyticsStats failed:', error);
    return {
      total_events: 0,
      events_period: 0,
      unique_sessions: 0,
      events_chart: [],
    };
  }
}

async function getPerformanceStats(startTime, endTime) {
  try {
    const [stats] = await sequelize.postgresql.query(`
      SELECT 
        COUNT(*) as total_metrics,
        AVG(CASE WHEN metric_name = 'response_time' THEN value END) as avg_response_time,
        AVG(CASE WHEN metric_name = 'error_rate' THEN value END) as error_rate
      FROM performance_metrics 
      WHERE timestamp BETWEEN :startTime AND :endTime
    `, {
      replacements: { startTime, endTime },
      type: QueryTypes.SELECT
    });

    const metricsChart = await sequelize.postgresql.query(`
      SELECT 
        DATE_TRUNC('hour', timestamp) as hour,
        metric_name,
        AVG(value) as avg_value
      FROM performance_metrics 
      WHERE timestamp BETWEEN :startTime AND :endTime
      GROUP BY hour, metric_name
      ORDER BY hour
    `, {
      replacements: { startTime, endTime },
      type: QueryTypes.SELECT
    });

    return {
      total_metrics: stats.total_metrics || 0,
      avg_response_time: parseFloat(stats.avg_response_time || 0),
      error_rate: parseFloat(stats.error_rate || 0),
      metrics_chart: metricsChart,
    };
  } catch (error) {
    logger.error('getPerformanceStats failed:', error);
    return {
      total_metrics: 0,
      avg_response_time: 0,
      error_rate: 0,
      metrics_chart: [],
    };
  }
}

async function getRealTimeData() {
  try {
    const data = await sequelize.postgresql.query(`
      SELECT data_type, data_source, value, timestamp
      FROM real_time_data 
      WHERE timestamp > NOW() - INTERVAL '1 hour'
      ORDER BY timestamp DESC
      LIMIT 100
    `, { type: QueryTypes.SELECT });

    return data;
  } catch (error) {
    logger.error('getRealTimeData failed:', error);
    return [];
  }
}

async function getCurrentMetrics() {
  // Return current system metrics
  return {
    cpu_usage: Math.random() * 100, // Simulated
    memory_usage: (process.memoryUsage().heapUsed / process.memoryUsage().heapTotal * 100),
    active_connections: getActiveConnectionsCount(),
    timestamp: new Date().toISOString(),
  };
}

async function getSystemHealthSummary() {
  const { getDatabaseHealth } = require('../database/connection');
  
  try {
    const dbHealth = await getDatabaseHealth();
    return {
      overall: Object.values(dbHealth).every(db => db.status === 'healthy') ? 'healthy' : 'degraded',
      databases: dbHealth,
      uptime: process.uptime(),
    };
  } catch (error) {
    return { overall: 'unknown', error: error.message };
  }
}

function getActiveConnectionsCount() {
  // This would typically come from a connection pool or monitoring system
  return Math.floor(Math.random() * 50) + 10; // Simulated
}

async function calculateKPIs(startTime, endTime) {
  // Implementation would aggregate data across all sources
  return {
    revenue: Math.random() * 100000,
    orders: Math.floor(Math.random() * 1000),
    users: Math.floor(Math.random() * 500),
    conversion_rate: Math.random() * 10,
    avg_session_duration: Math.random() * 600,
  };
}

async function calculateGrowthMetrics(period) {
  // Implementation would calculate period-over-period growth
  return {
    revenue_growth: (Math.random() - 0.5) * 40,
    user_growth: (Math.random() - 0.5) * 30,
    order_growth: (Math.random() - 0.5) * 50,
  };
}

function getDefaultInterval(period) {
  const intervalMap = {
    '1h': '5m',
    '6h': '15m',
    '24h': '1h',
    '7d': '6h',
    '30d': '1d',
  };
  return intervalMap[period] || '1h';
}

async function getChartData(type, period, interval) {
  // Implementation would return chart data based on type
  const dataPoints = 20;
  return Array.from({ length: dataPoints }, (_, i) => ({
    timestamp: moment().subtract(dataPoints - i, 'hours').toISOString(),
    value: Math.random() * 100,
  }));
}

async function getExportData(period) {
  // Implementation would aggregate all dashboard data for export
  return {
    exported_at: new Date().toISOString(),
    period,
    data: {
      summary: 'Export data would be here',
    },
  };
}

function convertToCSV(data) {
  // Simple CSV conversion
  return 'timestamp,metric,value\n' + 
         Object.entries(data).map(([key, value]) => 
           `${new Date().toISOString()},${key},${value}`
         ).join('\n');
}

module.exports = router;

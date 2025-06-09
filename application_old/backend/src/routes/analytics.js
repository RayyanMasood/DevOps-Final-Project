/**
 * Analytics Routes
 * Endpoints for analytics events and dashboard data
 */

const express = require('express');
const { postgresql } = require('../models');
const logger = require('../utils/logger');

const router = express.Router();

// Track analytics event
router.post('/events', async (req, res) => {
  try {
    const event = await postgresql.AnalyticsEvent.create(req.body);
    
    // Broadcast real-time event
    if (global.io) {
      global.io.to('analytics').emit('analytics-event', event);
    }
    
    res.status(201).json({ event });
  } catch (error) {
    logger.error('Track analytics event failed:', error);
    res.status(500).json({ error: 'Failed to track event' });
  }
});

// Get analytics dashboard data
router.get('/dashboard', async (req, res) => {
  try {
    const events = await postgresql.AnalyticsEvent.findAll({
      limit: 100,
      order: [['timestamp', 'DESC']],
    });
    
    res.json({ events });
  } catch (error) {
    logger.error('Get analytics dashboard failed:', error);
    res.status(500).json({ error: 'Failed to fetch analytics data' });
  }
});

module.exports = router;

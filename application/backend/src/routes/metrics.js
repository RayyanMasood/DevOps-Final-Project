/**
 * Metrics Routes
 * Performance metrics and monitoring data
 */

const express = require('express');
const { postgresql } = require('../models');
const logger = require('../utils/logger');

const router = express.Router();

// Submit performance metric
router.post('/', async (req, res) => {
  try {
    const metric = await postgresql.PerformanceMetric.create(req.body);
    
    // Broadcast real-time metric
    if (global.io) {
      global.io.to('monitoring').emit('metrics-update', [metric]);
    }
    
    res.status(201).json({ metric });
  } catch (error) {
    logger.error('Submit metric failed:', error);
    res.status(500).json({ error: 'Failed to submit metric' });
  }
});

// Get metrics dashboard
router.get('/dashboard', async (req, res) => {
  try {
    const metrics = await postgresql.PerformanceMetric.findAll({
      limit: 100,
      order: [['timestamp', 'DESC']],
    });
    
    res.json({ metrics });
  } catch (error) {
    logger.error('Get metrics dashboard failed:', error);
    res.status(500).json({ error: 'Failed to fetch metrics' });
  }
});

module.exports = router;

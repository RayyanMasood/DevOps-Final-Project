/**
 * Orders Routes
 * CRUD operations for order management
 */

const express = require('express');
const { body, query, param } = require('express-validator');
const { Op } = require('sequelize');
const { mysql } = require('../models');
const validateRequest = require('../middleware/validateRequest');
const logger = require('../utils/logger');

const router = express.Router();

// Get all orders with pagination and filtering
router.get('/', [
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 1000 }),
  query('status').optional().isIn(['pending', 'processing', 'shipped', 'delivered', 'cancelled']),
  query('user_id').optional().isInt(),
  query('start_date').optional().isISO8601(),
  query('end_date').optional().isISO8601(),
  validateRequest,
], async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const offset = (page - 1) * limit;
    
    const where = {};
    if (req.query.status) where.status = req.query.status;
    if (req.query.user_id) where.user_id = req.query.user_id;
    if (req.query.start_date || req.query.end_date) {
      where.order_date = {};
      if (req.query.start_date) where.order_date[Op.gte] = new Date(req.query.start_date);
      if (req.query.end_date) where.order_date[Op.lte] = new Date(req.query.end_date);
    }

    const { count, rows } = await mysql.Order.findAndCountAll({
      where,
      include: [{ model: mysql.User, as: 'user', attributes: ['id', 'username', 'email'] }],
      limit,
      offset,
      order: [['created_at', 'DESC']],
    });

    res.json({
      orders: rows,
      pagination: {
        current_page: page,
        total_pages: Math.ceil(count / limit),
        total_records: count,
        per_page: limit,
      },
    });
  } catch (error) {
    logger.error('Get orders failed:', error);
    res.status(500).json({ error: 'Failed to fetch orders', message: error.message });
  }
});

// Get order statistics
router.get('/stats', async (req, res) => {
  try {
    const stats = await mysql.Order.findAll({
      attributes: [
        'status',
        [mysql.Order.sequelize.fn('COUNT', '*'), 'count'],
        [mysql.Order.sequelize.fn('SUM', mysql.Order.sequelize.col('total_amount')), 'total_revenue'],
      ],
      group: ['status'],
      raw: true,
    });

    res.json({
      statistics: stats,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Get order stats failed:', error);
    res.status(500).json({ error: 'Failed to fetch order statistics', message: error.message });
  }
});

module.exports = router;

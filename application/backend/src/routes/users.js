/**
 * Users Routes
 * CRUD operations for user management
 */

const express = require('express');
const { body, query, param } = require('express-validator');
const { Op } = require('sequelize');
const { mysql } = require('../models');
const validateRequest = require('../middleware/validateRequest');
const logger = require('../utils/logger');

const router = express.Router();

// Get all users with pagination and filtering
router.get('/', [
  query('page').optional().isInt({ min: 1 }).withMessage('Page must be a positive integer'),
  query('limit').optional().isInt({ min: 1, max: 1000 }).withMessage('Limit must be between 1 and 1000'),
  query('sort').optional().isIn(['id', 'username', 'email', 'created_at', 'last_login']),
  query('order').optional().isIn(['ASC', 'DESC']),
  query('status').optional().isIn(['active', 'inactive', 'suspended']),
  query('search').optional().isString(),
  validateRequest,
], async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const offset = (page - 1) * limit;
    const sort = req.query.sort || 'created_at';
    const order = req.query.order || 'DESC';
    const { status, search } = req.query;

    // Build where conditions
    const where = {};
    if (status) where.status = status;
    if (search) {
      where[Op.or] = [
        { username: { [Op.like]: `%${search}%` } },
        { email: { [Op.like]: `%${search}%` } },
        { first_name: { [Op.like]: `%${search}%` } },
        { last_name: { [Op.like]: `%${search}%` } },
      ];
    }

    const { count, rows } = await mysql.User.findAndCountAll({
      where,
      limit,
      offset,
      order: [[sort, order]],
      attributes: { exclude: ['deleted_at'] },
    });

    const totalPages = Math.ceil(count / limit);

    res.json({
      users: rows,
      pagination: {
        current_page: page,
        total_pages: totalPages,
        total_records: count,
        per_page: limit,
        has_next: page < totalPages,
        has_prev: page > 1,
      },
      filters: {
        status,
        search,
        sort,
        order,
      },
    });
  } catch (error) {
    logger.error('Get users failed:', error);
    res.status(500).json({
      error: 'Failed to fetch users',
      message: error.message,
    });
  }
});

// Get user by ID
router.get('/:id', [
  param('id').isInt().withMessage('User ID must be an integer'),
  validateRequest,
], async (req, res) => {
  try {
    const user = await mysql.User.findByPk(req.params.id, {
      include: [
        {
          model: mysql.Order,
          as: 'orders',
          limit: 10,
          order: [['created_at', 'DESC']],
        },
      ],
    });

    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        id: req.params.id,
      });
    }

    res.json({ user });
  } catch (error) {
    logger.error(`Get user ${req.params.id} failed:`, error);
    res.status(500).json({
      error: 'Failed to fetch user',
      message: error.message,
    });
  }
});

// Create new user
router.post('/', [
  body('username').isLength({ min: 3, max: 50 }).isAlphanumeric(),
  body('email').isEmail().normalizeEmail(),
  body('first_name').isLength({ min: 1, max: 50 }).trim(),
  body('last_name').isLength({ min: 1, max: 50 }).trim(),
  body('date_of_birth').optional().isISO8601().toDate(),
  body('status').optional().isIn(['active', 'inactive', 'suspended']),
  body('profile_data').optional().isObject(),
  validateRequest,
], async (req, res) => {
  try {
    const user = await mysql.User.create(req.body);
    
    logger.info(`User created: ${user.id} (${user.username})`);
    
    // Emit real-time update
    req.app.locals.io?.emit('user:created', {
      user: user.toJSON(),
      timestamp: new Date().toISOString(),
    });

    res.status(201).json({
      message: 'User created successfully',
      user,
    });
  } catch (error) {
    if (error.name === 'SequelizeUniqueConstraintError') {
      return res.status(400).json({
        error: 'User already exists',
        field: error.errors[0].path,
        value: error.errors[0].value,
      });
    }
    
    logger.error('Create user failed:', error);
    res.status(500).json({
      error: 'Failed to create user',
      message: error.message,
    });
  }
});

// Update user
router.put('/:id', [
  param('id').isInt().withMessage('User ID must be an integer'),
  body('username').optional().isLength({ min: 3, max: 50 }).isAlphanumeric(),
  body('email').optional().isEmail().normalizeEmail(),
  body('first_name').optional().isLength({ min: 1, max: 50 }).trim(),
  body('last_name').optional().isLength({ min: 1, max: 50 }).trim(),
  body('date_of_birth').optional().isISO8601().toDate(),
  body('status').optional().isIn(['active', 'inactive', 'suspended']),
  body('profile_data').optional().isObject(),
  validateRequest,
], async (req, res) => {
  try {
    const user = await mysql.User.findByPk(req.params.id);
    
    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        id: req.params.id,
      });
    }

    await user.update(req.body);
    
    logger.info(`User updated: ${user.id} (${user.username})`);
    
    // Emit real-time update
    req.app.locals.io?.emit('user:updated', {
      user: user.toJSON(),
      timestamp: new Date().toISOString(),
    });

    res.json({
      message: 'User updated successfully',
      user,
    });
  } catch (error) {
    if (error.name === 'SequelizeUniqueConstraintError') {
      return res.status(400).json({
        error: 'User data conflicts with existing user',
        field: error.errors[0].path,
        value: error.errors[0].value,
      });
    }
    
    logger.error(`Update user ${req.params.id} failed:`, error);
    res.status(500).json({
      error: 'Failed to update user',
      message: error.message,
    });
  }
});

// Delete user (soft delete)
router.delete('/:id', [
  param('id').isInt().withMessage('User ID must be an integer'),
  validateRequest,
], async (req, res) => {
  try {
    const user = await mysql.User.findByPk(req.params.id);
    
    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        id: req.params.id,
      });
    }

    await user.destroy(); // Soft delete due to paranoid: true
    
    logger.info(`User deleted: ${user.id} (${user.username})`);
    
    // Emit real-time update
    req.app.locals.io?.emit('user:deleted', {
      user_id: user.id,
      username: user.username,
      timestamp: new Date().toISOString(),
    });

    res.json({
      message: 'User deleted successfully',
      id: req.params.id,
    });
  } catch (error) {
    logger.error(`Delete user ${req.params.id} failed:`, error);
    res.status(500).json({
      error: 'Failed to delete user',
      message: error.message,
    });
  }
});

// Get user statistics
router.get('/stats', async (req, res) => {
  try {
    const stats = await mysql.User.findAll({
      attributes: [
        'status',
        [mysql.User.sequelize.fn('COUNT', '*'), 'count'],
      ],
      group: ['status'],
      raw: true,
    });

    const totalUsers = await mysql.User.count();
    const recentUsers = await mysql.User.count({
      where: {
        created_at: {
          [Op.gte]: new Date(Date.now() - 24 * 60 * 60 * 1000), // Last 24 hours
        },
      },
    });

    const avgLoginCount = await mysql.User.findOne({
      attributes: [
        [mysql.User.sequelize.fn('AVG', mysql.User.sequelize.col('login_count')), 'avg_logins'],
      ],
      raw: true,
    });

    res.json({
      total_users: totalUsers,
      recent_users_24h: recentUsers,
      average_login_count: parseFloat(avgLoginCount.avg_logins || 0),
      status_distribution: stats.reduce((acc, stat) => {
        acc[stat.status] = parseInt(stat.count);
        return acc;
      }, {}),
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Get user stats failed:', error);
    res.status(500).json({
      error: 'Failed to fetch user statistics',
      message: error.message,
    });
  }
});

module.exports = router;

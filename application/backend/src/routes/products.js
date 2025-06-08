/**
 * Products Routes
 * CRUD operations for product management
 */

const express = require('express');
const { mysql } = require('../models');
const validateRequest = require('../middleware/validateRequest');
const logger = require('../utils/logger');

const router = express.Router();

// Basic CRUD operations for products
router.get('/', async (req, res) => {
  try {
    const products = await mysql.Product.findAll({ where: { is_active: true } });
    res.json({ products });
  } catch (error) {
    logger.error('Get products failed:', error);
    res.status(500).json({ error: 'Failed to fetch products' });
  }
});

router.get('/stats', async (req, res) => {
  try {
    const stats = {
      total_products: await mysql.Product.count({ where: { is_active: true } }),
      low_stock_count: await mysql.Product.count({ where: { stock_quantity: { [mysql.Product.sequelize.Op.lt]: 10 } } }),
    };
    res.json(stats);
  } catch (error) {
    logger.error('Get product stats failed:', error);
    res.status(500).json({ error: 'Failed to fetch product statistics' });
  }
});

module.exports = router;

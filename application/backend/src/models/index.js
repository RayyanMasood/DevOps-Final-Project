/**
 * Database Models Index
 * Exports all models for both MySQL and PostgreSQL databases
 */

const { DataTypes } = require('sequelize');
const { sequelize } = require('../database/connection');

// MySQL Models
const mysqlModels = {};

// User model (MySQL)
mysqlModels.User = sequelize.mysql.define('User', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true,
  },
  username: {
    type: DataTypes.STRING(50),
    allowNull: false,
    unique: true,
    validate: {
      len: [3, 50],
      isAlphanumeric: true,
    },
  },
  email: {
    type: DataTypes.STRING(100),
    allowNull: false,
    unique: true,
    validate: {
      isEmail: true,
    },
  },
  first_name: {
    type: DataTypes.STRING(50),
    allowNull: false,
    validate: {
      len: [1, 50],
    },
  },
  last_name: {
    type: DataTypes.STRING(50),
    allowNull: false,
    validate: {
      len: [1, 50],
    },
  },
  date_of_birth: {
    type: DataTypes.DATEONLY,
    allowNull: true,
  },
  status: {
    type: DataTypes.ENUM('active', 'inactive', 'suspended'),
    defaultValue: 'active',
  },
  last_login: {
    type: DataTypes.DATE,
    allowNull: true,
  },
  login_count: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
  },
  profile_data: {
    type: DataTypes.JSON,
    allowNull: true,
  },
}, {
  tableName: 'users',
  indexes: [
    { fields: ['email'] },
    { fields: ['username'] },
    { fields: ['status'] },
    { fields: ['last_login'] },
  ],
});

// Order model (MySQL) - E-commerce style data
mysqlModels.Order = sequelize.mysql.define('Order', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true,
  },
  user_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: mysqlModels.User,
      key: 'id',
    },
  },
  order_number: {
    type: DataTypes.STRING(20),
    allowNull: false,
    unique: true,
  },
  total_amount: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    validate: {
      min: 0,
    },
  },
  currency: {
    type: DataTypes.STRING(3),
    defaultValue: 'USD',
  },
  status: {
    type: DataTypes.ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled'),
    defaultValue: 'pending',
  },
  payment_method: {
    type: DataTypes.ENUM('credit_card', 'debit_card', 'paypal', 'bank_transfer'),
    allowNull: false,
  },
  shipping_address: {
    type: DataTypes.JSON,
    allowNull: false,
  },
  order_date: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
  shipped_date: {
    type: DataTypes.DATE,
    allowNull: true,
  },
  delivered_date: {
    type: DataTypes.DATE,
    allowNull: true,
  },
  notes: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
}, {
  tableName: 'orders',
  indexes: [
    { fields: ['user_id'] },
    { fields: ['order_number'] },
    { fields: ['status'] },
    { fields: ['order_date'] },
    { fields: ['total_amount'] },
  ],
});

// Product model (MySQL)
mysqlModels.Product = sequelize.mysql.define('Product', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true,
  },
  name: {
    type: DataTypes.STRING(200),
    allowNull: false,
  },
  sku: {
    type: DataTypes.STRING(50),
    allowNull: false,
    unique: true,
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  price: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    validate: {
      min: 0,
    },
  },
  cost: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    validate: {
      min: 0,
    },
  },
  category: {
    type: DataTypes.STRING(100),
    allowNull: false,
  },
  brand: {
    type: DataTypes.STRING(100),
    allowNull: true,
  },
  stock_quantity: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    validate: {
      min: 0,
    },
  },
  weight: {
    type: DataTypes.DECIMAL(8, 3),
    allowNull: true,
    comment: 'Weight in kg',
  },
  dimensions: {
    type: DataTypes.JSON,
    allowNull: true,
    comment: 'Length, width, height in cm',
  },
  is_active: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  tags: {
    type: DataTypes.JSON,
    allowNull: true,
  },
}, {
  tableName: 'products',
  indexes: [
    { fields: ['sku'] },
    { fields: ['category'] },
    { fields: ['brand'] },
    { fields: ['is_active'] },
    { fields: ['price'] },
  ],
});

// PostgreSQL Models
const postgresModels = {};

// Analytics Event model (PostgreSQL) - For tracking user behavior
postgresModels.AnalyticsEvent = sequelize.postgresql.define('AnalyticsEvent', {
  id: {
    type: DataTypes.UUID,
    primaryKey: true,
    defaultValue: DataTypes.UUIDV4,
  },
  session_id: {
    type: DataTypes.UUID,
    allowNull: false,
  },
  user_id: {
    type: DataTypes.INTEGER,
    allowNull: true, // Can be null for anonymous users
  },
  event_type: {
    type: DataTypes.STRING(50),
    allowNull: false,
  },
  event_name: {
    type: DataTypes.STRING(100),
    allowNull: false,
  },
  page_url: {
    type: DataTypes.STRING(500),
    allowNull: true,
  },
  referrer: {
    type: DataTypes.STRING(500),
    allowNull: true,
  },
  user_agent: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  ip_address: {
    type: DataTypes.INET,
    allowNull: true,
  },
  country: {
    type: DataTypes.STRING(2),
    allowNull: true,
  },
  city: {
    type: DataTypes.STRING(100),
    allowNull: true,
  },
  device_type: {
    type: DataTypes.ENUM('desktop', 'mobile', 'tablet'),
    allowNull: true,
  },
  browser: {
    type: DataTypes.STRING(50),
    allowNull: true,
  },
  os: {
    type: DataTypes.STRING(50),
    allowNull: true,
  },
  event_data: {
    type: DataTypes.JSONB,
    allowNull: true,
  },
  timestamp: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
    allowNull: false,
  },
}, {
  tableName: 'analytics_events',
  indexes: [
    { fields: ['session_id'] },
    { fields: ['user_id'] },
    { fields: ['event_type'] },
    { fields: ['event_name'] },
    { fields: ['timestamp'] },
    { fields: ['country'] },
    { fields: ['device_type'] },
    { using: 'gin', fields: ['event_data'] }, // GIN index for JSONB
  ],
});

// Performance Metrics model (PostgreSQL)
postgresModels.PerformanceMetric = sequelize.postgresql.define('PerformanceMetric', {
  id: {
    type: DataTypes.UUID,
    primaryKey: true,
    defaultValue: DataTypes.UUIDV4,
  },
  metric_name: {
    type: DataTypes.STRING(100),
    allowNull: false,
  },
  metric_type: {
    type: DataTypes.ENUM('counter', 'gauge', 'histogram', 'summary'),
    allowNull: false,
  },
  value: {
    type: DataTypes.DOUBLE,
    allowNull: false,
  },
  unit: {
    type: DataTypes.STRING(20),
    allowNull: true,
  },
  tags: {
    type: DataTypes.JSONB,
    allowNull: true,
  },
  source: {
    type: DataTypes.STRING(50),
    allowNull: false,
    defaultValue: 'application',
  },
  instance_id: {
    type: DataTypes.STRING(100),
    allowNull: true,
  },
  timestamp: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
    allowNull: false,
  },
}, {
  tableName: 'performance_metrics',
  indexes: [
    { fields: ['metric_name'] },
    { fields: ['metric_type'] },
    { fields: ['source'] },
    { fields: ['timestamp'] },
    { fields: ['instance_id'] },
    { using: 'gin', fields: ['tags'] },
  ],
});

// Real-time Data model (PostgreSQL) - For live dashboard updates
postgresModels.RealTimeData = sequelize.postgresql.define('RealTimeData', {
  id: {
    type: DataTypes.UUID,
    primaryKey: true,
    defaultValue: DataTypes.UUIDV4,
  },
  data_type: {
    type: DataTypes.STRING(50),
    allowNull: false,
  },
  data_source: {
    type: DataTypes.STRING(100),
    allowNull: false,
  },
  value: {
    type: DataTypes.JSONB,
    allowNull: false,
  },
  metadata: {
    type: DataTypes.JSONB,
    allowNull: true,
  },
  timestamp: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
    allowNull: false,
  },
  expires_at: {
    type: DataTypes.DATE,
    allowNull: true,
    comment: 'Automatic cleanup time for temporary data',
  },
}, {
  tableName: 'real_time_data',
  indexes: [
    { fields: ['data_type'] },
    { fields: ['data_source'] },
    { fields: ['timestamp'] },
    { fields: ['expires_at'] },
    { using: 'gin', fields: ['value'] },
    { using: 'gin', fields: ['metadata'] },
  ],
});

// Define associations
// MySQL associations
mysqlModels.User.hasMany(mysqlModels.Order, { foreignKey: 'user_id', as: 'orders' });
mysqlModels.Order.belongsTo(mysqlModels.User, { foreignKey: 'user_id', as: 'user' });

// Note: Cross-database associations are not directly supported by Sequelize
// We'll handle these relationships in the application logic

// Export models
module.exports = {
  mysql: mysqlModels,
  postgresql: postgresModels,
  sequelize,
};

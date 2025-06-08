/**
 * KPI Card Component
 * Displays key performance indicators with animated counters and trends
 */

import React from 'react';
import { Card, Statistic, Typography, Space } from 'antd';
import { ArrowUpOutlined, ArrowDownOutlined } from '@ant-design/icons';
import CountUp from 'react-countup';
import { motion } from 'framer-motion';
import './KPICard.css';

const { Text } = Typography;

const KPICard = ({
  title,
  value,
  prefix = '',
  suffix = '',
  precision = 0,
  trend = 0,
  icon,
  color = '#1890ff',
  loading = false,
}) => {
  const isPositiveTrend = trend >= 0;
  const trendColor = isPositiveTrend ? '#52c41a' : '#ff4d4f';
  const TrendIcon = isPositiveTrend ? ArrowUpOutlined : ArrowDownOutlined;

  const cardVariants = {
    hidden: { scale: 0.95, opacity: 0 },
    visible: {
      scale: 1,
      opacity: 1,
      transition: {
        duration: 0.3,
        ease: 'easeOut'
      }
    },
    hover: {
      scale: 1.02,
      transition: {
        duration: 0.2
      }
    }
  };

  return (
    <motion.div
      variants={cardVariants}
      initial="hidden"
      animate="visible"
      whileHover="hover"
      className="kpi-card-container"
    >
      <Card
        className="kpi-card"
        bordered={false}
        loading={loading}
        bodyStyle={{ padding: '20px' }}
      >
        <div className="kpi-content">
          {/* Header with icon and title */}
          <div className="kpi-header">
            <Space>
              <div 
                className="kpi-icon"
                style={{ color: color }}
              >
                {icon}
              </div>
              <Text type="secondary" className="kpi-title">
                {title}
              </Text>
            </Space>
          </div>

          {/* Main value */}
          <div className="kpi-value">
            <Statistic
              value={value}
              prefix={prefix}
              suffix={suffix}
              precision={precision}
              valueStyle={{
                fontSize: '28px',
                fontWeight: 'bold',
                color: color,
              }}
              formatter={(value) => (
                <CountUp
                  end={value}
                  duration={2}
                  separator=","
                  decimals={precision}
                  prefix={prefix}
                  suffix={suffix}
                />
              )}
            />
          </div>

          {/* Trend indicator */}
          {trend !== 0 && (
            <div className="kpi-trend">
              <Space>
                <TrendIcon style={{ color: trendColor }} />
                <Text style={{ color: trendColor, fontSize: '12px' }}>
                  {Math.abs(trend).toFixed(1)}%
                </Text>
                <Text type="secondary" style={{ fontSize: '12px' }}>
                  vs last period
                </Text>
              </Space>
            </div>
          )}

          {/* Progress bar indicator */}
          <div 
            className="kpi-indicator"
            style={{ backgroundColor: `${color}20` }}
          >
            <motion.div
              className="kpi-indicator-fill"
              style={{ backgroundColor: color }}
              initial={{ width: 0 }}
              animate={{ width: '100%' }}
              transition={{ duration: 1.5, delay: 0.5 }}
            />
          </div>
        </div>
      </Card>
    </motion.div>
  );
};

export default KPICard;

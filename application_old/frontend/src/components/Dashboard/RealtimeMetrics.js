/**
 * Real-time Metrics Component
 * Displays live system performance metrics with gauges and indicators
 */

import React, { useState, useEffect } from 'react';
import { Card, Progress, Space, Badge, Typography, Row, Col, Statistic } from 'antd';
import {
  CpuFilled,
  DatabaseFilled,
  CloudServerOutlined,
  ThunderboltFilled,
  WifiOutlined,
} from '@ant-design/icons';
import { motion } from 'framer-motion';
import { socketService } from '../../services/socketService';
import './RealtimeMetrics.css';

const { Title, Text } = Typography;

const RealtimeMetrics = ({ data = {}, loading = false, height = 300 }) => {
  const [metrics, setMetrics] = useState({
    cpu_usage: 0,
    memory_usage: 0,
    disk_usage: 0,
    network_usage: 0,
    response_time: 0,
    active_connections: 0,
    error_rate: 0,
    throughput: 0,
  });

  const [lastUpdate, setLastUpdate] = useState(null);

  useEffect(() => {
    // Listen for real-time metrics updates
    socketService.on('metrics-update', handleMetricsUpdate);
    socketService.on('subscribed-metrics', handleSubscribedMetrics);

    // Subscribe to system metrics
    socketService.subscribeToMetrics([
      'cpu_usage',
      'memory_usage',
      'disk_usage',
      'network_usage',
      'response_time',
      'active_connections',
      'error_rate',
      'throughput'
    ]);

    return () => {
      socketService.off('metrics-update', handleMetricsUpdate);
      socketService.off('subscribed-metrics', handleSubscribedMetrics);
    };
  }, []);

  const handleMetricsUpdate = (data) => {
    if (data.metrics && Array.isArray(data.metrics)) {
      const newMetrics = { ...metrics };
      
      data.metrics.forEach(metric => {
        if (metric.metric_name && typeof metric.value === 'number') {
          newMetrics[metric.metric_name] = metric.value;
        }
      });
      
      setMetrics(newMetrics);
      setLastUpdate(new Date());
    }
  };

  const handleSubscribedMetrics = (data) => {
    if (data.metrics && Array.isArray(data.metrics)) {
      handleMetricsUpdate(data);
    }
  };

  // Update metrics from props data
  useEffect(() => {
    if (data && typeof data === 'object') {
      setMetrics(prevMetrics => ({
        ...prevMetrics,
        ...data,
      }));
    }
  }, [data]);

  // Get status color based on value and thresholds
  const getStatusColor = (value, type) => {
    switch (type) {
      case 'percentage':
        if (value < 50) return '#52c41a'; // Green
        if (value < 80) return '#faad14'; // Yellow
        return '#f5222d'; // Red
      
      case 'response_time':
        if (value < 200) return '#52c41a';
        if (value < 1000) return '#faad14';
        return '#f5222d';
      
      case 'error_rate':
        if (value < 1) return '#52c41a';
        if (value < 5) return '#faad14';
        return '#f5222d';
      
      default:
        return '#1890ff';
    }
  };

  // Get status text
  const getStatusText = (value, type) => {
    const color = getStatusColor(value, type);
    if (color === '#52c41a') return 'Excellent';
    if (color === '#faad14') return 'Warning';
    return 'Critical';
  };

  const metricsConfig = [
    {
      key: 'cpu_usage',
      title: 'CPU Usage',
      icon: <CpuFilled />,
      unit: '%',
      type: 'percentage',
      color: '#1890ff',
    },
    {
      key: 'memory_usage',
      title: 'Memory Usage',
      icon: <DatabaseFilled />,
      unit: '%',
      type: 'percentage',
      color: '#52c41a',
    },
    {
      key: 'disk_usage',
      title: 'Disk Usage',
      icon: <CloudServerOutlined />,
      unit: '%',
      type: 'percentage',
      color: '#faad14',
    },
    {
      key: 'network_usage',
      title: 'Network Usage',
      icon: <WifiOutlined />,
      unit: '%',
      type: 'percentage',
      color: '#722ed1',
    },
    {
      key: 'response_time',
      title: 'Response Time',
      icon: <ThunderboltFilled />,
      unit: 'ms',
      type: 'response_time',
      color: '#eb2f96',
    },
    {
      key: 'error_rate',
      title: 'Error Rate',
      icon: <DatabaseFilled />,
      unit: '%',
      type: 'error_rate',
      color: '#f5222d',
    },
  ];

  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.1
      }
    }
  };

  const itemVariants = {
    hidden: { scale: 0.8, opacity: 0 },
    visible: {
      scale: 1,
      opacity: 1,
      transition: { duration: 0.5 }
    }
  };

  return (
    <Card
      title={
        <div className="metrics-header">
          <Space>
            <Title level={4} style={{ margin: 0 }}>
              Real-time Metrics
            </Title>
            {lastUpdate && (
              <Badge
                status="processing"
                text={`Updated ${lastUpdate.toLocaleTimeString()}`}
              />
            )}
          </Space>
        </div>
      }
      className="realtime-metrics-card"
      loading={loading}
      bodyStyle={{ padding: '16px', height: height - 64 }}
    >
      <motion.div
        variants={containerVariants}
        initial="hidden"
        animate="visible"
        className="metrics-container"
      >
        <Row gutter={[16, 16]}>
          {metricsConfig.map((config) => {
            const value = metrics[config.key] || 0;
            const statusColor = getStatusColor(value, config.type);
            const statusText = getStatusText(value, config.type);

            return (
              <Col xs={12} sm={8} lg={6} key={config.key}>
                <motion.div variants={itemVariants}>
                  <Card
                    size="small"
                    className="metric-item"
                    bodyStyle={{ padding: '12px' }}
                  >
                    <div className="metric-content">
                      <div className="metric-header">
                        <Space>
                          <div 
                            className="metric-icon"
                            style={{ color: config.color }}
                          >
                            {config.icon}
                          </div>
                          <Text className="metric-title">
                            {config.title}
                          </Text>
                        </Space>
                      </div>

                      <div className="metric-value">
                        <Statistic
                          value={value}
                          suffix={config.unit}
                          precision={config.type === 'percentage' ? 1 : 0}
                          valueStyle={{
                            fontSize: '20px',
                            fontWeight: 'bold',
                            color: statusColor,
                          }}
                        />
                      </div>

                      <div className="metric-progress">
                        <Progress
                          percent={config.type === 'percentage' ? value : Math.min(value / 10, 100)}
                          strokeColor={statusColor}
                          showInfo={false}
                          size="small"
                        />
                      </div>

                      <div className="metric-status">
                        <Badge
                          color={statusColor}
                          text={
                            <Text style={{ fontSize: '11px', color: statusColor }}>
                              {statusText}
                            </Text>
                          }
                        />
                      </div>
                    </div>
                  </Card>
                </motion.div>
              </Col>
            );
          })}
        </Row>

        {/* Summary Statistics */}
        <motion.div variants={itemVariants} className="metrics-summary">
          <Row gutter={[16, 8]} style={{ marginTop: '16px' }}>
            <Col span={8}>
              <Statistic
                title="Active Connections"
                value={metrics.active_connections || 0}
                prefix={<WifiOutlined />}
                valueStyle={{ fontSize: '16px' }}
              />
            </Col>
            <Col span={8}>
              <Statistic
                title="Throughput"
                value={metrics.throughput || 0}
                suffix="req/s"
                prefix={<ThunderboltFilled />}
                valueStyle={{ fontSize: '16px' }}
              />
            </Col>
            <Col span={8}>
              <Statistic
                title="Uptime"
                value={data.uptime || 0}
                suffix="hrs"
                prefix={<CloudServerOutlined />}
                valueStyle={{ fontSize: '16px' }}
                precision={1}
              />
            </Col>
          </Row>
        </motion.div>
      </motion.div>
    </Card>
  );
};

export default RealtimeMetrics;

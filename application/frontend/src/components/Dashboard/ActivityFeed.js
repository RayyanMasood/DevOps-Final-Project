/**
 * Activity Feed Component
 * Displays real-time activity feed with system events and user actions
 */

import React, { useState, useEffect } from 'react';
import { Card, Timeline, Badge, Space, Typography, Button, Empty } from 'antd';
import {
  UserOutlined,
  ShoppingCartOutlined,
  DatabaseOutlined,
  WarningOutlined,
  CheckCircleOutlined,
  CloseCircleOutlined,
  InfoCircleOutlined,
  ReloadOutlined,
} from '@ant-design/icons';
import { motion, AnimatePresence } from 'framer-motion';
import moment from 'moment';
import { socketService } from '../../services/socketService';
import './ActivityFeed.css';

const { Text, Title } = Typography;

const ActivityFeed = ({ title = "System Activity", loading = false, maxItems = 20 }) => {
  const [activities, setActivities] = useState([]);
  const [isLive, setIsLive] = useState(true);

  useEffect(() => {
    // Listen for real-time events
    socketService.on('analytics-event', handleNewActivity);
    socketService.on('error-occurred', handleErrorActivity);
    socketService.on('client-connected', handleConnectionActivity);
    socketService.on('client-disconnected', handleDisconnectionActivity);

    // Join monitoring room for system events
    socketService.joinRoom('monitoring');

    // Generate some initial activities
    generateInitialActivities();

    return () => {
      socketService.off('analytics-event', handleNewActivity);
      socketService.off('error-occurred', handleErrorActivity);
      socketService.off('client-connected', handleConnectionActivity);
      socketService.off('client-disconnected', handleDisconnectionActivity);
    };
  }, []);

  const generateInitialActivities = () => {
    const initialActivities = [
      {
        id: Date.now() + 1,
        type: 'user_login',
        title: 'User logged in',
        description: 'john.doe@example.com logged in from Chrome',
        timestamp: moment().subtract(5, 'minutes').toISOString(),
        icon: 'user',
        color: 'green',
      },
      {
        id: Date.now() + 2,
        type: 'order_created',
        title: 'New order created',
        description: 'Order #12345 created by customer',
        timestamp: moment().subtract(10, 'minutes').toISOString(),
        icon: 'shopping',
        color: 'blue',
      },
      {
        id: Date.now() + 3,
        type: 'database_backup',
        title: 'Database backup completed',
        description: 'Daily backup completed successfully',
        timestamp: moment().subtract(1, 'hour').toISOString(),
        icon: 'database',
        color: 'green',
      },
      {
        id: Date.now() + 4,
        type: 'system_warning',
        title: 'High CPU usage detected',
        description: 'CPU usage above 80% for 5 minutes',
        timestamp: moment().subtract(2, 'hours').toISOString(),
        icon: 'warning',
        color: 'orange',
      },
    ];
    setActivities(initialActivities);
  };

  const handleNewActivity = (data) => {
    if (!isLive) return;
    
    const activity = {
      id: Date.now() + Math.random(),
      type: data.event_type || 'analytics',
      title: `Analytics: ${data.event_name || 'Event'}`,
      description: `${data.event_type} on ${data.page_url || 'unknown page'}`,
      timestamp: data.timestamp || new Date().toISOString(),
      icon: 'info',
      color: 'blue',
    };
    
    addActivity(activity);
  };

  const handleErrorActivity = (data) => {
    if (!isLive) return;
    
    const activity = {
      id: Date.now() + Math.random(),
      type: 'error',
      title: 'Application Error',
      description: `${data.error.method} ${data.error.path} - ${data.error.message}`,
      timestamp: data.timestamp || new Date().toISOString(),
      icon: 'error',
      color: 'red',
    };
    
    addActivity(activity);
  };

  const handleConnectionActivity = (data) => {
    if (!isLive) return;
    
    const activity = {
      id: Date.now() + Math.random(),
      type: 'connection',
      title: 'Client Connected',
      description: `New WebSocket connection: ${data.clientId}`,
      timestamp: data.timestamp || new Date().toISOString(),
      icon: 'success',
      color: 'green',
    };
    
    addActivity(activity);
  };

  const handleDisconnectionActivity = (data) => {
    if (!isLive) return;
    
    const activity = {
      id: Date.now() + Math.random(),
      type: 'disconnection',
      title: 'Client Disconnected',
      description: `WebSocket disconnection: ${data.reason}`,
      timestamp: data.timestamp || new Date().toISOString(),
      icon: 'info',
      color: 'gray',
    };
    
    addActivity(activity);
  };

  const addActivity = (newActivity) => {
    setActivities(prev => {
      const updated = [newActivity, ...prev];
      return updated.slice(0, maxItems); // Keep only the latest items
    });
  };

  const getActivityIcon = (type) => {
    const iconMap = {
      user: <UserOutlined />,
      shopping: <ShoppingCartOutlined />,
      database: <DatabaseOutlined />,
      warning: <WarningOutlined />,
      error: <CloseCircleOutlined />,
      success: <CheckCircleOutlined />,
      info: <InfoCircleOutlined />,
    };
    return iconMap[type] || <InfoCircleOutlined />;
  };

  const getActivityColor = (color) => {
    const colorMap = {
      green: '#52c41a',
      blue: '#1890ff',
      orange: '#faad14',
      red: '#f5222d',
      gray: '#8c8c8c',
    };
    return colorMap[color] || '#1890ff';
  };

  const toggleLive = () => {
    setIsLive(!isLive);
  };

  const refreshFeed = () => {
    generateInitialActivities();
  };

  const timelineItems = activities.map((activity) => ({
    key: activity.id,
    dot: (
      <Badge
        dot
        status={activity.color === 'red' ? 'error' : activity.color === 'green' ? 'success' : 'processing'}
      >
        <div
          className="activity-icon"
          style={{ color: getActivityColor(activity.color) }}
        >
          {getActivityIcon(activity.icon)}
        </div>
      </Badge>
    ),
    children: (
      <motion.div
        initial={{ opacity: 0, x: -20 }}
        animate={{ opacity: 1, x: 0 }}
        exit={{ opacity: 0, x: 20 }}
        transition={{ duration: 0.3 }}
        className="activity-item"
      >
        <div className="activity-content">
          <div className="activity-header">
            <Text strong className="activity-title">
              {activity.title}
            </Text>
            <Text type="secondary" className="activity-time">
              {moment(activity.timestamp).fromNow()}
            </Text>
          </div>
          <Text type="secondary" className="activity-description">
            {activity.description}
          </Text>
        </div>
      </motion.div>
    ),
  }));

  return (
    <Card
      title={
        <div className="activity-header">
          <Space>
            <Title level={4} style={{ margin: 0 }}>
              {title}
            </Title>
            <Badge
              status={isLive ? 'processing' : 'default'}
              text={isLive ? 'Live' : 'Paused'}
            />
          </Space>
        </div>
      }
      extra={
        <Space>
          <Button
            type={isLive ? 'primary' : 'default'}
            size="small"
            onClick={toggleLive}
          >
            {isLive ? 'Pause' : 'Resume'}
          </Button>
          <Button
            type="text"
            icon={<ReloadOutlined />}
            size="small"
            onClick={refreshFeed}
          />
        </Space>
      }
      className="activity-feed-card"
      bodyStyle={{ 
        padding: '16px',
        maxHeight: '400px',
        overflowY: 'auto'
      }}
      loading={loading}
    >
      {activities.length === 0 ? (
        <Empty
          description="No recent activity"
          image={Empty.PRESENTED_IMAGE_SIMPLE}
        />
      ) : (
        <AnimatePresence>
          <Timeline
            className="activity-timeline"
            items={timelineItems}
          />
        </AnimatePresence>
      )}
    </Card>
  );
};

export default ActivityFeed;

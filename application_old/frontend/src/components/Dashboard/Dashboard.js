/**
 * Main Dashboard Component
 * Real-time BI dashboard with KPIs, charts, and live data updates
 */

import React, { useState, useEffect, useCallback } from 'react';
import { 
  Row, 
  Col, 
  Card, 
  Statistic, 
  Select, 
  DatePicker, 
  Space, 
  Alert,
  Button,
  Tooltip,
  Badge,
  Spin
} from 'antd';
import {
  ReloadOutlined,
  FullscreenOutlined,
  DownloadOutlined,
  SettingOutlined,
  DashboardOutlined,
  TrendingUpOutlined,
  UsergroupAddOutlined,
  ShoppingCartOutlined,
  DollarOutlined
} from '@ant-design/icons';
import { useQuery } from 'react-query';
import moment from 'moment';
import CountUp from 'react-countup';
import { motion } from 'framer-motion';

// Components
import KPICard from './KPICard';
import ChartWidget from './ChartWidget';
import RealtimeMetrics from './RealtimeMetrics';
import DataTable from './DataTable';
import ActivityFeed from './ActivityFeed';

// Services
import { socketService } from '../../services/socketService';
import { apiService } from '../../services/apiService';

// Styles
import './Dashboard.css';

const { RangePicker } = DatePicker;
const { Option } = Select;

// Animation variants
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
  hidden: { y: 20, opacity: 0 },
  visible: {
    y: 0,
    opacity: 1,
    transition: {
      duration: 0.5
    }
  }
};

const Dashboard = () => {
  // State management
  const [selectedPeriod, setSelectedPeriod] = useState('24h');
  const [dateRange, setDateRange] = useState(null);
  const [refreshKey, setRefreshKey] = useState(0);
  const [realTimeData, setRealTimeData] = useState({});
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [autoRefresh, setAutoRefresh] = useState(true);

  // Fetch dashboard data
  const {
    data: dashboardData,
    isLoading,
    error,
    refetch
  } = useQuery(
    ['dashboard', selectedPeriod, dateRange, refreshKey],
    () => apiService.getDashboardData({
      period: selectedPeriod,
      start_date: dateRange?.[0]?.format('YYYY-MM-DD'),
      end_date: dateRange?.[1]?.format('YYYY-MM-DD')
    }),
    {
      refetchInterval: autoRefresh ? 30000 : false, // Auto-refresh every 30 seconds
      refetchIntervalInBackground: true,
    }
  );

  // Setup real-time WebSocket listeners
  useEffect(() => {
    // Join dashboard room for real-time updates
    socketService.emit('join-room', 'dashboard');

    // Listen for real-time updates
    socketService.on('dashboard-update', handleDashboardUpdate);
    socketService.on('real-time-update', handleRealTimeUpdate);
    socketService.on('kpi-update', handleKPIUpdate);

    // Request initial dashboard data
    socketService.emit('request-dashboard-data', {
      period: selectedPeriod
    });

    // Cleanup on unmount
    return () => {
      socketService.emit('leave-room', 'dashboard');
      socketService.off('dashboard-update', handleDashboardUpdate);
      socketService.off('real-time-update', handleRealTimeUpdate);
      socketService.off('kpi-update', handleKPIUpdate);
    };
  }, [selectedPeriod]);

  // Handle real-time dashboard updates
  const handleDashboardUpdate = useCallback((data) => {
    console.log('Dashboard update received:', data);
    // Trigger a refetch to get latest data
    setRefreshKey(prev => prev + 1);
  }, []);

  // Handle real-time data updates
  const handleRealTimeUpdate = useCallback((data) => {
    setRealTimeData(prevData => ({
      ...prevData,
      ...data.data,
      timestamp: data.timestamp
    }));
  }, []);

  // Handle KPI updates
  const handleKPIUpdate = useCallback((data) => {
    // Update specific KPIs without full refetch
    console.log('KPI update received:', data);
  }, []);

  // Handle period change
  const handlePeriodChange = (period) => {
    setSelectedPeriod(period);
    setDateRange(null); // Clear custom date range
  };

  // Handle date range change
  const handleDateRangeChange = (dates) => {
    setDateRange(dates);
    if (dates) {
      setSelectedPeriod('custom');
    }
  };

  // Handle manual refresh
  const handleRefresh = () => {
    refetch();
    socketService.emit('request-dashboard-data', {
      period: selectedPeriod
    });
  };

  // Handle export
  const handleExport = async () => {
    try {
      await apiService.exportDashboardData({
        period: selectedPeriod,
        format: 'json'
      });
    } catch (error) {
      console.error('Export failed:', error);
    }
  };

  // Toggle fullscreen
  const handleFullscreen = () => {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen();
      setIsFullscreen(true);
    } else {
      document.exitFullscreen();
      setIsFullscreen(false);
    }
  };

  // Prepare KPI data
  const kpis = dashboardData?.kpis || {};
  const kpiCards = [
    {
      title: 'Total Revenue',
      value: kpis.revenue_period || 0,
      prefix: '$',
      precision: 2,
      trend: dashboardData?.growth?.revenue_growth || 0,
      icon: <DollarOutlined />,
      color: '#52c41a',
    },
    {
      title: 'Total Orders',
      value: kpis.orders_period || 0,
      trend: dashboardData?.growth?.order_growth || 0,
      icon: <ShoppingCartOutlined />,
      color: '#1890ff',
    },
    {
      title: 'New Users',
      value: kpis.new_users_period || 0,
      trend: dashboardData?.growth?.user_growth || 0,
      icon: <UsergroupAddOutlined />,
      color: '#722ed1',
    },
    {
      title: 'Conversion Rate',
      value: kpis.conversion_rate || 0,
      suffix: '%',
      precision: 2,
      trend: 2.3,
      icon: <TrendingUpOutlined />,
      color: '#eb2f96',
    },
  ];

  // Error state
  if (error) {
    return (
      <Alert
        message="Dashboard Error"
        description={`Failed to load dashboard data: ${error.message}`}
        type="error"
        action={
          <Button type="primary" onClick={handleRefresh}>
            Retry
          </Button>
        }
        showIcon
      />
    );
  }

  return (
    <motion.div
      className="dashboard-container"
      variants={containerVariants}
      initial="hidden"
      animate="visible"
    >
      {/* Dashboard Header */}
      <motion.div variants={itemVariants}>
        <Card className="dashboard-header" bodyStyle={{ padding: '16px 24px' }}>
          <Row justify="space-between" align="middle">
            <Col>
              <Space align="center">
                <DashboardOutlined style={{ fontSize: '24px', color: '#1890ff' }} />
                <div>
                  <h2 style={{ margin: 0 }}>DevOps Dashboard</h2>
                  <p style={{ margin: 0, color: '#666' }}>
                    Real-time business intelligence and monitoring
                  </p>
                </div>
              </Space>
            </Col>
            
            <Col>
              <Space>
                {/* Period Selector */}
                <Select
                  value={selectedPeriod}
                  onChange={handlePeriodChange}
                  style={{ width: 120 }}
                >
                  <Option value="1h">Last Hour</Option>
                  <Option value="24h">Last 24h</Option>
                  <Option value="7d">Last 7 days</Option>
                  <Option value="30d">Last 30 days</Option>
                  <Option value="custom">Custom</Option>
                </Select>

                {/* Date Range Picker */}
                {selectedPeriod === 'custom' && (
                  <RangePicker
                    value={dateRange}
                    onChange={handleDateRangeChange}
                    allowClear
                  />
                )}

                {/* Control Buttons */}
                <Tooltip title="Refresh Data">
                  <Button
                    icon={<ReloadOutlined />}
                    onClick={handleRefresh}
                    loading={isLoading}
                  />
                </Tooltip>

                <Tooltip title="Export Data">
                  <Button
                    icon={<DownloadOutlined />}
                    onClick={handleExport}
                  />
                </Tooltip>

                <Tooltip title="Fullscreen">
                  <Button
                    icon={<FullscreenOutlined />}
                    onClick={handleFullscreen}
                  />
                </Tooltip>

                <Tooltip title="Settings">
                  <Button icon={<SettingOutlined />} />
                </Tooltip>
              </Space>
            </Col>
          </Row>
        </Card>
      </motion.div>

      {/* Real-time Status Indicator */}
      <motion.div variants={itemVariants}>
        <Alert
          message={
            <Space>
              <Badge 
                status={realTimeData.timestamp ? 'processing' : 'default'} 
                text={
                  realTimeData.timestamp 
                    ? `Live data • Updated ${moment(realTimeData.timestamp).fromNow()}`
                    : 'Waiting for real-time data...'
                }
              />
            </Space>
          }
          type="info"
          showIcon={false}
          style={{ marginBottom: 16 }}
        />
      </motion.div>

      {/* KPI Cards */}
      <motion.div variants={itemVariants}>
        <Row gutter={[16, 16]} style={{ marginBottom: 24 }}>
          {kpiCards.map((kpi, index) => (
            <Col xs={24} sm={12} lg={6} key={index}>
              <KPICard {...kpi} loading={isLoading} />
            </Col>
          ))}
        </Row>
      </motion.div>

      {/* Charts Section */}
      <Row gutter={[16, 16]} style={{ marginBottom: 24 }}>
        {/* Revenue Chart */}
        <Col xs={24} lg={12}>
          <motion.div variants={itemVariants}>
            <ChartWidget
              title="Revenue Trends"
              type="area"
              data={dashboardData?.charts?.revenue_chart || []}
              loading={isLoading}
              height={300}
            />
          </motion.div>
        </Col>

        {/* User Activity Chart */}
        <Col xs={24} lg={12}>
          <motion.div variants={itemVariants}>
            <ChartWidget
              title="User Activity"
              type="line"
              data={dashboardData?.charts?.user_activity || []}
              loading={isLoading}
              height={300}
            />
          </motion.div>
        </Col>

        {/* Order Trends */}
        <Col xs={24} lg={12}>
          <motion.div variants={itemVariants}>
            <ChartWidget
              title="Order Trends"
              type="bar"
              data={dashboardData?.charts?.order_trends || []}
              loading={isLoading}
              height={300}
            />
          </motion.div>
        </Col>

        {/* Performance Metrics */}
        <Col xs={24} lg={12}>
          <motion.div variants={itemVariants}>
            <RealtimeMetrics
              data={realTimeData}
              loading={isLoading}
              height={300}
            />
          </motion.div>
        </Col>
      </Row>

      {/* Data Tables and Activity Feed */}
      <Row gutter={[16, 16]}>
        {/* Recent Activity */}
        <Col xs={24} lg={16}>
          <motion.div variants={itemVariants}>
            <DataTable
              title="Recent Transactions"
              data={dashboardData?.recent_data || []}
              loading={isLoading}
            />
          </motion.div>
        </Col>

        {/* Activity Feed */}
        <Col xs={24} lg={8}>
          <motion.div variants={itemVariants}>
            <ActivityFeed
              title="System Activity"
              loading={isLoading}
            />
          </motion.div>
        </Col>
      </Row>
    </motion.div>
  );
};

export default Dashboard;

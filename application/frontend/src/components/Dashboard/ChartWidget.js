/**
 * Chart Widget Component
 * Displays various types of charts using Recharts library
 */

import React, { useState, useMemo } from 'react';
import { Card, Select, Button, Space, Tooltip, Empty } from 'antd';
import {
  FullscreenOutlined,
  DownloadOutlined,
  ReloadOutlined,
  SettingOutlined,
} from '@ant-design/icons';
import {
  LineChart,
  Line,
  AreaChart,
  Area,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip as RechartsTooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';
import { motion } from 'framer-motion';
import moment from 'moment';
import './ChartWidget.css';

const { Option } = Select;

// Color palette for charts
const COLORS = [
  '#1890ff',
  '#52c41a',
  '#faad14',
  '#f5222d',
  '#722ed1',
  '#13c2c2',
  '#eb2f96',
  '#fa8c16',
];

const ChartWidget = ({
  title,
  type = 'line',
  data = [],
  loading = false,
  height = 300,
  xKey = 'timestamp',
  yKey = 'value',
  allowTypeChange = true,
  showControls = true,
  colors = COLORS,
  ...props
}) => {
  const [chartType, setChartType] = useState(type);
  const [isFullscreen, setIsFullscreen] = useState(false);

  // Process data for charts
  const processedData = useMemo(() => {
    if (!data || !Array.isArray(data)) return [];
    
    return data.map(item => ({
      ...item,
      [xKey]: moment(item[xKey]).format('MMM DD HH:mm'),
      timestamp_raw: item[xKey], // Keep original for sorting
    })).sort((a, b) => new Date(a.timestamp_raw) - new Date(b.timestamp_raw));
  }, [data, xKey]);

  // Custom tooltip formatter
  const CustomTooltip = ({ active, payload, label }) => {
    if (active && payload && payload.length) {
      return (
        <div className="chart-tooltip">
          <p className="tooltip-label">{label}</p>
          {payload.map((entry, index) => (
            <p key={index} style={{ color: entry.color }}>
              {`${entry.name}: ${entry.value.toLocaleString()}`}
            </p>
          ))}
        </div>
      );
    }
    return null;
  };

  // Export chart data
  const handleExport = () => {
    const dataStr = JSON.stringify(processedData, null, 2);
    const dataUri = 'data:application/json;charset=utf-8,'+ encodeURIComponent(dataStr);
    const exportFileDefaultName = `${title.toLowerCase().replace(/\s+/g, '-')}-${Date.now()}.json`;
    
    const linkElement = document.createElement('a');
    linkElement.setAttribute('href', dataUri);
    linkElement.setAttribute('download', exportFileDefaultName);
    linkElement.click();
  };

  // Toggle fullscreen
  const handleFullscreen = () => {
    setIsFullscreen(!isFullscreen);
  };

  // Render appropriate chart based on type
  const renderChart = () => {
    if (!processedData.length) {
      return (
        <div style={{ height, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Empty description="No data available" />
        </div>
      );
    }

    const commonProps = {
      data: processedData,
      margin: { top: 20, right: 30, left: 20, bottom: 5 },
    };

    switch (chartType) {
      case 'line':
        return (
          <LineChart {...commonProps}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis 
              dataKey={xKey} 
              stroke="#666"
              fontSize={12}
              tickMargin={8}
            />
            <YAxis 
              stroke="#666"
              fontSize={12}
              tickFormatter={(value) => value.toLocaleString()}
            />
            <RechartsTooltip content={<CustomTooltip />} />
            <Legend />
            <Line
              type="monotone"
              dataKey={yKey}
              stroke={colors[0]}
              strokeWidth={2}
              dot={{ fill: colors[0], strokeWidth: 2, r: 4 }}
              activeDot={{ r: 6, stroke: colors[0], strokeWidth: 2 }}
            />
          </LineChart>
        );

      case 'area':
        return (
          <AreaChart {...commonProps}>
            <defs>
              <linearGradient id="colorGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor={colors[0]} stopOpacity={0.8}/>
                <stop offset="95%" stopColor={colors[0]} stopOpacity={0.1}/>
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey={xKey} stroke="#666" fontSize={12} />
            <YAxis 
              stroke="#666" 
              fontSize={12}
              tickFormatter={(value) => value.toLocaleString()}
            />
            <RechartsTooltip content={<CustomTooltip />} />
            <Legend />
            <Area
              type="monotone"
              dataKey={yKey}
              stroke={colors[0]}
              strokeWidth={2}
              fill="url(#colorGradient)"
            />
          </AreaChart>
        );

      case 'bar':
        return (
          <BarChart {...commonProps}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey={xKey} stroke="#666" fontSize={12} />
            <YAxis 
              stroke="#666" 
              fontSize={12}
              tickFormatter={(value) => value.toLocaleString()}
            />
            <RechartsTooltip content={<CustomTooltip />} />
            <Legend />
            <Bar 
              dataKey={yKey} 
              fill={colors[0]}
              radius={[4, 4, 0, 0]}
            />
          </BarChart>
        );

      case 'pie':
        return (
          <PieChart width="100%" height={height}>
            <Pie
              data={processedData}
              cx="50%"
              cy="50%"
              labelLine={false}
              label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
              outerRadius={80}
              fill="#8884d8"
              dataKey={yKey}
            >
              {processedData.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={colors[index % colors.length]} />
              ))}
            </Pie>
            <RechartsTooltip content={<CustomTooltip />} />
            <Legend />
          </PieChart>
        );

      default:
        return renderChart();
    }
  };

  const cardVariants = {
    hidden: { opacity: 0, y: 20 },
    visible: { 
      opacity: 1, 
      y: 0,
      transition: { duration: 0.5 }
    }
  };

  return (
    <motion.div
      variants={cardVariants}
      initial="hidden"
      animate="visible"
      className={`chart-widget ${isFullscreen ? 'fullscreen' : ''}`}
    >
      <Card
        title={
          <div className="chart-header">
            <span className="chart-title">{title}</span>
            {processedData.length > 0 && (
              <span className="chart-subtitle">
                {processedData.length} data points
              </span>
            )}
          </div>
        }
        extra={
          showControls && (
            <Space>
              {allowTypeChange && (
                <Select
                  value={chartType}
                  onChange={setChartType}
                  size="small"
                  style={{ width: 100 }}
                >
                  <Option value="line">Line</Option>
                  <Option value="area">Area</Option>
                  <Option value="bar">Bar</Option>
                  <Option value="pie">Pie</Option>
                </Select>
              )}
              
              <Tooltip title="Export Data">
                <Button
                  type="text"
                  icon={<DownloadOutlined />}
                  size="small"
                  onClick={handleExport}
                />
              </Tooltip>

              <Tooltip title="Fullscreen">
                <Button
                  type="text"
                  icon={<FullscreenOutlined />}
                  size="small"
                  onClick={handleFullscreen}
                />
              </Tooltip>

              <Tooltip title="Settings">
                <Button
                  type="text"
                  icon={<SettingOutlined />}
                  size="small"
                />
              </Tooltip>
            </Space>
          )
        }
        className="chart-card"
        loading={loading}
        bodyStyle={{ padding: '16px' }}
      >
        <div style={{ height }}>
          <ResponsiveContainer width="100%" height="100%">
            {renderChart()}
          </ResponsiveContainer>
        </div>
      </Card>
    </motion.div>
  );
};

export default ChartWidget;

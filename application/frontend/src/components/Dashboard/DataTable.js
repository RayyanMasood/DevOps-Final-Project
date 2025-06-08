/**
 * Data Table Component
 * Displays tabular data with sorting, filtering, and pagination
 */

import React, { useState, useMemo } from 'react';
import { 
  Card, 
  Table, 
  Input, 
  Button, 
  Space, 
  Tag, 
  Tooltip,
  Badge,
  Typography 
} from 'antd';
import {
  SearchOutlined,
  ReloadOutlined,
  DownloadOutlined,
  FilterOutlined,
  EyeOutlined,
} from '@ant-design/icons';
import { motion } from 'framer-motion';
import moment from 'moment';
import numeral from 'numeral';
import './DataTable.css';

const { Text } = Typography;
const { Search } = Input;

const DataTable = ({ 
  title = "Data Table", 
  data = [], 
  loading = false,
  columns: customColumns = null,
  showSearch = true,
  showRefresh = true,
  showExport = true,
  pageSize = 10,
  onRefresh,
  onRowClick,
  ...props 
}) => {
  const [searchText, setSearchText] = useState('');
  const [filteredData, setFilteredData] = useState(data);

  // Default columns configuration
  const defaultColumns = [
    {
      title: 'ID',
      dataIndex: 'id',
      key: 'id',
      width: 80,
      sorter: (a, b) => a.id - b.id,
      render: (text) => <Text code>{text}</Text>,
    },
    {
      title: 'Timestamp',
      dataIndex: 'created_at',
      key: 'timestamp',
      width: 180,
      sorter: (a, b) => moment(a.created_at).valueOf() - moment(b.created_at).valueOf(),
      render: (text) => (
        <Tooltip title={moment(text).format('YYYY-MM-DD HH:mm:ss')}>
          {moment(text).fromNow()}
        </Tooltip>
      ),
    },
    {
      title: 'Type',
      dataIndex: 'type',
      key: 'type',
      width: 120,
      filters: [
        { text: 'Order', value: 'order' },
        { text: 'User', value: 'user' },
        { text: 'Product', value: 'product' },
        { text: 'Payment', value: 'payment' },
      ],
      onFilter: (value, record) => record.type?.includes(value),
      render: (text) => {
        const colors = {
          order: 'blue',
          user: 'green',
          product: 'orange',
          payment: 'purple',
        };
        return <Tag color={colors[text] || 'default'}>{text?.toUpperCase()}</Tag>;
      },
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      width: 120,
      filters: [
        { text: 'Active', value: 'active' },
        { text: 'Pending', value: 'pending' },
        { text: 'Completed', value: 'completed' },
        { text: 'Failed', value: 'failed' },
      ],
      onFilter: (value, record) => record.status === value,
      render: (status) => {
        const statusConfig = {
          active: { color: 'green', text: 'Active' },
          pending: { color: 'orange', text: 'Pending' },
          completed: { color: 'blue', text: 'Completed' },
          failed: { color: 'red', text: 'Failed' },
          success: { color: 'green', text: 'Success' },
        };
        const config = statusConfig[status] || { color: 'default', text: status };
        return <Badge color={config.color} text={config.text} />;
      },
    },
    {
      title: 'Amount',
      dataIndex: 'amount',
      key: 'amount',
      width: 120,
      sorter: (a, b) => (a.amount || 0) - (b.amount || 0),
      render: (amount) => {
        if (amount == null) return '-';
        return (
          <Text strong style={{ color: amount > 0 ? '#52c41a' : '#f5222d' }}>
            {numeral(amount).format('$0,0.00')}
          </Text>
        );
      },
    },
    {
      title: 'Description',
      dataIndex: 'description',
      key: 'description',
      ellipsis: true,
      render: (text) => (
        <Tooltip title={text}>
          <Text>{text}</Text>
        </Tooltip>
      ),
    },
    {
      title: 'Actions',
      key: 'actions',
      width: 100,
      render: (_, record) => (
        <Space size="small">
          <Tooltip title="View Details">
            <Button
              type="text"
              icon={<EyeOutlined />}
              size="small"
              onClick={(e) => {
                e.stopPropagation();
                onRowClick?.(record);
              }}
            />
          </Tooltip>
        </Space>
      ),
    },
  ];

  const columns = customColumns || defaultColumns;

  // Filter data based on search text
  const handleSearch = (value) => {
    setSearchText(value);
    if (!value) {
      setFilteredData(data);
      return;
    }

    const filtered = data.filter(item =>
      Object.values(item).some(val =>
        String(val).toLowerCase().includes(value.toLowerCase())
      )
    );
    setFilteredData(filtered);
  };

  // Export data
  const handleExport = () => {
    const dataToExport = searchText ? filteredData : data;
    const dataStr = JSON.stringify(dataToExport, null, 2);
    const dataUri = 'data:application/json;charset=utf-8,'+ encodeURIComponent(dataStr);
    const exportFileDefaultName = `${title.toLowerCase().replace(/\s+/g, '-')}-${Date.now()}.json`;
    
    const linkElement = document.createElement('a');
    linkElement.setAttribute('href', dataUri);
    linkElement.setAttribute('download', exportFileDefaultName);
    linkElement.click();
  };

  // Memoized data for performance
  const tableData = useMemo(() => {
    return searchText ? filteredData : data;
  }, [data, filteredData, searchText]);

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
      className="data-table-container"
    >
      <Card
        title={
          <div className="table-header">
            <Space>
              <Text strong style={{ fontSize: '16px' }}>
                {title}
              </Text>
              <Badge 
                count={tableData.length} 
                style={{ backgroundColor: '#52c41a' }}
                showZero
              />
            </Space>
          </div>
        }
        extra={
          <Space>
            {showSearch && (
              <Search
                placeholder="Search data..."
                allowClear
                onChange={(e) => handleSearch(e.target.value)}
                style={{ width: 200 }}
                prefix={<SearchOutlined />}
              />
            )}
            
            {showRefresh && (
              <Tooltip title="Refresh Data">
                <Button
                  type="text"
                  icon={<ReloadOutlined />}
                  onClick={onRefresh}
                  loading={loading}
                />
              </Tooltip>
            )}

            {showExport && (
              <Tooltip title="Export Data">
                <Button
                  type="text"
                  icon={<DownloadOutlined />}
                  onClick={handleExport}
                  disabled={!tableData.length}
                />
              </Tooltip>
            )}
          </Space>
        }
        className="data-table-card"
        bodyStyle={{ padding: 0 }}
      >
        <Table
          columns={columns}
          dataSource={tableData}
          rowKey="id"
          loading={loading}
          pagination={{
            pageSize,
            showSizeChanger: true,
            showQuickJumper: true,
            showTotal: (total, range) =>
              `${range[0]}-${range[1]} of ${total} items`,
            pageSizeOptions: ['10', '20', '50', '100'],
          }}
          scroll={{ x: 'max-content' }}
          size="small"
          onRow={(record) => ({
            onClick: () => onRowClick?.(record),
            className: 'clickable-row',
          })}
          className="custom-table"
          {...props}
        />
      </Card>
    </motion.div>
  );
};

export default DataTable;

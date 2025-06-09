/**
 * Main React Application Component
 * DevOps Final Project - Real-time Dashboard
 */

import React, { useEffect, useState } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { ConfigProvider, Layout, message, notification } from 'antd';
import { QueryClient, QueryClientProvider } from 'react-query';
import { ReactQueryDevtools } from 'react-query/devtools';

// Components
import Dashboard from './components/Dashboard/Dashboard';
import Header from './components/Layout/Header';
import Sidebar from './components/Layout/Sidebar';
import Analytics from './components/Analytics/Analytics';
import Monitoring from './components/Monitoring/Monitoring';
import Settings from './components/Settings/Settings';
import LoadingScreen from './components/Common/LoadingScreen';
import ErrorBoundary from './components/Common/ErrorBoundary';

// Services
import { socketService } from './services/socketService';
import { apiService } from './services/apiService';

// Styles
import './App.css';

const { Content, Sider } = Layout;

// Create a React Query client
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 2,
      staleTime: 30000, // 30 seconds
      cacheTime: 300000, // 5 minutes
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: 1,
    },
  },
});

// Ant Design theme configuration
const theme = {
  token: {
    colorPrimary: '#1890ff',
    borderRadius: 6,
    colorBgContainer: '#ffffff',
  },
  components: {
    Layout: {
      headerBg: '#001529',
      siderBg: '#001529',
    },
  },
};

function App() {
  const [loading, setLoading] = useState(true);
  const [collapsed, setCollapsed] = useState(false);
  const [connectionStatus, setConnectionStatus] = useState('disconnected');
  const [systemHealth, setSystemHealth] = useState(null);

  // Initialize application
  useEffect(() => {
    const initializeApp = async () => {
      try {
        // Check API health
        const health = await apiService.checkHealth();
        setSystemHealth(health);

        // Initialize WebSocket connection
        socketService.connect(process.env.REACT_APP_WEBSOCKET_URL || 'ws://localhost:3001');
        
        // Setup WebSocket event listeners
        setupSocketListeners();

        setLoading(false);
      } catch (error) {
        console.error('Failed to initialize application:', error);
        message.error('Failed to connect to backend services');
        setLoading(false);
      }
    };

    initializeApp();

    // Cleanup on unmount
    return () => {
      socketService.disconnect();
    };
  }, []);

  // Setup WebSocket event listeners
  const setupSocketListeners = () => {
    // Connection status events
    socketService.on('connect', () => {
      setConnectionStatus('connected');
      notification.success({
        message: 'Connected',
        description: 'Real-time updates are now active',
        placement: 'bottomRight',
        duration: 3,
      });
    });

    socketService.on('disconnect', () => {
      setConnectionStatus('disconnected');
      notification.warning({
        message: 'Disconnected',
        description: 'Real-time updates are unavailable',
        placement: 'bottomRight',
        duration: 5,
      });
    });

    socketService.on('reconnect', () => {
      setConnectionStatus('connected');
      notification.info({
        message: 'Reconnected',
        description: 'Real-time updates have been restored',
        placement: 'bottomRight',
        duration: 3,
      });
    });

    // Error handling
    socketService.on('error', (error) => {
      console.error('WebSocket error:', error);
      message.error(`Connection error: ${error.message}`);
    });

    // System health updates
    socketService.on('system-health', (health) => {
      setSystemHealth(health);
    });

    // Global notifications for important events
    socketService.on('alert', (alert) => {
      const type = alert.severity || 'info';
      notification[type]({
        message: alert.title,
        description: alert.message,
        placement: 'topRight',
        duration: alert.duration || 0, // 0 = persistent
      });
    });
  };

  // Handle sidebar collapse
  const handleSidebarCollapse = (collapsed) => {
    setCollapsed(collapsed);
  };

  // Show loading screen while initializing
  if (loading) {
    return (
      <ConfigProvider theme={theme}>
        <LoadingScreen message="Initializing DevOps Dashboard..." />
      </ConfigProvider>
    );
  }

  return (
    <ConfigProvider theme={theme}>
      <QueryClientProvider client={queryClient}>
        <ErrorBoundary>
          <Router>
            <Layout style={{ minHeight: '100vh' }}>
              {/* Sidebar Navigation */}
              <Sider
                collapsible
                collapsed={collapsed}
                onCollapse={handleSidebarCollapse}
                width={250}
                theme="dark"
              >
                <Sidebar 
                  collapsed={collapsed} 
                  connectionStatus={connectionStatus}
                />
              </Sider>

              {/* Main Content Layout */}
              <Layout>
                {/* Header */}
                <Header 
                  connectionStatus={connectionStatus}
                  systemHealth={systemHealth}
                />

                {/* Main Content */}
                <Content
                  style={{
                    margin: '16px',
                    padding: '24px',
                    background: '#f0f2f5',
                    minHeight: 'calc(100vh - 112px)',
                  }}
                >
                  <Routes>
                    {/* Default route redirects to dashboard */}
                    <Route path="/" element={<Navigate to="/dashboard" replace />} />
                    
                    {/* Dashboard - Main BI interface */}
                    <Route 
                      path="/dashboard" 
                      element={<Dashboard />} 
                    />
                    
                    {/* Analytics - User behavior and events */}
                    <Route 
                      path="/analytics" 
                      element={<Analytics />} 
                    />
                    
                    {/* Monitoring - System performance and health */}
                    <Route 
                      path="/monitoring" 
                      element={<Monitoring />} 
                    />
                    
                    {/* Settings - Application configuration */}
                    <Route 
                      path="/settings" 
                      element={<Settings />} 
                    />
                    
                    {/* Catch-all route */}
                    <Route 
                      path="*" 
                      element={<Navigate to="/dashboard" replace />} 
                    />
                  </Routes>
                </Content>
              </Layout>
            </Layout>
          </Router>
        </ErrorBoundary>
        
        {/* React Query DevTools (development only) */}
        {process.env.NODE_ENV === 'development' && (
          <ReactQueryDevtools initialIsOpen={false} />
        )}
      </QueryClientProvider>
    </ConfigProvider>
  );
}

export default App;

/**
 * API Service
 * Handles HTTP requests to the backend API
 */

import axios from 'axios';

// Create axios instance with default configuration
const api = axios.create({
  baseURL: process.env.REACT_APP_API_URL || 'http://localhost:3001/api',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor
api.interceptors.request.use(
  (config) => {
    // Add timestamp to prevent caching
    config.params = {
      ...config.params,
      _t: Date.now(),
    };

    // Add authorization header if token exists
    const token = localStorage.getItem('authToken');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }

    console.log('API Request:', config.method?.toUpperCase(), config.url);
    return config;
  },
  (error) => {
    console.error('API Request Error:', error);
    return Promise.reject(error);
  }
);

// Response interceptor
api.interceptors.response.use(
  (response) => {
    console.log('API Response:', response.status, response.config.url);
    return response;
  },
  (error) => {
    console.error('API Response Error:', error.response?.status, error.config?.url, error.message);
    
    // Handle specific error codes
    if (error.response?.status === 401) {
      // Unauthorized - redirect to login or refresh token
      localStorage.removeItem('authToken');
      // window.location.href = '/login';
    } else if (error.response?.status === 503) {
      // Service unavailable
      console.warn('Service temporarily unavailable');
    }

    return Promise.reject(error);
  }
);

class ApiService {
  // Health check
  async checkHealth() {
    const response = await api.get('/health');
    return response.data;
  }

  async getDetailedHealth() {
    const response = await api.get('/health/detailed');
    return response.data;
  }

  async getDatabaseHealth() {
    const response = await api.get('/health/database');
    return response.data;
  }

  // Dashboard endpoints
  async getDashboardData(params = {}) {
    const response = await api.get('/dashboard', { params });
    return response.data;
  }

  async getRealTimeDashboardData() {
    const response = await api.get('/dashboard/real-time');
    return response.data;
  }

  async getKPIs(params = {}) {
    const response = await api.get('/dashboard/kpis', { params });
    return response.data;
  }

  async getChartData(type, params = {}) {
    const response = await api.get(`/dashboard/charts/${type}`, { params });
    return response.data;
  }

  async exportDashboardData(params = {}) {
    const response = await api.get('/dashboard/export', { 
      params,
      responseType: 'blob' // For file downloads
    });
    
    // Create download link
    const url = window.URL.createObjectURL(new Blob([response.data]));
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `dashboard-export-${Date.now()}.${params.format || 'json'}`);
    document.body.appendChild(link);
    link.click();
    link.remove();
    window.URL.revokeObjectURL(url);
    
    return response.data;
  }

  // Users endpoints
  async getUsers(params = {}) {
    const response = await api.get('/users', { params });
    return response.data;
  }

  async getUser(id) {
    const response = await api.get(`/users/${id}`);
    return response.data;
  }

  async createUser(userData) {
    const response = await api.post('/users', userData);
    return response.data;
  }

  async updateUser(id, userData) {
    const response = await api.put(`/users/${id}`, userData);
    return response.data;
  }

  async deleteUser(id) {
    const response = await api.delete(`/users/${id}`);
    return response.data;
  }

  async getUserStats() {
    const response = await api.get('/users/stats');
    return response.data;
  }

  // Orders endpoints
  async getOrders(params = {}) {
    const response = await api.get('/orders', { params });
    return response.data;
  }

  async getOrder(id) {
    const response = await api.get(`/orders/${id}`);
    return response.data;
  }

  async createOrder(orderData) {
    const response = await api.post('/orders', orderData);
    return response.data;
  }

  async updateOrder(id, orderData) {
    const response = await api.put(`/orders/${id}`, orderData);
    return response.data;
  }

  async deleteOrder(id) {
    const response = await api.delete(`/orders/${id}`);
    return response.data;
  }

  async getOrderStats() {
    const response = await api.get('/orders/stats');
    return response.data;
  }

  // Products endpoints
  async getProducts(params = {}) {
    const response = await api.get('/products', { params });
    return response.data;
  }

  async getProduct(id) {
    const response = await api.get(`/products/${id}`);
    return response.data;
  }

  async createProduct(productData) {
    const response = await api.post('/products', productData);
    return response.data;
  }

  async updateProduct(id, productData) {
    const response = await api.put(`/products/${id}`, productData);
    return response.data;
  }

  async deleteProduct(id) {
    const response = await api.delete(`/products/${id}`);
    return response.data;
  }

  async getProductStats() {
    const response = await api.get('/products/stats');
    return response.data;
  }

  // Analytics endpoints
  async getAnalyticsEvents(params = {}) {
    const response = await api.get('/analytics/events', { params });
    return response.data;
  }

  async trackAnalyticsEvent(eventData) {
    const response = await api.post('/analytics/events', eventData);
    return response.data;
  }

  async getAnalyticsDashboard(params = {}) {
    const response = await api.get('/analytics/dashboard', { params });
    return response.data;
  }

  async getAnalyticsReport(type, params = {}) {
    const response = await api.get(`/analytics/reports/${type}`, { params });
    return response.data;
  }

  // Metrics endpoints
  async getMetrics(params = {}) {
    const response = await api.get('/metrics', { params });
    return response.data;
  }

  async submitMetric(metricData) {
    const response = await api.post('/metrics', metricData);
    return response.data;
  }

  async getMetricsDashboard(params = {}) {
    const response = await api.get('/metrics/dashboard', { params });
    return response.data;
  }

  async getRealTimeMetrics() {
    const response = await api.get('/metrics/real-time');
    return response.data;
  }

  // Utility methods
  async testConnection() {
    try {
      await this.checkHealth();
      return { status: 'connected', timestamp: new Date().toISOString() };
    } catch (error) {
      return { 
        status: 'disconnected', 
        error: error.message,
        timestamp: new Date().toISOString()
      };
    }
  }

  async testDatabaseConnection() {
    try {
      const health = await this.getDatabaseHealth();
      return {
        status: 'connected',
        databases: health.databases,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      return {
        status: 'error',
        error: error.message,
        timestamp: new Date().toISOString()
      };
    }
  }

  // Error handling utility
  handleApiError(error) {
    if (error.response) {
      // Server responded with error status
      const { status, data } = error.response;
      return {
        type: 'server_error',
        status,
        message: data.message || data.error || 'Server error occurred',
        details: data.details || null,
      };
    } else if (error.request) {
      // Request was made but no response received
      return {
        type: 'network_error',
        message: 'Network error - unable to reach server',
        details: error.message,
      };
    } else {
      // Error in request setup
      return {
        type: 'client_error',
        message: 'Request configuration error',
        details: error.message,
      };
    }
  }

  // Batch requests utility
  async batchRequest(requests) {
    try {
      const responses = await Promise.allSettled(requests);
      return responses.map((response, index) => ({
        index,
        status: response.status,
        data: response.status === 'fulfilled' ? response.value.data : null,
        error: response.status === 'rejected' ? this.handleApiError(response.reason) : null,
      }));
    } catch (error) {
      throw this.handleApiError(error);
    }
  }
}

// Create singleton instance
const apiService = new ApiService();

export { apiService };
export default apiService;

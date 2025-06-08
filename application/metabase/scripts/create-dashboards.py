#!/usr/bin/env python3

"""
Metabase Dashboard Creation Script
Creates comprehensive BI dashboards with real-time metrics and visualizations
"""

import json
import requests
import time
import sys
import os
import argparse
import logging
from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/metabase-dashboards.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class MetabaseDashboardCreator:
    """Creates and manages Metabase dashboards"""
    
    def __init__(self, base_url: str, session_token: str):
        self.base_url = base_url.rstrip('/')
        self.session_token = session_token
        self.session = requests.Session()
        self.session.headers.update({
            'X-Metabase-Session': session_token,
            'Content-Type': 'application/json'
        })
        
        # Store database IDs
        self.mysql_db_id = None
        self.postgresql_db_id = None
        
        # Dashboard collections
        self.collections = {}
        
    def get_databases(self) -> Dict[str, int]:
        """Get database IDs from Metabase"""
        logger.info("Fetching database information...")
        
        response = self.session.get(f"{self.base_url}/api/database")
        response.raise_for_status()
        
        databases = response.json()['data']
        db_map = {}
        
        for db in databases:
            if db['engine'] == 'mysql':
                self.mysql_db_id = db['id']
                db_map['mysql'] = db['id']
                logger.info(f"Found MySQL database: {db['name']} (ID: {db['id']})")
            elif db['engine'] == 'postgres':
                self.postgresql_db_id = db['id']
                db_map['postgresql'] = db['id']
                logger.info(f"Found PostgreSQL database: {db['name']} (ID: {db['id']})")
        
        return db_map
    
    def create_collection(self, name: str, description: str, color: str = "#509EE3") -> int:
        """Create a collection for organizing dashboards"""
        logger.info(f"Creating collection: {name}")
        
        # Check if collection already exists
        response = self.session.get(f"{self.base_url}/api/collection")
        response.raise_for_status()
        
        collections = response.json()
        for collection in collections:
            if collection['name'] == name:
                logger.info(f"Collection '{name}' already exists (ID: {collection['id']})")
                return collection['id']
        
        # Create new collection
        data = {
            "name": name,
            "description": description,
            "color": color,
            "parent_id": None
        }
        
        response = self.session.post(f"{self.base_url}/api/collection", json=data)
        response.raise_for_status()
        
        collection_id = response.json()['id']
        logger.info(f"Created collection: {name} (ID: {collection_id})")
        
        return collection_id
    
    def create_question(self, name: str, description: str, database_id: int, 
                       query: Dict[str, Any], visualization_settings: Dict[str, Any] = None,
                       collection_id: Optional[int] = None) -> int:
        """Create a question (chart/visualization)"""
        logger.info(f"Creating question: {name}")
        
        data = {
            "name": name,
            "description": description,
            "database_id": database_id,
            "dataset_query": query,
            "display": query.get("display", "table"),
            "visualization_settings": visualization_settings or {},
            "collection_id": collection_id
        }
        
        response = self.session.post(f"{self.base_url}/api/card", json=data)
        response.raise_for_status()
        
        question_id = response.json()['id']
        logger.info(f"Created question: {name} (ID: {question_id})")
        
        return question_id
    
    def create_dashboard(self, name: str, description: str, collection_id: Optional[int] = None) -> int:
        """Create a dashboard"""
        logger.info(f"Creating dashboard: {name}")
        
        data = {
            "name": name,
            "description": description,
            "collection_id": collection_id,
            "parameters": []
        }
        
        response = self.session.post(f"{self.base_url}/api/dashboard", json=data)
        response.raise_for_status()
        
        dashboard_id = response.json()['id']
        logger.info(f"Created dashboard: {name} (ID: {dashboard_id})")
        
        return dashboard_id
    
    def add_card_to_dashboard(self, dashboard_id: int, card_id: int, 
                             row: int, col: int, size_x: int = 4, size_y: int = 4) -> int:
        """Add a card to a dashboard"""
        data = {
            "cardId": card_id,
            "row": row,
            "col": col,
            "sizeX": size_x,
            "sizeY": size_y,
            "parameter_mappings": []
        }
        
        response = self.session.post(f"{self.base_url}/api/dashboard/{dashboard_id}/cards", json=data)
        response.raise_for_status()
        
        return response.json()['id']
    
    def create_executive_dashboard(self) -> int:
        """Create executive overview dashboard"""
        logger.info("Creating Executive Overview Dashboard...")
        
        # Create collection
        collection_id = self.create_collection(
            "Executive Dashboards",
            "High-level business metrics and KPIs for executives",
            "#E74C3C"
        )
        
        # Create dashboard
        dashboard_id = self.create_dashboard(
            "Executive Overview",
            "Real-time business metrics and key performance indicators",
            collection_id
        )
        
        # Revenue metrics
        revenue_today_query = {
            "type": "native",
            "native": {
                "query": """
                SELECT 
                    COALESCE(SUM(total_amount), 0) as revenue_today,
                    COUNT(*) as orders_today
                FROM orders 
                WHERE DATE(order_date) = CURDATE() 
                  AND status IN ('completed', 'delivered')
                """,
                "template-tags": {}
            },
            "database": self.mysql_db_id,
            "display": "scalar"
        }
        
        revenue_card_id = self.create_question(
            "Revenue Today",
            "Total revenue for today",
            self.mysql_db_id,
            revenue_today_query,
            {
                "column_settings": {
                    "[\"name\",\"revenue_today\"]": {
                        "number_style": "currency",
                        "currency": "USD"
                    }
                }
            },
            collection_id
        )
        
        # Orders today
        orders_today_query = {
            "type": "native",
            "native": {
                "query": """
                SELECT COUNT(*) as orders_today
                FROM orders 
                WHERE DATE(order_date) = CURDATE()
                """,
                "template-tags": {}
            },
            "database": self.mysql_db_id,
            "display": "scalar"
        }
        
        orders_card_id = self.create_question(
            "Orders Today",
            "Number of orders placed today",
            self.mysql_db_id,
            orders_today_query,
            {},
            collection_id
        )
        
        # Active users
        active_users_query = {
            "type": "native",
            "native": {
                "query": """
                SELECT COUNT(DISTINCT user_id) as active_users_today
                FROM analytics_events 
                WHERE DATE(timestamp) = CURRENT_DATE
                  AND user_id IS NOT NULL
                """,
                "template-tags": {}
            },
            "database": self.postgresql_db_id,
            "display": "scalar"
        }
        
        active_users_card_id = self.create_question(
            "Active Users Today",
            "Number of active users today",
            self.postgresql_db_id,
            active_users_query,
            {},
            collection_id
        )
        
        # Conversion rate
        conversion_rate_query = {
            "type": "native",
            "native": {
                "query": """
                WITH visitors AS (
                    SELECT COUNT(DISTINCT session_id) as total_sessions
                    FROM analytics_events 
                    WHERE DATE(timestamp) = CURRENT_DATE
                ),
                conversions AS (
                    SELECT COUNT(DISTINCT session_id) as converted_sessions
                    FROM analytics_events 
                    WHERE DATE(timestamp) = CURRENT_DATE
                      AND event_type = 'conversion'
                )
                SELECT 
                    CASE 
                        WHEN v.total_sessions > 0 
                        THEN ROUND((c.converted_sessions::DECIMAL / v.total_sessions) * 100, 2)
                        ELSE 0 
                    END as conversion_rate
                FROM visitors v, conversions c
                """,
                "template-tags": {}
            },
            "database": self.postgresql_db_id,
            "display": "scalar"
        }
        
        conversion_card_id = self.create_question(
            "Conversion Rate Today",
            "Conversion rate for today (%)",
            self.postgresql_db_id,
            conversion_rate_query,
            {
                "column_settings": {
                    "[\"name\",\"conversion_rate\"]": {
                        "number_style": "percent",
                        "decimals": 2
                    }
                }
            },
            collection_id
        )
        
        # Revenue trend (last 30 days)
        revenue_trend_query = {
            "type": "native",
            "native": {
                "query": """
                SELECT 
                    DATE(order_date) as date,
                    SUM(total_amount) as revenue,
                    COUNT(*) as orders
                FROM orders 
                WHERE order_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
                  AND status IN ('completed', 'delivered')
                GROUP BY DATE(order_date)
                ORDER BY date DESC
                """,
                "template-tags": {}
            },
            "database": self.mysql_db_id,
            "display": "line"
        }
        
        revenue_trend_card_id = self.create_question(
            "Revenue Trend (30 Days)",
            "Daily revenue for the last 30 days",
            self.mysql_db_id,
            revenue_trend_query,
            {
                "graph.dimensions": ["date"],
                "graph.metrics": ["revenue"],
                "graph.x_axis.scale": "timeseries"
            },
            collection_id
        )
        
        # Add cards to dashboard
        self.add_card_to_dashboard(dashboard_id, revenue_card_id, 0, 0, 3, 3)
        self.add_card_to_dashboard(dashboard_id, orders_card_id, 0, 3, 3, 3)
        self.add_card_to_dashboard(dashboard_id, active_users_card_id, 0, 6, 3, 3)
        self.add_card_to_dashboard(dashboard_id, conversion_card_id, 0, 9, 3, 3)
        self.add_card_to_dashboard(dashboard_id, revenue_trend_card_id, 3, 0, 12, 6)
        
        logger.info("Executive Overview Dashboard created successfully")
        return dashboard_id
    
    def create_sales_dashboard(self) -> int:
        """Create sales analytics dashboard"""
        logger.info("Creating Sales Analytics Dashboard...")
        
        collection_id = self.create_collection(
            "Sales Analytics",
            "Detailed sales performance metrics and customer insights",
            "#27AE60"
        )
        
        dashboard_id = self.create_dashboard(
            "Sales Performance",
            "Comprehensive sales analytics and performance metrics",
            collection_id
        )
        
        # Top selling products
        top_products_query = {
            "type": "native",
            "native": {
                "query": """
                SELECT 
                    p.name,
                    p.category,
                    SUM(oi.quantity) as total_sold,
                    SUM(oi.total_price) as revenue,
                    COUNT(DISTINCT oi.order_id) as order_count
                FROM products p
                JOIN order_items oi ON p.id = oi.product_id
                JOIN orders o ON oi.order_id = o.id
                WHERE o.status IN ('completed', 'delivered')
                  AND o.order_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
                GROUP BY p.id, p.name, p.category
                ORDER BY total_sold DESC
                LIMIT 10
                """,
                "template-tags": {}
            },
            "database": self.mysql_db_id,
            "display": "bar"
        }
        
        top_products_card_id = self.create_question(
            "Top Selling Products",
            "Best performing products by quantity sold",
            self.mysql_db_id,
            top_products_query,
            collection_id=collection_id
        )
        
        # Sales by category
        category_sales_query = {
            "type": "native",
            "native": {
                "query": """
                SELECT 
                    p.category,
                    SUM(oi.total_price) as revenue,
                    COUNT(DISTINCT oi.order_id) as orders,
                    SUM(oi.quantity) as items_sold
                FROM products p
                JOIN order_items oi ON p.id = oi.product_id
                JOIN orders o ON oi.order_id = o.id
                WHERE o.status IN ('completed', 'delivered')
                  AND o.order_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
                GROUP BY p.category
                ORDER BY revenue DESC
                """,
                "template-tags": {}
            },
            "database": self.mysql_db_id,
            "display": "pie"
        }
        
        category_card_id = self.create_question(
            "Sales by Category",
            "Revenue distribution by product category",
            self.mysql_db_id,
            category_sales_query,
            collection_id=collection_id
        )
        
        # Customer segments
        customer_segments_query = {
            "type": "native",
            "native": {
                "query": """
                SELECT 
                    cs.segment_type,
                    COUNT(*) as customers,
                    AVG(cs.lifetime_value) as avg_clv,
                    SUM(cs.lifetime_value) as total_clv
                FROM customer_segments cs
                WHERE cs.is_active = 1
                GROUP BY cs.segment_type
                ORDER BY total_clv DESC
                """,
                "template-tags": {}
            },
            "database": self.mysql_db_id,
            "display": "bar"
        }
        
        segments_card_id = self.create_question(
            "Customer Segments",
            "Customer distribution by segment type",
            self.mysql_db_id,
            customer_segments_query,
            collection_id=collection_id
        )
        
        # Add cards to dashboard
        self.add_card_to_dashboard(dashboard_id, top_products_card_id, 0, 0, 8, 6)
        self.add_card_to_dashboard(dashboard_id, category_card_id, 0, 8, 4, 6)
        self.add_card_to_dashboard(dashboard_id, segments_card_id, 6, 0, 12, 6)
        
        logger.info("Sales Analytics Dashboard created successfully")
        return dashboard_id
    
    def create_customer_dashboard(self) -> int:
        """Create customer analytics dashboard"""
        logger.info("Creating Customer Analytics Dashboard...")
        
        collection_id = self.create_collection(
            "Customer Analytics",
            "Customer behavior, retention, and lifetime value analysis",
            "#9B59B6"
        )
        
        dashboard_id = self.create_dashboard(
            "Customer Analytics",
            "Customer behavior and retention metrics",
            collection_id
        )
        
        # Customer acquisition
        acquisition_query = {
            "type": "native",
            "native": {
                "query": """
                SELECT 
                    DATE(created_at) as date,
                    COUNT(*) as new_customers
                FROM users 
                WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
                GROUP BY DATE(created_at)
                ORDER BY date DESC
                """,
                "template-tags": {}
            },
            "database": self.mysql_db_id,
            "display": "line"
        }
        
        acquisition_card_id = self.create_question(
            "Customer Acquisition",
            "New customers acquired daily",
            self.mysql_db_id,
            acquisition_query,
            collection_id=collection_id
        )
        
        # Customer lifetime value distribution
        clv_distribution_query = {
            "type": "native",
            "native": {
                "query": """
                SELECT 
                    CASE 
                        WHEN lifetime_value < 100 THEN '$0-$99'
                        WHEN lifetime_value < 500 THEN '$100-$499'
                        WHEN lifetime_value < 1000 THEN '$500-$999'
                        WHEN lifetime_value < 2000 THEN '$1000-$1999'
                        ELSE '$2000+'
                    END as clv_range,
                    COUNT(*) as customers
                FROM customer_segments
                WHERE is_active = 1
                GROUP BY clv_range
                ORDER BY MIN(lifetime_value)
                """,
                "template-tags": {}
            },
            "database": self.mysql_db_id,
            "display": "bar"
        }
        
        clv_card_id = self.create_question(
            "Customer Lifetime Value Distribution",
            "Distribution of customers by CLV ranges",
            self.mysql_db_id,
            clv_distribution_query,
            collection_id=collection_id
        )
        
        # User behavior flow
        behavior_flow_query = {
            "type": "native",
            "native": {
                "query": """
                SELECT 
                    event_type,
                    COUNT(*) as event_count,
                    COUNT(DISTINCT session_id) as unique_sessions
                FROM analytics_events 
                WHERE timestamp >= NOW() - INTERVAL '7 days'
                GROUP BY event_type
                ORDER BY event_count DESC
                """,
                "template-tags": {}
            },
            "database": self.postgresql_db_id,
            "display": "bar"
        }
        
        behavior_card_id = self.create_question(
            "User Behavior Events",
            "Most common user events in the last 7 days",
            self.postgresql_db_id,
            behavior_flow_query,
            collection_id=collection_id
        )
        
        # Add cards to dashboard
        self.add_card_to_dashboard(dashboard_id, acquisition_card_id, 0, 0, 6, 6)
        self.add_card_to_dashboard(dashboard_id, clv_card_id, 0, 6, 6, 6)
        self.add_card_to_dashboard(dashboard_id, behavior_card_id, 6, 0, 12, 6)
        
        logger.info("Customer Analytics Dashboard created successfully")
        return dashboard_id
    
    def create_realtime_dashboard(self) -> int:
        """Create real-time monitoring dashboard"""
        logger.info("Creating Real-time Monitoring Dashboard...")
        
        collection_id = self.create_collection(
            "Real-time Monitoring",
            "Live system metrics and real-time business data",
            "#F39C12"
        )
        
        dashboard_id = self.create_dashboard(
            "Real-time Monitor",
            "Live metrics and system health monitoring",
            collection_id
        )
        
        # Live user activity
        live_activity_query = {
            "type": "native",
            "native": {
                "query": """
                SELECT 
                    DATE_TRUNC('minute', timestamp) as minute,
                    COUNT(*) as events,
                    COUNT(DISTINCT session_id) as active_sessions
                FROM analytics_events 
                WHERE timestamp >= NOW() - INTERVAL '1 hour'
                GROUP BY DATE_TRUNC('minute', timestamp)
                ORDER BY minute DESC
                """,
                "template-tags": {}
            },
            "database": self.postgresql_db_id,
            "display": "line"
        }
        
        live_activity_card_id = self.create_question(
            "Live User Activity",
            "User activity in the last hour (by minute)",
            self.postgresql_db_id,
            live_activity_query,
            collection_id=collection_id
        )
        
        # System performance metrics
        performance_query = {
            "type": "native",
            "native": {
                "query": """
                SELECT 
                    metric_name,
                    AVG(value) as avg_value,
                    MAX(value) as max_value
                FROM performance_metrics 
                WHERE timestamp >= NOW() - INTERVAL '1 hour'
                  AND metric_name IN ('cpu_usage', 'memory_usage', 'response_time')
                GROUP BY metric_name
                ORDER BY metric_name
                """,
                "template-tags": {}
            },
            "database": self.postgresql_db_id,
            "display": "bar"
        }
        
        performance_card_id = self.create_question(
            "System Performance",
            "Average system metrics in the last hour",
            self.postgresql_db_id,
            performance_query,
            collection_id=collection_id
        )
        
        # Recent orders
        recent_orders_query = {
            "type": "native",
            "native": {
                "query": """
                SELECT 
                    o.order_number,
                    u.username,
                    o.total_amount,
                    o.status,
                    o.order_date
                FROM orders o
                JOIN users u ON o.user_id = u.id
                WHERE o.order_date >= DATE_SUB(NOW(), INTERVAL 2 HOUR)
                ORDER BY o.order_date DESC
                LIMIT 20
                """,
                "template-tags": {}
            },
            "database": self.mysql_db_id,
            "display": "table"
        }
        
        recent_orders_card_id = self.create_question(
            "Recent Orders",
            "Orders placed in the last 2 hours",
            self.mysql_db_id,
            recent_orders_query,
            collection_id=collection_id
        )
        
        # Add cards to dashboard
        self.add_card_to_dashboard(dashboard_id, live_activity_card_id, 0, 0, 6, 6)
        self.add_card_to_dashboard(dashboard_id, performance_card_id, 0, 6, 6, 6)
        self.add_card_to_dashboard(dashboard_id, recent_orders_card_id, 6, 0, 12, 6)
        
        logger.info("Real-time Monitoring Dashboard created successfully")
        return dashboard_id
    
    def create_marketing_dashboard(self) -> int:
        """Create marketing analytics dashboard"""
        logger.info("Creating Marketing Analytics Dashboard...")
        
        collection_id = self.create_collection(
            "Marketing Analytics",
            "Campaign performance and marketing attribution analysis",
            "#E67E22"
        )
        
        dashboard_id = self.create_dashboard(
            "Marketing Performance",
            "Marketing campaign metrics and attribution analysis",
            collection_id
        )
        
        # Campaign performance
        campaign_performance_query = {
            "type": "native",
            "native": {
                "query": """
                SELECT 
                    mc.campaign_name,
                    mc.campaign_type,
                    SUM(cm.clicks) as total_clicks,
                    SUM(cm.conversions) as total_conversions,
                    SUM(cm.cost) as total_cost,
                    SUM(cm.revenue) as total_revenue,
                    CASE 
                        WHEN SUM(cm.clicks) > 0 
                        THEN ROUND((SUM(cm.conversions)::DECIMAL / SUM(cm.clicks)) * 100, 2)
                        ELSE 0 
                    END as conversion_rate,
                    CASE 
                        WHEN SUM(cm.cost) > 0 
                        THEN ROUND(SUM(cm.revenue) / SUM(cm.cost), 2)
                        ELSE 0 
                    END as roas
                FROM marketing_campaigns mc
                LEFT JOIN campaign_metrics cm ON mc.id = cm.campaign_id
                WHERE mc.status = 'active'
                  AND cm.metric_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
                GROUP BY mc.id, mc.campaign_name, mc.campaign_type
                ORDER BY total_revenue DESC
                """,
                "template-tags": {}
            },
            "database": self.mysql_db_id,
            "display": "table"
        }
        
        campaign_card_id = self.create_question(
            "Campaign Performance",
            "Marketing campaign performance metrics",
            self.mysql_db_id,
            campaign_performance_query,
            collection_id=collection_id
        )
        
        # Traffic sources
        traffic_sources_query = {
            "type": "native",
            "native": {
                "query": """
                SELECT 
                    traffic_source,
                    SUM(unique_visitors) as visitors,
                    SUM(page_views) as page_views,
                    AVG(conversion_rate) as avg_conversion_rate
                FROM traffic_analytics 
                WHERE date_recorded >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
                GROUP BY traffic_source
                ORDER BY visitors DESC
                """,
                "template-tags": {}
            },
            "database": self.mysql_db_id,
            "display": "pie"
        }
        
        traffic_card_id = self.create_question(
            "Traffic Sources",
            "Website traffic by source",
            self.mysql_db_id,
            traffic_sources_query,
            collection_id=collection_id
        )
        
        # Add cards to dashboard
        self.add_card_to_dashboard(dashboard_id, campaign_card_id, 0, 0, 12, 8)
        self.add_card_to_dashboard(dashboard_id, traffic_card_id, 8, 0, 6, 6)
        
        logger.info("Marketing Analytics Dashboard created successfully")
        return dashboard_id
    
    def setup_auto_refresh(self, dashboard_ids: List[int], refresh_seconds: int = 60):
        """Set up auto-refresh for dashboards"""
        logger.info(f"Setting up auto-refresh ({refresh_seconds}s) for dashboards...")
        
        for dashboard_id in dashboard_ids:
            # Get dashboard details
            response = self.session.get(f"{self.base_url}/api/dashboard/{dashboard_id}")
            response.raise_for_status()
            
            dashboard = response.json()
            
            # Enable auto-refresh
            dashboard['auto_apply_filters'] = True
            dashboard['cache_ttl'] = refresh_seconds
            
            # Update dashboard
            response = self.session.put(f"{self.base_url}/api/dashboard/{dashboard_id}", json=dashboard)
            response.raise_for_status()
            
            logger.info(f"Auto-refresh enabled for dashboard ID: {dashboard_id}")
    
    def create_all_dashboards(self) -> Dict[str, int]:
        """Create all dashboards"""
        logger.info("Starting comprehensive dashboard creation...")
        
        # Get database information
        self.get_databases()
        
        if not self.mysql_db_id or not self.postgresql_db_id:
            raise ValueError("Required databases not found. Please set up database connections first.")
        
        dashboards = {}
        
        try:
            # Create dashboards
            dashboards['executive'] = self.create_executive_dashboard()
            dashboards['sales'] = self.create_sales_dashboard()
            dashboards['customer'] = self.create_customer_dashboard()
            dashboards['realtime'] = self.create_realtime_dashboard()
            dashboards['marketing'] = self.create_marketing_dashboard()
            
            # Set up auto-refresh for real-time dashboard
            self.setup_auto_refresh([dashboards['realtime']], 30)  # 30 second refresh
            
            logger.info("All dashboards created successfully!")
            
            return dashboards
            
        except Exception as e:
            logger.error(f"Error creating dashboards: {e}")
            raise

def main():
    parser = argparse.ArgumentParser(description='Create Metabase dashboards for DevOps analytics')
    parser.add_argument('--url', default='http://localhost:3000', help='Metabase URL')
    parser.add_argument('--email', required=True, help='Admin email')
    parser.add_argument('--password', required=True, help='Admin password')
    parser.add_argument('--dashboards', nargs='+', 
                       choices=['executive', 'sales', 'customer', 'realtime', 'marketing', 'all'],
                       default=['all'], help='Dashboards to create')
    
    args = parser.parse_args()
    
    try:
        # Authenticate with Metabase
        logger.info("Authenticating with Metabase...")
        auth_response = requests.post(f"{args.url}/api/session", json={
            "username": args.email,
            "password": args.password
        })
        auth_response.raise_for_status()
        
        session_token = auth_response.json()['id']
        logger.info("Authentication successful")
        
        # Create dashboard creator
        creator = MetabaseDashboardCreator(args.url, session_token)
        
        # Create requested dashboards
        if 'all' in args.dashboards:
            dashboards = creator.create_all_dashboards()
        else:
            dashboards = {}
            creator.get_databases()
            
            if 'executive' in args.dashboards:
                dashboards['executive'] = creator.create_executive_dashboard()
            if 'sales' in args.dashboards:
                dashboards['sales'] = creator.create_sales_dashboard()
            if 'customer' in args.dashboards:
                dashboards['customer'] = creator.create_customer_dashboard()
            if 'realtime' in args.dashboards:
                dashboards['realtime'] = creator.create_realtime_dashboard()
            if 'marketing' in args.dashboards:
                dashboards['marketing'] = creator.create_marketing_dashboard()
        
        # Display results
        print("\n=== Dashboard Creation Summary ===")
        for name, dashboard_id in dashboards.items():
            print(f"{name.title()} Dashboard: {args.url}/dashboard/{dashboard_id}")
        
        print(f"\nTotal dashboards created: {len(dashboards)}")
        print("All dashboards are ready for use!")
        
    except Exception as e:
        logger.error(f"Dashboard creation failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()

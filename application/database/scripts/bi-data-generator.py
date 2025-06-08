#!/usr/bin/env python3

"""
BI Data Generator for DevOps Dashboard
Generates realistic business intelligence data for impressive dashboard visualizations
"""

import random
import json
import time
import logging
import argparse
from datetime import datetime, timedelta
from typing import Dict, List, Any
import threading
import signal
import sys
from dataclasses import dataclass
import psycopg2
import mysql.connector
from decimal import Decimal

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/bi-data-generator.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class DatabaseConfig:
    """Database connection configuration"""
    host: str
    port: int
    database: str
    username: str
    password: str
    
class BiDataGenerator:
    """Generates realistic BI data for dashboard demonstrations"""
    
    def __init__(self, mysql_config: DatabaseConfig, postgresql_config: DatabaseConfig):
        self.mysql_config = mysql_config
        self.postgresql_config = postgresql_config
        self.running = False
        self.mysql_conn = None
        self.postgresql_conn = None
        
        # Business data configuration
        self.product_categories = [
            'Electronics', 'Furniture', 'Sports', 'Kitchen', 'Office', 'Home'
        ]
        
        self.user_agents = [
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
            'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X)',
            'Mozilla/5.0 (Android 11; Mobile; rv:92.0)'
        ]
        
        self.countries = ['US', 'CA', 'GB', 'DE', 'FR', 'AU', 'JP', 'BR']
        self.cities = {
            'US': ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix'],
            'CA': ['Toronto', 'Vancouver', 'Montreal', 'Calgary', 'Ottawa'],
            'GB': ['London', 'Manchester', 'Birmingham', 'Liverpool', 'Leeds'],
            'DE': ['Berlin', 'Munich', 'Hamburg', 'Cologne', 'Frankfurt'],
            'FR': ['Paris', 'Lyon', 'Marseille', 'Toulouse', 'Nice'],
        }
        
        self.page_urls = [
            '/dashboard', '/analytics', '/monitoring', '/settings',
            '/products', '/orders', '/users', '/reports'
        ]
        
        self.event_types = [
            'page_view', 'click', 'scroll', 'form_submit', 
            'download', 'search', 'filter_change', 'chart_interaction'
        ]
        
    def connect_databases(self):
        """Establish database connections"""
        try:
            # MySQL connection
            self.mysql_conn = mysql.connector.connect(
                host=self.mysql_config.host,
                port=self.mysql_config.port,
                database=self.mysql_config.database,
                user=self.mysql_config.username,
                password=self.mysql_config.password,
                autocommit=True
            )
            logger.info("MySQL connection established")
            
            # PostgreSQL connection
            self.postgresql_conn = psycopg2.connect(
                host=self.postgresql_config.host,
                port=self.postgresql_config.port,
                database=self.postgresql_config.database,
                user=self.postgresql_config.username,
                password=self.postgresql_config.password
            )
            self.postgresql_conn.autocommit = True
            logger.info("PostgreSQL connection established")
            
        except Exception as e:
            logger.error(f"Database connection failed: {e}")
            raise
    
    def disconnect_databases(self):
        """Close database connections"""
        if self.mysql_conn:
            self.mysql_conn.close()
            logger.info("MySQL connection closed")
            
        if self.postgresql_conn:
            self.postgresql_conn.close()
            logger.info("PostgreSQL connection closed")
    
    def generate_order_data(self) -> Dict[str, Any]:
        """Generate realistic order data"""
        now = datetime.now()
        
        # Get random user and products
        mysql_cursor = self.mysql_conn.cursor()
        
        # Get random user
        mysql_cursor.execute("SELECT id FROM users WHERE is_active = 1 ORDER BY RAND() LIMIT 1")
        user_result = mysql_cursor.fetchone()
        user_id = user_result[0] if user_result else 1
        
        # Get random products (1-5 items per order)
        item_count = random.randint(1, 5)
        mysql_cursor.execute(f"""
            SELECT id, price FROM products 
            WHERE is_active = 1 
            ORDER BY RAND() 
            LIMIT {item_count}
        """)
        products = mysql_cursor.fetchall()
        
        if not products:
            return None
        
        # Calculate order total
        total_amount = 0
        order_items = []
        
        for product_id, price in products:
            quantity = random.randint(1, 3)
            unit_price = float(price) * random.uniform(0.9, 1.1)  # Add some price variation
            item_total = unit_price * quantity
            total_amount += item_total
            
            order_items.append({
                'product_id': product_id,
                'quantity': quantity,
                'unit_price': unit_price
            })
        
        # Generate order
        order_number = f"ORD-{now.strftime('%Y%m%d')}-{random.randint(1000, 9999)}"
        status = random.choices(
            ['pending', 'processing', 'shipped', 'delivered'],
            weights=[10, 30, 40, 20]
        )[0]
        
        payment_method = random.choice(['credit_card', 'debit_card', 'paypal'])
        payment_status = 'completed' if status in ['shipped', 'delivered'] else random.choice(['pending', 'completed'])
        
        return {
            'user_id': user_id,
            'order_number': order_number,
            'status': status,
            'total_amount': total_amount,
            'payment_method': payment_method,
            'payment_status': payment_status,
            'items': order_items
        }
    
    def generate_analytics_event(self) -> Dict[str, Any]:
        """Generate realistic analytics event data"""
        country = random.choice(self.countries)
        city = random.choice(self.cities.get(country, ['Unknown']))
        
        event_type = random.choice(self.event_types)
        page_url = random.choice(self.page_urls)
        
        # Generate event-specific data
        event_data = {}
        
        if event_type == 'page_view':
            event_data = {
                'load_time': random.randint(500, 3000),
                'engagement_time': random.randint(10, 300)
            }
        elif event_type == 'click':
            event_data = {
                'element': random.choice(['button', 'link', 'menu', 'chart']),
                'position': {
                    'x': random.randint(0, 1920),
                    'y': random.randint(0, 1080)
                }
            }
        elif event_type == 'scroll':
            event_data = {
                'scroll_depth': random.randint(10, 100),
                'max_scroll': random.randint(500, 2000)
            }
        elif event_type == 'form_submit':
            event_data = {
                'form_id': random.choice(['contact', 'search', 'filter', 'settings']),
                'fields': random.randint(2, 8)
            }
        
        return {
            'session_id': f"sess_{random.randint(1000000, 9999999)}",
            'user_id': random.randint(1, 10) if random.random() > 0.3 else None,
            'event_type': event_type,
            'event_name': f"{event_type}_{page_url.replace('/', '')}",
            'page_url': page_url,
            'device_type': random.choice(['desktop', 'mobile', 'tablet']),
            'browser': random.choice(['Chrome', 'Firefox', 'Safari', 'Edge']),
            'operating_system': random.choice(['Windows', 'macOS', 'Linux', 'iOS', 'Android']),
            'country': country,
            'city': city,
            'event_data': event_data
        }
    
    def generate_performance_metrics(self) -> List[Dict[str, Any]]:
        """Generate realistic performance metrics"""
        metrics = []
        
        # System metrics
        metrics.extend([
            {
                'metric_name': 'cpu_usage',
                'metric_type': 'gauge',
                'value': random.uniform(20, 80),
                'unit': 'percent',
                'source': 'system',
                'tags': {'hostname': 'web-server-1', 'environment': 'production'}
            },
            {
                'metric_name': 'memory_usage',
                'metric_type': 'gauge',
                'value': random.uniform(40, 85),
                'unit': 'percent',
                'source': 'system',
                'tags': {'hostname': 'web-server-1', 'environment': 'production'}
            },
            {
                'metric_name': 'disk_usage',
                'metric_type': 'gauge',
                'value': random.uniform(30, 70),
                'unit': 'percent',
                'source': 'system',
                'tags': {'hostname': 'web-server-1', 'environment': 'production'}
            }
        ])
        
        # Application metrics
        metrics.extend([
            {
                'metric_name': 'response_time',
                'metric_type': 'histogram',
                'value': random.uniform(50, 500),
                'unit': 'milliseconds',
                'source': 'application',
                'tags': {'endpoint': random.choice(['/api/dashboard', '/api/analytics', '/api/users'])}
            },
            {
                'metric_name': 'request_count',
                'metric_type': 'counter',
                'value': random.randint(10, 100),
                'unit': 'requests',
                'source': 'application',
                'tags': {'status': random.choice(['200', '201', '400', '500'])}
            },
            {
                'metric_name': 'active_connections',
                'metric_type': 'gauge',
                'value': random.randint(20, 100),
                'unit': 'connections',
                'source': 'application',
                'tags': {'service': 'websocket'}
            }
        ])
        
        # Business metrics
        current_hour = datetime.now().hour
        base_revenue = 1000 + (current_hour * 50)  # Higher during business hours
        
        metrics.extend([
            {
                'metric_name': 'revenue_per_hour',
                'metric_type': 'gauge',
                'value': base_revenue + random.uniform(-200, 400),
                'unit': 'dollars',
                'source': 'business',
                'tags': {'source': 'ecommerce'}
            },
            {
                'metric_name': 'conversion_rate',
                'metric_type': 'gauge',
                'value': random.uniform(2.5, 4.5),
                'unit': 'percent',
                'source': 'business',
                'tags': {'funnel': 'checkout'}
            }
        ])
        
        return metrics
    
    def insert_order_data(self, order_data: Dict[str, Any]):
        """Insert order data into MySQL"""
        try:
            mysql_cursor = self.mysql_conn.cursor()
            
            # Insert order
            order_sql = """
                INSERT INTO orders (
                    user_id, order_number, status, total_amount, 
                    payment_method, payment_status, order_date
                ) VALUES (%s, %s, %s, %s, %s, %s, %s)
            """
            
            mysql_cursor.execute(order_sql, (
                order_data['user_id'],
                order_data['order_number'],
                order_data['status'],
                order_data['total_amount'],
                order_data['payment_method'],
                order_data['payment_status'],
                datetime.now()
            ))
            
            order_id = mysql_cursor.lastrowid
            
            # Insert order items
            for item in order_data['items']:
                item_sql = """
                    INSERT INTO order_items (
                        order_id, product_id, quantity, unit_price
                    ) VALUES (%s, %s, %s, %s)
                """
                
                mysql_cursor.execute(item_sql, (
                    order_id,
                    item['product_id'],
                    item['quantity'],
                    item['unit_price']
                ))
            
            logger.info(f"Order created: {order_data['order_number']} (${order_data['total_amount']:.2f})")
            
        except Exception as e:
            logger.error(f"Failed to insert order data: {e}")
    
    def insert_analytics_event(self, event_data: Dict[str, Any]):
        """Insert analytics event into PostgreSQL"""
        try:
            postgresql_cursor = self.postgresql_conn.cursor()
            
            event_sql = """
                INSERT INTO analytics_events (
                    session_id, user_id, event_type, event_name, page_url,
                    device_type, browser, operating_system, country, city, event_data
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
            
            postgresql_cursor.execute(event_sql, (
                event_data['session_id'],
                event_data['user_id'],
                event_data['event_type'],
                event_data['event_name'],
                event_data['page_url'],
                event_data['device_type'],
                event_data['browser'],
                event_data['operating_system'],
                event_data['country'],
                event_data['city'],
                json.dumps(event_data['event_data'])
            ))
            
            logger.debug(f"Analytics event: {event_data['event_type']} on {event_data['page_url']}")
            
        except Exception as e:
            logger.error(f"Failed to insert analytics event: {e}")
    
    def insert_performance_metrics(self, metrics: List[Dict[str, Any]]):
        """Insert performance metrics into PostgreSQL"""
        try:
            postgresql_cursor = self.postgresql_conn.cursor()
            
            for metric in metrics:
                metric_sql = """
                    INSERT INTO performance_metrics (
                        metric_name, metric_type, value, unit, source, tags
                    ) VALUES (%s, %s, %s, %s, %s, %s)
                """
                
                postgresql_cursor.execute(metric_sql, (
                    metric['metric_name'],
                    metric['metric_type'],
                    metric['value'],
                    metric['unit'],
                    metric['source'],
                    json.dumps(metric['tags'])
                ))
            
            logger.debug(f"Inserted {len(metrics)} performance metrics")
            
        except Exception as e:
            logger.error(f"Failed to insert performance metrics: {e}")
    
    def generate_batch_data(self):
        """Generate a batch of data for all types"""
        try:
            # Generate 1-3 orders
            for _ in range(random.randint(1, 3)):
                order_data = self.generate_order_data()
                if order_data:
                    self.insert_order_data(order_data)
            
            # Generate 5-15 analytics events
            for _ in range(random.randint(5, 15)):
                event_data = self.generate_analytics_event()
                self.insert_analytics_event(event_data)
            
            # Generate performance metrics
            metrics = self.generate_performance_metrics()
            self.insert_performance_metrics(metrics)
            
        except Exception as e:
            logger.error(f"Error generating batch data: {e}")
    
    def run_continuous(self, interval: int = 30):
        """Run continuous data generation"""
        self.running = True
        logger.info(f"Starting continuous data generation (interval: {interval}s)")
        
        try:
            self.connect_databases()
            
            while self.running:
                start_time = time.time()
                
                self.generate_batch_data()
                
                # Calculate sleep time to maintain interval
                elapsed = time.time() - start_time
                sleep_time = max(0, interval - elapsed)
                
                if sleep_time > 0:
                    time.sleep(sleep_time)
                
        except KeyboardInterrupt:
            logger.info("Received interrupt signal, stopping...")
        except Exception as e:
            logger.error(f"Error in continuous generation: {e}")
        finally:
            self.running = False
            self.disconnect_databases()
    
    def generate_historical_data(self, days: int = 30):
        """Generate historical data for the past N days"""
        logger.info(f"Generating historical data for {days} days")
        
        try:
            self.connect_databases()
            
            start_date = datetime.now() - timedelta(days=days)
            
            for day in range(days):
                current_date = start_date + timedelta(days=day)
                
                # Generate data for each hour of the day
                for hour in range(24):
                    # More activity during business hours
                    if 9 <= hour <= 17:
                        events_per_hour = random.randint(20, 50)
                        orders_per_hour = random.randint(3, 8)
                    else:
                        events_per_hour = random.randint(5, 15)
                        orders_per_hour = random.randint(0, 2)
                    
                    # Generate events for this hour
                    for _ in range(events_per_hour):
                        event_data = self.generate_analytics_event()
                        self.insert_analytics_event(event_data)
                    
                    # Generate orders for this hour
                    for _ in range(orders_per_hour):
                        order_data = self.generate_order_data()
                        if order_data:
                            self.insert_order_data(order_data)
                    
                    # Generate metrics every hour
                    metrics = self.generate_performance_metrics()
                    self.insert_performance_metrics(metrics)
                
                logger.info(f"Generated data for {current_date.strftime('%Y-%m-%d')}")
            
            logger.info("Historical data generation completed")
            
        except Exception as e:
            logger.error(f"Error generating historical data: {e}")
        finally:
            self.disconnect_databases()
    
    def stop(self):
        """Stop the data generator"""
        self.running = False
        logger.info("Data generator stopped")

def signal_handler(signum, frame):
    """Handle interrupt signals"""
    logger.info("Received termination signal")
    sys.exit(0)

def main():
    parser = argparse.ArgumentParser(description='BI Data Generator for DevOps Dashboard')
    parser.add_argument('--mode', choices=['continuous', 'historical', 'batch'], 
                       default='continuous', help='Generation mode')
    parser.add_argument('--interval', type=int, default=30, 
                       help='Interval between batches in seconds (continuous mode)')
    parser.add_argument('--days', type=int, default=30, 
                       help='Number of days for historical data')
    parser.add_argument('--mysql-host', default='localhost', help='MySQL host')
    parser.add_argument('--mysql-port', type=int, default=3307, help='MySQL port')
    parser.add_argument('--mysql-user', default='app_user', help='MySQL username')
    parser.add_argument('--mysql-password', required=True, help='MySQL password')
    parser.add_argument('--mysql-database', default='devops_app', help='MySQL database')
    parser.add_argument('--postgresql-host', default='localhost', help='PostgreSQL host')
    parser.add_argument('--postgresql-port', type=int, default=5433, help='PostgreSQL port')
    parser.add_argument('--postgresql-user', default='analytics_user', help='PostgreSQL username')
    parser.add_argument('--postgresql-password', required=True, help='PostgreSQL password')
    parser.add_argument('--postgresql-database', default='devops_analytics', help='PostgreSQL database')
    
    args = parser.parse_args()
    
    # Setup signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Create database configs
    mysql_config = DatabaseConfig(
        host=args.mysql_host,
        port=args.mysql_port,
        database=args.mysql_database,
        username=args.mysql_user,
        password=args.mysql_password
    )
    
    postgresql_config = DatabaseConfig(
        host=args.postgresql_host,
        port=args.postgresql_port,
        database=args.postgresql_database,
        username=args.postgresql_user,
        password=args.postgresql_password
    )
    
    # Create and run generator
    generator = BiDataGenerator(mysql_config, postgresql_config)
    
    try:
        if args.mode == 'continuous':
            generator.run_continuous(args.interval)
        elif args.mode == 'historical':
            generator.generate_historical_data(args.days)
        elif args.mode == 'batch':
            generator.connect_databases()
            generator.generate_batch_data()
            generator.disconnect_databases()
            logger.info("Batch data generation completed")
            
    except Exception as e:
        logger.error(f"Generator failed: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()

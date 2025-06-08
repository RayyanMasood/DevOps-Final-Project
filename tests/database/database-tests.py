#!/usr/bin/env python3

"""
Database Testing Suite for DevOps Dashboard
Comprehensive database connectivity, integrity, and performance tests
"""

import asyncio
import asyncpg
import pymysql
import json
import time
import statistics
import argparse
import sys
import os
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class DatabaseTester:
    def __init__(self, config_file=None):
        self.config = self.load_config(config_file)
        self.results = {
            'test_run': {
                'id': datetime.now().strftime('%Y%m%d_%H%M%S'),
                'timestamp': datetime.now().isoformat(),
                'config': self.config
            },
            'tests': [],
            'summary': {
                'total_tests': 0,
                'passed_tests': 0,
                'failed_tests': 0,
                'warnings': 0
            }
        }
        
    def load_config(self, config_file):
        """Load database configuration"""
        default_config = {
            'mysql': {
                'host': os.getenv('MYSQL_HOST', 'localhost'),
                'port': int(os.getenv('MYSQL_PORT', 3306)),
                'user': os.getenv('MYSQL_USER', 'devops_user'),
                'password': os.getenv('MYSQL_PASSWORD', 'secure_password'),
                'database': os.getenv('MYSQL_DATABASE', 'devops_dashboard'),
                'connect_timeout': 10
            },
            'postgresql': {
                'host': os.getenv('POSTGRES_HOST', 'localhost'),
                'port': int(os.getenv('POSTGRES_PORT', 5432)),
                'user': os.getenv('POSTGRES_USER', 'devops_user'),
                'password': os.getenv('POSTGRES_PASSWORD', 'secure_password'),
                'database': os.getenv('POSTGRES_DATABASE', 'devops_analytics'),
                'connect_timeout': 10
            },
            'test_settings': {
                'performance_threshold_ms': 1000,
                'connection_pool_size': 5,
                'query_timeout': 30,
                'data_integrity_samples': 100
            }
        }
        
        if config_file and os.path.exists(config_file):
            with open(config_file, 'r') as f:
                file_config = json.load(f)
                # Merge with defaults
                for key in default_config:
                    if key in file_config:
                        default_config[key].update(file_config[key])
        
        return default_config
    
    def log_test_result(self, test_name, status, message="", duration=0, details=None):
        """Log test result"""
        result = {
            'test_name': test_name,
            'status': status,  # 'PASS', 'FAIL', 'WARN'
            'message': message,
            'duration_ms': duration,
            'timestamp': datetime.now().isoformat(),
            'details': details or {}
        }
        
        self.results['tests'].append(result)
        self.results['summary']['total_tests'] += 1
        
        if status == 'PASS':
            self.results['summary']['passed_tests'] += 1
            logger.info(f"✅ {test_name} - PASSED ({duration:.2f}ms)")
        elif status == 'FAIL':
            self.results['summary']['failed_tests'] += 1
            logger.error(f"❌ {test_name} - FAILED: {message}")
        elif status == 'WARN':
            self.results['summary']['warnings'] += 1
            logger.warning(f"⚠️ {test_name} - WARNING: {message}")
        
        if message:
            logger.info(f"   {message}")
    
    async def test_mysql_connectivity(self):
        """Test MySQL database connectivity"""
        test_name = "MySQL Database Connectivity"
        start_time = time.time()
        
        try:
            config = self.config['mysql']
            
            # Test basic connection
            connection = pymysql.connect(
                host=config['host'],
                port=config['port'],
                user=config['user'],
                password=config['password'],
                database=config['database'],
                connect_timeout=config['connect_timeout'],
                autocommit=True
            )
            
            duration = (time.time() - start_time) * 1000
            
            # Test basic query
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1 as test")
                result = cursor.fetchone()
                
                if result and result[0] == 1:
                    self.log_test_result(test_name, 'PASS', 
                                       f"Connected to MySQL at {config['host']}:{config['port']}", duration)
                else:
                    self.log_test_result(test_name, 'FAIL', "Basic query failed", duration)
            
            connection.close()
            return True
            
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            self.log_test_result(test_name, 'FAIL', str(e), duration)
            return False
    
    async def test_postgresql_connectivity(self):
        """Test PostgreSQL database connectivity"""
        test_name = "PostgreSQL Database Connectivity"
        start_time = time.time()
        
        try:
            config = self.config['postgresql']
            
            # Test async connection
            connection = await asyncpg.connect(
                host=config['host'],
                port=config['port'],
                user=config['user'],
                password=config['password'],
                database=config['database'],
                command_timeout=config['connect_timeout']
            )
            
            duration = (time.time() - start_time) * 1000
            
            # Test basic query
            result = await connection.fetchval("SELECT 1")
            
            if result == 1:
                self.log_test_result(test_name, 'PASS', 
                                   f"Connected to PostgreSQL at {config['host']}:{config['port']}", duration)
            else:
                self.log_test_result(test_name, 'FAIL', "Basic query failed", duration)
            
            await connection.close()
            return True
            
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            self.log_test_result(test_name, 'FAIL', str(e), duration)
            return False
    
    async def test_mysql_schema_integrity(self):
        """Test MySQL schema and data integrity"""
        test_name = "MySQL Schema Integrity"
        start_time = time.time()
        
        try:
            config = self.config['mysql']
            connection = pymysql.connect(**{k: v for k, v in config.items() if k != 'connect_timeout'})
            
            with connection.cursor() as cursor:
                # Check required tables exist
                required_tables = ['users', 'products', 'orders', 'order_items']
                cursor.execute("SHOW TABLES")
                existing_tables = [row[0] for row in cursor.fetchall()]
                
                missing_tables = [table for table in required_tables if table not in existing_tables]
                
                if missing_tables:
                    duration = (time.time() - start_time) * 1000
                    self.log_test_result(test_name, 'FAIL', 
                                       f"Missing tables: {', '.join(missing_tables)}", duration)
                    connection.close()
                    return False
                
                # Check table structures
                schema_issues = []
                
                # Validate users table
                cursor.execute("DESCRIBE users")
                users_columns = {row[0]: row[1] for row in cursor.fetchall()}
                required_user_columns = {'id': 'int', 'username': 'varchar', 'email': 'varchar'}
                
                for col, col_type in required_user_columns.items():
                    if col not in users_columns:
                        schema_issues.append(f"users table missing {col} column")
                    elif col_type not in users_columns[col].lower():
                        schema_issues.append(f"users.{col} has wrong type: {users_columns[col]}")
                
                # Check data consistency
                cursor.execute("SELECT COUNT(*) FROM users")
                user_count = cursor.fetchone()[0]
                
                cursor.execute("SELECT COUNT(*) FROM products")
                product_count = cursor.fetchone()[0]
                
                cursor.execute("SELECT COUNT(*) FROM orders")
                order_count = cursor.fetchone()[0]
                
                # Check for orphaned records
                cursor.execute("""
                    SELECT COUNT(*) FROM orders o 
                    LEFT JOIN users u ON o.user_id = u.id 
                    WHERE u.id IS NULL
                """)
                orphaned_orders = cursor.fetchone()[0]
                
                if orphaned_orders > 0:
                    schema_issues.append(f"{orphaned_orders} orphaned orders found")
                
                duration = (time.time() - start_time) * 1000
                
                if schema_issues:
                    self.log_test_result(test_name, 'WARN', 
                                       f"Schema issues: {'; '.join(schema_issues)}", duration,
                                       {'user_count': user_count, 'product_count': product_count, 
                                        'order_count': order_count})
                else:
                    self.log_test_result(test_name, 'PASS', 
                                       f"Schema valid. Users: {user_count}, Products: {product_count}, Orders: {order_count}", 
                                       duration)
            
            connection.close()
            return True
            
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            self.log_test_result(test_name, 'FAIL', str(e), duration)
            return False
    
    async def test_postgresql_schema_integrity(self):
        """Test PostgreSQL schema and data integrity"""
        test_name = "PostgreSQL Schema Integrity"
        start_time = time.time()
        
        try:
            config = self.config['postgresql']
            connection = await asyncpg.connect(**{k: v for k, v in config.items() if k != 'connect_timeout'})
            
            # Check required tables exist
            required_tables = ['user_analytics', 'product_analytics', 'order_analytics', 'daily_metrics']
            
            tables_query = """
                SELECT table_name FROM information_schema.tables 
                WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
            """
            existing_tables = [row[0] for row in await connection.fetch(tables_query)]
            
            missing_tables = [table for table in required_tables if table not in existing_tables]
            
            if missing_tables:
                duration = (time.time() - start_time) * 1000
                self.log_test_result(test_name, 'FAIL', 
                                   f"Missing tables: {', '.join(missing_tables)}", duration)
                await connection.close()
                return False
            
            # Check data consistency
            user_analytics_count = await connection.fetchval("SELECT COUNT(*) FROM user_analytics")
            product_analytics_count = await connection.fetchval("SELECT COUNT(*) FROM product_analytics")
            order_analytics_count = await connection.fetchval("SELECT COUNT(*) FROM order_analytics")
            daily_metrics_count = await connection.fetchval("SELECT COUNT(*) FROM daily_metrics")
            
            # Check for recent data
            recent_data = await connection.fetchval("""
                SELECT COUNT(*) FROM daily_metrics 
                WHERE metric_date >= CURRENT_DATE - INTERVAL '7 days'
            """)
            
            duration = (time.time() - start_time) * 1000
            
            if recent_data == 0:
                self.log_test_result(test_name, 'WARN', 
                                   "No recent data in daily_metrics (last 7 days)", duration,
                                   {'user_analytics_count': user_analytics_count,
                                    'product_analytics_count': product_analytics_count,
                                    'order_analytics_count': order_analytics_count,
                                    'daily_metrics_count': daily_metrics_count})
            else:
                self.log_test_result(test_name, 'PASS', 
                                   f"Schema valid. Recent data: {recent_data} daily metrics", duration,
                                   {'user_analytics_count': user_analytics_count,
                                    'product_analytics_count': product_analytics_count,
                                    'order_analytics_count': order_analytics_count,
                                    'daily_metrics_count': daily_metrics_count})
            
            await connection.close()
            return True
            
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            self.log_test_result(test_name, 'FAIL', str(e), duration)
            return False
    
    async def test_database_performance(self):
        """Test database query performance"""
        test_name = "Database Query Performance"
        start_time = time.time()
        
        try:
            # Test MySQL performance
            mysql_times = []
            config = self.config['mysql']
            connection = pymysql.connect(**{k: v for k, v in config.items() if k != 'connect_timeout'})
            
            # Run multiple queries to get average performance
            for i in range(5):
                query_start = time.time()
                with connection.cursor() as cursor:
                    cursor.execute("""
                        SELECT u.username, COUNT(o.id) as order_count, SUM(oi.quantity * p.price) as total_value
                        FROM users u
                        LEFT JOIN orders o ON u.id = o.user_id
                        LEFT JOIN order_items oi ON o.id = oi.order_id
                        LEFT JOIN products p ON oi.product_id = p.id
                        GROUP BY u.id, u.username
                        ORDER BY total_value DESC
                        LIMIT 10
                    """)
                    cursor.fetchall()
                query_time = (time.time() - query_start) * 1000
                mysql_times.append(query_time)
            
            connection.close()
            
            # Test PostgreSQL performance
            postgres_times = []
            config = self.config['postgresql']
            pg_connection = await asyncpg.connect(**{k: v for k, v in config.items() if k != 'connect_timeout'})
            
            for i in range(5):
                query_start = time.time()
                await pg_connection.fetch("""
                    SELECT user_id, 
                           AVG(session_duration) as avg_session,
                           COUNT(*) as session_count,
                           MAX(last_activity) as last_seen
                    FROM user_analytics
                    WHERE last_activity >= CURRENT_DATE - INTERVAL '30 days'
                    GROUP BY user_id
                    ORDER BY avg_session DESC
                    LIMIT 10
                """)
                query_time = (time.time() - query_start) * 1000
                postgres_times.append(query_time)
            
            await pg_connection.close()
            
            # Calculate averages
            mysql_avg = statistics.mean(mysql_times)
            postgres_avg = statistics.mean(postgres_times)
            
            duration = (time.time() - start_time) * 1000
            threshold = self.config['test_settings']['performance_threshold_ms']
            
            if mysql_avg < threshold and postgres_avg < threshold:
                self.log_test_result(test_name, 'PASS', 
                                   f"MySQL avg: {mysql_avg:.2f}ms, PostgreSQL avg: {postgres_avg:.2f}ms", 
                                   duration,
                                   {'mysql_times': mysql_times, 'postgres_times': postgres_times})
            elif mysql_avg >= threshold or postgres_avg >= threshold:
                slow_db = "MySQL" if mysql_avg >= threshold else "PostgreSQL"
                slow_time = mysql_avg if mysql_avg >= threshold else postgres_avg
                self.log_test_result(test_name, 'WARN', 
                                   f"{slow_db} queries slow: {slow_time:.2f}ms (threshold: {threshold}ms)", 
                                   duration,
                                   {'mysql_times': mysql_times, 'postgres_times': postgres_times})
            
            return True
            
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            self.log_test_result(test_name, 'FAIL', str(e), duration)
            return False
    
    async def test_connection_pooling(self):
        """Test database connection pooling and concurrent access"""
        test_name = "Database Connection Pooling"
        start_time = time.time()
        
        try:
            pool_size = self.config['test_settings']['connection_pool_size']
            
            # Test concurrent MySQL connections
            mysql_tasks = []
            for i in range(pool_size):
                mysql_tasks.append(self._test_mysql_connection_worker(i))
            
            mysql_results = await asyncio.gather(*mysql_tasks, return_exceptions=True)
            mysql_success = sum(1 for r in mysql_results if r is True)
            
            # Test concurrent PostgreSQL connections
            postgres_tasks = []
            for i in range(pool_size):
                postgres_tasks.append(self._test_postgres_connection_worker(i))
            
            postgres_results = await asyncio.gather(*postgres_tasks, return_exceptions=True)
            postgres_success = sum(1 for r in postgres_results if r is True)
            
            duration = (time.time() - start_time) * 1000
            
            if mysql_success == pool_size and postgres_success == pool_size:
                self.log_test_result(test_name, 'PASS', 
                                   f"All {pool_size} concurrent connections successful", duration,
                                   {'mysql_success': mysql_success, 'postgres_success': postgres_success})
            else:
                self.log_test_result(test_name, 'WARN', 
                                   f"MySQL: {mysql_success}/{pool_size}, PostgreSQL: {postgres_success}/{pool_size}", 
                                   duration,
                                   {'mysql_errors': [r for r in mysql_results if r is not True],
                                    'postgres_errors': [r for r in postgres_results if r is not True]})
            
            return True
            
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            self.log_test_result(test_name, 'FAIL', str(e), duration)
            return False
    
    async def _test_mysql_connection_worker(self, worker_id):
        """Worker function for concurrent MySQL connection test"""
        try:
            config = self.config['mysql']
            connection = pymysql.connect(**{k: v for k, v in config.items() if k != 'connect_timeout'})
            
            with connection.cursor() as cursor:
                cursor.execute("SELECT CONNECTION_ID()")
                conn_id = cursor.fetchone()[0]
                
                # Simulate some work
                await asyncio.sleep(0.1)
                
                cursor.execute("SELECT 1")
                result = cursor.fetchone()[0]
            
            connection.close()
            return result == 1
            
        except Exception as e:
            return e
    
    async def _test_postgres_connection_worker(self, worker_id):
        """Worker function for concurrent PostgreSQL connection test"""
        try:
            config = self.config['postgresql']
            connection = await asyncpg.connect(**{k: v for k, v in config.items() if k != 'connect_timeout'})
            
            # Get connection process ID
            conn_id = await connection.fetchval("SELECT pg_backend_pid()")
            
            # Simulate some work
            await asyncio.sleep(0.1)
            
            result = await connection.fetchval("SELECT 1")
            
            await connection.close()
            return result == 1
            
        except Exception as e:
            return e
    
    async def test_data_integrity_cross_database(self):
        """Test data integrity between MySQL and PostgreSQL"""
        test_name = "Cross-Database Data Integrity"
        start_time = time.time()
        
        try:
            # Connect to both databases
            mysql_config = self.config['mysql']
            mysql_conn = pymysql.connect(**{k: v for k, v in mysql_config.items() if k != 'connect_timeout'})
            
            postgres_config = self.config['postgresql']
            pg_conn = await asyncpg.connect(**{k: v for k, v in postgres_config.items() if k != 'connect_timeout'})
            
            # Get user counts from MySQL
            with mysql_conn.cursor() as cursor:
                cursor.execute("SELECT COUNT(*) FROM users")
                mysql_user_count = cursor.fetchone()[0]
                
                cursor.execute("SELECT COUNT(*) FROM orders")
                mysql_order_count = cursor.fetchone()[0]
            
            # Get corresponding counts from PostgreSQL analytics
            pg_user_count = await pg_conn.fetchval("SELECT COUNT(DISTINCT user_id) FROM user_analytics")
            pg_order_count = await pg_conn.fetchval("SELECT COUNT(DISTINCT order_id) FROM order_analytics")
            
            # Check if counts are reasonably consistent
            user_diff_pct = abs(mysql_user_count - pg_user_count) / max(mysql_user_count, 1) * 100
            order_diff_pct = abs(mysql_order_count - pg_order_count) / max(mysql_order_count, 1) * 100
            
            mysql_conn.close()
            await pg_conn.close()
            
            duration = (time.time() - start_time) * 1000
            
            if user_diff_pct <= 5 and order_diff_pct <= 5:  # Allow 5% variance
                self.log_test_result(test_name, 'PASS', 
                                   f"Data consistency good. User diff: {user_diff_pct:.1f}%, Order diff: {order_diff_pct:.1f}%", 
                                   duration,
                                   {'mysql_users': mysql_user_count, 'pg_users': pg_user_count,
                                    'mysql_orders': mysql_order_count, 'pg_orders': pg_order_count})
            else:
                self.log_test_result(test_name, 'WARN', 
                                   f"Data inconsistency detected. User diff: {user_diff_pct:.1f}%, Order diff: {order_diff_pct:.1f}%", 
                                   duration,
                                   {'mysql_users': mysql_user_count, 'pg_users': pg_user_count,
                                    'mysql_orders': mysql_order_count, 'pg_orders': pg_order_count})
            
            return True
            
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            self.log_test_result(test_name, 'FAIL', str(e), duration)
            return False
    
    async def run_all_tests(self):
        """Run all database tests"""
        logger.info("🗄️ Starting comprehensive database tests...")
        
        # Connectivity tests
        mysql_connected = await self.test_mysql_connectivity()
        postgres_connected = await self.test_postgresql_connectivity()
        
        if not mysql_connected or not postgres_connected:
            logger.error("Database connectivity failed. Skipping remaining tests.")
            return False
        
        # Schema and integrity tests
        await self.test_mysql_schema_integrity()
        await self.test_postgresql_schema_integrity()
        
        # Performance tests
        await self.test_database_performance()
        await self.test_connection_pooling()
        
        # Cross-database integrity
        await self.test_data_integrity_cross_database()
        
        return True
    
    def generate_report(self, output_file=None):
        """Generate test report"""
        # Calculate success rate
        total_tests = self.results['summary']['total_tests']
        passed_tests = self.results['summary']['passed_tests']
        success_rate = (passed_tests / total_tests * 100) if total_tests > 0 else 0
        
        self.results['summary']['success_rate'] = success_rate
        self.results['test_run']['completed_at'] = datetime.now().isoformat()
        
        if output_file:
            with open(output_file, 'w') as f:
                json.dump(self.results, f, indent=2, default=str)
            logger.info(f"📄 Test report saved to: {output_file}")
        
        # Console report
        print("\n" + "="*80)
        print("                DATABASE TESTING RESULTS")
        print("="*80)
        
        print(f"\n📊 Test Summary:")
        print(f"   Total Tests:      {total_tests}")
        print(f"   Passed:           {passed_tests}")
        print(f"   Failed:           {self.results['summary']['failed_tests']}")
        print(f"   Warnings:         {self.results['summary']['warnings']}")
        print(f"   Success Rate:     {success_rate:.1f}%")
        
        print(f"\n📋 Test Details:")
        for test in self.results['tests']:
            status_icon = {"PASS": "✅", "FAIL": "❌", "WARN": "⚠️"}.get(test['status'], "❓")
            print(f"   {status_icon} {test['test_name']}: {test['status']}")
            if test['message']:
                print(f"      {test['message']}")
            if test['duration_ms'] > 0:
                print(f"      Duration: {test['duration_ms']:.2f}ms")
        
        # Assessment
        print(f"\n🏆 Database Health Assessment:")
        if success_rate >= 90:
            print("   ✅ Excellent database health")
        elif success_rate >= 75:
            print("   ⚠️  Good database health with minor issues")
        else:
            print("   ❌ Database health issues need attention")
        
        print("\n" + "="*80)
        
        return success_rate >= 75

def main():
    parser = argparse.ArgumentParser(description='Database testing for DevOps Dashboard')
    parser.add_argument('--config', help='Database configuration file (JSON)')
    parser.add_argument('--output', help='Output file for test results (JSON)')
    parser.add_argument('--mysql-host', help='MySQL host override')
    parser.add_argument('--postgres-host', help='PostgreSQL host override')
    
    args = parser.parse_args()
    
    # Override hosts if provided
    if args.mysql_host:
        os.environ['MYSQL_HOST'] = args.mysql_host
    if args.postgres_host:
        os.environ['POSTGRES_HOST'] = args.postgres_host
    
    # Create and run database tester
    tester = DatabaseTester(args.config)
    
    try:
        # Run all tests
        success = asyncio.run(tester.run_all_tests())
        
        # Generate report
        report_success = tester.generate_report(args.output)
        
        # Exit with appropriate code
        if success and report_success:
            sys.exit(0)
        else:
            sys.exit(1)
            
    except KeyboardInterrupt:
        logger.error("\n⏹️  Database tests interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"\n❌ Database tests failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()

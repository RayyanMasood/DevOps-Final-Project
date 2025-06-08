#!/usr/bin/env python3

"""
Metabase BI Tool Testing Suite
Comprehensive testing for Metabase connectivity, dashboards, and data visualization
"""

import asyncio
import aiohttp
import json
import time
import argparse
import sys
import os
from datetime import datetime, timedelta
import logging
from urllib.parse import urljoin

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class MetabaseTester:
    def __init__(self, metabase_url, username=None, password=None):
        self.metabase_url = metabase_url.rstrip('/')
        self.username = username or os.getenv('METABASE_USERNAME', 'admin@devops.local')
        self.password = password or os.getenv('METABASE_PASSWORD', 'MetabaseAdmin123!')
        self.session_token = None
        
        self.results = {
            'test_run': {
                'id': datetime.now().strftime('%Y%m%d_%H%M%S'),
                'timestamp': datetime.now().isoformat(),
                'metabase_url': self.metabase_url,
                'username': self.username
            },
            'tests': [],
            'summary': {
                'total_tests': 0,
                'passed_tests': 0,
                'failed_tests': 0,
                'warnings': 0
            }
        }
    
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
    
    async def test_metabase_availability(self, session):
        """Test if Metabase is available and responding"""
        test_name = "Metabase Service Availability"
        start_time = time.time()
        
        try:
            async with session.get(f"{self.metabase_url}/api/health") as response:
                duration = (time.time() - start_time) * 1000
                
                if response.status == 200:
                    health_data = await response.json()
                    self.log_test_result(test_name, 'PASS', 
                                       f"Metabase is healthy (status: {health_data.get('status', 'unknown')})", 
                                       duration, health_data)
                    return True
                else:
                    self.log_test_result(test_name, 'FAIL', 
                                       f"Health check failed with status {response.status}", duration)
                    return False
                    
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            self.log_test_result(test_name, 'FAIL', str(e), duration)
            return False
    
    async def authenticate(self, session):
        """Authenticate with Metabase and get session token"""
        test_name = "Metabase Authentication"
        start_time = time.time()
        
        try:
            auth_data = {
                "username": self.username,
                "password": self.password
            }
            
            async with session.post(f"{self.metabase_url}/api/session", 
                                  json=auth_data) as response:
                duration = (time.time() - start_time) * 1000
                
                if response.status == 200:
                    auth_response = await response.json()
                    self.session_token = auth_response.get('id')
                    
                    if self.session_token:
                        self.log_test_result(test_name, 'PASS', 
                                           "Authentication successful", duration)
                        return True
                    else:
                        self.log_test_result(test_name, 'FAIL', 
                                           "No session token received", duration)
                        return False
                else:
                    error_text = await response.text()
                    self.log_test_result(test_name, 'FAIL', 
                                       f"Authentication failed: {response.status} - {error_text}", duration)
                    return False
                    
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            self.log_test_result(test_name, 'FAIL', str(e), duration)
            return False
    
    async def test_database_connections(self, session):
        """Test Metabase database connections"""
        test_name = "Database Connections"
        start_time = time.time()
        
        try:
            headers = {'X-Metabase-Session': self.session_token}
            
            async with session.get(f"{self.metabase_url}/api/database", 
                                 headers=headers) as response:
                duration = (time.time() - start_time) * 1000
                
                if response.status == 200:
                    databases = await response.json()
                    
                    if not databases:
                        self.log_test_result(test_name, 'WARN', 
                                           "No databases configured", duration)
                        return False
                    
                    # Check each database connection
                    connected_dbs = []
                    failed_dbs = []
                    
                    for db in databases:
                        db_name = db.get('name', 'Unknown')
                        db_id = db.get('id')
                        
                        # Test connection to this database
                        test_url = f"{self.metabase_url}/api/database/{db_id}/schema"
                        
                        async with session.get(test_url, headers=headers) as db_response:
                            if db_response.status == 200:
                                connected_dbs.append(db_name)
                            else:
                                failed_dbs.append(f"{db_name} (HTTP {db_response.status})")
                    
                    if failed_dbs:
                        self.log_test_result(test_name, 'WARN', 
                                           f"Some database connections failed: {', '.join(failed_dbs)}", 
                                           duration,
                                           {'connected': connected_dbs, 'failed': failed_dbs})
                    else:
                        self.log_test_result(test_name, 'PASS', 
                                           f"All {len(connected_dbs)} databases connected: {', '.join(connected_dbs)}", 
                                           duration,
                                           {'connected': connected_dbs})
                    
                    return len(connected_dbs) > 0
                else:
                    self.log_test_result(test_name, 'FAIL', 
                                       f"Failed to get database list: {response.status}", duration)
                    return False
                    
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            self.log_test_result(test_name, 'FAIL', str(e), duration)
            return False
    
    async def test_dashboards(self, session):
        """Test Metabase dashboards"""
        test_name = "Dashboard Functionality"
        start_time = time.time()
        
        try:
            headers = {'X-Metabase-Session': self.session_token}
            
            # Get list of dashboards
            async with session.get(f"{self.metabase_url}/api/dashboard", 
                                 headers=headers) as response:
                if response.status != 200:
                    duration = (time.time() - start_time) * 1000
                    self.log_test_result(test_name, 'FAIL', 
                                       f"Failed to get dashboards: {response.status}", duration)
                    return False
                
                dashboards = await response.json()
                
                if not dashboards:
                    duration = (time.time() - start_time) * 1000
                    self.log_test_result(test_name, 'WARN', 
                                       "No dashboards found", duration)
                    return False
                
                # Test accessing each dashboard
                accessible_dashboards = []
                failed_dashboards = []
                
                for dashboard in dashboards[:5]:  # Test up to 5 dashboards
                    dashboard_name = dashboard.get('name', 'Unknown')
                    dashboard_id = dashboard.get('id')
                    
                    # Get dashboard details
                    dashboard_url = f"{self.metabase_url}/api/dashboard/{dashboard_id}"
                    
                    async with session.get(dashboard_url, headers=headers) as dash_response:
                        if dash_response.status == 200:
                            dashboard_data = await dash_response.json()
                            card_count = len(dashboard_data.get('ordered_cards', []))
                            accessible_dashboards.append(f"{dashboard_name} ({card_count} cards)")
                        else:
                            failed_dashboards.append(f"{dashboard_name} (HTTP {dash_response.status})")
                
                duration = (time.time() - start_time) * 1000
                
                if failed_dashboards:
                    self.log_test_result(test_name, 'WARN', 
                                       f"Some dashboards inaccessible: {', '.join(failed_dashboards)}", 
                                       duration,
                                       {'accessible': accessible_dashboards, 'failed': failed_dashboards})
                else:
                    self.log_test_result(test_name, 'PASS', 
                                       f"All {len(accessible_dashboards)} dashboards accessible", 
                                       duration,
                                       {'accessible': accessible_dashboards})
                
                return len(accessible_dashboards) > 0
                
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            self.log_test_result(test_name, 'FAIL', str(e), duration)
            return False
    
    async def test_queries(self, session):
        """Test executing queries in Metabase"""
        test_name = "Query Execution"
        start_time = time.time()
        
        try:
            headers = {'X-Metabase-Session': self.session_token}
            
            # Get list of cards (saved questions)
            async with session.get(f"{self.metabase_url}/api/card", 
                                 headers=headers) as response:
                if response.status != 200:
                    duration = (time.time() - start_time) * 1000
                    self.log_test_result(test_name, 'FAIL', 
                                       f"Failed to get cards: {response.status}", duration)
                    return False
                
                cards = await response.json()
                
                if not cards:
                    duration = (time.time() - start_time) * 1000
                    self.log_test_result(test_name, 'WARN', 
                                       "No saved questions found", duration)
                    return False
                
                # Test executing queries
                successful_queries = []
                failed_queries = []
                query_times = []
                
                for card in cards[:3]:  # Test up to 3 queries
                    card_name = card.get('name', 'Unknown')
                    card_id = card.get('id')
                    
                    # Execute query
                    query_start = time.time()
                    query_url = f"{self.metabase_url}/api/card/{card_id}/query"
                    
                    async with session.post(query_url, headers=headers) as query_response:
                        query_duration = (time.time() - query_start) * 1000
                        query_times.append(query_duration)
                        
                        if query_response.status == 202:  # Query accepted
                            successful_queries.append(f"{card_name} ({query_duration:.0f}ms)")
                        else:
                            failed_queries.append(f"{card_name} (HTTP {query_response.status})")
                
                duration = (time.time() - start_time) * 1000
                avg_query_time = sum(query_times) / len(query_times) if query_times else 0
                
                if failed_queries:
                    self.log_test_result(test_name, 'WARN', 
                                       f"Some queries failed: {', '.join(failed_queries)}", 
                                       duration,
                                       {'successful': successful_queries, 'failed': failed_queries,
                                        'avg_query_time': avg_query_time})
                else:
                    self.log_test_result(test_name, 'PASS', 
                                       f"All {len(successful_queries)} queries executed successfully. Avg time: {avg_query_time:.0f}ms", 
                                       duration,
                                       {'successful': successful_queries, 'avg_query_time': avg_query_time})
                
                return len(successful_queries) > 0
                
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            self.log_test_result(test_name, 'FAIL', str(e), duration)
            return False
    
    async def test_user_management(self, session):
        """Test user management functionality"""
        test_name = "User Management"
        start_time = time.time()
        
        try:
            headers = {'X-Metabase-Session': self.session_token}
            
            # Get current user info
            async with session.get(f"{self.metabase_url}/api/user/current", 
                                 headers=headers) as response:
                if response.status != 200:
                    duration = (time.time() - start_time) * 1000
                    self.log_test_result(test_name, 'FAIL', 
                                       f"Failed to get current user: {response.status}", duration)
                    return False
                
                current_user = await response.json()
                
                # Get all users (admin only)
                async with session.get(f"{self.metabase_url}/api/user", 
                                     headers=headers) as users_response:
                    duration = (time.time() - start_time) * 1000
                    
                    if users_response.status == 200:
                        users = await users_response.json()
                        active_users = [u for u in users if u.get('is_active', True)]
                        admin_users = [u for u in users if u.get('is_superuser', False)]
                        
                        self.log_test_result(test_name, 'PASS', 
                                           f"User management accessible. Active users: {len(active_users)}, Admins: {len(admin_users)}", 
                                           duration,
                                           {'current_user': current_user.get('email', 'Unknown'),
                                            'total_users': len(users),
                                            'active_users': len(active_users),
                                            'admin_users': len(admin_users)})
                    elif users_response.status == 403:
                        self.log_test_result(test_name, 'WARN', 
                                           "Current user doesn't have admin privileges", duration,
                                           {'current_user': current_user.get('email', 'Unknown'),
                                            'is_admin': current_user.get('is_superuser', False)})
                    else:
                        self.log_test_result(test_name, 'FAIL', 
                                           f"Failed to get users: {users_response.status}", duration)
                        return False
                
                return True
                
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            self.log_test_result(test_name, 'FAIL', str(e), duration)
            return False
    
    async def test_permissions(self, session):
        """Test permissions and security"""
        test_name = "Permissions and Security"
        start_time = time.time()
        
        try:
            headers = {'X-Metabase-Session': self.session_token}
            
            # Test permissions API
            async with session.get(f"{self.metabase_url}/api/permissions/group", 
                                 headers=headers) as response:
                duration = (time.time() - start_time) * 1000
                
                if response.status == 200:
                    groups = await response.json()
                    
                    # Check for default groups
                    all_users_group = any(g.get('name') == 'All Users' for g in groups)
                    admin_group = any(g.get('name') == 'Administrators' for g in groups)
                    
                    if all_users_group and admin_group:
                        self.log_test_result(test_name, 'PASS', 
                                           f"Permissions configured properly. {len(groups)} groups found", 
                                           duration,
                                           {'groups': [g.get('name') for g in groups]})
                    else:
                        self.log_test_result(test_name, 'WARN', 
                                           "Missing default permission groups", duration,
                                           {'groups': [g.get('name') for g in groups],
                                            'all_users_group': all_users_group,
                                            'admin_group': admin_group})
                elif response.status == 403:
                    self.log_test_result(test_name, 'WARN', 
                                       "Insufficient permissions to view groups", duration)
                else:
                    self.log_test_result(test_name, 'FAIL', 
                                       f"Failed to get permission groups: {response.status}", duration)
                    return False
                
                return True
                
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            self.log_test_result(test_name, 'FAIL', str(e), duration)
            return False
    
    async def test_api_performance(self, session):
        """Test API response performance"""
        test_name = "API Performance"
        start_time = time.time()
        
        try:
            headers = {'X-Metabase-Session': self.session_token}
            
            # Test multiple API endpoints and measure response times
            endpoints = [
                ('/api/dashboard', 'Dashboards'),
                ('/api/card', 'Cards'),
                ('/api/database', 'Databases'),
                ('/api/user/current', 'Current User')
            ]
            
            response_times = {}
            slow_endpoints = []
            
            for endpoint, name in endpoints:
                endpoint_start = time.time()
                
                async with session.get(f"{self.metabase_url}{endpoint}", 
                                     headers=headers) as response:
                    endpoint_duration = (time.time() - endpoint_start) * 1000
                    response_times[name] = endpoint_duration
                    
                    if endpoint_duration > 2000:  # 2 second threshold
                        slow_endpoints.append(f"{name} ({endpoint_duration:.0f}ms)")
            
            duration = (time.time() - start_time) * 1000
            avg_response_time = sum(response_times.values()) / len(response_times)
            
            if slow_endpoints:
                self.log_test_result(test_name, 'WARN', 
                                   f"Slow API responses detected: {', '.join(slow_endpoints)}", 
                                   duration,
                                   {'response_times': response_times, 'avg_response_time': avg_response_time})
            else:
                self.log_test_result(test_name, 'PASS', 
                                   f"API performance good. Average response time: {avg_response_time:.0f}ms", 
                                   duration,
                                   {'response_times': response_times, 'avg_response_time': avg_response_time})
            
            return True
            
        except Exception as e:
            duration = (time.time() - start_time) * 1000
            self.log_test_result(test_name, 'FAIL', str(e), duration)
            return False
    
    async def run_all_tests(self):
        """Run all Metabase tests"""
        logger.info("📊 Starting comprehensive Metabase tests...")
        
        async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=30)) as session:
            # Basic availability test
            if not await self.test_metabase_availability(session):
                logger.error("Metabase is not available. Skipping remaining tests.")
                return False
            
            # Authentication test
            if not await self.authenticate(session):
                logger.error("Authentication failed. Skipping authenticated tests.")
                return False
            
            # Run authenticated tests
            await self.test_database_connections(session)
            await self.test_dashboards(session)
            await self.test_queries(session)
            await self.test_user_management(session)
            await self.test_permissions(session)
            await self.test_api_performance(session)
        
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
        print("                METABASE TESTING RESULTS")
        print("="*80)
        
        print(f"\n📊 Test Summary:")
        print(f"   Metabase URL:     {self.metabase_url}")
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
        print(f"\n🏆 Metabase Health Assessment:")
        if success_rate >= 90:
            print("   ✅ Excellent Metabase functionality")
        elif success_rate >= 75:
            print("   ⚠️  Good Metabase functionality with minor issues")
        else:
            print("   ❌ Metabase functionality issues need attention")
        
        print("\n" + "="*80)
        
        return success_rate >= 75

def main():
    parser = argparse.ArgumentParser(description='Metabase testing for DevOps Dashboard')
    parser.add_argument('--url', required=True, help='Metabase URL')
    parser.add_argument('--username', help='Metabase username')
    parser.add_argument('--password', help='Metabase password')
    parser.add_argument('--output', help='Output file for test results (JSON)')
    
    args = parser.parse_args()
    
    # Validate URL
    if not args.url.startswith(('http://', 'https://')):
        logger.error("❌ Error: URL must start with http:// or https://")
        sys.exit(1)
    
    # Create and run Metabase tester
    tester = MetabaseTester(args.url, args.username, args.password)
    
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
        logger.error("\n⏹️  Metabase tests interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"\n❌ Metabase tests failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3

"""
Load Testing Script for DevOps Dashboard
Comprehensive performance testing with concurrent users and detailed metrics
"""

import asyncio
import aiohttp
import time
import json
import argparse
import statistics
import sys
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor
import threading
import random

class LoadTester:
    def __init__(self, base_url, concurrent_users=10, duration=60, ramp_up=10):
        self.base_url = base_url.rstrip('/')
        self.concurrent_users = concurrent_users
        self.duration = duration
        self.ramp_up = ramp_up
        
        # Results tracking
        self.results = {
            'requests': [],
            'errors': [],
            'start_time': None,
            'end_time': None,
            'total_requests': 0,
            'successful_requests': 0,
            'failed_requests': 0,
            'response_times': [],
            'throughput_per_second': [],
            'concurrent_users_active': []
        }
        
        # Test scenarios
        self.scenarios = [
            {'path': '/health', 'weight': 20, 'method': 'GET'},
            {'path': '/api/health', 'weight': 15, 'method': 'GET'},
            {'path': '/api/users', 'weight': 25, 'method': 'GET', 'params': {'limit': '10'}},
            {'path': '/api/products', 'weight': 25, 'method': 'GET', 'params': {'limit': '10'}},
            {'path': '/api/orders', 'weight': 10, 'method': 'GET', 'params': {'limit': '5'}},
            {'path': '/api/dashboard/metrics', 'weight': 5, 'method': 'GET'}
        ]
        
        # Create weighted scenario list
        self.weighted_scenarios = []
        for scenario in self.scenarios:
            self.weighted_scenarios.extend([scenario] * scenario['weight'])
    
    async def make_request(self, session, scenario, user_id):
        """Make a single HTTP request"""
        url = f"{self.base_url}{scenario['path']}"
        params = scenario.get('params', {})
        method = scenario.get('method', 'GET')
        
        start_time = time.time()
        
        try:
            async with session.request(method, url, params=params, timeout=aiohttp.ClientTimeout(total=10)) as response:
                await response.text()  # Read response body
                end_time = time.time()
                
                response_time = (end_time - start_time) * 1000  # Convert to milliseconds
                
                request_data = {
                    'user_id': user_id,
                    'url': url,
                    'method': method,
                    'status_code': response.status,
                    'response_time': response_time,
                    'timestamp': datetime.now().isoformat(),
                    'success': 200 <= response.status < 400
                }
                
                self.results['requests'].append(request_data)
                self.results['response_times'].append(response_time)
                self.results['total_requests'] += 1
                
                if request_data['success']:
                    self.results['successful_requests'] += 1
                else:
                    self.results['failed_requests'] += 1
                
                return request_data
                
        except Exception as e:
            end_time = time.time()
            response_time = (end_time - start_time) * 1000
            
            error_data = {
                'user_id': user_id,
                'url': url,
                'method': method,
                'error': str(e),
                'response_time': response_time,
                'timestamp': datetime.now().isoformat()
            }
            
            self.results['errors'].append(error_data)
            self.results['failed_requests'] += 1
            self.results['total_requests'] += 1
            
            return error_data
    
    async def user_session(self, user_id, session):
        """Simulate a single user session"""
        requests_made = 0
        start_time = time.time()
        
        while time.time() - start_time < self.duration:
            # Select random scenario
            scenario = random.choice(self.weighted_scenarios)
            
            # Make request
            await self.make_request(session, scenario, user_id)
            requests_made += 1
            
            # Random think time between requests (0.1 to 2 seconds)
            think_time = random.uniform(0.1, 2.0)
            await asyncio.sleep(think_time)
        
        return requests_made
    
    async def monitor_metrics(self):
        """Monitor real-time metrics during test execution"""
        while self.results['start_time'] and not self.results['end_time']:
            current_time = time.time()
            
            # Calculate requests per second in last second
            recent_requests = [
                r for r in self.results['requests']
                if time.time() - time.mktime(datetime.fromisoformat(r['timestamp']).timetuple()) <= 1
            ]
            
            self.results['throughput_per_second'].append({
                'timestamp': datetime.now().isoformat(),
                'rps': len(recent_requests)
            })
            
            await asyncio.sleep(1)
    
    async def run_load_test(self):
        """Execute the load test"""
        print(f"🚀 Starting load test...")
        print(f"   Target URL: {self.base_url}")
        print(f"   Concurrent Users: {self.concurrent_users}")
        print(f"   Duration: {self.duration} seconds")
        print(f"   Ramp-up: {self.ramp_up} seconds")
        print()
        
        self.results['start_time'] = datetime.now().isoformat()
        
        # Create connector with connection pooling
        connector = aiohttp.TCPConnector(
            limit=self.concurrent_users * 2,
            limit_per_host=self.concurrent_users * 2
        )
        
        async with aiohttp.ClientSession(connector=connector) as session:
            tasks = []
            
            # Start monitoring task
            monitor_task = asyncio.create_task(self.monitor_metrics())
            
            # Ramp up users gradually
            if self.ramp_up > 0:
                ramp_delay = self.ramp_up / self.concurrent_users
                
                for user_id in range(self.concurrent_users):
                    if user_id > 0:
                        await asyncio.sleep(ramp_delay)
                    
                    task = asyncio.create_task(self.user_session(user_id, session))
                    tasks.append(task)
                    print(f"📈 User {user_id + 1} started")
            else:
                # Start all users immediately
                for user_id in range(self.concurrent_users):
                    task = asyncio.create_task(self.user_session(user_id, session))
                    tasks.append(task)
            
            print(f"🏃 All {self.concurrent_users} users active...")
            
            # Wait for all user sessions to complete
            await asyncio.gather(*tasks)
            
            # Stop monitoring
            self.results['end_time'] = datetime.now().isoformat()
            monitor_task.cancel()
        
        print("✅ Load test completed")
    
    def analyze_results(self):
        """Analyze and generate test results"""
        if not self.results['requests']:
            print("❌ No successful requests recorded")
            return
        
        response_times = self.results['response_times']
        
        # Calculate statistics
        stats = {
            'total_requests': self.results['total_requests'],
            'successful_requests': self.results['successful_requests'],
            'failed_requests': self.results['failed_requests'],
            'success_rate': (self.results['successful_requests'] / self.results['total_requests']) * 100,
            'average_response_time': statistics.mean(response_times),
            'median_response_time': statistics.median(response_times),
            'min_response_time': min(response_times),
            'max_response_time': max(response_times),
            'p95_response_time': self.percentile(response_times, 95),
            'p99_response_time': self.percentile(response_times, 99),
            'requests_per_second': self.results['total_requests'] / self.duration,
            'concurrent_users': self.concurrent_users,
            'test_duration': self.duration
        }
        
        # Error analysis
        error_summary = {}
        for error in self.results['errors']:
            error_type = error.get('error', 'Unknown')
            error_summary[error_type] = error_summary.get(error_type, 0) + 1
        
        # Endpoint analysis
        endpoint_stats = {}
        for request in self.results['requests']:
            endpoint = request['url'].replace(self.base_url, '')
            if endpoint not in endpoint_stats:
                endpoint_stats[endpoint] = {
                    'requests': 0,
                    'response_times': [],
                    'success_count': 0,
                    'error_count': 0
                }
            
            endpoint_stats[endpoint]['requests'] += 1
            endpoint_stats[endpoint]['response_times'].append(request['response_time'])
            
            if request['success']:
                endpoint_stats[endpoint]['success_count'] += 1
            else:
                endpoint_stats[endpoint]['error_count'] += 1
        
        # Calculate endpoint averages
        for endpoint, data in endpoint_stats.items():
            if data['response_times']:
                data['avg_response_time'] = statistics.mean(data['response_times'])
                data['success_rate'] = (data['success_count'] / data['requests']) * 100
        
        return {
            'summary': stats,
            'errors': error_summary,
            'endpoints': endpoint_stats,
            'raw_results': self.results
        }
    
    def percentile(self, data, percentile):
        """Calculate percentile"""
        sorted_data = sorted(data)
        index = int(len(sorted_data) * percentile / 100)
        return sorted_data[index] if index < len(sorted_data) else sorted_data[-1]
    
    def generate_report(self, results, output_file=None):
        """Generate detailed test report"""
        if output_file:
            with open(output_file, 'w') as f:
                json.dump(results, f, indent=2, default=str)
            print(f"📄 Detailed results saved to: {output_file}")
        
        # Console report
        stats = results['summary']
        errors = results['errors']
        endpoints = results['endpoints']
        
        print("\n" + "="*80)
        print("                    LOAD TEST RESULTS")
        print("="*80)
        
        print(f"\n📊 Test Summary:")
        print(f"   Duration:             {stats['test_duration']} seconds")
        print(f"   Concurrent Users:     {stats['concurrent_users']}")
        print(f"   Total Requests:       {stats['total_requests']}")
        print(f"   Successful Requests:  {stats['successful_requests']}")
        print(f"   Failed Requests:      {stats['failed_requests']}")
        print(f"   Success Rate:         {stats['success_rate']:.2f}%")
        print(f"   Requests/Second:      {stats['requests_per_second']:.2f}")
        
        print(f"\n⏱️  Response Time Statistics:")
        print(f"   Average:              {stats['average_response_time']:.2f} ms")
        print(f"   Median:               {stats['median_response_time']:.2f} ms")
        print(f"   Min:                  {stats['min_response_time']:.2f} ms")
        print(f"   Max:                  {stats['max_response_time']:.2f} ms")
        print(f"   95th Percentile:      {stats['p95_response_time']:.2f} ms")
        print(f"   99th Percentile:      {stats['p99_response_time']:.2f} ms")
        
        if errors:
            print(f"\n❌ Error Summary:")
            for error_type, count in errors.items():
                print(f"   {error_type}: {count}")
        
        print(f"\n🎯 Endpoint Performance:")
        for endpoint, data in endpoints.items():
            print(f"   {endpoint}:")
            print(f"     Requests:       {data['requests']}")
            print(f"     Success Rate:   {data['success_rate']:.2f}%")
            print(f"     Avg Response:   {data['avg_response_time']:.2f} ms")
        
        # Performance assessment
        print(f"\n🏆 Performance Assessment:")
        
        if stats['success_rate'] >= 99.9:
            print("   ✅ Excellent reliability (>99.9% success rate)")
        elif stats['success_rate'] >= 99:
            print("   ✅ Good reliability (>99% success rate)")
        elif stats['success_rate'] >= 95:
            print("   ⚠️  Acceptable reliability (>95% success rate)")
        else:
            print("   ❌ Poor reliability (<95% success rate)")
        
        if stats['average_response_time'] <= 100:
            print("   ✅ Excellent response time (<100ms average)")
        elif stats['average_response_time'] <= 500:
            print("   ✅ Good response time (<500ms average)")
        elif stats['average_response_time'] <= 1000:
            print("   ⚠️  Acceptable response time (<1000ms average)")
        else:
            print("   ❌ Poor response time (>1000ms average)")
        
        if stats['requests_per_second'] >= 100:
            print("   ✅ Excellent throughput (>100 RPS)")
        elif stats['requests_per_second'] >= 50:
            print("   ✅ Good throughput (>50 RPS)")
        elif stats['requests_per_second'] >= 20:
            print("   ⚠️  Acceptable throughput (>20 RPS)")
        else:
            print("   ❌ Poor throughput (<20 RPS)")
        
        print("\n" + "="*80)

def main():
    parser = argparse.ArgumentParser(description='Load testing for DevOps Dashboard')
    parser.add_argument('--url', required=True, help='Base URL to test')
    parser.add_argument('--users', type=int, default=10, help='Number of concurrent users')
    parser.add_argument('--duration', type=int, default=60, help='Test duration in seconds')
    parser.add_argument('--ramp-up', type=int, default=10, help='Ramp-up time in seconds')
    parser.add_argument('--output', help='Output file for detailed results (JSON)')
    
    args = parser.parse_args()
    
    # Validate URL
    if not args.url.startswith(('http://', 'https://')):
        print("❌ Error: URL must start with http:// or https://")
        sys.exit(1)
    
    # Create and run load tester
    tester = LoadTester(
        base_url=args.url,
        concurrent_users=args.users,
        duration=args.duration,
        ramp_up=args.ramp_up
    )
    
    try:
        # Run the test
        asyncio.run(tester.run_load_test())
        
        # Analyze and report results
        results = tester.analyze_results()
        tester.generate_report(results, args.output)
        
        # Exit with appropriate code
        if results['summary']['success_rate'] >= 95:
            sys.exit(0)
        else:
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\n⏹️  Load test interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Load test failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()

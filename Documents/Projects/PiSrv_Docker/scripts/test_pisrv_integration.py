#!/usr/bin/env python3
"""
Test PiSrv Integration with iOS Synchrony Data
Tests converted data against PiSrv inference endpoints
"""

import json
import requests
import time
from pathlib import Path
import sys
from datetime import datetime

def test_health_endpoint(base_url):
    """Test PiSrv health endpoint"""
    try:
        response = requests.get(f"{base_url}/healthz", timeout=5)
        return {
            'status': response.status_code,
            'response_time': response.elapsed.total_seconds(),
            'healthy': response.status_code == 200
        }
    except Exception as e:
        return {
            'status': None,
            'response_time': None,
            'healthy': False,
            'error': str(e)
        }

def test_motifs_endpoint(base_url, test_data=None):
    """Test /api/v1/analysis/motifs endpoint"""
    endpoint = f"{base_url}/api/v1/analysis/motifs"
    
    try:
        start_time = time.time()
        response = requests.get(endpoint, timeout=30)
        response_time = time.time() - start_time
        
        result = {
            'endpoint': '/api/v1/analysis/motifs',
            'status': response.status_code,
            'response_time': response_time,
            'success': response.status_code == 200
        }
        
        if response.status_code == 200:
            try:
                data = response.json()
                result['response_data'] = data
                result['contains_motifs'] = 'motifs' in str(data).lower()
            except json.JSONDecodeError:
                result['response_data'] = response.text[:200]
        else:
            result['error'] = response.text[:200]
            
        return result
        
    except Exception as e:
        return {
            'endpoint': '/api/v1/analysis/motifs',
            'status': None,
            'response_time': None,
            'success': False,
            'error': str(e)
        }

def test_infer_endpoint(base_url, test_request):
    """Test /api/v1/analysis/infer endpoint with test data"""
    endpoint = f"{base_url}/api/v1/analysis/infer"
    
    try:
        start_time = time.time()
        response = requests.post(
            endpoint,
            json=test_request,
            headers={'Content-Type': 'application/json'},
            timeout=30
        )
        response_time = time.time() - start_time
        
        result = {
            'endpoint': '/api/v1/analysis/infer',
            'status': response.status_code,
            'response_time': response_time,
            'success': response.status_code == 200,
            'request_size': len(json.dumps(test_request))
        }
        
        if response.status_code == 200:
            try:
                data = response.json()
                result['response_data'] = data
                
                # Validate expected response structure
                if isinstance(data, dict):
                    result['has_latent'] = 'latent' in data
                    result['has_motif_scores'] = 'motif_scores' in data
                    
                    if 'latent' in data:
                        result['latent_size'] = len(data['latent']) if isinstance(data['latent'], list) else None
                    if 'motif_scores' in data:
                        result['motif_scores_size'] = len(data['motif_scores']) if isinstance(data['motif_scores'], list) else None
                        
            except json.JSONDecodeError:
                result['response_data'] = response.text[:200]
        else:
            result['error'] = response.text[:500]
            
        return result
        
    except Exception as e:
        return {
            'endpoint': '/api/v1/analysis/infer',
            'status': None,
            'response_time': None,
            'success': False,
            'error': str(e)
        }

def load_test_data(test_data_dir):
    """Load converted test data"""
    data_path = Path(test_data_dir)
    
    # Load test samples
    test_samples_dir = data_path / "test_samples"
    test_requests = []
    
    if test_samples_dir.exists():
        for test_file in test_samples_dir.glob("test_request_*.json"):
            with open(test_file, 'r') as f:
                test_requests.append(json.load(f))
    
    return test_requests

def run_comprehensive_tests(base_url, test_data_dir):
    """Run comprehensive test suite"""
    print(f"🧪 Testing PiSrv integration")
    print(f"🌐 Base URL: {base_url}")
    print(f"📂 Test data: {test_data_dir}")
    print("=" * 60)
    
    test_results = {
        'test_timestamp': datetime.now().isoformat(),
        'base_url': base_url,
        'test_data_dir': str(test_data_dir),
        'tests': {}
    }
    
    # Test 1: Health Check
    print("🏥 Testing health endpoint...")
    health_result = test_health_endpoint(base_url)
    test_results['tests']['health'] = health_result
    
    if health_result['healthy']:
        print(f"✅ Health check passed ({health_result['response_time']:.3f}s)")
    else:
        print(f"❌ Health check failed: {health_result.get('error', 'Unknown error')}")
        print("⚠️  Continuing with other tests...")
    
    # Test 2: Motifs Endpoint
    print("\n🎯 Testing motifs endpoint...")
    motifs_result = test_motifs_endpoint(base_url)
    test_results['tests']['motifs'] = motifs_result
    
    if motifs_result['success']:
        print(f"✅ Motifs endpoint working ({motifs_result['response_time']:.3f}s)")
        print(f"   Contains motifs: {motifs_result.get('contains_motifs', False)}")
    else:
        print(f"❌ Motifs endpoint failed: {motifs_result.get('error', 'Unknown error')}")
    
    # Test 3: Load test data
    print("\n📊 Loading test data...")
    test_requests = load_test_data(test_data_dir)
    
    if not test_requests:
        print("❌ No test requests found. Run convert_for_pisrv.py first.")
        return test_results
    
    print(f"✅ Loaded {len(test_requests)} test requests")
    
    # Test 4: Infer Endpoint
    print(f"\n🔬 Testing infer endpoint with {len(test_requests)} samples...")
    infer_results = []
    
    for i, test_request in enumerate(test_requests):
        print(f"   Testing sample {i+1}/{len(test_requests)}...", end=" ")
        
        # Remove metadata from request for API call
        api_request = {'x': test_request['x']}
        
        result = test_infer_endpoint(base_url, api_request)
        result['sample_id'] = i + 1
        infer_results.append(result)
        
        if result['success']:
            print(f"✅ ({result['response_time']:.3f}s)")
            if result.get('latent_size'):
                print(f"      Latent: {result['latent_size']}, Motif scores: {result.get('motif_scores_size', 'N/A')}")
        else:
            print(f"❌ {result.get('error', 'Unknown error')[:50]}...")
    
    test_results['tests']['infer'] = {
        'total_samples': len(test_requests),
        'successful_samples': sum(1 for r in infer_results if r['success']),
        'failed_samples': sum(1 for r in infer_results if not r['success']),
        'average_response_time': sum(r.get('response_time', 0) for r in infer_results if r.get('response_time')) / len(infer_results),
        'detailed_results': infer_results
    }
    
    # Summary
    print(f"\n📋 Test Summary:")
    print(f"   Health: {'✅' if health_result['healthy'] else '❌'}")
    print(f"   Motifs: {'✅' if motifs_result['success'] else '❌'}")
    print(f"   Infer: {test_results['tests']['infer']['successful_samples']}/{test_results['tests']['infer']['total_samples']} successful")
    
    success_rate = test_results['tests']['infer']['successful_samples'] / test_results['tests']['infer']['total_samples'] * 100
    print(f"   Success rate: {success_rate:.1f}%")
    
    return test_results

def main(base_url, test_data_dir):
    """Main test function"""
    # Ensure test data directory exists
    if not Path(test_data_dir).exists():
        print(f"❌ Test data directory not found: {test_data_dir}")
        print("Run convert_for_pisrv.py first to generate test data")
        return
    
    # Run tests
    results = run_comprehensive_tests(base_url, test_data_dir)
    
    # Save results
    results_file = Path(test_data_dir) / "integration_test_results.json"
    with open(results_file, 'w') as f:
        json.dump(results, f, indent=2, default=str)
    
    print(f"\n💾 Test results saved: {results_file}")
    print("🎉 Testing complete!")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python test_pisrv_integration.py <base_url> <test_data_directory>")
        print("Example: python test_pisrv_integration.py http://localhost:8080 ./pisrv_formatted")
        sys.exit(1)
    
    base_url = sys.argv[1].rstrip('/')
    test_data_dir = sys.argv[2]
    
    main(base_url, test_data_dir)
#!/usr/bin/env python3
"""
Convert iOS Synchrony Data for PiSrv Integration
Transforms synchrony data into formats compatible with pisrv inference endpoints
"""

import json
import pandas as pd
import numpy as np
from pathlib import Path
import sys
from datetime import datetime

def load_synchrony_data(data_dir, format_type='mvp'):
    """Load synchrony data in specified format"""
    data_path = Path(data_dir)
    
    if format_type == 'mvp':
        jsonl_file = data_path / 'synchrony_mvp_data.jsonl'
    else:
        jsonl_file = data_path / 'synchrony_data.jsonl'
    
    records = []
    with open(jsonl_file, 'r') as f:
        for line in f:
            records.append(json.loads(line.strip()))
    
    return records

def extract_imu_windows(records, window_size=100):
    """Extract IMU data windows suitable for inference"""
    imu_windows = []
    
    for record in records:
        # Extract IMU data based on record structure
        # This will need to be adapted based on actual data structure
        if 'imu_data' in record:
            imu_data = record['imu_data']
            
            # Ensure we have the right shape (100x9 for TCN-VAE model)
            if isinstance(imu_data, list) and len(imu_data) >= window_size:
                # Take first window_size samples
                window = imu_data[:window_size]
                
                # Validate each row has 9 columns (ax,ay,az,gx,gy,gz,mx,my,mz)
                if all(len(row) == 9 for row in window):
                    imu_windows.append({
                        'session_id': record.get('session_id'),
                        'timestamp': record.get('timestamp'),
                        'window': window,
                        'metadata': {
                            'source': 'ios_synchrony',
                            'record_id': record.get('id'),
                            'window_size': window_size
                        }
                    })
    
    return imu_windows

def format_for_analysis_infer(imu_windows):
    """Format data for /api/v1/analysis/infer endpoint"""
    formatted_requests = []
    
    for window_data in imu_windows:
        # Format according to InferRequest structure
        request = {
            'x': window_data['window'],  # 100x9 array
            'metadata': window_data['metadata']
        }
        formatted_requests.append(request)
    
    return formatted_requests

def format_for_analysis_motifs(records):
    """Format data for /api/v1/analysis/motifs endpoint (if applicable)"""
    # This endpoint might not need specific input format
    # but we can prepare metadata for batch processing
    motif_requests = []
    
    for record in records:
        motif_requests.append({
            'session_id': record.get('session_id'),
            'timestamp': record.get('timestamp'),
            'sync_score': record.get('synchrony_score'),
            'metadata': {
                'source': 'ios_synchrony',
                'record_id': record.get('id')
            }
        })
    
    return motif_requests

def validate_pisrv_format(formatted_data):
    """Validate data format for PiSrv compatibility"""
    validation_results = {
        'valid_windows': 0,
        'invalid_windows': 0,
        'errors': []
    }
    
    for i, request in enumerate(formatted_data):
        try:
            # Check x field exists and has correct shape
            if 'x' not in request:
                validation_results['errors'].append(f"Request {i}: Missing 'x' field")
                validation_results['invalid_windows'] += 1
                continue
            
            x_data = request['x']
            
            # Validate shape (should be 100x9)
            if not isinstance(x_data, list):
                validation_results['errors'].append(f"Request {i}: 'x' must be a list")
                validation_results['invalid_windows'] += 1
                continue
            
            if len(x_data) != 100:
                validation_results['errors'].append(f"Request {i}: Expected 100 rows, got {len(x_data)}")
                validation_results['invalid_windows'] += 1
                continue
            
            for row_idx, row in enumerate(x_data):
                if not isinstance(row, list) or len(row) != 9:
                    validation_results['errors'].append(f"Request {i}, row {row_idx}: Expected 9 columns, got {len(row) if isinstance(row, list) else 'non-list'}")
                    validation_results['invalid_windows'] += 1
                    break
            else:
                validation_results['valid_windows'] += 1
                
        except Exception as e:
            validation_results['errors'].append(f"Request {i}: {str(e)}")
            validation_results['invalid_windows'] += 1
    
    return validation_results

def generate_test_requests(formatted_data, output_dir, num_samples=5):
    """Generate sample test requests for API testing"""
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)
    
    # Take first few samples for testing
    test_samples = formatted_data[:num_samples]
    
    # Save individual request files
    for i, request in enumerate(test_samples):
        test_file = output_path / f"test_request_{i+1}.json"
        with open(test_file, 'w') as f:
            json.dump(request, f, indent=2)
    
    # Save batch request file
    batch_file = output_path / "batch_requests.json"
    with open(batch_file, 'w') as f:
        json.dump(test_samples, f, indent=2)
    
    print(f"✅ Generated {len(test_samples)} test requests in {output_path}")

def main(data_dir, output_dir=None):
    """Main conversion function"""
    data_path = Path(data_dir)
    output_path = Path(output_dir) if output_dir else data_path / "pisrv_formatted"
    output_path.mkdir(exist_ok=True)
    
    print(f"🔄 Converting iOS synchrony data for PiSrv")
    print(f"📂 Source: {data_path}")
    print(f"📂 Output: {output_path}")
    print("=" * 60)
    
    # Load data
    print("📊 Loading synchrony data...")
    try:
        mvp_records = load_synchrony_data(data_dir, 'mvp')
        full_records = load_synchrony_data(data_dir, 'full')
        print(f"✅ Loaded {len(mvp_records)} MVP records, {len(full_records)} full records")
    except Exception as e:
        print(f"❌ Error loading data: {e}")
        return
    
    # Extract IMU windows
    print("🔬 Extracting IMU windows...")
    try:
        imu_windows = extract_imu_windows(mvp_records)
        print(f"✅ Extracted {len(imu_windows)} IMU windows")
    except Exception as e:
        print(f"❌ Error extracting IMU data: {e}")
        print("📝 Note: This may need adaptation based on actual data structure")
        return
    
    # Format for PiSrv endpoints
    print("🎯 Formatting for PiSrv endpoints...")
    infer_requests = format_for_analysis_infer(imu_windows)
    motif_requests = format_for_analysis_motifs(mvp_records)
    
    # Validate format
    print("🔍 Validating PiSrv format...")
    validation = validate_pisrv_format(infer_requests)
    print(f"✅ Valid windows: {validation['valid_windows']}")
    print(f"❌ Invalid windows: {validation['invalid_windows']}")
    
    if validation['errors']:
        print("⚠️  Validation errors:")
        for error in validation['errors'][:10]:  # Show first 10 errors
            print(f"  • {error}")
    
    # Save formatted data
    output_files = {
        'infer_requests.json': infer_requests,
        'motif_requests.json': motif_requests,
        'validation_report.json': validation
    }
    
    for filename, data in output_files.items():
        output_file = output_path / filename
        with open(output_file, 'w') as f:
            json.dump(data, f, indent=2, default=str)
        print(f"💾 Saved: {output_file}")
    
    # Generate test samples
    if validation['valid_windows'] > 0:
        generate_test_requests(infer_requests, output_path / "test_samples")
    
    # Create summary
    summary = {
        'conversion_timestamp': datetime.now().isoformat(),
        'source_records': len(mvp_records),
        'extracted_windows': len(imu_windows),
        'valid_infer_requests': validation['valid_windows'],
        'validation_errors': len(validation['errors']),
        'output_files': list(output_files.keys())
    }
    
    summary_file = output_path / "conversion_summary.json"
    with open(summary_file, 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"\n📋 Conversion Summary:")
    print(f"  • Source records: {summary['source_records']}")
    print(f"  • Extracted windows: {summary['extracted_windows']}")
    print(f"  • Valid requests: {summary['valid_infer_requests']}")
    print(f"  • Output files: {len(output_files)}")
    print(f"💾 Summary saved: {summary_file}")
    print("🎉 Conversion complete!")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python convert_for_pisrv.py <data_directory> [output_directory]")
        sys.exit(1)
    
    data_dir = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else None
    
    main(data_dir, output_dir)
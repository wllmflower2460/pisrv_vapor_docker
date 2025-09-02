#!/usr/bin/env python3
"""
iOS Synchrony Dataset Analysis Script
Analyzes structure, content, and quality of synchrony data files
"""

import json
import csv
import pandas as pd
from pathlib import Path
import sys
from datetime import datetime

def load_jsonl(file_path):
    """Load JSONL file and return list of records"""
    records = []
    with open(file_path, 'r') as f:
        for line in f:
            records.append(json.loads(line.strip()))
    return records

def analyze_structure(data, format_name):
    """Analyze data structure and return schema info"""
    if not data:
        return {}
    
    sample_record = data[0]
    structure = {
        'record_count': len(data),
        'fields': list(sample_record.keys()) if isinstance(sample_record, dict) else [],
        'field_types': {},
        'sample_record': sample_record
    }
    
    # Analyze field types from first record
    if isinstance(sample_record, dict):
        for field, value in sample_record.items():
            structure['field_types'][field] = type(value).__name__
    
    return structure

def compare_formats(full_data, mvp_data):
    """Compare full and MVP format structures"""
    full_structure = analyze_structure(full_data, "Full")
    mvp_structure = analyze_structure(mvp_data, "MVP")
    
    comparison = {
        'full_format': full_structure,
        'mvp_format': mvp_structure,
        'differences': {
            'fields_only_in_full': set(full_structure['fields']) - set(mvp_structure['fields']),
            'fields_only_in_mvp': set(mvp_structure['fields']) - set(full_structure['fields']),
            'common_fields': set(full_structure['fields']) & set(mvp_structure['fields'])
        }
    }
    
    return comparison

def validate_integrity(jsonl_data, csv_data, format_name):
    """Validate data integrity between JSONL and CSV formats"""
    results = {
        'record_count_match': len(jsonl_data) == len(csv_data),
        'jsonl_count': len(jsonl_data),
        'csv_count': len(csv_data),
        'issues': []
    }
    
    if not results['record_count_match']:
        results['issues'].append(f"Record count mismatch in {format_name}")
    
    return results

def generate_statistics(data, format_name):
    """Generate statistical summary of the data"""
    if not data:
        return {}
    
    stats = {
        'record_count': len(data),
        'timestamp_range': None,
        'numeric_field_stats': {},
        'text_field_stats': {}
    }
    
    # Convert to DataFrame for easier analysis
    df = pd.DataFrame(data)
    
    # Analyze numeric columns
    numeric_cols = df.select_dtypes(include=['number']).columns
    for col in numeric_cols:
        stats['numeric_field_stats'][col] = {
            'mean': df[col].mean(),
            'median': df[col].median(),
            'std': df[col].std(),
            'min': df[col].min(),
            'max': df[col].max(),
            'null_count': df[col].isnull().sum()
        }
    
    # Analyze text columns
    text_cols = df.select_dtypes(include=['object']).columns
    for col in text_cols:
        stats['text_field_stats'][col] = {
            'unique_values': df[col].nunique(),
            'null_count': df[col].isnull().sum(),
            'avg_length': df[col].astype(str).str.len().mean() if not df[col].empty else 0
        }
    
    return stats

def main(data_dir):
    """Main analysis function"""
    data_path = Path(data_dir)
    
    print(f"🔍 Analyzing iOS Synchrony Dataset at: {data_path}")
    print(f"📅 Analysis started: {datetime.now()}")
    print("=" * 60)
    
    # Load all data files
    files = {
        'full_jsonl': data_path / 'synchrony_data.jsonl',
        'full_csv': data_path / 'synchrony_data.csv',
        'mvp_jsonl': data_path / 'synchrony_mvp_data.jsonl', 
        'mvp_csv': data_path / 'synchrony_mvp_data.csv',
        'metadata': data_path / 'session_metadata.json'
    }
    
    # Check file existence
    missing_files = [name for name, path in files.items() if not path.exists()]
    if missing_files:
        print(f"❌ Missing files: {missing_files}")
        return
    
    print("✅ All files found")
    
    # Load data
    print("\n📊 Loading data files...")
    full_jsonl_data = load_jsonl(files['full_jsonl'])
    mvp_jsonl_data = load_jsonl(files['mvp_jsonl'])
    full_csv_data = pd.read_csv(files['full_csv']).to_dict('records')
    mvp_csv_data = pd.read_csv(files['mvp_csv']).to_dict('records')
    
    with open(files['metadata'], 'r') as f:
        metadata = json.load(f)
    
    print(f"📈 Loaded {len(full_jsonl_data)} full format records")
    print(f"📈 Loaded {len(mvp_jsonl_data)} MVP format records")
    
    # Analysis 1: Structure Comparison
    print("\n🔬 Analyzing data structures...")
    format_comparison = compare_formats(full_jsonl_data, mvp_jsonl_data)
    
    print(f"Full format fields: {len(format_comparison['full_format']['fields'])}")
    print(f"MVP format fields: {len(format_comparison['mvp_format']['fields'])}")
    print(f"Common fields: {len(format_comparison['differences']['common_fields'])}")
    print(f"Full-only fields: {format_comparison['differences']['fields_only_in_full']}")
    print(f"MVP-only fields: {format_comparison['differences']['fields_only_in_mvp']}")
    
    # Analysis 2: Data Integrity
    print("\n🔍 Validating data integrity...")
    full_integrity = validate_integrity(full_jsonl_data, full_csv_data, "Full")
    mvp_integrity = validate_integrity(mvp_jsonl_data, mvp_csv_data, "MVP")
    
    print(f"Full format integrity: {'✅' if full_integrity['record_count_match'] else '❌'}")
    print(f"MVP format integrity: {'✅' if mvp_integrity['record_count_match'] else '❌'}")
    
    # Analysis 3: Statistical Summary
    print("\n📊 Generating statistics...")
    full_stats = generate_statistics(full_jsonl_data, "Full")
    mvp_stats = generate_statistics(mvp_jsonl_data, "MVP")
    
    # Analysis 4: File Sizes
    file_sizes = {}
    for name, path in files.items():
        if path.exists():
            file_sizes[name] = path.stat().st_size
    
    print(f"\n💾 File sizes:")
    for name, size in file_sizes.items():
        print(f"  {name}: {size:,} bytes ({size/1024:.1f} KB)")
    
    # Generate comprehensive report
    report = {
        'analysis_timestamp': datetime.now().isoformat(),
        'metadata': metadata,
        'structure_comparison': format_comparison,
        'integrity_validation': {
            'full_format': full_integrity,
            'mvp_format': mvp_integrity
        },
        'statistics': {
            'full_format': full_stats,
            'mvp_format': mvp_stats
        },
        'file_sizes': file_sizes
    }
    
    # Save report
    report_path = data_path / 'analysis_report.json'
    with open(report_path, 'w') as f:
        json.dump(report, f, indent=2, default=str)
    
    print(f"\n💾 Analysis report saved: {report_path}")
    print("🎉 Analysis complete!")
    
    return report

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python analyze_synchrony_data.py <data_directory>")
        sys.exit(1)
    
    main(sys.argv[1])
#!/usr/bin/env python3
"""
Quick Data Peek - Fast preview of synchrony dataset files
"""

import json
import csv
from pathlib import Path
import sys

def peek_jsonl(file_path, num_records=3):
    """Quick peek at JSONL file structure"""
    print(f"\n📄 {file_path.name}")
    print("-" * 40)
    
    try:
        with open(file_path, 'r') as f:
            for i, line in enumerate(f):
                if i >= num_records:
                    break
                record = json.loads(line.strip())
                print(f"Record {i+1}:")
                if isinstance(record, dict):
                    for key, value in record.items():
                        # Truncate long values
                        str_value = str(value)[:100] + "..." if len(str(value)) > 100 else str(value)
                        print(f"  {key}: {str_value}")
                else:
                    print(f"  {record}")
                print()
    except Exception as e:
        print(f"❌ Error reading {file_path.name}: {e}")

def peek_csv(file_path, num_records=3):
    """Quick peek at CSV file structure"""
    print(f"\n📊 {file_path.name}")
    print("-" * 40)
    
    try:
        with open(file_path, 'r') as f:
            reader = csv.DictReader(f)
            headers = reader.fieldnames
            print(f"Headers ({len(headers)}): {', '.join(headers[:10])}{'...' if len(headers) > 10 else ''}")
            print()
            
            for i, row in enumerate(reader):
                if i >= num_records:
                    break
                print(f"Row {i+1}:")
                for key, value in row.items():
                    # Truncate long values
                    str_value = str(value)[:50] + "..." if len(str(value)) > 50 else str(value)
                    print(f"  {key}: {str_value}")
                print()
    except Exception as e:
        print(f"❌ Error reading {file_path.name}: {e}")

def peek_metadata(file_path):
    """Quick peek at metadata file"""
    print(f"\n🏷️  {file_path.name}")
    print("-" * 40)
    
    try:
        with open(file_path, 'r') as f:
            metadata = json.load(f)
        print(json.dumps(metadata, indent=2))
    except Exception as e:
        print(f"❌ Error reading {file_path.name}: {e}")

def main(data_dir):
    """Main peek function"""
    data_path = Path(data_dir)
    
    print(f"👀 Quick peek at synchrony dataset: {data_path}")
    print("=" * 60)
    
    # Check if directory exists
    if not data_path.exists():
        print(f"❌ Directory not found: {data_path}")
        return
    
    # List all files
    files = list(data_path.glob("*"))
    print(f"📁 Found {len(files)} files:")
    for f in files:
        print(f"  • {f.name} ({f.stat().st_size:,} bytes)")
    
    # Peek at specific files
    file_map = {
        'session_metadata.json': peek_metadata,
        'synchrony_data.jsonl': peek_jsonl,
        'synchrony_mvp_data.jsonl': peek_jsonl,
        'synchrony_data.csv': peek_csv,
        'synchrony_mvp_data.csv': peek_csv
    }
    
    for filename, peek_func in file_map.items():
        file_path = data_path / filename
        if file_path.exists():
            peek_func(file_path)
        else:
            print(f"\n❌ File not found: {filename}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python quick_data_peek.py <data_directory>")
        sys.exit(1)
    
    main(sys.argv[1])
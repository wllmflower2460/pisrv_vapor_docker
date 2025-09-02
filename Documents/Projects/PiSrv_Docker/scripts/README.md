# iOS Synchrony Dataset Analysis Scripts

This directory contains scripts for comprehensive analysis of iOS synchrony datasets and integration with PiSrv inference endpoints.

## Quick Start

**For complete analysis:**
```bash
./analyze_ios_dataset.sh /path/to/synchrony/data
```

**For quick peek only:**
```bash
./analyze_ios_dataset.sh /path/to/synchrony/data --quick
```

## Scripts Overview

### 🎯 Master Script
- **`analyze_ios_dataset.sh`** - Orchestrates the complete analysis workflow
  - Data validation
  - Comprehensive analysis  
  - PiSrv format conversion
  - Integration testing
  - Report generation

### 🔍 Analysis Scripts
- **`quick_data_peek.py`** - Fast preview of dataset structure and content
- **`analyze_synchrony_data.py`** - Comprehensive data analysis and statistics
- **`convert_for_pisrv.py`** - Convert data for PiSrv endpoint compatibility
- **`test_pisrv_integration.py`** - Test converted data against PiSrv APIs

## Expected Data Structure

Your synchrony dataset should contain:
```
synchrony_session_directory/
├── synchrony_data.jsonl          (945 records - full format)
├── synchrony_data.csv            (945 records - full format)
├── synchrony_mvp_data.jsonl      (945 records - MVP format)  
├── synchrony_mvp_data.csv        (945 records - MVP format)
└── session_metadata.json
```

## Usage Examples

### 1. Complete Analysis
```bash
# Run full analysis with custom output directory
./analyze_ios_dataset.sh /var/mobile/.../synchrony_data --output ./my_analysis

# Run analysis with specific PiSrv URL
./analyze_ios_dataset.sh /path/to/data --pisrv-url http://pisrv:8080
```

### 2. Individual Scripts
```bash
# Quick peek at data structure
python3 quick_data_peek.py /path/to/synchrony/data

# Full statistical analysis
python3 analyze_synchrony_data.py /path/to/synchrony/data

# Convert for PiSrv integration
python3 convert_for_pisrv.py /path/to/synchrony/data ./output

# Test PiSrv endpoints
python3 test_pisrv_integration.py http://localhost:8080 ./output/pisrv_formatted
```

## Output Structure

Analysis generates the following outputs:
```
analysis_output/
├── analysis_report.json              # Comprehensive analysis results
├── iOS_Synchrony_Dataset_Analysis_*.md # Final report document
├── pisrv_formatted/
│   ├── infer_requests.json           # Data formatted for /analysis/infer
│   ├── motif_requests.json           # Data formatted for /analysis/motifs  
│   ├── validation_report.json        # Format validation results
│   ├── conversion_summary.json       # Conversion statistics
│   └── test_samples/
│       ├── test_request_1.json       # Individual test requests
│       ├── test_request_2.json
│       ├── ...
│       └── batch_requests.json       # Batch test requests
└── integration_test_results.json     # PiSrv API test results
```

## Requirements

**Python packages:**
```bash
pip install pandas numpy requests
```

**System requirements:**
- Python 3.7+
- Access to synchrony data files
- Network access to PiSrv (for integration tests)

## Analysis Features

### 📊 Data Structure Analysis
- Compare full vs MVP format schemas
- Identify field differences and mappings
- Validate data consistency across formats

### 🔍 Quality Assessment  
- Record count validation
- Missing value detection
- Data type consistency checks
- Cross-format integrity validation

### 📈 Statistical Analysis
- Numeric field statistics (mean, median, std, range)
- Text field analysis (uniqueness, length)
- Temporal analysis (if timestamps present)
- Distribution analysis

### 🔄 PiSrv Integration
- Format conversion for `/api/v1/analysis/infer` endpoint
- Shape validation (100x9 IMU windows)
- Test request generation
- API endpoint testing

### 🧪 Testing & Validation
- Health endpoint testing
- Motifs endpoint validation
- Inference endpoint testing with real data
- Response validation and timing analysis

## Troubleshooting

### Data Access Issues
If iOS data path is not accessible:
1. Copy files to accessible location
2. Update path in command
3. Ensure file permissions are correct

### PiSrv Connection Issues
- Verify PiSrv is running: `curl http://localhost:8080/healthz`
- Check network connectivity
- Use `--skip-test` flag to skip integration tests

### Missing Dependencies
```bash
# Install required packages
pip install pandas numpy requests

# Check Python version
python3 --version  # Should be 3.7+
```

### Data Format Issues
The conversion script expects specific data structures. If conversion fails:
1. Check the structure with `quick_data_peek.py`
2. Adapt the `extract_imu_windows()` function in `convert_for_pisrv.py`
3. Verify IMU data is in expected format (100x9 arrays)

## Integration with PiSrv

The analysis scripts are designed to work with PiSrv inference endpoints:

- **`/api/v1/analysis/infer`** - Expects `{"x": [[100x9 IMU data]]}`
- **`/api/v1/analysis/motifs`** - GET endpoint for motif analysis
- **`/healthz`** - Health check endpoint

Generated test data follows the exact format expected by these endpoints.

## Documentation

Results are documented in:
- `../docs/iOS_Synchrony_Dataset_Analysis.md` - Analysis template
- Generated analysis reports with findings
- JSON reports with detailed statistics
- Integration test results with API performance metrics

---

For questions or issues, check the main project documentation or examine the generated analysis reports.
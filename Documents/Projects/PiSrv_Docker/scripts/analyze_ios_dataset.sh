#!/bin/bash
#
# iOS Synchrony Dataset Analysis Master Script
# Orchestrates the complete analysis workflow
#

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$(dirname "$SCRIPT_DIR")/docs"
DEFAULT_PISRV_URL="http://localhost:8080"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

usage() {
    cat << EOF
📊 iOS Synchrony Dataset Analysis Master Script

Usage: $0 <data_directory> [options]

Arguments:
  data_directory    Path to directory containing synchrony dataset files

Options:
  -o, --output DIR     Output directory for analysis results (default: data_directory/analysis)
  -u, --pisrv-url URL  PiSrv base URL for integration testing (default: $DEFAULT_PISRV_URL)
  -s, --skip-test      Skip PiSrv integration testing
  -q, --quick          Quick analysis only (peek + basic stats)
  -h, --help           Show this help message

Expected files in data directory:
  • synchrony_data.jsonl (945 records - full format)
  • synchrony_data.csv (945 records - full format)  
  • synchrony_mvp_data.jsonl (945 records - MVP format)
  • synchrony_mvp_data.csv (945 records - MVP format)
  • session_metadata.json

Examples:
  $0 /path/to/synchrony/data
  $0 /path/to/synchrony/data --output ./analysis_results
  $0 /path/to/synchrony/data --pisrv-url http://pisrv:8080 --quick
EOF
}

check_requirements() {
    log "Checking requirements..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        error "Python 3 is required but not installed"
        exit 1
    fi
    
    # Check required Python packages
    python3 -c "import pandas, numpy, requests" 2>/dev/null || {
        warning "Some Python packages may be missing. Install with:"
        echo "  pip install pandas numpy requests"
    }
    
    success "Requirements check complete"
}

validate_data_directory() {
    local data_dir="$1"
    
    log "Validating data directory: $data_dir"
    
    if [[ ! -d "$data_dir" ]]; then
        error "Data directory does not exist: $data_dir"
        exit 1
    fi
    
    # Check for expected files
    local required_files=(
        "synchrony_data.jsonl"
        "synchrony_data.csv"
        "synchrony_mvp_data.jsonl" 
        "synchrony_mvp_data.csv"
        "session_metadata.json"
    )
    
    local missing_files=()
    for file in "${required_files[@]}"; do
        if [[ ! -f "$data_dir/$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        error "Missing required files:"
        for file in "${missing_files[@]}"; do
            echo "  • $file"
        done
        exit 1
    fi
    
    success "Data directory validation complete"
}

run_quick_peek() {
    local data_dir="$1"
    
    log "Running quick data peek..."
    python3 "$SCRIPT_DIR/quick_data_peek.py" "$data_dir"
    success "Quick peek complete"
}

run_full_analysis() {
    local data_dir="$1"
    
    log "Running comprehensive data analysis..."
    python3 "$SCRIPT_DIR/analyze_synchrony_data.py" "$data_dir"
    success "Comprehensive analysis complete"
}

run_pisrv_conversion() {
    local data_dir="$1"
    local output_dir="$2"
    
    log "Converting data for PiSrv integration..."
    python3 "$SCRIPT_DIR/convert_for_pisrv.py" "$data_dir" "$output_dir/pisrv_formatted"
    success "PiSrv conversion complete"
}

run_integration_tests() {
    local pisrv_url="$1"
    local test_data_dir="$2"
    
    log "Testing PiSrv integration..."
    python3 "$SCRIPT_DIR/test_pisrv_integration.py" "$pisrv_url" "$test_data_dir/pisrv_formatted"
    success "Integration testing complete"
}

generate_final_report() {
    local data_dir="$1"
    local output_dir="$2"
    
    log "Generating final analysis report..."
    
    # Update the analysis document with findings
    local doc_file="$DOCS_DIR/iOS_Synchrony_Dataset_Analysis.md"
    local temp_doc="$output_dir/iOS_Synchrony_Dataset_Analysis_$(date +%Y%m%d_%H%M%S).md"
    
    # Copy template and add results
    cp "$doc_file" "$temp_doc"
    
    # Add completion timestamp
    sed -i '' "s/Analysis started: \[Date\]/Analysis started: $(date)/" "$temp_doc"
    sed -i '' "s/Last updated: \[Date\]/Last updated: $(date)/" "$temp_doc"
    
    echo "" >> "$temp_doc"
    echo "## Analysis Results Generated" >> "$temp_doc"
    echo "" >> "$temp_doc"
    echo "- 📊 Comprehensive analysis: \`analysis_report.json\`" >> "$temp_doc"
    echo "- 🔄 PiSrv conversion: \`pisrv_formatted/\`" >> "$temp_doc"
    echo "- 🧪 Integration tests: \`integration_test_results.json\`" >> "$temp_doc"
    
    success "Final report generated: $temp_doc"
}

main() {
    local data_dir=""
    local output_dir=""
    local pisrv_url="$DEFAULT_PISRV_URL"
    local skip_test=false
    local quick_only=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -u|--pisrv-url)
                pisrv_url="$2"
                shift 2
                ;;
            -s|--skip-test)
                skip_test=true
                shift
                ;;
            -q|--quick)
                quick_only=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [[ -z "$data_dir" ]]; then
                    data_dir="$1"
                else
                    error "Multiple data directories specified"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$data_dir" ]]; then
        error "Data directory is required"
        usage
        exit 1
    fi
    
    # Set default output directory
    if [[ -z "$output_dir" ]]; then
        output_dir="$data_dir/analysis"
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Start analysis
    echo "🚀 iOS Synchrony Dataset Analysis"
    echo "================================="
    echo "📂 Data directory: $data_dir"
    echo "📁 Output directory: $output_dir"
    echo "🌐 PiSrv URL: $pisrv_url"
    echo "⚡ Quick mode: $([ "$quick_only" = true ] && echo "enabled" || echo "disabled")"
    echo "🧪 Integration tests: $([ "$skip_test" = true ] && echo "disabled" || echo "enabled")"
    echo ""
    
    # Step 1: Check requirements
    check_requirements
    
    # Step 2: Validate data directory
    validate_data_directory "$data_dir"
    
    # Step 3: Quick peek (always run)
    run_quick_peek "$data_dir"
    
    if [[ "$quick_only" = true ]]; then
        success "Quick analysis complete!"
        exit 0
    fi
    
    # Step 4: Full analysis
    run_full_analysis "$data_dir"
    
    # Step 5: PiSrv conversion
    run_pisrv_conversion "$data_dir" "$output_dir"
    
    # Step 6: Integration testing (if enabled)
    if [[ "$skip_test" = false ]]; then
        run_integration_tests "$pisrv_url" "$output_dir"
    else
        warning "Skipping integration tests"
    fi
    
    # Step 7: Generate final report
    generate_final_report "$data_dir" "$output_dir"
    
    # Success summary
    echo ""
    echo "🎉 Analysis Complete!"
    echo "===================="
    echo "📊 Results saved in: $output_dir"
    echo ""
    echo "Generated files:"
    echo "  • analysis_report.json - Comprehensive analysis"
    echo "  • pisrv_formatted/ - Converted data for PiSrv"
    echo "  • test_samples/ - Sample requests for API testing"
    if [[ "$skip_test" = false ]]; then
        echo "  • integration_test_results.json - API test results"
    fi
    echo "  • iOS_Synchrony_Dataset_Analysis_*.md - Final report"
    echo ""
    success "All tasks completed successfully!"
}

# Run main function with all arguments
main "$@"
#!/bin/bash
# Hailo Sidecar Integration Smoke Test
# Tests the complete PiSrv + Hailo sidecar integration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PISRV_URL="${PISRV_URL:-http://localhost:8082}"
HAILO_URL="${HAILO_URL:-http://localhost:9000}"
EDGE_INFER_URL="${EDGE_INFER_URL:-http://localhost:8080}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_TOTAL++))
    log_info "Running: $test_name"
    
    if eval "$test_command"; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        return 1
    fi
}

# Test functions
test_hailo_health() {
    curl -fsS "$HAILO_URL/healthz" | jq -e '.ok == true' >/dev/null
}

test_hailo_contract() {
    local payload
    # Generate 100 rows of 9 zeros each without Python dependency
    payload='{"x":['
    for ((i=0; i<100; i++)); do
        if [ $i -gt 0 ]; then payload+=','; fi
        payload+='[0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]'
    done
    payload+=']}'
    
    local response
    response=$(curl -fsS -X POST "$HAILO_URL/infer" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    # Validate response shape: latent=64, motif_scores=12
    echo "$response" | jq -e '.latent | length == 64' >/dev/null && \
    echo "$response" | jq -e '.motif_scores | length == 12' >/dev/null
}

test_hailo_metrics() {
    curl -fsS "$HAILO_URL/metrics" | grep -q "hailo_build_info"
}

test_edge_infer_health() {
    curl -fsS "$EDGE_INFER_URL/healthz" | jq -e '.ok == true' >/dev/null
}

test_edge_infer_backend_integration() {
    # Test that EdgeInfer can reach Hailo when USE_REAL_MODEL=true
    local response
    response=$(curl -fsS "$EDGE_INFER_URL/healthz")
    
    # Check if backend_ok is present and true (when USE_REAL_MODEL=true)
    if echo "$response" | jq -e '.backend_ok' >/dev/null 2>&1; then
        echo "$response" | jq -e '.backend_ok == true' >/dev/null
    else
        # If backend_ok not present, that's fine for stub mode
        return 0
    fi
}

test_prometheus_scraping() {
    # Test that Prometheus can scrape Hailo metrics
    curl -fsS "$PROMETHEUS_URL/api/v1/query?query=up{job=\"hailo-inference\"}" | \
        jq -e '.data.result[0].value[1] == "1"' >/dev/null 2>&1
}

test_docker_compose_config() {
    # Validate docker compose configuration
    docker compose -f docker-compose.yml -f docker-compose.hailo.yml config >/dev/null 2>&1
}

# Main test execution
main() {
    log_info "🚀 Starting Hailo Sidecar Integration Smoke Tests"
    echo
    
    # Docker configuration test
    run_test "Docker Compose Config Validation" "test_docker_compose_config"
    
    # Wait for services to be ready
    log_info "⏳ Waiting for services to be ready..."
    sleep 5
    
    # Core Hailo sidecar tests
    log_info "🔍 Testing Hailo Sidecar..."
    run_test "Hailo Health Check" "test_hailo_health"
    run_test "Hailo Inference Contract (100x9 → 64+12)" "test_hailo_contract"
    run_test "Hailo Prometheus Metrics" "test_hailo_metrics"
    
    # EdgeInfer integration tests
    log_info "🔍 Testing EdgeInfer Integration..."
    run_test "EdgeInfer Health Check" "test_edge_infer_health"
    run_test "EdgeInfer → Hailo Backend Integration" "test_edge_infer_backend_integration" || true  # Optional
    
    # Monitoring integration tests
    log_info "🔍 Testing Monitoring Integration..."
    run_test "Prometheus Hailo Metrics Scraping" "test_prometheus_scraping" || true  # Optional if monitoring not running
    
    # Summary
    echo
    log_info "📊 Test Summary:"
    echo -e "   Total Tests: ${TESTS_TOTAL}"
    echo -e "   ${GREEN}Passed: ${TESTS_PASSED}${NC}"
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "   ${RED}Failed: ${TESTS_FAILED}${NC}"
    fi
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "🎉 All critical tests passed! Hailo integration is working."
        exit 0
    else
        log_error "💥 Some tests failed. Check the output above for details."
        exit 1
    fi
}

# Help message
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Hailo Sidecar Integration Smoke Test"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Environment Variables:"
    echo "  PISRV_URL         URL for PiSrv API (default: http://localhost:8082)"
    echo "  HAILO_URL         URL for Hailo sidecar (default: http://localhost:9000)"  
    echo "  EDGE_INFER_URL    URL for EdgeInfer (default: http://localhost:8080)"
    echo "  PROMETHEUS_URL    URL for Prometheus (default: http://localhost:9090)"
    echo
    echo "Examples:"
    echo "  # Test local development setup"
    echo "  ./scripts/smoke_test_hailo.sh"
    echo
    echo "  # Test with custom URLs"  
    echo "  HAILO_URL=http://pi:9000 ./scripts/smoke_test_hailo.sh"
    exit 0
fi

# Check dependencies
if ! command -v curl >/dev/null 2>&1; then
    log_error "curl is required but not installed"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required but not installed"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    log_error "python3 is required but not installed"
    exit 1
fi

# Run the tests
main "$@"
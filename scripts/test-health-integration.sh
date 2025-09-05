#!/bin/bash
set -e

echo "🧪 T2.1b Health Integration Test Suite"
echo "=====================================⠀"

# Configuration
BASE_URL="http://localhost:8080"
HAILO_URL="http://localhost:9000"
TEST_TIMEOUT=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

test_passed() {
    ((TESTS_PASSED++))
    log_info "✅ $1"
}

test_failed() {
    ((TESTS_FAILED++))
    log_error "❌ $1"
}

wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1

    log_info "Waiting for $service_name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$url" >/dev/null 2>&1; then
            log_info "$service_name is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    log_error "$service_name failed to start within $((max_attempts * 2)) seconds"
    return 1
}

# Test 1: Basic Health Check
test_basic_health() {
    echo
    log_info "Test 1: Basic EdgeInfer health check"
    
    if response=$(curl -s "$BASE_URL/healthz"); then
        if [[ "$response" == "OK" ]] || [[ "$response" == "DEGRADED" ]]; then
            test_passed "Basic health check returns valid response: $response"
        else
            test_failed "Basic health check returned unexpected response: $response"
        fi
    else
        test_failed "Basic health check request failed"
    fi
}

# Test 2: Detailed Health Check
test_detailed_health() {
    echo
    log_info "Test 2: Detailed health check"
    
    if response=$(curl -s -H "Accept: application/json" "$BASE_URL/health/detailed"); then
        if echo "$response" | jq -e '.status' >/dev/null 2>&1; then
            status=$(echo "$response" | jq -r '.status')
            uptime=$(echo "$response" | jq -r '.uptime')
            checks=$(echo "$response" | jq -r '.checks | keys | length')
            
            test_passed "Detailed health check returns JSON with status: $status, uptime: ${uptime}s, $checks checks"
            
            # Display health check details
            echo "$response" | jq '.'
        else
            test_failed "Detailed health check didn't return valid JSON"
        fi
    else
        test_failed "Detailed health check request failed"
    fi
}

# Test 3: Cross-Service Communication Test
test_cross_service_communication() {
    echo
    log_info "Test 3: Cross-service communication (if Hailo available)"
    
    # Check if USE_REAL_MODEL is enabled
    if response=$(curl -s -H "Accept: application/json" "$BASE_URL/health/detailed"); then
        hailo_status=$(echo "$response" | jq -r '.checks.hailo_backend.status')
        inference_status=$(echo "$response" | jq -r '.checks.inference_capability.status')
        
        if [[ "$hailo_status" == "healthy" ]]; then
            test_passed "Hailo backend connectivity: $hailo_status"
            
            if [[ "$inference_status" == "healthy" ]] || [[ "$inference_status" == "stub" ]]; then
                test_passed "Inference capability: $inference_status"
            else
                test_failed "Inference capability unhealthy: $inference_status"
            fi
        else
            log_warn "Hailo backend not available: $hailo_status (this is expected in stub mode)"
        fi
    else
        test_failed "Could not retrieve cross-service status"
    fi
}

# Test 4: Cascade Failure Simulation
test_cascade_failure() {
    echo
    log_info "Test 4: Cascade failure handling"
    
    # Test inference endpoint with potential backend failure
    test_data='{
        "samples": [
            {"ax": 0.1, "ay": 0.2, "az": 0.3, "gx": 0.1, "gy": 0.2, "gz": 0.3, "mx": 0.1, "my": 0.2, "mz": 0.3}
        ]
    }'
    
    if response=$(curl -s -X POST -H "Content-Type: application/json" -d "$test_data" "$BASE_URL/api/v1/analysis/process" 2>/dev/null); then
        if echo "$response" | jq -e '.latent' >/dev/null 2>&1; then
            latent_size=$(echo "$response" | jq '.latent | length')
            motif_size=$(echo "$response" | jq '.motif_scores | length')
            
            if [[ "$latent_size" == "64" ]] && [[ "$motif_size" == "12" ]]; then
                test_passed "Cascade failure handling: inference returns correct format (64 latent, 12 motifs)"
            else
                test_failed "Cascade failure handling: incorrect response format (latent: $latent_size, motifs: $motif_size)"
            fi
        else
            test_failed "Cascade failure handling: inference response missing expected fields"
        fi
    else
        test_failed "Cascade failure handling: inference endpoint not responding"
    fi
}

# Test 5: Health Check HTTP Status Codes
test_health_status_codes() {
    echo
    log_info "Test 5: Health check HTTP status codes"
    
    # Test HEAD request (for container health checks)
    if head_status=$(curl -s -o /dev/null -w "%{http_code}" --head "$BASE_URL/healthz"); then
        if [[ "$head_status" == "200" ]] || [[ "$head_status" == "503" ]]; then
            test_passed "HEAD health check returns appropriate status: $head_status"
        else
            test_failed "HEAD health check returned unexpected status: $head_status"
        fi
    else
        test_failed "HEAD health check request failed"
    fi
    
    # Test GET request status
    if get_status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/healthz"); then
        if [[ "$get_status" == "200" ]] || [[ "$get_status" == "503" ]]; then
            test_passed "GET health check returns appropriate status: $get_status"
        else
            test_failed "GET health check returned unexpected status: $get_status"
        fi
    else
        test_failed "GET health check request failed"
    fi
}

# Main execution
main() {
    echo "Starting health integration tests..."
    echo "Configuration:"
    echo "  - EdgeInfer URL: $BASE_URL"
    echo "  - Hailo URL: $HAILO_URL"
    echo "  - Timeout: ${TEST_TIMEOUT}s"
    echo
    
    # Wait for services to be ready
    if ! wait_for_service "$BASE_URL/healthz" "EdgeInfer"; then
        log_error "EdgeInfer service not available, aborting tests"
        exit 1
    fi
    
    # Run tests
    test_basic_health
    test_detailed_health
    test_cross_service_communication
    test_cascade_failure
    test_health_status_codes
    
    # Results
    echo
    echo "=====================================⠀"
    echo "Test Results:"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    echo "  Total:  $((TESTS_PASSED + TESTS_FAILED))"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_info "🎉 All tests passed!"
        exit 0
    else
        log_error "❌ Some tests failed"
        exit 1
    fi
}

# Check if jq is available
if ! command -v jq &> /dev/null; then
    log_error "jq is required for this test suite. Please install jq first."
    exit 1
fi

# Run main function
main "$@"
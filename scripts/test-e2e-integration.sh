#!/bin/bash
set -e

echo "🔄 T2.1c End-to-End Integration Test Suite"
echo "=========================================="

# Configuration
BASE_URL="http://localhost:8080"
API_BASE="$BASE_URL/api/v1/analysis"
TEST_TIMEOUT=30
LOAD_TEST_DURATION=60
CONCURRENT_USERS=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
E2E_TESTS_RUN=0
PERFORMANCE_TESTS_RUN=0

# Performance tracking
declare -a RESPONSE_TIMES=()
declare -a E2E_LATENCIES=()

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

log_perf() {
    echo -e "${BLUE}[PERF]${NC} $1"
}

test_passed() {
    ((TESTS_PASSED++))
    log_info "✅ $1"
}

test_failed() {
    ((TESTS_FAILED++))
    log_error "❌ $1"
}

# Performance measurement
measure_time() {
    local start_time=$(date +%s.%N)
    "$@"
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    echo "${duration}000" | cut -d. -f1  # Convert to milliseconds
}

# Generate realistic IMU data
generate_imu_samples() {
    local count=${1:-100}
    local session_id=$2
    local start_time=$(date +%s.%6N)
    
    cat <<EOF
{
  "sessionId": "$session_id",
  "samples": [
EOF
    
    for i in $(seq 0 $((count-1))); do
        local t=$(echo "$start_time + $i * 0.01" | bc -l)  # 100Hz sampling
        local ax=$(echo "scale=4; s($i * 0.1) * 2.0" | bc -l)
        local ay=$(echo "scale=4; c($i * 0.1) * 1.5" | bc -l)  
        local az=$(echo "scale=4; 9.81 + s($i * 0.05) * 0.5" | bc -l)
        local gx=$(echo "scale=4; s($i * 0.2) * 0.3" | bc -l)
        local gy=$(echo "scale=4; c($i * 0.15) * 0.2" | bc -l)
        local gz=$(echo "scale=4; s($i * 0.12) * 0.1" | bc -l)
        local mx=$(echo "scale=4; 25.0 + s($i * 0.08) * 5.0" | bc -l)
        local my=$(echo "scale=4; -15.0 + c($i * 0.06) * 3.0" | bc -l)
        local mz=$(echo "scale=4; 45.0 + s($i * 0.04) * 2.0" | bc -l)
        
        cat <<EOF
    {
      "t": $t,
      "ax": $ax, "ay": $ay, "az": $az,
      "gx": $gx, "gy": $gy, "gz": $gz,
      "mx": $mx, "my": $my, "mz": $mz
    }$([ $i -lt $((count-1)) ] && echo "," || echo "")
EOF
    done
    
    local end_time=$(echo "$start_time + $count * 0.01" | bc -l)
    cat <<EOF
  ],
  "windowStart": $start_time,
  "windowEnd": $end_time
}
EOF
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

# Test 1: Complete Session Lifecycle
test_complete_session_lifecycle() {
    echo
    log_info "Test 1: Complete session lifecycle (iOS → EdgeInfer → Hailo → Response)"
    ((E2E_TESTS_RUN++))
    
    local start_time=$(date +%s.%N)
    
    # Step 1: Start analysis session
    log_info "  Step 1: Starting analysis session..."
    local start_response=$(curl -s -X POST "$API_BASE/start")
    
    if ! echo "$start_response" | jq -e '.sessionId' >/dev/null 2>&1; then
        test_failed "Session start failed - invalid response: $start_response"
        return 1
    fi
    
    local session_id=$(echo "$start_response" | jq -r '.sessionId')
    local status=$(echo "$start_response" | jq -r '.status')
    
    if [[ "$status" == "started" ]]; then
        test_passed "Session started successfully: $session_id"
    else
        test_failed "Session start returned wrong status: $status"
        return 1
    fi
    
    # Step 2: Stream IMU data
    log_info "  Step 2: Streaming IMU data (simulating iOS app)..."
    local imu_data=$(generate_imu_samples 100 "$session_id")
    
    local stream_response_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X PUT -H "Content-Type: application/json" \
        -d "$imu_data" "$API_BASE/stream")
    
    if [[ "$stream_response_code" == "202" ]]; then
        test_passed "IMU data streamed successfully (100 samples)"
    else
        test_failed "IMU streaming failed with status: $stream_response_code"
        return 1
    fi
    
    # Step 3: Get motifs analysis
    log_info "  Step 3: Requesting motifs analysis (triggers EdgeInfer → Hailo)..."
    local motifs_response=$(curl -s "$API_BASE/motifs?sessionId=$session_id")
    
    if ! echo "$motifs_response" | jq -e '.motifs' >/dev/null 2>&1; then
        test_failed "Motifs analysis failed - invalid response: $motifs_response"
        return 1
    fi
    
    local motif_count=$(echo "$motifs_response" | jq '.motifs | length')
    local top_motif_score=$(echo "$motifs_response" | jq '.motifs[0].score')
    
    if [[ "$motif_count" -ge "12" ]] && [[ $(echo "$top_motif_score > 0" | bc) == "1" ]]; then
        test_passed "Motifs analysis successful: $motif_count motifs, top score: $top_motif_score"
    else
        test_failed "Motifs analysis invalid: count=$motif_count, score=$top_motif_score"
        return 1
    fi
    
    # Step 4: Get synchrony analysis  
    log_info "  Step 4: Requesting synchrony analysis (triggers EdgeInfer → Hailo)..."
    local synchrony_response=$(curl -s "$API_BASE/synchrony?sessionId=$session_id")
    
    if ! echo "$synchrony_response" | jq -e '.r' >/dev/null 2>&1; then
        test_failed "Synchrony analysis failed - invalid response: $synchrony_response"
        return 1
    fi
    
    local correlation=$(echo "$synchrony_response" | jq '.r')
    local lag_ms=$(echo "$synchrony_response" | jq '.lag_ms')
    local confidence=$(echo "$synchrony_response" | jq '.confidence')
    
    if [[ $(echo "$correlation >= -1 && $correlation <= 1" | bc) == "1" ]] && [[ "$lag_ms" -ge "0" ]]; then
        test_passed "Synchrony analysis successful: r=$correlation, lag=${lag_ms}ms, confidence=$confidence"
    else
        test_failed "Synchrony analysis invalid: r=$correlation, lag=$lag_ms"
        return 1
    fi
    
    # Step 5: Stop session
    log_info "  Step 5: Stopping session..."
    local stop_data="{\"sessionId\": \"$session_id\"}"
    local stop_response=$(curl -s -X POST -H "Content-Type: application/json" \
        -d "$stop_data" "$API_BASE/stop")
    
    if ! echo "$stop_response" | jq -e '.duration_s' >/dev/null 2>&1; then
        test_failed "Session stop failed - invalid response: $stop_response"
        return 1
    fi
    
    local duration=$(echo "$stop_response" | jq '.duration_s')
    local total_samples=$(echo "$stop_response" | jq '.totalSamples')
    
    test_passed "Session stopped successfully: duration=${duration}s, samples=$total_samples"
    
    # Calculate end-to-end latency
    local end_time=$(date +%s.%N)
    local total_time=$(echo "($end_time - $start_time) * 1000" | bc -l | cut -d. -f1)
    E2E_LATENCIES+=($total_time)
    
    log_perf "Complete session lifecycle: ${total_time}ms"
    test_passed "End-to-end session lifecycle completed in ${total_time}ms"
}

# Test 2: Performance Under Load
test_performance_under_load() {
    echo
    log_info "Test 2: Performance testing under load"
    ((PERFORMANCE_TESTS_RUN++))
    
    log_info "  Running $CONCURRENT_USERS concurrent sessions for ${LOAD_TEST_DURATION}s..."
    
    # Create temporary directory for load test results
    local temp_dir=$(mktemp -d)
    local pids=()
    
    # Start concurrent load test workers
    for i in $(seq 1 $CONCURRENT_USERS); do
        (
            local worker_results="$temp_dir/worker_$i.json"
            local session_count=0
            local success_count=0
            local error_count=0
            local start_time=$(date +%s)
            
            while [[ $(($(date +%s) - start_time)) -lt $LOAD_TEST_DURATION ]]; do
                ((session_count++))
                
                # Quick session test
                local session_response=$(curl -s -X POST "$API_BASE/start")
                if echo "$session_response" | jq -e '.sessionId' >/dev/null 2>&1; then
                    local session_id=$(echo "$session_response" | jq -r '.sessionId')
                    
                    # Quick motifs request  
                    local motifs_start=$(date +%s.%N)
                    local motifs_response=$(curl -s "$API_BASE/motifs?sessionId=$session_id")
                    local motifs_end=$(date +%s.%N)
                    local motifs_time=$(echo "($motifs_end - $motifs_start) * 1000" | bc -l | cut -d. -f1)
                    
                    if echo "$motifs_response" | jq -e '.motifs' >/dev/null 2>&1; then
                        ((success_count++))
                        echo "$motifs_time" >> "$temp_dir/response_times_$i.txt"
                    else
                        ((error_count++))
                    fi
                    
                    # Stop session
                    curl -s -X POST -H "Content-Type: application/json" \
                        -d "{\"sessionId\": \"$session_id\"}" "$API_BASE/stop" >/dev/null
                else
                    ((error_count++))
                fi
                
                sleep 0.1  # Brief pause between requests
            done
            
            # Write worker results
            cat > "$worker_results" <<EOF
{
  "worker_id": $i,
  "sessions": $session_count,
  "successes": $success_count,
  "errors": $error_count,
  "success_rate": $(echo "scale=4; $success_count / $session_count * 100" | bc -l)
}
EOF
        ) &
        pids+=($!)
    done
    
    # Wait for all workers to complete
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    # Collect and analyze results
    local total_sessions=0
    local total_successes=0
    local total_errors=0
    local all_response_times=()
    
    for i in $(seq 1 $CONCURRENT_USERS); do
        if [[ -f "$temp_dir/worker_$i.json" ]]; then
            local worker_sessions=$(jq '.sessions' "$temp_dir/worker_$i.json")
            local worker_successes=$(jq '.successes' "$temp_dir/worker_$i.json")
            local worker_errors=$(jq '.errors' "$temp_dir/worker_$i.json")
            
            total_sessions=$((total_sessions + worker_sessions))
            total_successes=$((total_successes + worker_successes))
            total_errors=$((total_errors + worker_errors))
        fi
        
        if [[ -f "$temp_dir/response_times_$i.txt" ]]; then
            while IFS= read -r time; do
                all_response_times+=("$time")
            done < "$temp_dir/response_times_$i.txt"
        fi
    done
    
    # Calculate performance metrics
    local success_rate=$(echo "scale=2; $total_successes * 100 / $total_sessions" | bc -l)
    local throughput=$(echo "scale=2; $total_successes / $LOAD_TEST_DURATION" | bc -l)
    
    # Calculate response time percentiles
    local sorted_times=($(printf '%s\n' "${all_response_times[@]}" | sort -n))
    local count=${#sorted_times[@]}
    
    if [[ $count -gt 0 ]]; then
        local p50_idx=$((count * 50 / 100))
        local p95_idx=$((count * 95 / 100))
        local p99_idx=$((count * 99 / 100))
        
        local p50=${sorted_times[$p50_idx]:-0}
        local p95=${sorted_times[$p95_idx]:-0}
        local p99=${sorted_times[$p99_idx]:-0}
        
        log_perf "Load test results:"
        log_perf "  Sessions: $total_sessions (success: $total_successes, errors: $total_errors)"
        log_perf "  Success rate: ${success_rate}%"
        log_perf "  Throughput: ${throughput} req/sec"
        log_perf "  Response times - P50: ${p50}ms, P95: ${p95}ms, P99: ${p99}ms"
        
        # Validate performance targets
        if [[ $(echo "$success_rate >= 95" | bc) == "1" ]] && \
           [[ $(echo "$p95 <= 200" | bc) == "1" ]]; then
            test_passed "Performance under load: ${success_rate}% success rate, P95: ${p95}ms"
        else
            test_failed "Performance targets not met: ${success_rate}% success rate, P95: ${p95}ms"
        fi
    else
        test_failed "No valid response times collected during load test"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Test 3: Error Scenarios and Recovery
test_error_scenarios() {
    echo
    log_info "Test 3: Error scenarios and recovery testing"
    
    # Test 3a: Invalid session ID
    log_info "  Test 3a: Invalid session ID handling..."
    local invalid_response=$(curl -s "$API_BASE/motifs?sessionId=invalid-session-id-123")
    local invalid_status=$(curl -s -o /dev/null -w "%{http_code}" "$API_BASE/motifs?sessionId=invalid-session-id-123")
    
    if [[ "$invalid_status" == "404" ]]; then
        test_passed "Invalid session ID properly returns 404"
    else
        test_failed "Invalid session ID returned status: $invalid_status"
    fi
    
    # Test 3b: Malformed request data
    log_info "  Test 3b: Malformed request data handling..."
    local malformed_status=$(curl -s -o /dev/null -w "%{http_code}" \
        -X PUT -H "Content-Type: application/json" \
        -d '{"invalid": "json structure"}' "$API_BASE/stream")
    
    if [[ "$malformed_status" == "400" ]] || [[ "$malformed_status" == "422" ]]; then
        test_passed "Malformed request properly handled with status: $malformed_status"
    else
        test_failed "Malformed request returned unexpected status: $malformed_status"
    fi
    
    # Test 3c: Backend failure graceful degradation
    log_info "  Test 3c: Backend failure graceful degradation..."
    local session_response=$(curl -s -X POST "$API_BASE/start")
    local session_id=$(echo "$session_response" | jq -r '.sessionId')
    
    # Request analysis (may fall back to stub mode if backend unavailable)
    local degraded_response=$(curl -s "$API_BASE/motifs?sessionId=$session_id")
    
    if echo "$degraded_response" | jq -e '.motifs' >/dev/null 2>&1; then
        local motif_count=$(echo "$degraded_response" | jq '.motifs | length')
        test_passed "Graceful degradation: service continues with $motif_count motifs"
    else
        test_failed "Service failed to provide graceful degradation"
    fi
    
    # Cleanup session
    curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"sessionId\": \"$session_id\"}" "$API_BASE/stop" >/dev/null
}

# Test 4: CI/CD Integration Smoke Tests  
test_smoke_tests() {
    echo
    log_info "Test 4: CI/CD integration smoke tests"
    
    # Smoke test 1: Service availability
    local health_status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/healthz")
    if [[ "$health_status" == "200" ]]; then
        test_passed "Smoke test: Service health check passes"
    else
        test_failed "Smoke test: Service health check failed with status: $health_status"
    fi
    
    # Smoke test 2: API endpoints responding
    local start_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_BASE/start")
    if [[ "$start_status" == "200" ]]; then
        test_passed "Smoke test: Analysis start endpoint responsive"
    else
        test_failed "Smoke test: Analysis start endpoint failed with status: $start_status"
    fi
    
    # Smoke test 3: Quick end-to-end validation
    local session_response=$(curl -s -X POST "$API_BASE/start")
    if echo "$session_response" | jq -e '.sessionId' >/dev/null 2>&1; then
        local session_id=$(echo "$session_response" | jq -r '.sessionId')
        local motifs_response=$(curl -s "$API_BASE/motifs?sessionId=$session_id")
        
        if echo "$motifs_response" | jq -e '.motifs[0]' >/dev/null 2>&1; then
            test_passed "Smoke test: End-to-end pipeline functional"
            
            # Cleanup
            curl -s -X POST -H "Content-Type: application/json" \
                -d "{\"sessionId\": \"$session_id\"}" "$API_BASE/stop" >/dev/null
        else
            test_failed "Smoke test: End-to-end pipeline not functional"
        fi
    else
        test_failed "Smoke test: Session creation failed"
    fi
}

# Performance summary
print_performance_summary() {
    echo
    log_perf "Performance Summary:"
    
    if [[ ${#E2E_LATENCIES[@]} -gt 0 ]]; then
        local total_latency=0
        for latency in "${E2E_LATENCIES[@]}"; do
            total_latency=$((total_latency + latency))
        done
        local avg_latency=$((total_latency / ${#E2E_LATENCIES[@]}))
        log_perf "  Average E2E latency: ${avg_latency}ms"
    fi
    
    log_perf "  End-to-end tests run: $E2E_TESTS_RUN"
    log_perf "  Performance tests run: $PERFORMANCE_TESTS_RUN"
}

# Main execution
main() {
    echo "Starting end-to-end integration tests..."
    echo "Configuration:"
    echo "  - API Base: $API_BASE"
    echo "  - Load test duration: ${LOAD_TEST_DURATION}s"
    echo "  - Concurrent users: $CONCURRENT_USERS"
    echo
    
    # Check dependencies
    for cmd in jq bc; do
        if ! command -v $cmd &> /dev/null; then
            log_error "$cmd is required for this test suite. Please install $cmd first."
            exit 1
        fi
    done
    
    # Wait for service to be ready
    if ! wait_for_service "$BASE_URL/healthz" "EdgeInfer API"; then
        log_error "Service not available, aborting tests"
        exit 1
    fi
    
    # Run test suites
    test_complete_session_lifecycle
    test_performance_under_load
    test_error_scenarios
    test_smoke_tests
    
    # Performance summary
    print_performance_summary
    
    # Results
    echo
    echo "=========================================="
    echo "End-to-End Test Results:"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    echo "  Total:  $((TESTS_PASSED + TESTS_FAILED))"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_info "🎉 All end-to-end tests passed!"
        exit 0
    else
        log_error "❌ Some tests failed"
        exit 1
    fi
}

# Run main function
main "$@"
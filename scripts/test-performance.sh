#!/bin/bash
set -e

echo "⚡ T2.1c Performance Testing Framework"
echo "====================================="

# Configuration
BASE_URL="http://localhost:8080"
API_BASE="$BASE_URL/api/v1/analysis"

# Default test parameters
DURATION=${DURATION:-60}
USERS=${USERS:-10}
RAMP_UP=${RAMP_UP:-10}
TARGET_LATENCY=${TARGET_LATENCY:-100}
TARGET_SUCCESS_RATE=${TARGET_SUCCESS_RATE:-95}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_perf() { echo -e "${BLUE}[PERF]${NC} $1"; }

# Check dependencies
check_dependencies() {
    for cmd in jq bc; do
        if ! command -v $cmd &> /dev/null; then
            log_error "$cmd is required. Please install it first."
            exit 1
        fi
    done
}

# Wait for service
wait_for_service() {
    log_info "Waiting for EdgeInfer service..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$BASE_URL/healthz" >/dev/null 2>&1; then
            log_info "Service is ready!"
            return 0
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    log_error "Service failed to start"
    return 1
}

# Generate test data
generate_imu_data() {
    local session_id=$1
    local sample_count=${2:-100}
    
    cat <<EOF
{
  "sessionId": "$session_id",
  "samples": [$(for i in $(seq 0 $((sample_count-1))); do
    echo "    {"
    echo "      \"t\": $(echo "scale=6; $(date +%s.%6N) + $i * 0.01" | bc),"
    echo "      \"ax\": $(echo "scale=4; s($i * 0.1) * 2.0" | bc -l),"
    echo "      \"ay\": $(echo "scale=4; c($i * 0.1) * 1.5" | bc -l),"
    echo "      \"az\": $(echo "scale=4; 9.81 + s($i * 0.05) * 0.5" | bc -l),"
    echo "      \"gx\": $(echo "scale=4; s($i * 0.2) * 0.3" | bc -l),"
    echo "      \"gy\": $(echo "scale=4; c($i * 0.15) * 0.2" | bc -l),"
    echo "      \"gz\": $(echo "scale=4; s($i * 0.12) * 0.1" | bc -l),"
    echo "      \"mx\": $(echo "scale=4; 25.0 + s($i * 0.08) * 5.0" | bc -l),"
    echo "      \"my\": $(echo "scale=4; -15.0 + c($i * 0.06) * 3.0" | bc -l),"
    echo "      \"mz\": $(echo "scale=4; 45.0 + s($i * 0.04) * 2.0" | bc -l)"
    echo "    }$([ $i -lt $((sample_count-1)) ] && echo "," || echo "")"
  done)],
  "windowStart": $(date +%s.%6N),
  "windowEnd": $(echo "$(date +%s.%6N) + $sample_count * 0.01" | bc)
}
EOF
}

# Performance test runner
run_performance_test() {
    local test_name=$1
    local duration=$2
    local users=$3
    local ramp_up=$4
    
    log_info "Running $test_name (${users} users, ${duration}s duration, ${ramp_up}s ramp-up)..."
    
    local temp_dir=$(mktemp -d)
    local pids=()
    local start_time=$(date +%s)
    
    # Results arrays
    declare -a response_times_start=()
    declare -a response_times_stream=()
    declare -a response_times_motifs=()
    declare -a response_times_synchrony=()
    declare -a response_times_stop=()
    
    # Start workers with ramp-up
    for user_id in $(seq 1 $users); do
        # Stagger user starts for ramp-up
        local delay=$(echo "$user_id * $ramp_up / $users" | bc -l)
        
        (
            sleep $delay
            
            local worker_file="$temp_dir/worker_${user_id}.json"
            local requests=0
            local errors=0
            local start_times=()
            local stream_times=()
            local motifs_times=()
            local synchrony_times=()
            local stop_times=()
            
            # Run requests for the remaining duration
            local worker_start=$(date +%s)
            local worker_end=$((start_time + duration))
            
            while [[ $(date +%s) -lt $worker_end ]]; do
                ((requests++))
                local session_start=$(date +%s.%N)
                
                # 1. Start session
                local start_response=$(curl -s -w "%{time_total}" -X POST "$API_BASE/start" 2>/dev/null)
                local start_time_ms=$(echo "${start_response##*$'\n'} * 1000" | bc -l | cut -d. -f1)
                local start_body=${start_response%$'\n'*}
                
                if echo "$start_body" | jq -e '.sessionId' >/dev/null 2>&1; then
                    start_times+=($start_time_ms)
                    local session_id=$(echo "$start_body" | jq -r '.sessionId')
                    
                    # 2. Stream data
                    local imu_data=$(generate_imu_data "$session_id" 50)  # Smaller for performance
                    local stream_response=$(curl -s -w "%{time_total}" -X PUT \
                        -H "Content-Type: application/json" -d "$imu_data" \
                        "$API_BASE/stream" 2>/dev/null)
                    local stream_time_ms=$(echo "${stream_response##*$'\n'} * 1000" | bc -l | cut -d. -f1)
                    stream_times+=($stream_time_ms)
                    
                    # 3. Get motifs
                    local motifs_response=$(curl -s -w "%{time_total}" \
                        "$API_BASE/motifs?sessionId=$session_id" 2>/dev/null)
                    local motifs_time_ms=$(echo "${motifs_response##*$'\n'} * 1000" | bc -l | cut -d. -f1)
                    local motifs_body=${motifs_response%$'\n'*}
                    
                    if echo "$motifs_body" | jq -e '.motifs' >/dev/null 2>&1; then
                        motifs_times+=($motifs_time_ms)
                    else
                        ((errors++))
                    fi
                    
                    # 4. Get synchrony
                    local synchrony_response=$(curl -s -w "%{time_total}" \
                        "$API_BASE/synchrony?sessionId=$session_id" 2>/dev/null)
                    local synchrony_time_ms=$(echo "${synchrony_response##*$'\n'} * 1000" | bc -l | cut -d. -f1)
                    local synchrony_body=${synchrony_response%$'\n'*}
                    
                    if echo "$synchrony_body" | jq -e '.r' >/dev/null 2>&1; then
                        synchrony_times+=($synchrony_time_ms)
                    else
                        ((errors++))
                    fi
                    
                    # 5. Stop session
                    local stop_data="{\"sessionId\": \"$session_id\"}"
                    local stop_response=$(curl -s -w "%{time_total}" -X POST \
                        -H "Content-Type: application/json" -d "$stop_data" \
                        "$API_BASE/stop" 2>/dev/null)
                    local stop_time_ms=$(echo "${stop_response##*$'\n'} * 1000" | bc -l | cut -d. -f1)
                    stop_times+=($stop_time_ms)
                else
                    ((errors++))
                fi
                
                # Brief pause between iterations
                sleep 0.1
            done
            
            # Write results
            {
                echo "{"
                echo "  \"user_id\": $user_id,"
                echo "  \"requests\": $requests,"
                echo "  \"errors\": $errors,"
                echo "  \"start_times\": [$(IFS=,; echo "${start_times[*]}")],"
                echo "  \"stream_times\": [$(IFS=,; echo "${stream_times[*]}")],"
                echo "  \"motifs_times\": [$(IFS=,; echo "${motifs_times[*]}")],"
                echo "  \"synchrony_times\": [$(IFS=,; echo "${synchrony_times[*]}")],"
                echo "  \"stop_times\": [$(IFS=,; echo "${stop_times[*]}")],⠀"
                echo "  \"success_rate\": $(echo "scale=2; ($requests - $errors) * 100 / $requests" | bc -l)"
                echo "}"
            } > "$worker_file"
        ) &
        pids+=($!)
    done
    
    # Show progress
    local end_time=$((start_time + duration))
    while [[ $(date +%s) -lt $end_time ]]; do
        local remaining=$((end_time - $(date +%s)))
        echo -ne "\r  Progress: $((duration - remaining))/${duration}s"
        sleep 1
    done
    echo
    
    # Wait for all workers
    log_info "Waiting for all workers to complete..."
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    # Analyze results
    analyze_results "$temp_dir" "$test_name"
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Analyze performance results
analyze_results() {
    local temp_dir=$1
    local test_name=$2
    
    log_info "Analyzing results for $test_name..."
    
    local total_requests=0
    local total_errors=0
    local all_start_times=()
    local all_motifs_times=()
    local all_synchrony_times=()
    
    # Collect all worker results
    for worker_file in "$temp_dir"/worker_*.json; do
        if [[ -f "$worker_file" ]]; then
            local requests=$(jq '.requests' "$worker_file")
            local errors=$(jq '.errors' "$worker_file")
            
            total_requests=$((total_requests + requests))
            total_errors=$((total_errors + errors))
            
            # Collect timing arrays
            local start_times=($(jq -r '.start_times[]?' "$worker_file"))
            local motifs_times=($(jq -r '.motifs_times[]?' "$worker_file"))
            local synchrony_times=($(jq -r '.synchrony_times[]?' "$worker_file"))
            
            all_start_times+=("${start_times[@]}")
            all_motifs_times+=("${motifs_times[@]}")
            all_synchrony_times+=("${synchrony_times[@]}")
        fi
    done
    
    # Calculate metrics
    local success_rate=$(echo "scale=2; ($total_requests - $total_errors) * 100 / $total_requests" | bc -l)
    local throughput=$(echo "scale=2; $total_requests / $DURATION" | bc -l)
    
    log_perf "Results for $test_name:"
    log_perf "  Total requests: $total_requests"
    log_perf "  Errors: $total_errors"
    log_perf "  Success rate: ${success_rate}%"
    log_perf "  Throughput: ${throughput} req/sec"
    
    # Calculate percentiles for each operation
    for op in "start" "motifs" "synchrony"; do
        local times_var="all_${op}_times[@]"
        local times=("${!times_var}")
        
        if [[ ${#times[@]} -gt 0 ]]; then
            local sorted=($(printf '%s\n' "${times[@]}" | sort -n))
            local count=${#sorted[@]}
            
            local p50_idx=$((count * 50 / 100))
            local p95_idx=$((count * 95 / 100))
            local p99_idx=$((count * 99 / 100))
            
            local p50=${sorted[$p50_idx]:-0}
            local p95=${sorted[$p95_idx]:-0}
            local p99=${sorted[$p99_idx]:-0}
            
            log_perf "  ${op} - P50: ${p50}ms, P95: ${p95}ms, P99: ${p99}ms"
            
            # Check if motifs/synchrony meet SLA (key inference operations)
            if [[ "$op" == "motifs" || "$op" == "synchrony" ]]; then
                if [[ $(echo "$p95 <= $TARGET_LATENCY" | bc) == "1" ]]; then
                    log_info "✅ $op P95 latency within target: ${p95}ms <= ${TARGET_LATENCY}ms"
                else
                    log_warn "⚠️  $op P95 latency exceeds target: ${p95}ms > ${TARGET_LATENCY}ms"
                fi
            fi
        fi
    done
    
    # Overall assessment
    if [[ $(echo "$success_rate >= $TARGET_SUCCESS_RATE" | bc) == "1" ]]; then
        log_info "✅ Success rate meets target: ${success_rate}% >= ${TARGET_SUCCESS_RATE}%"
    else
        log_error "❌ Success rate below target: ${success_rate}% < ${TARGET_SUCCESS_RATE}%"
    fi
}

# Stress test with increasing load
run_stress_test() {
    log_info "Running stress test with increasing load..."
    
    for users in 5 10 20 30; do
        log_info "Stress testing with $users concurrent users..."
        run_performance_test "Stress-${users}users" 30 $users 5
        echo
        sleep 2  # Brief pause between tests
    done
}

# Main execution
main() {
    echo "Performance Testing Configuration:"
    echo "  Duration: ${DURATION}s"
    echo "  Users: $USERS"
    echo "  Ramp-up: ${RAMP_UP}s"
    echo "  Target latency (P95): ${TARGET_LATENCY}ms"
    echo "  Target success rate: ${TARGET_SUCCESS_RATE}%"
    echo
    
    check_dependencies
    
    if ! wait_for_service; then
        exit 1
    fi
    
    # Run tests based on mode
    case "${1:-normal}" in
        "stress")
            run_stress_test
            ;;
        "quick")
            run_performance_test "Quick-Test" 15 5 2
            ;;
        *)
            run_performance_test "Standard-Test" $DURATION $USERS $RAMP_UP
            ;;
    esac
    
    log_info "Performance testing complete!"
}

# Show usage
if [[ "$1" == "--help" ]]; then
    echo "Usage: $0 [mode] [options]"
    echo "Modes:"
    echo "  normal  - Standard performance test (default)"
    echo "  stress  - Stress test with increasing load"
    echo "  quick   - Quick performance validation"
    echo
    echo "Environment variables:"
    echo "  DURATION=$DURATION"
    echo "  USERS=$USERS"  
    echo "  RAMP_UP=$RAMP_UP"
    echo "  TARGET_LATENCY=$TARGET_LATENCY"
    echo "  TARGET_SUCCESS_RATE=$TARGET_SUCCESS_RATE"
    exit 0
fi

main "$@"
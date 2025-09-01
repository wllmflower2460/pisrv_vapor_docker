#!/bin/bash
# GPUSrv HailoRT TCN Inference Sidecar API Test Script (for PiSrv)
# Usage: ./test_gpusrv_hailo_api.sh [gpusrv_ip]
# Default: http://localhost:9000

set -e

GPUSRV_IP="${1:-localhost}"
BASE_URL="http://${GPUSRV_IP}:9000"
TIMEOUT=10
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLES_DIR="${SCRIPT_DIR}/data/samples"

echo "🚀 Testing GPUSrv HailoRT TCN Inference Sidecar API"
echo "GPUSrv IP: $GPUSRV_IP"
echo "Base URL: $BASE_URL"
echo "========================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_endpoint() {
    local name="$1"
    local method="$2"
    local endpoint="$3"
    local data="$4"
    local expected_status="${5:-200}"
    
    echo -e "\n${BLUE}Testing: $name${NC}"
    echo "Endpoint: $method $endpoint"
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" --max-time $TIMEOUT "$BASE_URL$endpoint" 2>/dev/null || echo -e "\n000")
    else
        response=$(curl -s -w "\n%{http_code}" --max-time $TIMEOUT -X "$method" "$BASE_URL$endpoint" \
                  -H "Content-Type: application/json" -d "$data" 2>/dev/null || echo -e "\n000")
    fi
    
    # Split response and status code
    status_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$status_code" = "$expected_status" ]; then
        echo -e "${GREEN}✅ SUCCESS${NC} (HTTP $status_code)"
        if [ "$endpoint" = "/healthz" ] && [ -n "$body" ]; then
            echo "Health Status: $(echo "$body" | jq -r '.ok // "unknown"' 2>/dev/null || echo "parsing error")"
            echo "Model: $(echo "$body" | jq -r '.model // "unknown"' 2>/dev/null || echo "parsing error")"
            echo "Uptime: $(echo "$body" | jq -r '.uptime_s // "unknown"' 2>/dev/null || echo "parsing error")s"
        elif [ "$endpoint" = "/infer" ] && [ -n "$body" ]; then
            latent_count=$(echo "$body" | jq '.latent | length' 2>/dev/null || echo "unknown")
            motif_count=$(echo "$body" | jq '.motif_scores | length' 2>/dev/null || echo "unknown")
            echo "Latent dimensions: $latent_count"
            echo "Motif scores: $motif_count"
        fi
    else
        echo -e "${RED}❌ FAILED${NC} (HTTP $status_code)"
        if [ "$status_code" = "000" ]; then
            echo "Connection failed or timeout - GPUSrv may not be reachable at $GPUSRV_IP:9000"
        elif [ -n "$body" ]; then
            echo "Response: $body"
        fi
        return 1
    fi
}

# Check if samples directory exists
if [ ! -d "$SAMPLES_DIR" ]; then
    echo -e "${RED}❌ Samples directory not found: $SAMPLES_DIR${NC}"
    echo "Please ensure the test samples are present in tests/data/samples/"
    exit 1
fi

# Test basic connectivity
test_endpoint "Service Discovery" "GET" "/"

# Test health endpoint
test_endpoint "Health Check" "GET" "/healthz"

# Test status endpoint
test_endpoint "Status Check" "GET" "/status"

# Test documentation
test_endpoint "API Documentation" "GET" "/docs"

# Test OpenAPI spec
test_endpoint "OpenAPI Specification" "GET" "/openapi.json"

# Test metrics
test_endpoint "Prometheus Metrics" "GET" "/metrics"

# Test simple test endpoint
test_endpoint "Simple Test Endpoint" "POST" "/test"

# Test inference with each sample file
echo -e "\n${BLUE}Testing Inference with Sample Data${NC}"

if [ -f "$SAMPLES_DIR/realistic_imu_sample.json" ]; then
    echo -e "\n${BLUE}Testing with realistic IMU data${NC}"
    realistic_data=$(cat "$SAMPLES_DIR/realistic_imu_sample.json")
    test_endpoint "Realistic IMU Inference" "POST" "/infer" "$realistic_data"
else
    echo -e "${RED}❌ realistic_imu_sample.json not found in $SAMPLES_DIR${NC}"
fi

if [ -f "$SAMPLES_DIR/static_imu_sample.json" ]; then
    echo -e "\n${BLUE}Testing with static pattern IMU data${NC}"
    static_data=$(cat "$SAMPLES_DIR/static_imu_sample.json")
    test_endpoint "Static Pattern Inference" "POST" "/infer" "$static_data"
else
    echo -e "${RED}❌ static_imu_sample.json not found in $SAMPLES_DIR${NC}"
fi

if [ -f "$SAMPLES_DIR/random_imu_sample.json" ]; then
    echo -e "\n${BLUE}Testing with random IMU data${NC}"
    random_data=$(cat "$SAMPLES_DIR/random_imu_sample.json")
    test_endpoint "Random IMU Inference" "POST" "/infer" "$random_data"
else
    echo -e "${RED}❌ random_imu_sample.json not found in $SAMPLES_DIR${NC}"
fi

# Load test
echo -e "\n${BLUE}Running Mini Load Test (5 requests)${NC}"
start_time=$(date +%s.%N)
success_count=0

for i in {1..5}; do
    if [ -f "$SAMPLES_DIR/realistic_imu_sample.json" ]; then
        realistic_data=$(cat "$SAMPLES_DIR/realistic_imu_sample.json")
        response=$(curl -s -w "%{http_code}" --max-time $TIMEOUT -X POST "$BASE_URL/infer" \
                  -H "Content-Type: application/json" -d "$realistic_data" 2>/dev/null || echo "000")
        status_code=$(echo "$response" | tail -c 4)
        if [ "$status_code" = "200" ]; then
            success_count=$((success_count + 1))
        fi
    fi
done

end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "unknown")
avg_time=$(echo "scale=2; $duration / 5 * 1000" | bc -l 2>/dev/null || echo "unknown")

echo -e "${GREEN}Load Test Results:${NC}"
echo "Successful requests: $success_count/5"
if [ "$avg_time" != "unknown" ]; then
    echo "Average time per request: ${avg_time}ms"
fi

echo -e "\n========================================"
echo -e "${GREEN}🎯 GPUSrv API Testing Complete${NC}"
echo -e "\nTested GPUSrv at: ${YELLOW}$BASE_URL${NC}"
echo -e "\nFor EdgeInfer integration, use:"
echo -e "${BLUE}MODEL_BACKEND_URL=$BASE_URL/infer${NC}"
echo -e "${BLUE}curl -X POST $BASE_URL/infer \\"
echo "  -H \"Content-Type: application/json\" \\"
echo -e "  -d @tests/data/samples/realistic_imu_sample.json${NC}"

# Summary
passed_tests=$(echo "$success_count + 8" | bc 2>/dev/null || echo "8+")  # Approximate
echo -e "\n${GREEN}📊 Test Summary: Most endpoints tested successfully${NC}"
if [ "$success_count" -eq 5 ]; then
    echo -e "${GREEN}🎉 All inference tests passed! GPUSrv is ready for PiSrv integration.${NC}"
else
    echo -e "${YELLOW}⚠️  Some inference tests failed. Check GPUSrv connectivity and model status.${NC}"
fi
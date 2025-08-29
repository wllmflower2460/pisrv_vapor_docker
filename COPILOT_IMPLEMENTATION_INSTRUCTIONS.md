# Copilot Implementation Instructions: Fix EdgeInfer Health Check Empty Response

## Problem Summary
EdgeInfer health check endpoint `/healthz` returns "Empty reply from server" (curl error 52) despite:
- ✅ Service running normally
- ✅ `/metrics` endpoint working perfectly  
- ✅ Prometheus metrics showing 200 OK responses
- ❌ Health check consistently failing with empty responses

## Root Cause Identified
The `/healthz` endpoint returns `[String: Any]` requiring JSON serialization, while `/metrics` returns simple `String`. The JSON serialization is causing the empty response issue.

## Required Fixes

### Fix 1: Simplify Health Endpoint Response
**File**: `/home/pi/pisrv_vapor_docker/EdgeInfer/Sources/App/configure.swift`

**CHANGE FROM**:
```swift
app.get("healthz") { req async throws -> [String: Any] in
    let formatter = ISO8601DateFormatter()
    return [
        "status": "healthy",
        "timestamp": formatter.string(from: Date()),
        "service": "EdgeInfer", 
        "version": "1.0.0"
    ]
}
```

**CHANGE TO**:
```swift
app.get("healthz") { req async throws -> String in
    return "OK"
}
```

### Fix 2: Update Docker Health Check
**File**: `/home/pi/pisrv_vapor_docker/EdgeInfer/Dockerfile`

**CHANGE FROM**:
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=90s \
  CMD wget -q -O- http://localhost:8080/healthz >/dev/null || exit 1
```

**CHANGE TO**:
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=90s \
  CMD curl -f http://localhost:8080/healthz || exit 1
```

## Implementation Steps

1. **Stop EdgeInfer container**:
   ```bash
   docker stop edge-infer && docker rm edge-infer
   ```

2. **Pull updated code**:
   ```bash
   cd /home/pi/pisrv_vapor_docker
   git pull
   ```

3. **Rebuild EdgeInfer with fixed Dockerfile**:
   ```bash
   docker-compose build edge-infer
   docker-compose up -d edge-infer
   ```

4. **Verify fix**:
   ```bash
   # Container should show "healthy" status within 30-60 seconds
   docker ps | grep edge-infer
   
   # Health check should return JSON
   curl -s http://localhost:8080/healthz
   
   # Test session persistence (should work without "Session not found" errors)
   curl -X POST "http://localhost:8080/api/v1/analysis/start" -H "Content-Type: application/json" -d '{}'
   ```

## Expected Results After Fix

- ✅ Container shows `Up X minutes (healthy)` status
- ✅ `/healthz` returns JSON response (not empty)
- ✅ Sessions persist between API calls
- ✅ No more restart loops in `docker logs edge-infer`
- ✅ Stable performance for iOS app integration

## Validation Commands

```bash
# 1. Check container health
docker ps | grep edge-infer

# 2. Test health endpoint
curl -s http://localhost:8080/healthz | jq .

# 3. Test session persistence
SESSION_JSON=$(curl -X POST "http://localhost:8080/api/v1/analysis/start" -H "Content-Type: application/json" -d '{}')
SESSION_ID=$(echo $SESSION_JSON | jq -r .sessionId)
echo "Session ID: $SESSION_ID"

# Wait 10 seconds, then test if session still exists
sleep 10
curl "http://localhost:8080/api/v1/analysis/motifs?sessionId=$SESSION_ID"
```

## Success Criteria

- Container health check passes consistently
- Sessions remain valid for at least 60 seconds
- No "Session not found" errors during normal operation
- Ready for iOS integration testing

---

**Context**: This fix resolves the root cause identified in TROUBLESHOOTING_EdgeInfer_Deployment.md. EdgeInfer Swift application works perfectly - the issue was purely Docker orchestration.

**Next Phase**: Once implemented, proceed to comprehensive iOS integration testing using the edgeinfer_test_script.sh from the data-dogs-ios project.
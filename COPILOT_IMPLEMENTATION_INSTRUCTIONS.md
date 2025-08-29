# Copilot Implementation Instructions: ChatGPT Definitive Health Check Fix

## Problem Summary
EdgeInfer health check endpoint `/healthz` returns "Empty reply from server" (curl error 52) despite:
- ✅ Service running normally
- ✅ `/metrics` endpoint working perfectly  
- ✅ Prometheus metrics showing 200 OK responses
- ❌ Health check consistently failing with empty responses

## Root Cause Identified (ChatGPT Analysis)
**Key Insight**: Prometheus middleware records 200 status **before** response bytes are flushed to client. If there's HTTP framing ambiguity (missing Content-Length, etc.), clients get empty replies while metrics show 200 OK.

**Solution**: Explicit HTTP headers with `Content-Length` and `Connection: close` eliminate framing issues on embedded targets.

## Required Fixes

### Fix 1: Replace Health Endpoint with Explicit Headers
**File**: `/home/pi/pisrv_vapor_docker/EdgeInfer/Sources/App/configure.swift`

**REPLACE THE ENTIRE HEALTHZ SECTION WITH**:
```swift
// Register health check endpoint with explicit headers (fixes empty reply issue)
app.get("healthz") { req -> Response in
    var buf = req.byteBufferAllocator.buffer(capacity: 2)
    buf.writeString("OK")
    var headers = HTTPHeaders()
    headers.add(name: .contentType, value: "text/plain; charset=utf-8")
    headers.add(name: .contentLength, value: String(buf.readableBytes))
    headers.add(name: .connection, value: "close") // ensure immediate flush
    return Response(status: .ok, headers: headers, body: .init(buffer: buf))
}

// HEAD support for health check (wget --spider compatibility)
app.on(.HEAD, "healthz") { req -> Response in
    var headers = HTTPHeaders()
    headers.add(name: .contentLength, value: "0")
    headers.add(name: .connection, value: "close")
    return Response(status: .ok, headers: headers)
}
```

### Fix 2: Update Docker Health Check to Status-Only
**File**: `/home/pi/pisrv_vapor_docker/EdgeInfer/Dockerfile`

**CHANGE FROM**:
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=90s \
  CMD curl -f http://localhost:8080/healthz || exit 1
```

**CHANGE TO**:
```dockerfile
HEALTHCHECK --interval=30s --timeout=8s --retries=3 --start-period=90s \
  CMD curl -fsS -m 6 -o /dev/null http://localhost:8080/healthz || exit 1
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

3. **Rebuild EdgeInfer with ChatGPT fix**:
   ```bash
   docker-compose build edge-infer
   docker-compose up -d edge-infer
   ```

4. **Verify ChatGPT fix worked**:
   ```bash
   # Wait for 90s startup period
   sleep 90
   
   # Container should show "healthy" status (not "starting")
   docker ps | grep edge-infer
   
   # Health check should return "OK" with proper headers
   curl -v http://localhost:8080/healthz
   # Expected: HTTP/1.1 200 OK, Content-Length: 2, Body: "OK"
   
   # HEAD request should work (wget --spider compatibility)
   curl -I http://localhost:8080/healthz
   # Expected: HTTP/1.1 200 OK, Content-Length: 0, no body
   
   # Test session persistence (no more empty replies!)
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
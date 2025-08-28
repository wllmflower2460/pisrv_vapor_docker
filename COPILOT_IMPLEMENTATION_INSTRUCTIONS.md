# Copilot Implementation Instructions: Fix EdgeInfer Health Check

## Problem Summary
EdgeInfer is **fully functional** but Docker health check timeouts (3s) are too aggressive, causing container restart loops that clear sessions and make the API appear unstable.

## Required Fix
**File**: `/home/pi/pisrv_vapor_docker/docker-compose.yml`  
**Section**: `edge-infer` service health check configuration  
**Line**: ~49 (timeout: 3s)

## Exact Changes Needed

Replace the existing health check configuration:
```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -fsS http://localhost:8080/healthz || exit 1"]
  interval: 30s
  timeout: 3s          # ← CHANGE THIS
  retries: 3           # ← CHANGE THIS  
  start_period: 10s    # ← CHANGE THIS
```

With this updated configuration:
```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -fsS http://localhost:8080/healthz || exit 1"]
  interval: 30s
  timeout: 10s         # ← INCREASED from 3s
  retries: 5           # ← INCREASED from 3  
  start_period: 30s    # ← INCREASED from 10s
```

## Implementation Steps

1. **Stop EdgeInfer container**:
   ```bash
   docker stop edge-infer && docker rm edge-infer
   ```

2. **Edit docker-compose.yml**:
   ```bash
   nano /home/pi/pisrv_vapor_docker/docker-compose.yml
   ```

3. **Apply changes**:
   ```bash
   cd /home/pi/pisrv_vapor_docker
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
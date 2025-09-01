# EdgeInfer Rollback Guide

## 🔴 Emergency Kill-Switch

**Immediate rollback to stubs (no restart required):**
```bash
# Set environment variable to disable real model inference
USE_REAL_MODEL=false
```

## Rollback Methods

### Method 1: Environment Variable Toggle (Fastest)
```bash
# In docker-compose.model.yml or your deployment config
USE_REAL_MODEL=false  # Default: safe stub mode

# Redeploy without rebuilding
docker compose -f docker-compose.yml -f docker-compose.model.yml up -d
```

### Method 2: Stop Model Sidecar (Intermediate)
```bash
# Stop just the model runner, API will fallback to stubs
docker compose -f docker-compose.yml -f docker-compose.model.yml stop model-runner

# Or remove model service entirely
docker compose -f docker-compose.yml up -d
```

### Method 3: Revert to Previous Commit (Full Rollback)
```bash
# Identify last stable commit before model integration
git log --oneline -5

# Revert to commit before model changes
git revert <commit-hash>

# Or hard reset (destructive)
git reset --hard <commit-hash>
```

## Rollback Testing
```bash
# Verify stub mode is active
curl -s http://localhost:8080/api/v1/analysis/motifs | jq .

# Should return deterministic stub data, not real inference
# Look for consistent motif patterns across requests
```

## Monitoring During Rollback
- Check `/healthz` endpoint remains responsive
- Verify stub responses have expected structure
- Monitor error logs for model service connection failures (expected in stub mode)

## Recovery Notes
- Stub mode performance should be <5ms vs ~45ms for real inference
- All existing iOS app functionality remains intact
- No data loss - only inference method changes
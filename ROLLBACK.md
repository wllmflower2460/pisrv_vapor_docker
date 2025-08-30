# ROLLBACK

## When to roll back
- Elevated 5xx or p95 > baseline +30% for 15m after deploy
- Sidecar inference errors > 1% or timeout bursts
- iOS client error reports spike

## How to roll back (Docker Compose)
```bash
# Switch web image to last known good
docker compose pull web=edgeinfer:web-swift510
docker compose up -d

# (Optional) flip to stub analysis immediately
export USE_REAL_MODEL=false
docker compose up -d
```

## Verify after rollback
- `GET /healthz` → 200
- `GET /api/v1/analysis/motifs` → stub JSON present
- Prometheus scrape healthy, alerts cleared

## Notes
- Keep both images cached: `edgeinfer:web-swift6` and `edgeinfer:web-swift510`.
- The `USE_REAL_MODEL` flag acts as a quick “canary off” switch even without image change.

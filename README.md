<!-- Badges (populate after first green CI run on main) -->
![CI Swift 5.10](https://img.shields.io/github/actions/workflow/status/wllmflower2460/pisrv_vapor_docker/ci.yml?label=Swift%205.10&branch=main)
![CI Swift 6.0](https://img.shields.io/github/actions/workflow/status/wllmflower2460/pisrv_vapor_docker/ci.yml?label=Swift%206.0&branch=main)

# EdgeInfer Service

Minimal Vapor-based inference edge service with feature‑flagged model sidecar, fast fallback, and multi‑Swift CI.

## Features
- HTTP API for submitting analysis windows (see routes under `/analysis`).
- Feature flags:
  - `USE_REAL_MODEL` (default `false`): toggles calling external model sidecar.
  - `MODEL_BACKEND_URL` (default `http://localhost:9000/infer`): sidecar inference endpoint.
- Graceful fallback: network / non‑200 / decode failures yield deterministic stub motifs.
- Fast fallback path test ensures sub‑100ms error handling on connection refusal.
- Clean codebase: Fluent / Todo scaffold removed.
- Concurrency future‑proofing: CI will run Swift 5.10 and 6.0 with strict concurrency checks.
- Rollback + pre‑PR check docs included.

## Architecture Overview
```
Client --> Vapor API --> (if USE_REAL_MODEL) HTTP -> Sidecar (/infer)
                               | failure
                               v
                          Fallback Stub
```
`ModelInferenceService` handles request encoding / response decoding and error normalization.

## Use with Hailo sidecar (hailo_pipeline)

This service **does not** run models. It calls a model **sidecar** over HTTP.

- Feature flag: `USE_REAL_MODEL` (default `false`)
- Backend URL: `MODEL_BACKEND_URL` (default `http://hailo-inference:9000/infer`)

### Local smoke
Assuming a sidecar is reachable at `http://hailo-inference:9000/infer`:

```bash
# Vapor app (port 8080)
curl -s localhost:8080/healthz | jq .

# App calling the sidecar for motif analysis
curl -s -X POST localhost:8080/api/v1/analysis/motifs \
  -H 'Content-Type: application/json' \
  -d '{"sessionId":"test-session"}' | jq .
```

If `USE_REAL_MODEL=false`, the app returns deterministic stub motifs and remains healthy
even if the sidecar is unavailable (fast fallback).

## Endpoints (core)
- `GET /healthz` – liveness.
- `POST /analysis/motifs` – submit JSON payload with `window` (array of floats); returns motif scores.

## Fallback Logic
Any of: connection error, timeout, non‑2xx HTTP, malformed JSON → fallback scorer returns static deterministic values (stable for tests / monitoring).

## Testing
9 XCTest cases cover:
- Inference success path (mocked sidecar).
- Non‑200 and malformed JSON → fallback.
- DNS / connection refusal fast failure (< ~60ms expected).
- Real path flag toggle.
- Health & smoke.

Run locally:
```bash
swift test --parallel
```

## CI (after PR B)
Matrix: Swift 5.10-jammy & 6.0-jammy.
Flags: `-Xswiftc -strict-concurrency=complete` for build + test.
Both jobs become required checks on `main`.

## Feature Flags
| Flag | Purpose | Default |
|------|---------|---------|
| `USE_REAL_MODEL` | Enable sidecar inference call | false |
| `MODEL_BACKEND_URL` | Sidecar inference endpoint | http://localhost:9000/infer |

## Local Development
Build & run:
```bash
swift build
swift run
```
With real model (assuming sidecar on localhost:9000):
```bash
USE_REAL_MODEL=true swift run
```

Sample request:
```bash
curl -s -X POST localhost:8080/analysis/motifs \
  -H 'Content-Type: application/json' \
  -d '{"window":[0.12,0.34,0.56]}' | jq .
```

## Rollback
See `ROLLBACK.md` for revert & previous tag deployment instructions.

## Metrics
Motifs metrics stub present (NO-OP). Prometheus noisy placeholders removed; future real metrics can attach here.

## Deployment Notes
- Container image built from `Dockerfile` (multi-stage: builder + slim runtime if configured).
- Set `USE_REAL_MODEL=true` only when sidecar health is proven; otherwise rely on fallback.

## Future Work
- Address remaining Swift 6 Sendable/isolation warnings.
- Implement real metrics emission (latency histogram, fallback counter).
- Expose structured tracing headers.

## Contributing
See `CONTRIBUTING.md` and `pre-PR.md` checklist.

## License
Project inherits licensing terms from included source; see repository root for any LICENSE file.

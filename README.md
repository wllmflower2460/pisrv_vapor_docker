<!-- Badges (populate after first green CI run on main) -->
![CI Swift 5.10](https://img.shields.io/github/actions/workflow/status/wllmflower2460/pisrv_vapor_docker/ci.yml?label=Swift%205.10&branch=main)
![CI Swift 6.0](https://img.shields.io/github/actions/workflow/status/wllmflower2460/pisrv_vapor_docker/ci.yml?label=Swift%206.0&branch=main)

# EdgeInfer Service

Minimal Vapor-based inference edge service with feature‑flagged model sidecar, fast fallback, and multi‑Swift CI.

## Development: Submodules

This repo uses git submodules for model and example assets:

- `appdata/models/tcn_vae` (TCN-VAE models)
- `DataDogsServer/h8-examples` (Hailo Raspberry Pi 5 example pipelines)

**First clone (with submodules):**
```bash
git clone --recurse-submodules git@github.com:wllmflower2460/pisrv_vapor_docker.git
```

**Existing clone (initialize submodules):**
```bash
git submodule update --init --recursive
```

CI note: GitHub Actions uses recursive checkout; see `.github/workflows/` for `submodules: recursive` plus gitlinks-only initialization.

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

**Swift Unit Tests:**
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

**GPUSrv Integration Testing:**
Comprehensive test suite for testing GPUSrv HailoRT TCN Inference Sidecar:

```bash
# Test from PiSrv to GPUSrv (replace with actual GPUSrv IP)
./tests/test_gpusrv_hailo_api.sh 192.168.1.100

# Or test locally
./tests/test_gpusrv_hailo_api.sh localhost
```

**Test Data:**
- `tests/data/samples/realistic_imu_sample.json` - Production-like IMU data (validated ranges)
- `tests/data/samples/static_imu_sample.json` - Predictable test pattern
- `tests/data/samples/random_imu_sample.json` - Random test data

All samples are 100×9 IMU format: `[ax, ay, az, gx, gy, gz, mx, my, mz]`

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

## Docker Deployment with Hailo Sidecar

### Quick Start

**GPUSrv (Development/Stub Mode):**
```bash
# Copy and configure environment
cp .env.example .env
# Edit .env: set USE_REAL_MODEL=true

# Start with Hailo sidecar (stub mode)
docker compose -f docker-compose.yml -f docker-compose.hailo.yml --profile hailo-stub up -d

# Test integration
./scripts/smoke_test_hailo.sh
```

**Raspberry Pi 5 + Hailo-8 (Production):**
```bash
# Ensure model artifacts are available
mkdir -p models artifacts
# Copy HEF files from hailo_pipeline repo
cp ../hailo_pipeline/artifacts/*.hef models/

# Start with real Hailo device
docker compose -f docker-compose.yml -f docker-compose.hailo.yml --profile hailo-device up -d

# Verify hardware integration
./scripts/smoke_test_hailo.sh
```

### Architecture (with Hailo)
```
Client --> EdgeInfer (Vapor) --> (if USE_REAL_MODEL=true) --> Hailo Sidecar (/infer)
                                      | failure/timeout              |
                                      v                              v
                                 Fallback Stub                   HailoRT + TCN-VAE
                                                                     |
                                                                 Hailo-8 Device
                                                                (Pi only)
```

### Service Configuration

The stack includes these services:
- **edge-infer**: Vapor app (port 8080 → 8082 external)
- **api**: Vapor API service 
- **hailo-inference**: TCN-VAE inference sidecar (internal port 9000)
- **prometheus**: Metrics collection (port 9090)
- **grafana**: Monitoring dashboard (port 3000)

### Environment Variables

Key configuration (see `.env.example` for complete list):

```bash
# Core Integration
USE_REAL_MODEL=true                                    # Enable Hailo sidecar
MODEL_BACKEND_URL=http://hailo-inference:9000/infer   # Sidecar endpoint
BACKEND_TIMEOUT_MS=250                                # Request timeout
BACKEND_RETRIES=0                                     # Retry attempts

# Hailo Sidecar
HEF_PATH=/models/tcn_encoder_v1.0.0.hef              # Model file path
NUM_MOTIFS=12                                         # Output classes
MODELS_PATH=./models                                  # Model directory
```

### Health Checks & Monitoring

**Service Health:**
```bash
# EdgeInfer health (includes backend status)
curl -s http://localhost:8080/healthz | jq .

# Hailo sidecar health (with enhanced fields)
curl -s http://localhost:9000/healthz | jq .
# Returns: ok, model, uptime_s, config_version, hef_sha256

# Prometheus metrics
curl -s http://localhost:9000/metrics | grep hailo_
```

**Monitoring Stack:**
- **Prometheus**: Scrapes both EdgeInfer and Hailo metrics
- **Grafana**: Dashboards for latency, throughput, error rates
- **Enhanced Metrics**: `hailo_build_info`, `hailo_config_ok` for fleet management

### Troubleshooting

**Common Issues:**

1. **Hailo device not found (Pi only):**
   ```bash
   # Check device
   ls -la /dev/hailo0
   
   # Verify HailoRT
   hailo scan
   ```

2. **Model file not found:**
   ```bash
   # Check model artifacts
   ls -la models/ artifacts/
   
   # Verify HEF file integrity
   sha256sum models/tcn_encoder_v1.0.0.hef
   ```

3. **Service startup issues:**
   ```bash
   # Check service logs
   docker compose logs hailo-inference
   docker compose logs edge-infer
   
   # Validate compose config
   docker compose -f docker-compose.yml -f docker-compose.hailo.yml config
   ```

**Debug Commands:**
```bash
# Test GPUSrv Hailo sidecar comprehensively (new!)
./tests/test_gpusrv_hailo_api.sh [gpusrv-ip]

# Test specific samples manually
curl -X POST http://localhost:9000/infer \
  -H "Content-Type: application/json" \
  -d @tests/data/samples/realistic_imu_sample.json

# Check Prometheus scraping
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.job == "hailo-inference")'

# Run existing smoke tests
./scripts/smoke_test_hailo.sh --help
```

### Performance Expectations

**Targets (Pi 5 + Hailo-8):**
- **Inference Latency**: <50ms p95 per window
- **Throughput**: >20 windows/sec sustained
- **Memory Usage**: <512MB for sidecar
- **Success Rate**: >99% uptime

**Development (GPUSrv stub):**
- **Latency**: <100ms (CPU simulation)
- **Contract Compliance**: 100% (shape validation)
- **Monitoring**: Full Prometheus integration

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

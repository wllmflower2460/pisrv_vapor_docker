# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EdgeInfer Service - A Vapor-based inference edge service with feature-flagged model sidecar, fast fallback, and multi-Swift CI. The repository contains two main Swift applications:

1. **Main Vapor API** (`/Sources`) - Legacy API with sessions, file uploads, worker integration
2. **EdgeInfer Service** (`/EdgeInfer`) - Minimal Hailo-8 TCN-VAE edge inference service

## Architecture

```
Client --> Vapor API --> (if USE_REAL_MODEL) HTTP -> Sidecar (/infer)
                               | failure
                               v
                          Fallback Stub
```

The system uses Docker Compose with two main services:
- `edge-infer`: Hailo-8 inference service (port 8080)
- `api`/`vapor`: Main Vapor application (port 8082)

## Common Development Commands

### Build & Test
```bash
# Run tests in containerized environment
make test

# Build and run core app container
make build
make run

# Full stack with model runner
make compose-up
make compose-down
```

### Development (Swift)
```bash
# EdgeInfer service development
cd EdgeInfer
swift build
swift run
swift test --parallel

# With real model enabled
USE_REAL_MODEL=true swift run
```

### Container Management
```bash
# View logs
make logs
make compose-logs

# Health checks
make health
curl -sSf http://localhost:8080/healthz

# Container inspection
make ps
make inspect
```

### Model Artifacts
```bash
# Initialize submodules and check model artifacts
make init

# Check model artifacts only
make check-models
./scripts/check-models.sh appdata/models/tcn_vae
```

### API Testing
```bash
# Basic health
curl -sSf http://localhost:8080/healthz

# Session management (main API)
make sessions
make session SID=<session-id>
make smoke

# EdgeInfer motifs endpoint
curl -X POST http://localhost:8080/analysis/motifs \
  -H 'Content-Type: application/json' \
  -d '{"window":[0.12,0.34,0.56]}' | jq .
```

## Key File Structure

### EdgeInfer Service (`/EdgeInfer`)
- `Sources/App/AnalysisController.swift` - Main API endpoints
- `Sources/App/ModelInference/ModelInferenceService.swift` - Model communication
- `Sources/App/configure.swift` - Application configuration
- `Tests/AppTests/EdgeInferTests.swift` - Test suite (9 test cases)

### Main Vapor API (`/Sources`)
- `Sources/App/Controllers/AnalysisController.swift` - Analysis endpoints
- `Sources/App/Services/ModelInferenceService.swift` - Model integration
- `Sources/App/Middleware/` - Custom middleware (timing, logging, API key)

### Configuration
- `Makefile` - Unified build/test/deploy commands
- `docker-compose.yml` - Main service orchestration
- `docker-compose.model.yml` - Additional model runner configuration
- `Package.swift` - Swift package configuration

## Feature Flags

| Flag | Purpose | Default |
|------|---------|---------|
| `USE_REAL_MODEL` | Enable sidecar inference call | false |
| `MODEL_BACKEND_URL` | Sidecar inference endpoint | http://localhost:9000/infer |

## Testing Strategy

EdgeInfer has comprehensive test coverage:
- Inference success path (mocked sidecar)
- Non-200 and malformed JSON fallback
- DNS/connection refusal fast failure (< 60ms)
- Real path flag toggle
- Health checks and smoke tests

Always run `make test` before commits to ensure containerized test environment passes.

## Docker Architecture

- Multi-stage builds optimized for ARM64 (Raspberry Pi)
- Health checks configured for both services
- Hailo volume mount ready (`/opt/hailo`)
- Resource limits and restart policies configured
- Logging with rotation (10M max, 3 files)

## Monitoring & Metrics

- Prometheus metrics at `/metrics`
- Health endpoints at `/healthz`
- Structured logging with request timing
- Performance target: sub-100ms error handling

## Model Integration

Required model artifacts in `appdata/models/tcn_vae/`:
- `tcn_encoder_for_edgeinfer.pth`
- `full_tcn_vae_for_edgeinfer.pth`
- `model_config.json`

Use `make check-models` to verify all artifacts are present before deployment.
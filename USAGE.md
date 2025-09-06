# EdgeInfer + Hailo Integration Usage Guide

## Quick Start

### Development Mode (Stub)
```bash
# Copy environment configuration
cp .env.example .env

# Build and start with Hailo stub (no hardware required)
docker compose --profile hailo-stub up -d --build

# Check services
docker compose ps
docker compose logs -f
```

### Production Mode (Pi with Hailo-8)
```bash
# Enable real model mode
echo "USE_REAL_MODEL=true" >> .env

# Start with real Hailo device
docker compose --profile hailo-device up -d --build

# Monitor real inference
curl -X POST http://localhost:8080/analysis/motifs \
  -H 'Content-Type: application/json' \
  -d '{"window":[[0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9]]}'
```

## Service Architecture

```
edge-infer:8080     → Swift Vapor API (EdgeInfer)
├── Stub mode       → hailo-inference-stub:9000
└── Hardware mode   → hailo-inference:9000 → /dev/hailo0
```

## Health Checks

```bash
# EdgeInfer health
curl http://localhost:8080/healthz

# Hailo service health (when running)
curl http://localhost:9000/healthz  # Not exposed externally
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `USE_REAL_MODEL` | `false` | Enable Hailo hardware inference |
| `MODEL_BACKEND_URL` | `http://hailo-inference:9000/infer` | Hailo service endpoint |
| `BACKEND_TIMEOUT_MS` | `1500` | Inference timeout |
| `MODELS_PATH` | `./models` | Model artifacts directory |

## Troubleshooting

### Service Dependencies
EdgeInfer automatically waits for Hailo services but continues without them if unavailable.

### Port Conflicts
- EdgeInfer: 8080 (external)
- Vapor API: 8082 (external) 
- Hailo services: 9000 (internal only)

### Profiles
- `hailo-stub`: Development mode (no hardware)
- `hailo-device`: Production mode (requires Hailo-8)
# EdgeInfer - Hailo-8 TCN-VAE Edge Deployment Service

A Vapor-based edge inference API service for behavioral analysis using Hailo-8 accelerator.

## Architecture

This service implements ChatGPT's "tracer bullet" approach:
1. **Infrastructure first** - Prove the pipeline works with stubbed responses
2. **Performance validated** - <50ms API response times 
3. **iOS integration ready** - Compatible with existing DataDogs app
4. **Hailo-8 prepared** - Container architecture supports model integration

## API Endpoints

### Analysis Session Management
- `POST /api/v1/analysis/start` - Initialize behavioral analysis session
- `POST /api/v1/analysis/stop` - Terminate analysis session

### Real-time Analysis
- `PUT /api/v1/analysis/stream` - Stream IMU data (100Hz)
- `GET /api/v1/analysis/motifs?sessionId=<id>` - Get K=12 behavioral motifs
- `GET /api/v1/analysis/synchrony?sessionId=<id>` - Get handler-dog synchrony metrics

### System
- `GET /healthz` - Health check
- `GET /metrics` - Prometheus metrics

## Data Models

### IMU Sample
```swift
{
  "t": 1234567890.123,      // timestamp (seconds)
  "ax": 0.1, "ay": 0.2, "az": 9.8,  // accelerometer (m/s²)
  "gx": 0.01, "gy": 0.02, "gz": 0.03, // gyroscope (rad/s)
  "mx": 25.0, "my": -15.0, "mz": 40.0  // magnetometer (μT)
}
```

### Motifs Response (K=12)
```swift
{
  "sessionId": "uuid-string",
  "topK": 12,
  "motifs": [
    {
      "id": "m1",
      "score": 0.95,
      "confidence": 0.87,
      "duration_ms": 450,
      "description": "sit"
    }
    // ... 11 more motifs
  ]
}
```

### Synchrony Response
```swift
{
  "sessionId": "uuid-string", 
  "r": 0.42,           // correlation coefficient
  "lag_ms": 60,        // estimated lag
  "window_ms": 500,    // analysis window
  "confidence": 0.75   // measurement confidence
}
```

## Building & Running

### Docker Build (ARM64)
```bash
cd EdgeInfer
docker build -t edge-infer:latest .
```

### Docker Compose (from project root)
```bash
docker-compose up edge-infer
```

### Direct Swift Build (for development)
```bash
cd EdgeInfer
swift run
```

## Performance Features

### SessionStore Actor
- Thread-safe IMU data buffering
- Ring buffer (2000 samples) prevents memory growth
- Supports multiple simultaneous sessions

### Prometheus Metrics
- HTTP request latency histograms
- Request count by endpoint and status
- Available at `/metrics`

### CORS Configuration
- Configured for iOS app LAN communication
- Supports all necessary headers and methods

## Monitoring

### Health Check
```bash
curl http://localhost:8080/healthz
```

### Metrics Collection
```bash
curl http://localhost:8080/metrics
```

### API Smoke Tests
```bash
# Start session
curl -X POST http://localhost:8080/api/v1/analysis/start

# Get motifs (replace sessionId)
curl "http://localhost:8080/api/v1/analysis/motifs?sessionId=<session-id>"

# Get synchrony
curl "http://localhost:8080/api/v1/analysis/synchrony?sessionId=<session-id>"
```

## Development Notes

This service currently provides realistic stub responses for:
- 12 behavioral motifs with confidence scores
- Handler-dog synchrony metrics (correlation, lag)
- Performance metrics and logging

Future integration with Hailo-8 models will replace stub responses with real TCN-VAE inference while maintaining the same API contract.

## Dependencies

- Swift 5.10+
- Vapor 4.92+
- SwiftPrometheus 1.0+
- Ubuntu 22.04 (container runtime)

## Container Architecture

- Multi-stage build optimized for ARM64
- Hailo volume mount ready (`/opt/hailo`)
- Health checks and logging configured
- Restart policies for production deployment

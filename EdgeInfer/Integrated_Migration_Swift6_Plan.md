# Integrated Pi Migration + Swift 6 Upgrade Plan
**Timeline**: Pi arrives today → Weekend migration → Swift 6 pilot  
**Strategy**: Bare metal stability first, then toolchain upgrade with dual-CI validation

## 🎯 Phased Integration Strategy

### Phase 1: Hardware Stabilization (Weekend)
**Goal**: Establish rock-solid bare metal foundation  
**Duration**: Saturday-Sunday (per existing migration plan)

```
Current Pi (failed) → New Pi 5 16GB → 48h stability validation
```

**Success Criteria from Swift 6 Plan**:
- [ ] **Fresh-metal cutover stable for ≥ 48h** (no alerts; p95 latency flat or better)
- [ ] **Model artifacts integrated & validated** on Pi (<50 ms target; CPU within budget)  
- [ ] **Hardening essentials done** (tests re-enabled, rate limits, basic request validation)

### Phase 2: Swift 6 Pilot Branch (Week 1)  
**Goal**: Dual-toolchain validation with zero production risk  
**Duration**: T0+3 to T0+7 days

```
Swift 5.10 (production) + Swift 6.0 (pilot) → CI matrix validation
```

## 🔧 Enhanced Migration Workflow

### Weekend Hardware Migration (Enhanced)
Building on existing migration docs, add Swift 6 preparation:

#### Saturday: Data Recovery + Fresh Pi Setup
```bash
# Standard migration (per existing docs)
# + Swift 6 preparation during setup

# During Docker installation, prepare for multi-toolchain
docker volume create swift510-cache
docker volume create swift60-cache

# Clone repo with Swift 6 pilot preparation
git clone https://github.com/wllmflower2460/pisrv_vapor_docker.git
cd pisrv_vapor_docker
git checkout -b upgrade/swift6-pilot  # prep branch, don't switch yet
```

#### Sunday: Production Deployment + CI Enhancement  
```bash
# Deploy on Swift 5.10 (production)
docker compose up -d --build

# Set up dual-toolchain CI (immediate)
# Update .github/workflows/swift-tests.yml with matrix strategy
```

### Week 1: Swift 6 Pilot Development

#### Day 1-2: Pilot Branch Setup
```bash
# Switch to pilot branch
git checkout upgrade/swift6-pilot

# Update Package.swift
sed -i 's/swift-tools-version:5.10/swift-tools-version:6.0/' Package.swift

# Remove Linux test discovery files (Swift 6 auto-discovery)
git rm -f EdgeInfer/Tests/AppTests/LinuxMain.swift 2>/dev/null || true
git rm -f EdgeInfer/Tests/AppTests/XCTestManifests.swift 2>/dev/null || true

# Update Dockerfile
sed -i 's/swift:5.10-jammy/swift:6.0-jammy/' EdgeInfer/Dockerfile

# Commit pilot changes
git commit -am "chore: Swift 6 pilot (tools header, Docker base, discovery)"
git push -u origin upgrade/swift6-pilot
```

#### Day 3-5: CI Matrix Validation
Enhanced GitHub Actions workflow:

```yaml
# .github/workflows/swift-ci-matrix.yml
name: Swift Multi-Version CI
on: 
  push:
  pull_request:
    branches: [main, upgrade/swift6-pilot]

jobs:
  build-test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        swift: ['5.10', '6.0']
        include:
          - swift: '5.10'
            allow-failure: false
          - swift: '6.0'  
            allow-failure: true  # initially
    container: swift:${{ matrix.swift }}-jammy
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - name: Cache Swift packages
        uses: actions/cache@v3
        with:
          path: .build
          key: ${{ runner.os }}-swift${{ matrix.swift }}-${{ hashFiles('**/Package.resolved') }}
      - name: Resolve packages
        run: swift package resolve
      - name: Run tests
        run: swift test -Xswiftc -enable-testing -v --jobs 2
        continue-on-error: ${{ matrix.allow-failure }}
      - name: Build release
        run: swift build -c release --static-swift-stdlib
        continue-on-error: ${{ matrix.allow-failure }}
```

#### Day 6-7: Concurrency & Actor Warnings Resolution
```bash
# Incrementally fix Swift 6 strict concurrency warnings
# Focus on high-impact items:
# - @MainActor annotations
# - Sendable conformance  
# - Actor isolation fixes

# Build and test locally with both toolchains
docker run --rm -v "$PWD":/app -w /app swift:5.10-jammy swift test
docker run --rm -v "$PWD":/app -w /app swift:6.0-jammy swift test
```

## 🚀 Production Cutover Strategy

### Pre-Cutover Validation (T0+7 days)
```bash
# Build images for both toolchains
docker build -t edgeinfer:swift510 --build-arg SWIFT_VERSION=5.10 .
docker build -t edgeinfer:swift60 --build-arg SWIFT_VERSION=6.0 .

# Staging validation (A-series tests)
curl -s -w '\n%{http_code}\n' http://staging:8080/healthz
curl -s http://staging:8080/api/v1/analysis/motifs | jq .
curl -s -o /dev/null -w 'time_total=%{time_total}\n' http://staging:8080/api/v1/analysis/motifs

# Performance comparison
echo "Swift 5.10 baseline:" && curl -s -o /dev/null -w '%{time_total}\n' http://staging-510:8080/api/v1/analysis/motifs
echo "Swift 6.0 candidate:" && curl -s -o /dev/null -w '%{time_total}\n' http://staging-60:8080/api/v1/analysis/motifs
```

### Production Cutover (Low-risk window)
```bash
# Tag current state for instant rollback
docker tag edgeinfer:current edgeinfer:pre-swift6-rollback

# Deploy Swift 6.0
docker-compose down
docker tag edgeinfer:swift60 edgeinfer:current
docker-compose up -d

# Immediate validation
curl -s -w '\n%{http_code}\n' http://pisrv.local:8080/healthz
curl -s http://pisrv.local:8080/api/v1/analysis/motifs | jq .

# Monitor Prometheus/Grafana for 30-60 minutes
# Watch for: latency spikes, error rates, memory/CPU changes
```

### Instant Rollback (if needed)
```bash
# One-command rollback to Swift 5.10
docker-compose down
docker tag edgeinfer:pre-swift6-rollback edgeinfer:current
docker-compose up -d

# Or explicit version rollback  
docker tag edgeinfer:swift510 edgeinfer:current
docker-compose up -d
```

## 📊 Enhanced Monitoring During Transition

### Metrics to Watch
```bash
# Response time comparison (should be equivalent)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Memory usage patterns (Swift 6 may have different characteristics)
container_memory_usage_bytes{name="edgeinfer"}

# Error rate validation
rate(http_requests_total{status=~"5.."}[5m])
```

### Pi-Specific Considerations
```bash
# ARM64 performance validation
# Swift 6.0 may have different optimization characteristics on Pi
docker stats --no-stream | grep edgeinfer

# Temperature monitoring during builds
vcgencmd measure_temp

# Disk I/O during Swift 6 builds (may be heavier)
iostat -x 1 5
```

## 🎯 Success Criteria Integration

### Hardware Migration Success ✅ (Weekend)
- New Pi 5 stable with EdgeInfer running
- Monitoring stack operational  
- iOS app connectivity verified
- 48-hour stability window achieved

### Swift 6 Pilot Success ✅ (Week 1)  
- Dual-toolchain CI passing consistently
- No runtime behavior differences detected
- Performance parity maintained
- Concurrency warnings resolved

### Production Cutover Success ✅ (Week 2)
- Swift 6.0 production deployment stable
- Performance metrics within baseline
- Feature flag rollback capability retained
- Team confidence in new toolchain

## 📝 Combined Documentation Updates

Update existing Pi migration docs:
- Add Swift 6 preparation steps to deployment guide
- Include dual-toolchain testing in validation checklist  
- Enhance rollback procedures with toolchain rollback
- Document performance baseline establishment

This integrated approach gives you:
1. **Rock-solid hardware foundation** before any toolchain changes
2. **Zero-risk Swift 6 validation** with dual CI matrix  
3. **Multiple rollback layers** (hardware, toolchain, feature flags)
4. **Comprehensive monitoring** throughout the transition

The key insight from the Swift 6 plan is perfect: establish bare metal stability first, then layer on the toolchain upgrade with full CI validation. This minimizes risk and maximizes confidence at each step.
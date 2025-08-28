# Prometheus Drop-in for Vapor (Pi Server)

## 1) Package.swift
Add the dependency and product to your `Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "App",
    platforms: [.macOS(.v13)],
    dependencies: [
        // ... your other deps
        .package(url: "https://github.com/MrLotU/SwiftPrometheus.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                // ... your other products
                .product(name: "Prometheus", package: "SwiftPrometheus"),
            ],
            path: "Sources/App"
        ),
        .executableTarget(name: "Run", dependencies: [.target(name: "App")])
    ]
)
```

## 2) Files to add
- `Sources/App/Monitoring/PrometheusMetrics.swift`
- `Sources/App/Middleware/PrometheusMiddleware.swift`
- `Sources/App/Routes/MetricsRoute.swift`

## 3) Wire-up in configure.swift
Register middleware **before** routes and register the metrics route:

```swift
import Vapor
// import Prometheus // (not required in configure if already imported in files)

public func configure(_ app: Application) throws {
    // ... your existing config

    // Register Prometheus middleware early
    app.middleware.use(PrometheusMiddleware())

    // Routes
    try routes(app)            // your existing routes
    registerMetricsRoute(app)  // add /metrics endpoint
}
```

## 4) Scrape example
In Prometheus `prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'pisrv'
    static_configs:
      - targets: ['<pi-ip>:8080']
    metrics_path: /metrics
    scrape_interval: 15s
```

## 5) Exported metrics
- `http_requests_total{method,route,status}`
- `http_request_duration_seconds_bucket{route}`, plus `_sum` and `_count`

## Notes
- Route normalization replaces UUID-like segments with `:id` to avoid label explosion.
- Histogram buckets use Prometheus defaults to reduce CPU/memory overhead on Raspberry Pi.
- Works alongside your existing `TimingMiddleware` and access logs.

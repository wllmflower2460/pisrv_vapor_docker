// Sources/App/Monitoring/PrometheusMetrics.swift
// Prometheus drop-in for Vapor (Pi server)
//
// Requires Package.swift dependency:
// .package(url: "https://github.com/MrLotU/SwiftPrometheus.git", from: "2.0.0"),
// and target dependency:
// .product(name: "Prometheus", package: "SwiftPrometheus")
//
// Usage:
//   - register middleware in configure(_:) before routes
//   - add app.get("metrics") route to expose /metrics

import Prometheus
import Vapor

enum PrometheusMetrics {
    // Shared client for the process.
    static let client: PrometheusClient = {
        return PrometheusClient()
    }()

    // Counters & histograms (created once)
    static let httpRequestsTotal = client.createCounter(
        forType: Int.self,
        named: "http_requests_total",
        helpText: "Total HTTP requests",
        labels: ["method", "route", "status"]
    )

    static let httpRequestDurationSeconds = client.createHistogram(
        forType: Double.self,
        named: "http_request_duration_seconds",
        helpText: "HTTP request latencies (seconds)",
        // Default Prometheus buckets; keep coarse for Raspberry Pi
        buckets: .default,
        labels: ["route"]
    )

    // Helper to normalize dynamic path segments to avoid label explosion.
    // e.g., /sessions/1b2c-.../results -> /sessions/:id/results
    static func normalizedRoute(from path: String) -> String {
        // Replace UUID-like segments with :id
        let uuidRegex = try! NSRegularExpression(
            pattern: "^[0-9a-fA-F-]{8,}$"
        )
        let parts = path.split(separator: "/").map { String($0) }
        let mapped = parts.map { seg -> String in
            let range = NSRange(location: 0, length: seg.utf16.count)
            if uuidRegex.firstMatch(in: seg, options: [], range: range) != nil {
                return ":id"
            }
            return seg
        }
        return "/" + mapped.joined(separator: "/")
    }
}

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

struct SimpleMetrics {
    // Simple metrics implementation for EdgeInfer
    func recordRequest(method: String, route: String, status: Int, duration: Double) {
        // Stub implementation - metrics will be collected by PrometheusMiddleware
    }
}

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

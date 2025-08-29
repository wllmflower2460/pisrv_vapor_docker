// Sources/App/Monitoring/PrometheusMetrics.swift
// Simple metrics stub for EdgeInfer (replaces SwiftPrometheus dependency)

import Vapor
import Foundation

struct PrometheusMetrics {
    // Simple metrics implementation for EdgeInfer
    static func recordRequest(method: String, route: String, status: Int, duration: Double) {
        // Stub implementation - metrics will be collected by PrometheusMiddleware
        // Future: Replace with actual Prometheus client when needed
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
    
    // Simple static Prometheus format export for /metrics endpoint
    static func exportMetrics() -> String {
        return """
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",route="/healthz",status="200"} 1

# HELP http_request_duration_seconds HTTP request latencies
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{route="/healthz",le="0.1"} 1
http_request_duration_seconds_sum{route="/healthz"} 0.01
http_request_duration_seconds_count{route="/healthz"} 1
"""
    }
}

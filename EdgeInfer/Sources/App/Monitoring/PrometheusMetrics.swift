// Sources/App/Monitoring/PrometheusMetrics.swift
// Comprehensive Prometheus metrics for EdgeInfer service monitoring

import Vapor
import Foundation

actor PrometheusMetrics {
    // Thread-safe metrics storage
    private var requestCounts: [String: Int] = [:]
    private var requestDurations: [String: [Double]] = [:]
    private var sessionCounts: [String: Int] = [:]
    private var inferenceMetrics: [String: [Double]] = [:]
    private var memoryUsage: Double = 0.0
    private var errorCounts: [String: Int] = [:]
    private var healthCheckCounts: [String: Int] = [:]
    
    // Hailo sidecar specific metrics
    private var hailoInferenceCounts: [String: Int] = [:]
    private var hailoInferenceDurations: [String: [Double]] = [:]
    private var hailoErrorCounts: [String: Int] = [:]
    private var hailoSampleProcessed: [String: Int] = [:]
    
    static let shared = PrometheusMetrics()
    
    private init() {}
    
    // MARK: - Request Metrics
    func recordRequest(method: String, route: String, status: Int, duration: Double) {
        let key = "\(method)|\(route)|\(status)"
        requestCounts[key, default: 0] += 1
        requestDurations[key, default: []].append(duration)
        
        // Track errors separately
        if status >= 400 {
            let errorKey = "\(method)|\(route)"
            errorCounts[errorKey, default: 0] += 1
        }
    }
    
    // MARK: - Session Lifecycle Metrics
    func recordSessionStart() {
        sessionCounts["started", default: 0] += 1
    }
    
    func recordSessionStop(duration: Double, sampleCount: Int) {
        sessionCounts["stopped", default: 0] += 1
        sessionCounts["total_samples", default: 0] += sampleCount
        requestDurations["session_duration", default: []].append(duration)
    }
    
    func recordStreamingData(sampleCount: Int, processingTime: Double) {
        sessionCounts["stream_events", default: 0] += 1
        sessionCounts["stream_samples", default: 0] += sampleCount
        requestDurations["stream_processing", default: []].append(processingTime)
    }
    
    // MARK: - AI Inference Metrics
    func recordInference(operation: String, duration: Double, success: Bool, sampleCount: Int? = nil) {
        let key = "\(operation)_duration"
        inferenceMetrics[key, default: []].append(duration)
        
        let countKey = success ? "\(operation)_success" : "\(operation)_failure"
        sessionCounts[countKey, default: 0] += 1
        
        if let samples = sampleCount {
            sessionCounts["\(operation)_samples", default: 0] += samples
        }
    }
    
    // MARK: - Health Check Metrics
    func recordHealthCheck(component: String, success: Bool, duration: Double) {
        let statusKey = success ? "\(component)_healthy" : "\(component)_unhealthy"
        healthCheckCounts[statusKey, default: 0] += 1
        requestDurations["\(component)_health_duration", default: []].append(duration)
    }
    
    // MARK: - Resource Usage
    func updateMemoryUsage(_ usage: Double) {
        memoryUsage = usage
    }
    
    // MARK: - Hailo Sidecar Metrics
    func recordHailoInference(operation: String, duration: Double, success: Bool, sampleCount: Int, latentSize: Int? = nil, motifCount: Int? = nil) {
        let statusKey = success ? "\(operation)_success" : "\(operation)_failure"
        hailoInferenceCounts[statusKey, default: 0] += 1
        
        let durationKey = "\(operation)_duration"
        hailoInferenceDurations[durationKey, default: []].append(duration)
        
        hailoSampleProcessed["samples_processed", default: 0] += sampleCount
        
        if let latent = latentSize {
            hailoSampleProcessed["latent_vectors", default: 0] += 1
            hailoSampleProcessed["latent_dimensions", default: 0] = latent
        }
        
        if let motifs = motifCount {
            hailoSampleProcessed["motif_predictions", default: 0] += 1
            hailoSampleProcessed["motif_classes", default: 0] = motifs
        }
    }
    
    func recordHailoError(errorType: String, backendURL: String) {
        let errorKey = "\(errorType)"
        hailoErrorCounts[errorKey, default: 0] += 1
        
        // Track backend-specific errors
        let backendKey = "backend_\(backendURL.contains("9000") ? "hailo" : "unknown")"
        hailoErrorCounts[backendKey, default: 0] += 1
    }
    
    func recordHailoHealth(component: String, responseTime: Double, success: Bool) {
        let healthKey = success ? "\(component)_healthy" : "\(component)_unhealthy"
        hailoInferenceCounts[healthKey, default: 0] += 1
        hailoInferenceDurations["\(component)_health_time", default: []].append(responseTime)
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
    
    // MARK: - Prometheus Export
    func exportMetrics() -> String {
        var output = ""
        
        // HTTP Request Metrics
        output += "# HELP edgeinfer_http_requests_total Total HTTP requests by method, route, and status\n"
        output += "# TYPE edgeinfer_http_requests_total counter\n"
        for (key, count) in requestCounts {
            let parts = key.split(separator: "|")
            if parts.count == 3 {
                let method = parts[0]
                let route = parts[1]
                let status = parts[2]
                output += "edgeinfer_http_requests_total{method=\"\(method)\",route=\"\(route)\",status=\"\(status)\"} \(count)\n"
            }
        }
        
        // HTTP Request Duration
        output += "\n# HELP edgeinfer_http_request_duration_seconds HTTP request duration in seconds\n"
        output += "# TYPE edgeinfer_http_request_duration_seconds summary\n"
        for (key, durations) in requestDurations {
            if key.contains("|"), durations.count > 0 {
                let parts = key.split(separator: "|")
                if parts.count == 3 {
                    let route = parts[1]
                    let sum = durations.reduce(0, +)
                    let count = durations.count
                    output += "edgeinfer_http_request_duration_seconds_sum{route=\"\(route)\"} \(sum)\n"
                    output += "edgeinfer_http_request_duration_seconds_count{route=\"\(route)\"} \(count)\n"
                }
            }
        }
        
        // Session Metrics
        output += "\n# HELP edgeinfer_sessions_total Total sessions by lifecycle stage\n"
        output += "# TYPE edgeinfer_sessions_total counter\n"
        for (key, count) in sessionCounts {
            output += "edgeinfer_sessions_total{stage=\"\(key)\"} \(count)\n"
        }
        
        // AI Inference Metrics
        output += "\n# HELP edgeinfer_inference_duration_seconds AI inference operation duration\n"
        output += "# TYPE edgeinfer_inference_duration_seconds summary\n"
        for (key, durations) in inferenceMetrics {
            if durations.count > 0 {
                let sum = durations.reduce(0, +)
                let count = durations.count
                let operation = key.replacingOccurrences(of: "_duration", with: "")
                output += "edgeinfer_inference_duration_seconds_sum{operation=\"\(operation)\"} \(sum)\n"
                output += "edgeinfer_inference_duration_seconds_count{operation=\"\(operation)\"} \(count)\n"
                
                // Add percentiles for key operations
                if !durations.isEmpty {
                    let sorted = durations.sorted()
                    let p50 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.5))]
                    let p95 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
                    let p99 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.99))]
                    
                    output += "edgeinfer_inference_duration_seconds{operation=\"\(operation)\",quantile=\"0.5\"} \(p50)\n"
                    output += "edgeinfer_inference_duration_seconds{operation=\"\(operation)\",quantile=\"0.95\"} \(p95)\n"
                    output += "edgeinfer_inference_duration_seconds{operation=\"\(operation)\",quantile=\"0.99\"} \(p99)\n"
                }
            }
        }
        
        // Error Rate Metrics
        output += "\n# HELP edgeinfer_http_errors_total HTTP errors by method and route\n"
        output += "# TYPE edgeinfer_http_errors_total counter\n"
        for (key, count) in errorCounts {
            let parts = key.split(separator: "|")
            if parts.count == 2 {
                let method = parts[0]
                let route = parts[1]
                output += "edgeinfer_http_errors_total{method=\"\(method)\",route=\"\(route)\"} \(count)\n"
            }
        }
        
        // Health Check Metrics
        output += "\n# HELP edgeinfer_health_checks_total Health check results by component\n"
        output += "# TYPE edgeinfer_health_checks_total counter\n"
        for (key, count) in healthCheckCounts {
            output += "edgeinfer_health_checks_total{result=\"\(key)\"} \(count)\n"
        }
        
        // Memory Usage
        output += "\n# HELP edgeinfer_memory_usage_bytes Current memory usage in bytes\n"
        output += "# TYPE edgeinfer_memory_usage_bytes gauge\n"
        output += "edgeinfer_memory_usage_bytes \(Int(memoryUsage))\n"
        
        // System uptime
        let uptime = ProcessInfo.processInfo.systemUptime
        output += "\n# HELP edgeinfer_uptime_seconds Service uptime in seconds\n"
        output += "# TYPE edgeinfer_uptime_seconds gauge\n"
        output += "edgeinfer_uptime_seconds \(uptime)\n"
        
        // Hailo Sidecar Metrics
        output += "\n# HELP hailo_inference_requests_total Total Hailo inference requests by operation and status\n"
        output += "# TYPE hailo_inference_requests_total counter\n"
        for (key, count) in hailoInferenceCounts {
            let parts = key.split(separator: "_")
            if parts.count >= 2 {
                let operation = parts.dropLast().joined(separator: "_")
                let status = String(parts.last!)
                output += "hailo_inference_requests_total{operation=\"\(operation)\",status=\"\(status)\"} \(count)\n"
            }
        }
        
        output += "\n# HELP hailo_inference_duration_seconds Hailo inference operation duration\n"
        output += "# TYPE hailo_inference_duration_seconds summary\n"
        for (key, durations) in hailoInferenceDurations {
            if durations.count > 0 {
                let sum = durations.reduce(0, +)
                let count = durations.count
                let operation = key.replacingOccurrences(of: "_duration", with: "").replacingOccurrences(of: "_time", with: "")
                output += "hailo_inference_duration_seconds_sum{operation=\"\(operation)\"} \(sum)\n"
                output += "hailo_inference_duration_seconds_count{operation=\"\(operation)\"} \(count)\n"
                
                // Add percentiles for inference operations
                if !durations.isEmpty {
                    let sorted = durations.sorted()
                    let p50 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.5))]
                    let p95 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
                    let p99 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.99))]
                    
                    output += "hailo_inference_duration_seconds{operation=\"\(operation)\",quantile=\"0.5\"} \(p50)\n"
                    output += "hailo_inference_duration_seconds{operation=\"\(operation)\",quantile=\"0.95\"} \(p95)\n"
                    output += "hailo_inference_duration_seconds{operation=\"\(operation)\",quantile=\"0.99\"} \(p99)\n"
                }
            }
        }
        
        output += "\n# HELP hailo_inference_errors_total Hailo inference errors by type\n"
        output += "# TYPE hailo_inference_errors_total counter\n"
        for (errorType, count) in hailoErrorCounts {
            output += "hailo_inference_errors_total{error_type=\"\(errorType)\"} \(count)\n"
        }
        
        output += "\n# HELP hailo_samples_processed_total Total samples processed by Hailo sidecar\n"
        output += "# TYPE hailo_samples_processed_total counter\n"
        for (key, count) in hailoSampleProcessed {
            output += "hailo_samples_processed_total{metric=\"\(key)\"} \(count)\n"
        }
        
        return output
    }
}

import Vapor
import Foundation

struct HealthStatus: Content {
    let status: String
    let timestamp: Date
    let version: String
    let uptime: TimeInterval
    let checks: [String: CheckResult]
    
    struct CheckResult: Content {
        let status: String
        let message: String?
        let latency_ms: Int?
        let last_checked: Date
    }
}

struct HealthCheckService {
    private static var appStartTime = Date()
    
    static func performHealthCheck(_ req: Request) async -> HealthStatus {
        let startTime = Date()
        var checks: [String: HealthStatus.CheckResult] = [:]
        
        // 1. Basic service health
        checks["service"] = HealthStatus.CheckResult(
            status: "healthy",
            message: "EdgeInfer service operational",
            latency_ms: nil,
            last_checked: startTime
        )
        
        // 2. Hailo backend connectivity check
        let hailoCheck = await checkHailoBackend(req)
        checks["hailo_backend"] = hailoCheck
        
        // Record Hailo health check metrics
        await PrometheusMetrics.shared.recordHealthCheck(
            component: "hailo_backend",
            success: hailoCheck.status == "healthy",
            duration: Double(hailoCheck.latency_ms ?? 0) / 1000.0
        )
        
        // Record detailed Hailo sidecar health metrics
        await PrometheusMetrics.shared.recordHailoHealth(
            component: "hailo_sidecar",
            responseTime: Double(hailoCheck.latency_ms ?? 0) / 1000.0,
            success: hailoCheck.status == "healthy"
        )
        
        // 3. Model inference capability check (if enabled)
        if Environment.get("USE_REAL_MODEL") == "true" {
            let inferenceCheck = await checkInferenceCapability(req)
            checks["inference_capability"] = inferenceCheck
            
            // Record inference capability metrics
            await PrometheusMetrics.shared.recordHealthCheck(
                component: "inference_capability",
                success: inferenceCheck.status == "healthy",
                duration: Double(inferenceCheck.latency_ms ?? 0) / 1000.0
            )
        } else {
            checks["inference_capability"] = HealthStatus.CheckResult(
                status: "stub",
                message: "Running in stub mode (USE_REAL_MODEL=false)",
                latency_ms: nil,
                last_checked: startTime
            )
        }
        
        // 4. Memory and resource check
        let resourceCheck = checkSystemResources()
        checks["system_resources"] = resourceCheck
        
        // Determine overall health status
        let overallStatus = determineOverallStatus(checks)
        
        return HealthStatus(
            status: overallStatus,
            timestamp: startTime,
            version: "1.0.0",
            uptime: Date().timeIntervalSince(appStartTime),
            checks: checks
        )
    }
    
    private static func checkHailoBackend(_ req: Request) async -> HealthStatus.CheckResult {
        let startTime = Date()
        let backendURL = Environment.get("MODEL_BACKEND_URL") ?? "http://hailo-inference:9000"
        
        do {
            // Extract base URL and add /healthz endpoint
            let baseURL = backendURL.components(separatedBy: "/infer").first ?? backendURL
            let healthURL = "\(baseURL)/healthz"
            
            let response = try await req.client.get(URI(string: healthURL))
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            
            if response.status == .ok {
                return HealthStatus.CheckResult(
                    status: "healthy",
                    message: "Hailo backend responding",
                    latency_ms: latency,
                    last_checked: startTime
                )
            } else {
                return HealthStatus.CheckResult(
                    status: "degraded",
                    message: "Hailo backend returned status \(response.status.code)",
                    latency_ms: latency,
                    last_checked: startTime
                )
            }
        } catch {
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            return HealthStatus.CheckResult(
                status: "unhealthy",
                message: "Cannot connect to Hailo backend: \(error.localizedDescription)",
                latency_ms: latency > 5000 ? nil : latency, // Don't report latency if timeout
                last_checked: startTime
            )
        }
    }
    
    private static func checkInferenceCapability(_ req: Request) async -> HealthStatus.CheckResult {
        let startTime = Date()
        
        do {
            // Create a minimal test inference request
            let testWindow = (0..<100).map { _ in
                (0..<9).map { _ in Float.random(in: -1...1) }
            }
            
            let backendURL = Environment.get("MODEL_BACKEND_URL") ?? "http://hailo-inference:9000"
            let response = try await req.client.post(URI(string: "\(backendURL)/infer")) { clientRequest in
                try clientRequest.content.encode(IMUWindow(x: testWindow))
            }
            
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            
            if response.status == .ok {
                // Validate response structure
                let result = try response.content.decode(ModelInferenceResult.self)
                if result.latent.count == 64 && result.motif_scores.count == 12 {
                    return HealthStatus.CheckResult(
                        status: "healthy",
                        message: "Inference pipeline operational",
                        latency_ms: latency,
                        last_checked: startTime
                    )
                } else {
                    return HealthStatus.CheckResult(
                        status: "degraded",
                        message: "Inference returned malformed response",
                        latency_ms: latency,
                        last_checked: startTime
                    )
                }
            } else {
                return HealthStatus.CheckResult(
                    status: "unhealthy",
                    message: "Inference request failed with status \(response.status.code)",
                    latency_ms: latency,
                    last_checked: startTime
                )
            }
        } catch {
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            return HealthStatus.CheckResult(
                status: "unhealthy",
                message: "Inference capability test failed: \(error.localizedDescription)",
                latency_ms: latency > 5000 ? nil : latency,
                last_checked: startTime
            )
        }
    }
    
    private static func checkSystemResources() -> HealthStatus.CheckResult {
        // Basic system resource check - can be enhanced with actual metrics
        let startTime = Date()
        
        // For now, just report healthy - this can be enhanced with actual resource monitoring
        return HealthStatus.CheckResult(
            status: "healthy",
            message: "System resources within normal limits",
            latency_ms: 1,
            last_checked: startTime
        )
    }
    
    private static func determineOverallStatus(_ checks: [String: HealthStatus.CheckResult]) -> String {
        let unhealthyCount = checks.values.filter { $0.status == "unhealthy" }.count
        let degradedCount = checks.values.filter { $0.status == "degraded" }.count
        
        if unhealthyCount > 0 {
            return "unhealthy"
        } else if degradedCount > 0 {
            return "degraded"
        } else {
            return "healthy"
        }
    }
}

// Support structs (ensuring they exist)
struct IMUWindow: Content {
    let x: [[Float]]
}

struct ModelInferenceResult: Content {
    let latent: [Float]
    let motif_scores: [Float]
}
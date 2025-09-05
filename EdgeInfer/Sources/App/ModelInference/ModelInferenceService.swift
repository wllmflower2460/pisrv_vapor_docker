import Vapor
import Foundation

struct IMUWindow: Content { 
    let x: [[Float]]  // (T,9) IMU window
}

struct ModelInferenceResult: Content {
    let latent: [Float]
    let motif_scores: [Float]
}

struct ModelInferenceService {
    private static var backendHealthy = true
    private static var lastHealthCheck = Date.distantPast
    private static let healthCheckInterval: TimeInterval = 30 // seconds
    
    static func analyzeIMUWindow(_ req: Request, samples: [IMUData]) async throws -> ModelInferenceResult {
        let useReal = Environment.get("USE_REAL_MODEL") == "true"
        
        if !useReal {
            // Return stub data
            req.logger.debug("Using stub mode for inference")
            return generateStubResult()
        }
        
        // Check if we should attempt real model inference
        let shouldTryReal = await shouldAttemptRealInference(req)
        
        if !shouldTryReal {
            req.logger.warning("Backend unhealthy, falling back to stub mode")
            return generateStubResult()
        }
        
        // Attempt real model inference with cascade failure handling
        let inferenceStart = Date()
        do {
            let result = try await performRealInference(req, samples: samples)
            let inferenceTime = Date().timeIntervalSince(inferenceStart)
            
            // Record successful Hailo sidecar metrics
            await PrometheusMetrics.shared.recordHailoInference(
                operation: "tcn_vae_inference",
                duration: inferenceTime,
                success: true,
                sampleCount: samples.count,
                latentSize: result.latent.count,
                motifCount: result.motif_scores.count
            )
            
            backendHealthy = true // Mark as healthy on successful request
            return result
        } catch {
            let inferenceTime = Date().timeIntervalSince(inferenceStart)
            
            // Record failed Hailo sidecar metrics
            await PrometheusMetrics.shared.recordHailoInference(
                operation: "tcn_vae_inference", 
                duration: inferenceTime,
                success: false,
                sampleCount: samples.count
            )
            
            // Record specific error types
            let errorType = classifyInferenceError(error)
            await PrometheusMetrics.shared.recordHailoError(errorType: errorType, backendURL: Environment.get("MODEL_BACKEND_URL") ?? "unknown")
            
            req.logger.error("Real inference failed (\(errorType)): \(error), falling back to stub")
            backendHealthy = false
            
            // Cascade failure: return stub data instead of failing completely
            return generateStubResult()
        }
    }
    
    private static func shouldAttemptRealInference(_ req: Request) async -> Bool {
        // If backend is healthy or we haven't checked recently, try it
        if backendHealthy || Date().timeIntervalSince(lastHealthCheck) < healthCheckInterval {
            return true
        }
        
        // Perform quick health check
        lastHealthCheck = Date()
        let isHealthy = await checkBackendHealth(req)
        backendHealthy = isHealthy
        
        return isHealthy
    }
    
    private static func checkBackendHealth(_ req: Request) async -> Bool {
        let backendURL = Environment.get("MODEL_BACKEND_URL") ?? "http://hailo-inference:9000/infer"
        let baseURL = backendURL.components(separatedBy: "/infer").first ?? backendURL
        let healthURL = "\(baseURL)/healthz"
        
        do {
            let response = try await req.client.get(URI(string: healthURL))
            return response.status == .ok
        } catch {
            req.logger.debug("Backend health check failed: \(error)")
            return false
        }
    }
    
    private static func performRealInference(_ req: Request, samples: [IMUData]) async throws -> ModelInferenceResult {
        let backendURL = Environment.get("MODEL_BACKEND_URL") ?? "http://hailo-inference:9000/infer"
        let timeout = TimeInterval(Environment.get("BACKEND_TIMEOUT_MS").flatMap(Int.init) ?? 1500) / 1000.0
        
        // Convert IMUData to window format
        let window = samples.map { sample in
            [sample.ax, sample.ay, sample.az, 
             sample.gx, sample.gy, sample.gz,
             sample.mx, sample.my, sample.mz]
        }
        
        // Create client request with timeout
        let response = try await withTimeout(seconds: timeout) {
            try await req.client.post(URI(string: backendURL)) { clientRequest in
                try clientRequest.content.encode(IMUWindow(x: window))
            }
        }
        
        guard response.status == .ok else {
            throw ModelInferenceError.backendError(response.status)
        }
        
        let result = try response.content.decode(ModelInferenceResult.self)
        
        // Validate response structure
        guard result.latent.count == 64 && result.motif_scores.count == 12 else {
            throw ModelInferenceError.malformedResponse
        }
        
        return result
    }
    
    private static func generateStubResult() -> ModelInferenceResult {
        return ModelInferenceResult(
            latent: (0..<64).map { _ in Float.random(in: -1...1) },
            motif_scores: (0..<12).map { _ in Float.random(in: 0.1...0.95) }
        )
    }
    
    // Classify inference errors for detailed monitoring
    private static func classifyInferenceError(_ error: Error) -> String {
        switch error {
        case ModelInferenceError.timeout:
            return "timeout"
        case ModelInferenceError.backendError(let status):
            return "http_\(status.code)"
        case ModelInferenceError.malformedResponse:
            return "malformed_response"
        case is DecodingError:
            return "decode_error"
        default:
            return "unknown_error"
        }
    }
}

// Helper function for timeout handling
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        // Add the main operation
        group.addTask {
            try await operation()
        }
        
        // Add timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw ModelInferenceError.timeout
        }
        
        // Return the first result (either success or timeout)
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

enum ModelInferenceError: Error {
    case timeout
    case modelNotLoaded
    case invalidInput
    case backendError(HTTPResponseStatus)
    case malformedResponse
}
import Vapor

// Simple in-memory metrics storage
class SimpleMetrics {
    private var requestCount = 0
    private var durations: [Double] = []
    private var lock = NSLock()
    
    func recordRequest(method: String, path: String, status: String, duration: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        
        requestCount += 1
        durations.append(duration)
        
        // Keep only last 1000 durations to avoid memory bloat
        if durations.count > 1000 {
            durations.removeFirst(durations.count - 1000)
        }
    }
    
    func collect() -> String {
        lock.lock()
        defer { lock.unlock() }
        
        let avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
        return """
        # HELP http_requests_total Total HTTP requests
        # TYPE http_requests_total counter
        http_requests_total \(requestCount)
        
        # HELP http_request_duration_seconds HTTP request duration
        # TYPE http_request_duration_seconds gauge
        http_request_duration_seconds \(avgDuration)
        """
    }
}

struct PrometheusMiddleware: AsyncMiddleware {
    let metrics: SimpleMetrics
    
    init(metrics: SimpleMetrics) {
        self.metrics = metrics
    }
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let startTime = Date()
        
        do {
            let response = try await next.respond(to: request)
            let duration = Date().timeIntervalSince(startTime)
            
            recordMetrics(
                request: request,
                response: response,
                duration: duration
            )
            
            return response
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let response = Response(status: .internalServerError)
            
            recordMetrics(
                request: request,
                response: response,
                duration: duration
            )
            
            throw error
        }
    }
    
    private func recordMetrics(
        request: Request,
        response: Response,
        duration: TimeInterval
    ) {
        metrics.recordRequest(
            method: request.method.rawValue,
            path: request.url.path,
            status: String(response.status.code),
            duration: duration
        )
    }
}

// MARK: - Metrics Controller

struct MetricsController: RouteCollection {
    let metrics: SimpleMetrics
    
    init(metrics: SimpleMetrics) {
        self.metrics = metrics
    }
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("metrics") { req in
            return metrics.collect()
        }
        
        routes.get("healthz") { req in
            return HealthResponse(
                status: "healthy",
                timestamp: Date(),
                service: "EdgeInfer",
                version: "1.0.0"
            )
        }
    }
}

struct HealthResponse: Content {
    let status: String
    let timestamp: Date
    let service: String
    let version: String
}

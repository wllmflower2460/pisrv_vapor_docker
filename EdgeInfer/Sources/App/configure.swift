import Vapor

// Configure your application
public func configure(_ app: Application) async throws {
    
    // MARK: - Middleware Configuration
    
    // Add CORS middleware for iOS app communication
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration), at: .beginning)
    
    // Add enhanced Prometheus metrics middleware
    app.middleware.use(PrometheusMiddleware())
    
    // Add error handling middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    
    // MARK: - Route Registration
    
    // Register enhanced health check endpoint with cross-service validation
    app.get("healthz") { req async throws -> Response in
        let healthStatus = await HealthCheckService.performHealthCheck(req)
        
        // Return appropriate HTTP status based on health
        let httpStatus: HTTPResponseStatus = switch healthStatus.status {
            case "healthy": .ok
            case "degraded": .ok  // Still operational, but with issues
            case "unhealthy": .serviceUnavailable
            default: .internalServerError
        }
        
        // Support both simple text response (for basic health checks)
        // and JSON response (for detailed monitoring)
        if req.headers.accept.contains(where: { $0.mediaType == .json }) {
            return try await healthStatus.encodeResponse(status: httpStatus, for: req)
        } else {
            // Simple text response for basic health checks
            let message = healthStatus.status == "healthy" ? "OK" : "DEGRADED"
            var buf = req.byteBufferAllocator.buffer(capacity: message.count)
            buf.writeString(message)
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "text/plain; charset=utf-8")
            headers.add(name: .contentLength, value: String(buf.readableBytes))
            headers.add(name: .connection, value: "close")
            return Response(status: httpStatus, headers: headers, body: .init(buffer: buf))
        }
    }
    
    // HEAD support for health check (wget --spider compatibility)
    app.on(.HEAD, "healthz") { req async throws -> Response in
        let healthStatus = await HealthCheckService.performHealthCheck(req)
        let httpStatus: HTTPResponseStatus = switch healthStatus.status {
            case "healthy": .ok
            case "degraded": .ok
            case "unhealthy": .serviceUnavailable
            default: .internalServerError
        }
        var headers = HTTPHeaders()
        headers.add(name: .contentLength, value: "0")
        headers.add(name: .connection, value: "close")
        return Response(status: httpStatus, headers: headers)
    }
    
    // Detailed health check endpoint for monitoring systems
    app.get("health", "detailed") { req async throws -> HealthStatus in
        return await HealthCheckService.performHealthCheck(req)
    }
    
    // Register comprehensive Prometheus metrics endpoint  
    app.get("metrics") { req async throws -> Response in
        let metricsData = await PrometheusMetrics.shared.exportMetrics()
        
        // Prometheus metrics format response
        var buffer = req.byteBufferAllocator.buffer(capacity: metricsData.count)
        buffer.writeString(metricsData)
        
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/plain; version=0.0.4; charset=utf-8")
        headers.add(name: .contentLength, value: String(buffer.readableBytes))
        
        return Response(status: .ok, headers: headers, body: .init(buffer: buffer))
    }
    
    // Register analysis endpoints  
    let analysisController = AnalysisController()
    try app.register(collection: analysisController)
    
    // MARK: - Application Configuration
    
    // Configure HTTP client timeouts for model inference
    app.http.client.configuration.timeout = .init(
        connect: .seconds(2),
        read: .milliseconds(45)
    )
    
    // Configure server
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = 8080
    
    // Set up logging
    app.logger.logLevel = .info
    app.logger.info("EdgeInfer service configured successfully")
    app.logger.info("Listening on http://0.0.0.0:8080")
    app.logger.info("Health check available at: /healthz")
    app.logger.info("Metrics available at: /metrics")
    app.logger.info("Analysis API available at: /api/v1/analysis/*")
}

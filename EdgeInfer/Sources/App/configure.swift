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
    
    // Register health check endpoint with explicit headers (fixes empty reply issue)
    app.get("healthz") { req -> Response in
        var buf = req.byteBufferAllocator.buffer(capacity: 2)
        buf.writeString("OK")
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/plain; charset=utf-8")
        headers.add(name: .contentLength, value: String(buf.readableBytes))
        headers.add(name: .connection, value: "close") // ensure immediate flush
        return Response(status: .ok, headers: headers, body: .init(buffer: buf))
    }
    
    // HEAD support for health check (wget --spider compatibility)
    app.on(.HEAD, "healthz") { req -> Response in
        var headers = HTTPHeaders()
        headers.add(name: .contentLength, value: "0")
        headers.add(name: .connection, value: "close")
        return Response(status: .ok, headers: headers)
    }
    
    // Register enhanced Prometheus metrics endpoint
    app.get("metrics") { req async throws -> String in
        try await PrometheusMetrics.client.collect()
    }
    
    // Register analysis endpoints  
    let analysisController = AnalysisController()
    try app.register(collection: analysisController)
    
    // MARK: - Application Configuration
    
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

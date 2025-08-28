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
    
    // Register health check endpoint (required for Docker health check)
    app.get("healthz") { req async throws -> [String: Any] in
        let formatter = ISO8601DateFormatter()
        return [
            "status": "healthy",
            "timestamp": formatter.string(from: Date()),
            "service": "EdgeInfer",
            "version": "1.0.0"
        ]
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

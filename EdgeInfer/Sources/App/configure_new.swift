import Vapor

// Configure your application
public func configure(_ app: Application) async throws {
    
    // MARK: - Middleware Configuration
    
    // Create shared metrics instance
    let metrics = SimpleMetrics()
    
    // Add CORS middleware for iOS app communication
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration), at: .beginning)
    
    // Add Prometheus metrics middleware
    let prometheusMiddleware = PrometheusMiddleware(metrics: metrics)
    app.middleware.use(prometheusMiddleware)
    
    // Add error handling middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    
    // MARK: - Route Registration
    
    // Register metrics and health endpoints
    let metricsController = MetricsController(metrics: metrics)
    try app.register(collection: metricsController)
    
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

import Foundation
import Fluent
import FluentSQLiteDriver
import Vapor

/// A description
/// - Parameter app:
/// - Throws:
public func configure(_ app: Application) throws {
    // Accept large uploads
    app.routes.defaultMaxBodySize = "2gb"

    // Listen on all interfaces (Docker)
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = 8080

    // Set log level early
    app.logger.logLevel = .info

        // Determine test mode early
        let isTest = app.environment == .testing || Environment.get("TEST_MODE") == "1"

        // HTTP client timeouts (tighter in tests)
        if isTest {
            app.http.client.configuration.timeout = .init(connect: .seconds(1), read: .seconds(2))
        } else {
            app.http.client.configuration.timeout = .init(connect: .seconds(2), read: .milliseconds(45))
        }

    // Boot diagnostics
    let apiKeys = (Environment.get("API_KEY") ?? "")
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    app.logger.info("API_KEY configured: \(apiKeys.count) key(s)")

    let sessionsDir = Environment.get("SESSIONS_DIR") ?? "/var/app/sessions"
    app.logger.info("SESSIONS_DIR=\(sessionsDir)")

    // Middleware
    app.middleware.use(TimingMiddleware())
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    app.middleware.use(AccessLogMiddleware()) // Log each request

        if isTest {
            // In-memory DB and skip migrations for faster, side-effect free tests
            app.logger.info("[configure] Test mode: using in-memory SQLite and skipping migrations")
            app.databases.use(.sqlite(.memory), as: .sqlite)
        } else {
        try FileManager.default.createDirectory(atPath: sessionsDir, withIntermediateDirectories: true, attributes: nil)
        let dbPath = sessionsDir + "/app.db"
        app.databases.use(.sqlite(.file(dbPath)), as: .sqlite)
        app.logger.info("SQLite path: \(dbPath)")
        app.migrations.add(CreateTodo())
        try app.autoMigrate().wait()
    }

    // Routes
    try routes(app)
}

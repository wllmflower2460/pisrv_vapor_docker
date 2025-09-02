import XCTVapor
@testable import App

/// Ensures the real-path fallback occurs quickly when the sidecar cannot be reached.
/// Uses 127.0.0.1:0 (invalid port) and a 50ms connect timeout to avoid 1s waits.
final class FallbackFastTests: XCTestCase {
    func testRealPathFallbackFast() async throws {
        let app = try await Application.make(.testing)
        defer { await app.asyncShutdown() }
        try configure(app)

        // Force real path, but point to an impossible endpoint
        setenv("USE_REAL_MODEL", "true", 1)
        setenv("MODEL_BACKEND_URL", "http://127.0.0.1:0", 1)

        // Make connection fail fast
        app.http.client.configuration.timeout.connect = .milliseconds(50)
        app.http.client.configuration.timeout.read = .milliseconds(200)

        let start = Date()
        try app.test(.GET, "/api/v1/analysis/motifs") { res in
            let elapsed = Date().timeIntervalSince(start)
            XCTAssertLessThan(elapsed, 0.25, "Fallback took too long (\(elapsed)s)")
            XCTAssertEqual(res.status, .ok)
            let body = res.body.string
            XCTAssertTrue(body.contains("motifs"))
        }
    }
}

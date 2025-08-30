import XCTVapor
import XCTest
@testable import App

final class AnalysisTests: XCTestCase {
    override func setUp() async throws {
        // Ensure flags reset
        unsetenv("USE_REAL_MODEL")
        unsetenv("MODEL_BACKEND_URL")
    }

    func makeApp() throws -> Application {
        let app = Application(.testing)
        try configure(app)
        return app
    }

    func testMotifs_StubPath() throws {
        let app = try makeApp()
        defer { app.shutdown() }
        setenv("USE_REAL_MODEL", "false", 1)
        try app.test(.GET, "/api/v1/analysis/motifs") { res in
            XCTAssertEqual(res.status, .ok)
            // Expect stub structure (should contain "motifs")
            XCTAssertTrue(res.body.string.contains("motifs"))
        }
    }

    func testMotifs_RealFlagButNoBackendFallsBack() throws {
        let app = try makeApp()
        defer { app.shutdown() }
        setenv("USE_REAL_MODEL", "true", 1)
        // No backend URL set, should not crash and should return fallback
        try app.test(.GET, "/api/v1/analysis/motifs") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertTrue(res.body.string.contains("motifs"))
        }
    }

    func testHealthz() throws {
        let app = try makeApp()
        defer { app.shutdown() }
        try app.test(.GET, "/healthz") { res in
            XCTAssertEqual(res.status, .ok)
        }
    }
#if !os(macOS)
    static var allTests: [(String, (AnalysisTests) -> () throws -> Void)] {
        [
            ("testMotifs_StubPath", testMotifs_StubPath),
            ("testMotifs_RealFlagButNoBackendFallsBack", testMotifs_RealFlagButNoBackendFallsBack),
            ("testHealthz", testHealthz)
        ]
    }
#endif

}

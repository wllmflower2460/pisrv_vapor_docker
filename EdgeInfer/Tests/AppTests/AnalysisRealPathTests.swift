// Tests/AppTests/AnalysisRealPathTests.swift
import XCTVapor
@testable import App

final class AnalysisRealPathTests: XCTestCase {
    func testMotifs_RealPath_UsesSidecarClientAndReturnsJSON() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        // Flip real path on
        setenv("USE_REAL_MODEL", "true", 1)
        setenv("MODEL_BACKEND_URL", "http://model-runner:8000", 1)
        setenv("TEST_MODE", "1", 1) // optional hook if your handler supports it

        // Inject mock client
        app.clients.use { app in MockClient(eventLoopGroup: app.eventLoopGroup) }

        try app.test(.GET, "/api/v1/analysis/motifs") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertTrue(res.body.string.contains(""motif_scores""))
        }
    }
}

#if os(Linux)
extension AnalysisRealPathTests {
    static var allTests: [(String, (AnalysisRealPathTests) -> () throws -> Void)] {
        [
            ("testMotifs_RealPath_UsesSidecarClientAndReturnsJSON", testMotifs_RealPath_UsesSidecarClientAndReturnsJSON)
        ]
    }
}
#endif

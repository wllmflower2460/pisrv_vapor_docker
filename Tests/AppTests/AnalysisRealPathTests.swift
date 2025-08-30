import XCTVapor
import XCTest
@testable import App

final class AnalysisRealPathTests: XCTestCase {
    func testMotifs_RealPath_UsesMockSidecar() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        setenv("USE_REAL_MODEL", "true", 1)
        setenv("MODEL_BACKEND_URL", "http://model-runner:8000", 1)
        setenv("TEST_MODE", "1", 1)

        app.clients.use { app in MockClient(eventLoopGroup: app.eventLoopGroup) }

        try app.test(.GET, "/api/v1/analysis/motifs") { res in
            XCTAssertEqual(res.status, .ok)
            let body = res.body.string
            XCTAssertTrue(body.contains("motifs"))
            XCTAssertTrue(body.contains("useReal"))
        }
    }
}

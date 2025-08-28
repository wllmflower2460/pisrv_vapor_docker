import XCTest
import XCTVapor
@testable import App

final class AppTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        app = Application(.testing)
        try await configure(app)
    }
    
    override func tearDown() async throws {
        app.shutdown()
    }
    
    func testHealthCheck() async throws {
        try await app.test(.GET, "healthz") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertTrue(res.body.string.contains("ok"))
        }
    }
    
    func testAnalysisStart() async throws {
        try await app.test(.POST, "api/v1/analysis/start") { res in
            XCTAssertEqual(res.status, .ok)
            
            let response = try res.content.decode(SessionStartResponse.self)
            XCTAssertEqual(response.status, "started")
            XCTAssertFalse(response.sessionId.isEmpty)
        }
    }
    
    func testMetricsEndpoint() async throws {
        try await app.test(.GET, "metrics") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertTrue(res.body.string.contains("http_requests_total"))
        }
    }
}

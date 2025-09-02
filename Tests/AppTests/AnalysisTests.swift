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
    
    func testInfer_StubMode() throws {
        let app = try makeApp()
        defer { app.shutdown() }
        setenv("USE_REAL_MODEL", "false", 1)
        
        // Valid 100x9 input
        let validInput = [
            "x": (0..<100).map { _ in (0..<9).map { _ in Double.random(in: -1...1) } }
        ]
        
        try app.test(.POST, "/api/v1/analysis/infer", beforeRequest: { req in
            try req.content.encode(validInput)
        }) { res in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(InferResponse.self)
            XCTAssertEqual(response.latent.count, 64)
            XCTAssertEqual(response.motif_scores.count, 12)
        }
    }
    
    func testInfer_BadRowCount() throws {
        let app = try makeApp()
        defer { app.shutdown() }
        setenv("USE_REAL_MODEL", "false", 1)
        
        // Invalid: only 50 rows instead of 100
        let invalidInput = [
            "x": (0..<50).map { _ in (0..<9).map { _ in Double.random(in: -1...1) } }
        ]
        
        try app.test(.POST, "/api/v1/analysis/infer", beforeRequest: { req in
            try req.content.encode(invalidInput)
        }) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
    }
    
    func testInfer_BadColumnCount() throws {
        let app = try makeApp()
        defer { app.shutdown() }
        setenv("USE_REAL_MODEL", "false", 1)
        
        // Invalid: 5 columns instead of 9 in some rows
        let invalidInput = [
            "x": (0..<100).map { i in 
                let cols = i < 10 ? 5 : 9  // First 10 rows have wrong column count
                return (0..<cols).map { _ in Double.random(in: -1...1) }
            }
        ]
        
        try app.test(.POST, "/api/v1/analysis/infer", beforeRequest: { req in
            try req.content.encode(invalidInput)
        }) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
    }
    
    func testInfer_RealModeNoBackend() throws {
        let app = try makeApp()
        defer { app.shutdown() }
        setenv("USE_REAL_MODEL", "true", 1)
        // No backend URL set, should fallback gracefully
        
        let validInput = [
            "x": (0..<100).map { _ in (0..<9).map { _ in Double.random(in: -1...1) } }
        ]
        
        try app.test(.POST, "/api/v1/analysis/infer", beforeRequest: { req in
            try req.content.encode(validInput)
        }) { res in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(InferResponse.self)
            XCTAssertEqual(response.latent.count, 64)
            XCTAssertEqual(response.motif_scores.count, 12)
        }
    }

}

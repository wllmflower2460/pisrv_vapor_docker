import XCTVapor
@testable import App

final class HealthzTests: XCTestCase {
    func testHealthzGET() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        try app.test(.GET, "healthz") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: .contentType), "text/plain; charset=utf-8")
            XCTAssertEqual(res.headers.first(name: .contentLength), "2")
            let body = String(decoding: res.body.readableBytesView, as: UTF8.self)
            XCTAssertEqual(body, "OK")
        }
    }

    func testHealthzHEAD() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        try app.test(.HEAD, "healthz") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: .contentLength), "0")
            XCTAssertEqual(res.body.readableBytes, 0)
        }
    }
}
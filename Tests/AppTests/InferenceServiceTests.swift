import XCTVapor
@testable import App

final class InferenceServiceTests: XCTestCase {
    struct StubClient: Client {
        let eventLoop: EventLoop
        let status: HTTPResponseStatus
        let bodyJSON: String
        func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")
            let buffer = ByteBuffer(string: bodyJSON)
            return eventLoop.makeSucceededFuture(ClientResponse(status: status, headers: headers, body: buffer))
        }
        func delegating(to eventLoop: EventLoop) -> Client { self }
        func shutdown() {}
    }

    func withApp(status: HTTPResponseStatus, body: String, test: (Application, Request) async throws -> Void) async throws {
        let app = try await Application.make(.testing)
        try configure(app)
        let loop = app.eventLoopGroup.next()
        let client = StubClient(eventLoop: loop, status: status, bodyJSON: body)
        app.clients.use { _ in client }
        let req = Request(application: app, on: loop)
        try await test(app, req)
        try await app.asyncShutdown()
    }

    func testAnalyzeIMUWindow_success() async throws {
        let goodJSON = "{\"latent\":[0.1],\"motif_scores\":[0.9,0.8,0.7]}"
        try await withApp(status: .ok, body: goodJSON) { app, req in
            let window = [[Float(0.5)]]
            let resp = try await ModelInferenceService.analyzeIMUWindow(req, window: window, modelURL: "http://x")
            XCTAssertEqual(resp.motif_scores?.count, 3)
        }
    }

    func testAnalyzeIMUWindow_non200() async throws {
        try await withApp(status: .badGateway, body: "{}") { app, req in
            let window = [[Float(0.5)]]
            await XCTAssertThrowsErrorAsync(try await ModelInferenceService.analyzeIMUWindow(req, window: window, modelURL: "http://x")) { error in
                guard let abort = error as? Abort else { return XCTFail("Expected Abort") }
                XCTAssertEqual(abort.status, .badGateway)
            }
        }
    }

    func testAnalyzeIMUWindow_malformedJSON() async throws {
        try await withApp(status: .ok, body: "{not-json}") { app, req in
            let window = [[Float(0.5)]]
            await XCTAssertThrowsErrorAsync(try await ModelInferenceService.analyzeIMUWindow(req, window: window, modelURL: "http://x"))
        }
    }
}

// Helper async assertion
func XCTAssertThrowsErrorAsync<T>(_ expression: @autoclosure () async throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line, _ errorHandler: (Error) -> Void = { _ in }) async {
    do { _ = try await expression(); XCTFail("Expected error", file: file, line: line) } catch { errorHandler(error) }
}

import Vapor

struct TimingMiddleware: AsyncMiddleware {
    func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Correlation ID (reuse header if present, otherwise generate)
        let reqId = req.headers.first(name: "X-Request-ID") ?? UUID().uuidString
        req.logger[metadataKey: "request_id"] = .string(reqId)

        let t0 = Date()
        do {
            let response = try await next.respond(to: req)
            log(req: req, res: response, started: t0, reqId: reqId)
            // echo the request id for the client/proxies
            let res = response
            res.headers.replaceOrAdd(name: "X-Request-ID", value: reqId)
            return res
        } catch {
            // log failures too
            let status = (error as? AbortError)?.status ?? .internalServerError
            log(req: req, status: status, started: t0, reqId: reqId, error: error)
            throw error
        }
    }

    private func log(req: Request, res: Response, started: Date, reqId: String) {
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        let ua = req.headers.first(name: .userAgent) ?? "-"
        let ip = req.remoteAddress?.ipAddress ?? "-"
        // logfmt: method=GET path=/foo status=200 ms=12 ua=... ip=... rid=...
        req.logger.info("req method=\(req.method.rawValue) path=\(req.url.path) status=\(res.status.code) ms=\(ms) ua=\"\(ua)\" ip=\(ip) rid=\(reqId)")
    }

    private func log(req: Request, status: HTTPStatus, started: Date, reqId: String, error: Error) {
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        let ua = req.headers.first(name: .userAgent) ?? "-"
        let ip = req.remoteAddress?.ipAddress ?? "-"
        req.logger.error("req method=\(req.method.rawValue) path=\(req.url.path) status=\(status.code) ms=\(ms) ua=\"\(ua)\" ip=\(ip) rid=\(reqId) err=\"\(String(describing: error))\"")
    }
}

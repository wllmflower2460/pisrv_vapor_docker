import Vapor
import NIOCore

struct AccessLogMiddleware: AsyncMiddleware {
    func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let start = NIODeadline.now()
        let ua = req.headers.first(name: .userAgent) ?? "-"
        let ip = req.remoteAddress?.ipAddress ?? "-"
        let res = try await next.respond(to: req)
        let ms = Double(NIODeadline.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        req.logger.info("req method=\(req.method) path=\(req.url.path) status=\(res.status.code) ms=\(String(format: "%.1f", ms)) ua=\"\(ua)\" ip=\(ip)")
        return res
    }
}

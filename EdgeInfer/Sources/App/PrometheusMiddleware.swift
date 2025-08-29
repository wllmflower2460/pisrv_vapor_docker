// Sources/App/Middleware/PrometheusMiddleware.swift
// Records per-request metrics for Prometheus.

import Vapor

struct PrometheusMiddleware: AsyncMiddleware {
    func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let started = Date()
        do {
            let res = try await next.respond(to: req)
            observe(req: req, status: res.status.code, started: started)
            return res
        } catch {
            let status = (error as? AbortError)?.status.code ?? HTTPStatus.internalServerError.code
            observe(req: req, status: status, started: started)
            throw error
        }
    }

    private func observe(req: Request, status: UInt, started: Date) {
        let elapsed = Date().timeIntervalSince(started) // seconds (Double)
        let method = req.method.rawValue.uppercased()
        // Simple logging for now - full Prometheus integration can be added later
        req.logger.info("Request: \(method) \(req.url.path) -> \(status) (\(elapsed)s)")
    }
}

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
        let method = req.method.string.uppercased()
        let route = PrometheusMetrics.normalizedRoute(from: req.url.path)

        // Histogram per normalized route
        PrometheusMetrics.httpRequestDurationSeconds.observe(elapsed, labels: ["route": route])

        // Counter by method/route/status
        PrometheusMetrics.httpRequestsTotal.inc(1, 
            labels: ["method": method, "route": route, "status": String(status)])
    }
}

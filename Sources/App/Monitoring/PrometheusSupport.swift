// Local Prometheus support (embedded) so App target compiles without external drop-in tree.
// If the external provisioning drop-in is later merged into Sources/App, these can be removed.
import Vapor
#if canImport(Prometheus)
import Prometheus

enum PrometheusMetrics {
    static let client: PrometheusClient = {
        PrometheusClient()
    }()

    static let httpRequestsTotal = client.createCounter(
        forType: Int.self,
        named: "http_requests_total",
        helpText: "Total HTTP requests",
        labels: ["method", "route", "status"]
    )

    static let httpRequestDurationSeconds = client.createHistogram(
        forType: Double.self,
        named: "http_request_duration_seconds",
        helpText: "HTTP request latencies (seconds)",
        buckets: .default,
        labels: ["route"]
    )

    static func normalizedRoute(from path: String) -> String {
        let parts = path.split(separator: "/")
        return "/" + parts.joined(separator: "/")
    }
}

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
        let elapsed = Date().timeIntervalSince(started)
        let method = req.method.string.uppercased()
        let route = PrometheusMetrics.normalizedRoute(from: req.url.path)
        PrometheusMetrics.httpRequestDurationSeconds.observe(elapsed, labels: ["route": route])
        PrometheusMetrics.httpRequestsTotal.inc(1, labels: ["method": method, "route": route, "status": String(status)])
    }
}

func registerMetricsRoute(_ app: Application) {
    app.get("metrics") { _ async throws -> String in
        try await PrometheusMetrics.client.collect()
    }
}
#endif

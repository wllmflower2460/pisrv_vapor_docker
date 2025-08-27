// Middleware/APIKeyMiddleware.swift
// created by Will on 8/9/25 (patched)

import Vapor

/// Checks API key against env `API_KEY`.
/// - Multiple keys supported via CSV: API_KEY="k1,k2,k3"
/// - If API_KEY is unset/empty, middleware is a no-op (allows all) — handy for dev.
struct APIKeyMiddleware: AsyncMiddleware {
    private let allowed: Set<String>

    init(_ env: Environment = .production) {
        let raw = Environment.get("API_KEY") ?? ""
        self.allowed = Set(
            raw.split(separator: ",")
               .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
               .filter { !$0.isEmpty }
        )
    }

    func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Dev mode: no keys configured → allow all
        if allowed.isEmpty {
            req.logger.debug("APIKeyMiddleware: no API_KEY configured; allowing request")
            return try await next.respond(to: req)
        }

        // Prefer X-API-Key; also accept Authorization: Bearer <key>
        let headerKey = req.headers.first(name: "X-API-Key")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let bearerKey = req.headers.bearerAuthorization?.token
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let key = (headerKey?.isEmpty == false ? headerKey : nil)
                       ?? (bearerKey?.isEmpty == false ? bearerKey : nil) else {
            req.logger.warning("401 unauthorized: missing API key header")
            throw Abort(.unauthorized)
        }

        guard allowed.contains(key) else {
            req.logger.warning("401 unauthorized: invalid API key (last4=\(key.suffix(4)))")
            throw Abort(.unauthorized)
        }

        return try await next.respond(to: req)
    }
}

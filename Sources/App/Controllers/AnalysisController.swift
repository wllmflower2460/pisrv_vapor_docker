import Vapor

struct Motif: Content {
    let id: String
    let score: Double
}

struct MotifsResponse: Content {
    let motifs: [Motif]
    let useReal: Bool
}

struct AnalysisController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api","v1","analysis")
        api.get("motifs", use: motifs)
    }
    
    func motifs(req: Request) async throws -> MotifsResponse {
        let useReal = (Environment.get("USE_REAL_MODEL") == "true")
        // For now always stub; future: call sidecar if useReal
        let motifs = (1...3).map { Motif(id: "m\($0)", score: Double.random(in: 0.5...0.95)) }
        return MotifsResponse(motifs: motifs, useReal: useReal)
    }
}

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
        let started = Date()
        let useRealFlag = (Environment.get("USE_REAL_MODEL") == "true")
        if !useRealFlag {
            let motifs = (1...3).map { Motif(id: "m\($0)", score: Double.random(in: 0.5...0.95)) }
            let resp = MotifsResponse(motifs: motifs, useReal: false)
            MotifsMetrics.observe(Date().timeIntervalSince(started), useReal: false)
            return resp
        }

        // Real path: call model-runner sidecar; fallback gracefully to stub
        let backend = Environment.get("MODEL_BACKEND_URL") ?? "http://model-runner:8000"
        do {
            let window = Self.mockWindow()
            let result = try await ModelInferenceService.analyzeIMUWindow(req, window: window, modelURL: backend)
            let scores = (result.motif_scores ?? []).prefix(3)
            let motifs = scores.enumerated().map { idx, val in
                Motif(id: "m\(idx+1)", score: Double(val))
            }
            let resp = MotifsResponse(motifs: motifs, useReal: true)
            MotifsMetrics.observe(Date().timeIntervalSince(started), useReal: true)
            return resp
        } catch {
            req.logger.warning("Model inference failed: \(error). Falling back to stub motifs.")
            let motifs = (1...3).map { Motif(id: "m\($0)", score: Double.random(in: 0.5...0.95)) }
            let resp = MotifsResponse(motifs: motifs, useReal: false)
            MotifsMetrics.observe(Date().timeIntervalSince(started), useReal: false)
            return resp
        }
    }

    // TEMP: mock window until real IMU buffer integration
    private static func mockWindow(length: Int = 100, features: Int = 9) -> [[Float]] {
        (0..<length).map { _ in (0..<features).map { _ in Float.random(in: -1...1) } }
    }
}

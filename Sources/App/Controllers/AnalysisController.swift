import Vapor

struct Motif: Content {
    let id: String
    let score: Double
}

struct MotifsResponse: Content {
    let motifs: [Motif]
    let useReal: Bool
}

struct InferRequest: Content {
    let x: [[Double]]
    
    func validate() throws {
        guard x.count == 100 else {
            throw Abort(.badRequest, reason: "Input must have exactly 100 rows, got \(x.count)")
        }
        for (i, row) in x.enumerated() {
            guard row.count == 9 else {
                throw Abort(.badRequest, reason: "Row \(i) must have exactly 9 columns, got \(row.count)")
            }
        }
    }
}

struct InferResponse: Content {
    let latent: [Double]
    let motif_scores: [Double]
}

struct AnalysisController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api","v1","analysis")
        api.get("motifs", use: motifs)
        api.post("infer", use: infer)
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

    func infer(req: Request) async throws -> InferResponse {
        let inferRequest = try req.content.decode(InferRequest.self)
        try inferRequest.validate()
        
        let useRealFlag = (Environment.get("USE_REAL_MODEL") == "true")
        if !useRealFlag {
            // Stub mode: return mock data with correct dimensions
            let latent = (0..<64).map { _ in Double.random(in: -1...1) }
            let motifScores = (0..<12).map { _ in Double.random(in: 0...1) }
            return InferResponse(latent: latent, motif_scores: motifScores)
        }
        
        // Real mode: proxy to sidecar
        let backend = Environment.get("MODEL_BACKEND_URL") ?? "http://hailo-inference:8000/infer"
        
        do {
            // Convert Double to Float for the sidecar
            var window = Array(repeating: [Float](), count: inferRequest.x.count)
            for (i, row) in inferRequest.x.enumerated() {
                var floatRow = [Float]()
                floatRow.reserveCapacity(row.count)
                for value in row {
                    floatRow.append(Float(value))
                }
                window[i] = floatRow
            }
            let result = try await ModelInferenceService.analyzeIMUWindow(req, window: window, modelURL: backend)
            
            let latent = (result.latent ?? []).map(Double.init)
            let motifScores = (result.motif_scores ?? []).map(Double.init)
            
            // Validate response dimensions
            guard latent.count == 64 else {
                throw Abort(.badGateway, reason: "Invalid latent dimension: expected 64, got \(latent.count)")
            }
            guard motifScores.count == 12 else {
                throw Abort(.badGateway, reason: "Invalid motif_scores dimension: expected 12, got \(motifScores.count)")
            }
            
            return InferResponse(latent: latent, motif_scores: motifScores)
        } catch {
            req.logger.warning("Model inference failed: \(error). Falling back to stub.")
            // Fallback to stub
            let latent = (0..<64).map { _ in Double.random(in: -1...1) }
            let motifScores = (0..<12).map { _ in Double.random(in: 0...1) }
            return InferResponse(latent: latent, motif_scores: motifScores)
        }
    }
    
    // TEMP: mock window until real IMU buffer integration
    private static func mockWindow(length: Int = 100, features: Int = 9) -> [[Float]] {
        (0..<length).map { _ in (0..<features).map { _ in Float.random(in: -1...1) } }
    }
}

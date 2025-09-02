import Vapor

struct IMUWindow: Content { let x: [[Float]] }

struct InferenceResponse: Content {
    let latent: [Float]?
    let motif_scores: [Float]?
}

enum ModelInferenceService {
    static func analyzeIMUWindow(_ req: Request, window: [[Float]], modelURL: String, timeoutMs: Int = 1500) async throws -> InferenceResponse {
        let resp = try await req.client.post(URI(string: modelURL)) { out in
            try out.content.encode(IMUWindow(x: window))
            out.headers.add(name: .contentType, value: "application/json")
        }
        guard resp.status == .ok else {
            throw Abort(.badGateway, reason: "Model backend status: \(resp.status.code)")
        }
        return try resp.content.decode(InferenceResponse.self)
    }
}

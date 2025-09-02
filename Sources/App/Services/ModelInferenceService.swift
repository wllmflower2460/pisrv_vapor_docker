import Vapor

struct IMUWindow: Content { let x: [[Float]] }

struct InferenceResponse: Content {
    let latent: [Float]?
    let motif_scores: [Float]?
}

enum ModelInferenceService {
    static func analyzeIMUWindow(_ req: Request, window: [[Float]], modelURL: String) async throws -> InferenceResponse {
        // Ensure the request is sent to the /infer endpoint
        var uri = URI(string: modelURL)
        if !uri.path.hasSuffix("/infer") {
            uri.path = uri.path.hasSuffix("/") ? uri.path + "infer" : uri.path + "/infer"
        }
        let resp = try await req.client.post(uri) { out in
            try out.content.encode(IMUWindow(x: window))
            out.headers.add(name: .contentType, value: "application/json")
        }
        guard resp.status == .ok else {
            throw Abort(.badGateway, reason: "Model backend status: \(resp.status.code)")
        }
        return try resp.content.decode(InferenceResponse.self)
    }
}

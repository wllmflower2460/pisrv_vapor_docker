import Vapor
import Foundation

struct IMUWindow: Content { 
    let x: [[Float]]  // (T,9) IMU window
}

struct ModelInferenceResult: Content {
    let latent: [Float]
    let motif_scores: [Float]
}

struct ModelInferenceService {
    static func analyzeIMUWindow(_ req: Request, samples: [IMUData]) async throws -> ModelInferenceResult {
        let useReal = Environment.get("USE_REAL_MODEL") == "true"
        
        if !useReal {
            // Return stub data
            return ModelInferenceResult(
                latent: (0..<64).map { _ in Float.random(in: -1...1) },
                motif_scores: (0..<12).map { _ in Float.random(in: 0.1...0.95) }
            )
        }
        
        // Real model inference
        let backendURL = Environment.get("MODEL_BACKEND_URL") ?? "http://model-runner:8000"
        
        // Convert IMUData to window format
        let window = samples.map { sample in
            [sample.ax, sample.ay, sample.az, 
             sample.gx, sample.gy, sample.gz,
             sample.mx, sample.my, sample.mz]
        }
        
        let response = try await req.client.post(URI(string: "\(backendURL)/infer")) { clientRequest in
            try clientRequest.content.encode(IMUWindow(x: window))
        }
        
        guard response.status == .ok else {
            throw ModelInferenceError.backendError(response.status)
        }
        
        return try response.content.decode(ModelInferenceResult.self)
    }
}

enum ModelInferenceError: Error {
    case timeout
    case modelNotLoaded
    case invalidInput
    case backendError(HTTPResponseStatus)
}
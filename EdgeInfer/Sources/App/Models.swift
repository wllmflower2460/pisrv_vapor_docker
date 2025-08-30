import Vapor
import Foundation

// MARK: - IMU Data Models
struct IMUSample: Content {
    let t: Double           // timestamp in seconds
    let ax, ay, az: Double  // accelerometer (m/s²)
    let gx, gy, gz: Double  // gyroscope (rad/s)
    let mx, my, mz: Double  // magnetometer (μT)
}

struct IMUWindow: Content {
    let sessionId: String
    let samples: [IMUSample]
    let windowStart: Double
    let windowEnd: Double
}

// MARK: - Analysis Response Models
struct SessionStartResponse: Content {
    let sessionId: String
    let status: String
    let timestamp: Double
    
    init(sessionId: String = UUID().uuidString) {
        self.sessionId = sessionId
        self.status = "started"
        self.timestamp = Date().timeIntervalSince1970
    }
}

struct Motif: Content {
    let id: String
    let score: Double
    let confidence: Double?
    let duration_ms: Int?
    let description: String?
    
    // Constructor for stub motifs
    init(id: String, score: Double, confidence: Double? = nil, duration_ms: Int? = nil, description: String? = nil) {
        self.id = id
        self.score = score
        self.confidence = confidence
        self.duration_ms = duration_ms
        self.description = description
    }
}

struct MotifsResponse: Content {
    let sessionId: String
    let topK: Int
    let motifs: [Motif]
    let timestamp: Double
    let analysisWindowMs: Int
    
    init(sessionId: String, analysisWindowMs: Int = 500) {
        self.sessionId = sessionId
        self.topK = 12
        self.timestamp = Date().timeIntervalSince1970
        self.analysisWindowMs = analysisWindowMs
        
        // Generate realistic K=12 behavioral motif stubs
        self.motifs = (1...12).map { i in
            let behaviors = ["sit", "stay", "heel", "come", "down", "shake", "spin", "jump", "bark", "sniff", "walk", "play"]
            return Motif(
                id: "m\(i)",
                score: Double(13 - i) / 12.0, // Decreasing confidence
                confidence: 0.85 + Double.random(in: -0.15...0.10),
                duration_ms: Int.random(in: 200...800),
                description: behaviors[i-1]
            )
        }
    }
    
    // Constructor for real AI-generated motifs
    init(sessionId: String, realMotifs: [Motif], analysisWindowMs: Int = 1000) {
        self.sessionId = sessionId
        self.topK = realMotifs.count
        self.timestamp = Date().timeIntervalSince1970
        self.analysisWindowMs = analysisWindowMs
        self.motifs = realMotifs
    }
}

struct SynchronyResponse: Content {
    let sessionId: String
    let r: Double            // correlation coefficient (-1 to 1)
    let lag_ms: Int         // estimated lag in milliseconds
    let window_ms: Int      // analysis window size
    let confidence: Double  // confidence in synchrony measurement
    let timestamp: Double
    
    init(sessionId: String, window_ms: Int = 500) {
        self.sessionId = sessionId
        self.window_ms = window_ms
        self.timestamp = Date().timeIntervalSince1970
        
        // Generate realistic handler-dog synchrony metrics
        self.r = 0.35 + Double.random(in: -0.15...0.25) // Typical synchrony range
        self.lag_ms = Int.random(in: 40...120) // Realistic reaction lag
        self.confidence = 0.75 + Double.random(in: -0.10...0.20)
    }
    
    // Constructor for real AI-generated synchrony
    init(sessionId: String, realSynchrony: SynchronyMetrics) {
        self.sessionId = sessionId
        self.r = realSynchrony.r
        self.lag_ms = realSynchrony.lag_ms
        self.window_ms = realSynchrony.window_ms
        self.timestamp = Date().timeIntervalSince1970
        
        // Calculate confidence based on correlation strength
        self.confidence = min(0.95, abs(realSynchrony.r) + 0.5)
    }
}

struct SynchronyMetrics {
    let r: Double            // correlation coefficient (-1 to 1)
    let lag_ms: Int         // estimated lag in milliseconds  
    let window_ms: Int      // analysis window size
}

struct SessionStopResponse: Content {
    let sessionId: String
    let status: String
    let duration_s: Double
    let totalSamples: Int
    let timestamp: Double
}

// MARK: - Session Management
struct Session {
    let id: String
    let startTime: Date
    var samples: [IMUSample]
    let maxSamples: Int
    
    init(id: String, maxSamples: Int = 2000) {
        self.id = id
        self.startTime = Date()
        self.samples = []
        self.maxSamples = maxSamples
    }
    
    mutating func append(newSamples: [IMUSample]) {
        samples.append(contentsOf: newSamples)
        
        // Ring buffer - keep only the most recent samples
        if samples.count > maxSamples {
            let excess = samples.count - maxSamples
            samples.removeFirst(excess)
        }
    }
    
    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    func getLatestSamples(count: Int) -> [IMUSample] {
        return Array(samples.suffix(count))
    }
}

// MARK: - Thread-Safe Session Store
actor SessionStore {
    private var sessions: [String: Session] = [:]
    private let defaultMaxSamples = 2_000  // ~20 seconds at 100Hz
    
    func createSession(id: String? = nil) -> String {
        let sessionId = id ?? UUID().uuidString
        sessions[sessionId] = Session(id: sessionId, maxSamples: defaultMaxSamples)
        return sessionId
    }
    
    func append(sessionId: String, window: IMUWindow) throws {
        guard var session = sessions[sessionId] else {
            throw Abort(.badRequest, reason: "Session not found: \(sessionId)")
        }
        
        session.append(newSamples: window.samples)
        sessions[sessionId] = session
    }
    
    func getSession(id: String) -> Session? {
        return sessions[id]
    }
    
    func stopSession(id: String) -> Session? {
        return sessions.removeValue(forKey: id)
    }
    
    func getActiveSessions() -> [String] {
        return Array(sessions.keys)
    }
    
    func getLatestSamples(sessionId: String, count: Int) -> [IMUSample] {
        guard let session = sessions[sessionId] else {
            return []
        }
        
        let samples = session.samples
        return Array(samples.suffix(count))
    }
    
    func cleanup(olderThan interval: TimeInterval = 3600) {
        let cutoff = Date().addingTimeInterval(-interval)
        sessions = sessions.filter { $0.value.startTime > cutoff }
    }
}

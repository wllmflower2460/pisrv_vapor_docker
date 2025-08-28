import Vapor

struct AnalysisController: RouteCollection {
    let sessionStore = SessionStore()
    
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api", "v1", "analysis")
        
        api.post("start", use: startAnalysis)
        api.put("stream", use: streamIMU)
        api.get("motifs", use: getMotifs)
        api.get("synchrony", use: getSynchrony)
        api.post("stop", use: stopAnalysis)
    }
    
    // POST /api/v1/analysis/start
    @Sendable
    func startAnalysis(req: Request) async throws -> SessionStartResponse {
        let sessionId = await sessionStore.createSession()
        
        req.logger.info("Started analysis session: \(sessionId)")
        
        return SessionStartResponse(sessionId: sessionId)
    }
    
    // PUT /api/v1/analysis/stream
    @Sendable
    func streamIMU(req: Request) async throws -> HTTPStatus {
        let window = try req.content.decode(IMUWindow.self)
        
        do {
            try await sessionStore.append(sessionId: window.sessionId, window: window)
            
            req.logger.debug("Streamed \(window.samples.count) samples for session: \(window.sessionId)")
            
            return .accepted
        } catch {
            req.logger.error("Failed to stream IMU data: \(error)")
            throw error
        }
    }
    
    // GET /api/v1/analysis/motifs?sessionId=<id>
    @Sendable
    func getMotifs(req: Request) async throws -> MotifsResponse {
        guard let sessionId = req.query[String.self, at: "sessionId"] else {
            throw Abort(.badRequest, reason: "Missing sessionId parameter")
        }
        
        guard let _ = await sessionStore.getSession(id: sessionId) else {
            throw Abort(.notFound, reason: "Session not found: \(sessionId)")
        }
        
        let response = MotifsResponse(sessionId: sessionId)
        
        req.logger.debug("Generated motifs for session: \(sessionId)")
        
        return response
    }
    
    // GET /api/v1/analysis/synchrony?sessionId=<id>
    @Sendable
    func getSynchrony(req: Request) async throws -> SynchronyResponse {
        guard let sessionId = req.query[String.self, at: "sessionId"] else {
            throw Abort(.badRequest, reason: "Missing sessionId parameter")
        }
        
        guard let _ = await sessionStore.getSession(id: sessionId) else {
            throw Abort(.notFound, reason: "Session not found: \(sessionId)")
        }
        
        let response = SynchronyResponse(sessionId: sessionId)
        
        req.logger.debug("Generated synchrony analysis for session: \(sessionId)")
        
        return response
    }
    
    // POST /api/v1/analysis/stop
    @Sendable
    func stopAnalysis(req: Request) async throws -> SessionStopResponse {
        struct StopRequest: Content {
            let sessionId: String
        }
        
        let stopReq = try req.content.decode(StopRequest.self)
        
        guard let session = await sessionStore.stopSession(id: stopReq.sessionId) else {
            throw Abort(.notFound, reason: "Session not found: \(stopReq.sessionId)")
        }
        
        let response = SessionStopResponse(
            sessionId: stopReq.sessionId,
            status: "stopped",
            duration_s: session.duration,
            totalSamples: session.samples.count,
            timestamp: Date().timeIntervalSince1970
        )
        
        req.logger.info("Stopped session: \(stopReq.sessionId), duration: \(session.duration)s, samples: \(session.samples.count)")
        
        return response
    }
}

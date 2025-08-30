/// APIKeyMiddleware.swift
/// created by  Will on 8/9/25
/// Checks `X-API-Key` header against env `API_KEY`.
/// - Supports multiple keys if `API_KEY="k1,k2,k3"`.
import Vapor

// MARK: - Types

struct UploadAck: Content { let sessionID: String }

struct UploadPayload: Content {
    var video: File
    var imu: File?
    var meta: String?
}

struct SessionSummary: Content {
    let id: String
    let files: [String: UInt64]
}

// MARK: - Routes

public func routes(_ app: Application) throws {

    // Root endpoint (public)
    app.get { _ in ["ok": true] }
    
    // Health probe (public)
    app.get("healthz") { _ in ["ok": true] }

    // List all session IDs (public)
    app.get("sessions") { req async throws -> [String] in
        let base = Environment.get("SESSIONS_DIR") ?? "/var/app/sessions"

        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(atPath: base)) ?? []
        var ids: [String] = []
        for item in items {
            var isDir: ObjCBool = false
            let path = (base as NSString).appendingPathComponent(item)
            if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                ids.append(item)
            }
        }
        return ids.sorted()
    }

    // Summary for a session (public)
    app.get("sessions", ":id") { req async throws -> SessionSummary in
        let base = Environment.get("SESSIONS_DIR") ?? "/var/app/sessions"
        guard let id = req.parameters.get("id") else { throw Abort(.badRequest) }
        let sdir = URL(fileURLWithPath: base).appendingPathComponent(id, isDirectory: true)

        var out: [String: UInt64] = [:]
        for name in ["video.mp4", "imu.json", "meta.json", "results.json"] {
            let p = sdir.appendingPathComponent(name)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: p.path),
               let size = attrs[.size] as? UInt64 {
                out[name] = size
            }
        }
        return SessionSummary(id: id, files: out)
    }
    app.get("admin","retention","candidates") { _ async throws -> [String] in
        let base = Environment.get("SESSIONS_DIR") ?? "/var/app/sessions"
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(atPath: base)) ?? []
        let cutoff = Date().addingTimeInterval(-7*24*3600)
        return items.compactMap { name in
            var isDir: ObjCBool = false
            let p = (base as NSString).appendingPathComponent(name)
            guard fm.fileExists(atPath: p, isDirectory: &isDir), isDir.boolValue,
                  let attrs = try? fm.attributesOfItem(atPath: p),
                  let mtime = attrs[.modificationDate] as? Date,
                  mtime < cutoff
            else { return nil }
            return name
        }
    }
    // Stream results.json (public)
    app.get("sessions", ":id", "results") { req async throws -> Response in
        let base = Environment.get("SESSIONS_DIR") ?? "/var/app/sessions"
        guard let id = req.parameters.get("id") else { throw Abort(.badRequest) }
        let p = URL(fileURLWithPath: base)
            .appendingPathComponent(id)
            .appendingPathComponent("results.json")
        
        guard FileManager.default.fileExists(atPath: p.path) else {
            // Enhanced debugging for 202 responses
            let sdir = URL(fileURLWithPath: base).appendingPathComponent(id)
            let sessionExists = FileManager.default.fileExists(atPath: sdir.path)
            let videoExists = FileManager.default.fileExists(atPath: sdir.appendingPathComponent("video.mp4").path)
            let metaExists = FileManager.default.fileExists(atPath: sdir.appendingPathComponent("meta.json").path)
            let imuExists = FileManager.default.fileExists(atPath: sdir.appendingPathComponent("imu.json").path)
            
            req.logger.info("Processing session \(id): sessionDir=\(sessionExists), video=\(videoExists), meta=\(metaExists), imu=\(imuExists), results=false")
            
            // Check directory permissions
            if sessionExists {
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: sdir.path)
                    let perms = attrs[.posixPermissions] as? Int ?? 0
                    let owner = attrs[.ownerAccountName] as? String ?? "unknown"
                    req.logger.info("Session dir permissions: \(String(perms, radix: 8)), owner: \(owner)")
                } catch {
                    req.logger.error("Failed to get session dir attributes: \(error)")
                }
            }
            
            let res = Response(status: .accepted)
            res.headers.add(name: .contentType, value: "application/json")
            res.headers.add(name: "Retry-After", value: "2")
            res.body = .init(string: #"{"status": "processing", "debug": {"session_exists": \(sessionExists), "video_exists": \(videoExists)}}"#)
            return res
        }

        let data = try Data(contentsOf: p)
        let res = Response(status: .ok)
        res.headers.contentType = .json
        res.body = .init(data: data)
        return res
    }

    // Multipart upload (protected by API key)
    let protected = app.grouped(APIKeyMiddleware(app.environment))
    protected.on(.POST, "sessions", "upload", body: .collect(maxSize: "2gb")) { req async throws -> UploadAck in
        let payload = try req.content.decode(UploadPayload.self)

        let base = Environment.get("SESSIONS_DIR") ?? "/var/app/sessions"
        try FileManager.default.createDirectory(atPath: base, withIntermediateDirectories: true, attributes: nil)

        let sid = UUID().uuidString
        let sdir = URL(fileURLWithPath: base).appendingPathComponent(sid, isDirectory: true)
        try FileManager.default.createDirectory(at: sdir, withIntermediateDirectories: true, attributes: nil)

        try await req.fileio.writeFile(payload.video.data,
                                       at: sdir.appendingPathComponent("video.mp4").path)

        if let imu = payload.imu {
            try await req.fileio.writeFile(imu.data,
                                           at: sdir.appendingPathComponent("imu.json").path)
        }

        if let meta = payload.meta {
            try Data(meta.utf8).write(to: sdir.appendingPathComponent("meta.json"))
        }

        return UploadAck(sessionID: sid)
    }

    // Analysis (temporary stub integration)
    try app.register(collection: AnalysisController())
}

/*
==========================================================
SELF-TEST COMMANDS (run from the Pi or machine with access)
==========================================================

# 1. Health check
curl -v http://localhost:8082/healthz
# Expect: HTTP 200 and body "ok"

# 2. Unauthorized upload (should 200 now - no auth required)
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
     -X POST \
     http://localhost:8082/sessions/upload
# Expect: HTTP 415 (content type issue, not auth issue)

# 3. Upload with form data
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
     -X POST \
     -F "video=@/etc/hostname;type=video/mp4" \
     -F "meta={\"note\":\"hello\"}" \
     http://localhost:8082/sessions/upload
# Expect: HTTP 200

# 4. List sessions
curl -v http://localhost:8082/sessions
# Expect: JSON array of session IDs

# 5. Get session summary
curl -v http://localhost:8082/sessions/<SESSION_ID>
# Expect: JSON with file names and sizes

# 6. Get results.json
curl -v http://localhost:8082/sessions/<SESSION_ID>/results
# Expect: JSON contents of results.json (404 if not present)

==========================================================
TROUBLESHOOTING QUICK HINTS
==========================================================
- If 401s unexpectedly: Check API_KEY env is set in `.env` and that your process sees it.
- If uploads fail: Verify Content-Type is `multipart/form-data` and field names match `UploadPayload`.
- If session list is empty: Confirm `SESSIONS_DIR` exists and Pi user has read access.
- If file sizes are 0: Check file writing permissions and that you're not sending empty files.
- If results.json 404s: Ensure processing stage creates it in the correct session directory.
==========================================================
*/

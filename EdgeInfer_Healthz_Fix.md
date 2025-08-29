# EdgeInfer Health Endpoint — Definitive Fix Kit (Vapor + Docker)
**Last updated:** 2025-08-29

Drop this into your repo (e.g., `docs/EdgeInfer_Healthz_Fix.md`) and apply the snippets below. This resolves the “Empty reply from server” on `/healthz` while `/metrics` works.

---

## ✅ TL;DR Fix Checklist
1. **Replace** your `/healthz` with the explicit Vapor handlers below (**GET + HEAD**).
2. **Add explicit headers**: `Content-Type`, `Content-Length`, and `Connection: close` on **GET**.
3. **Use a status-only healthcheck** in Docker (curl `-fsS -m 6 -o /dev/null`).
4. **Start period ≥ 90s** on Pi to allow Swift warm-up.
5. **Verify** with `curl -v` (see commands). Done when you see `HTTP/1.1 200 OK` and body `OK`.

---

## 1) Vapor Routes (copy‑paste)
Put this in your routes file (e.g., `Sources/App/routes.swift`).

```swift
// Robust /healthz with explicit headers & length + HEAD support
app.get("healthz") { req -> Response in
    var buf = req.byteBufferAllocator.buffer(capacity: 2)
    buf.writeString("OK")
    var headers = HTTPHeaders()
    headers.add(name: .contentType, value: "text/plain; charset=utf-8")
    headers.add(name: .contentLength, value: String(buf.readableBytes))
    headers.add(name: .connection, value: "close") // ensure immediate flush
    return Response(status: .ok, headers: headers, body: .init(buffer: buf))
}

app.on(.HEAD, "healthz") { req -> Response in
    var headers = HTTPHeaders()
    headers.add(name: .contentLength, value: "0")
    headers.add(name: .connection, value: "close")
    return Response(status: .ok, headers: headers)
}
```

**Optional sugar (keep the explicit version above in production):**
```swift
app.get("healthz") { _ in "OK" }
app.on(.HEAD, "healthz") { _ in HTTPStatus.ok }
```

**Diagnostic endpoint (bigger body to test framing):**
```swift
app.get("healthz-fat") { _ in String(repeating: "OK", count: 1024) }
```

---

## 2) Docker Healthcheck (copy‑paste)
Switch to a status‑only check; fail fast.

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -fsS -m 6 -o /dev/null http://localhost:8080/healthz || exit 1"]
  interval: 30s
  timeout: 8s
  retries: 3
  start_period: 90s
```

> If you prefer `wget --spider`, it may send **HEAD**; with the HEAD route above that’s fine too.

---

## 3) Verification Commands
**Inside the container:**
```bash
curl -v http://localhost:8080/healthz
curl -v --http1.1 http://localhost:8080/healthz
curl -I -v http://localhost:8080/healthz            # HEAD should be 200 with no body
```

**From the host:**
```bash
curl -s -w '\nHTTP %{http_code} in %{time_total}s\n' http://<pi-ip>:<host-port>/healthz
```

Expected:
- `HTTP/1.1 200 OK`
- `Content-Type: text/plain; charset=utf-8`
- `Content-Length: 2`
- Body: `OK` (GET); no body for HEAD; **no** “Empty reply from server.”

---

## 4) If It Still Misbehaves (quick toggles)
- **Disable compression** temporarily if you added it:
  ```swift
  // app.middleware.remove(CompressionMiddleware.self)
  ```
- **Middleware order**: ensure metrics/compression don’t interfere—register metrics middleware **after** anything that might change the body.
- **Try larger body**: hit `/healthz-fat`; if it works, it was tiny‑body framing.
- **Protocol**: try `--http1.1` and `--http1.0` to spot negotiation issues.
- **Logs**: confirm `GET /healthz` returns 200 with a response size > 0.

---

## 5) Why Metrics Say 200 But curl Shows Empty Reply
Your metrics middleware records `res.status == 200` **before** bytes are flushed. If the socket closes or framing is ambiguous (e.g., no `Content-Length` and client doesn’t see chunked body), clients report an empty reply while middleware still counted a 200. The explicit headers and `Connection: close` remove ambiguity on embedded targets.

---

## 6) Commit Plan
1. Add the new routes to `routes.swift` (GET + HEAD).
2. Update `docker-compose` healthcheck block.
3. Rebuild/redeploy.
4. Verify with `curl -v` (inside container and host).

**Suggested commit message:**
```
fix(healthz): add explicit headers + HEAD route; tighten Docker healthcheck; stabilize tiny-body flush
```

---

## Notes
- Keep `start_period` generous (90–120s) on Pi for Swift warm-up.
- Prefer simple, synchronous health endpoints; push heavier checks to `/readyz` with a longer start period.

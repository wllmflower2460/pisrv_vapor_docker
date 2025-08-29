# EdgeInfer Healthz — Post‑Fix Hardening Kit
**Last updated:** 2025-08-29

This doc locks in the “empty reply” fix and prevents regressions. It includes: regression tests (XCTVapor), a Prometheus alert rule, and quick verification steps.

---

## 1) Regression Tests (XCTVapor)
Create `Tests/AppTests/HealthzTests.swift`:

```swift
import XCTVapor
@testable import App

final class HealthzTests: XCTestCase {
    func testHealthzGET() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        try app.test(.GET, "healthz") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: .contentType), "text/plain; charset=utf-8")
            XCTAssertEqual(res.headers.first(name: .contentLength), "2")
            let body = String(decoding: res.body.readableBytesView, as: UTF8.self)
            XCTAssertEqual(body, "OK")
        }
    }

    func testHealthzHEAD() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        try app.test(.HEAD, "healthz") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: .contentLength), "0")
            XCTAssertEqual(res.body.readableBytes, 0)
        }
    }
}
```

**Run locally:**
```bash
swift test -c release
```

**Optional CI (GitHub Actions minimal Swift):**
```yaml
# .github/workflows/swift-tests.yml
name: swift-tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Swift
        uses: swift-actions/setup-swift@v2
        with:
          swift-version: "5.10"
      - name: Run tests
        run: swift test -c release
```

---

## 2) Prometheus Alert Rule (healthz success rate)
Add this to `prometheus_rules_pisrv.yml`:

```yaml
groups:
- name: edgeinfer-healthz
  rules:
  - alert: HealthzNoSuccesses
    expr: sum(rate(http_requests_total{route="/healthz",status="200"}[10m])) < 0.005
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "healthz success rate low"
      description: "healthz 200s fell below expected rate in the last 10m."

  - alert: HealthzClientErrors
    expr: sum(rate(http_requests_total{route="/healthz",status=~"4.."}[10m])) > 0.05
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "healthz 4xx elevated"
      description: "Spike in 4xx for /healthz over 10m window."
```

Reload Prometheus (if enabled): `POST /-/reload` or restart the container.

**Grafana stat (optional):**
```
sum(rate(http_requests_total{route="/healthz",status="200"}[5m]))
```

---

## 3) Verification Steps

**Inside the container:**
```bash
curl -v http://localhost:8080/healthz
curl -I -v http://localhost:8080/healthz
curl -v --http1.1 http://localhost:8080/healthz
```

**From the host:**
```bash
curl -s -w '\nHTTP %{http_code} in %{time_total}s\n' http://<pi-ip>:<host-port>/healthz
```

Expected results:
- `HTTP/1.1 200 OK`
- `Content-Type: text/plain; charset=utf-8`
- `Content-Length: 2`
- Body: `OK` (GET); empty body for HEAD; no “Empty reply”.

---

## 4) Reference — Docker Healthcheck (status‑only)
Make sure your compose uses a status‑only check with a generous warm‑up:

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -fsS -m 6 -o /dev/null http://localhost:8080/healthz || exit 1"]
  interval: 30s
  timeout: 8s
  retries: 3
  start_period: 90s
```

---

## 5) Notes
- Keep `/healthz` minimal; push deeper tests to `/readyz` and increase `start_period` if needed.
- You can re‑enable keep‑alive later by removing `Connection: close` but keep `Content-Length` explicit.

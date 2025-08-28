# EdgeInfer Deployment — Docker Troubleshooting (v2)
**Last updated:** 2025-08-28

This guide is a focused, step‑by‑step playbook for stabilizing your Vapor‑on‑Pi deployment when containers report `unhealthy`, restart in loops, or fail to serve `/healthz` and `/metrics` reliably.

---

## Quick Wins (apply first)
> These fix 80% of field issues on Pi within minutes.

1. **Use duration strings in `healthcheck`** (not raw integers):
   ```yaml
   healthcheck:
     test: ["CMD-SHELL", "wget -q -O- http://localhost:8080/healthz >/dev/null || exit 1"]
     interval: 30s
     timeout: 10s
     retries: 5
     start_period: 90s   # give Swift warm-up slack on Pi
   ```

2. **Ensure `wget` (or `curl`) exists in the runtime image**:
   ```Dockerfile
   RUN apt-get update && apt-get install -y --no-install-recommends wget ca-certificates \
       && rm -rf /var/lib/apt/lists/*
   ```

3. **Keep `/healthz` cheap and synchronous.**
   - `/healthz` = “I’m up” (no DB, no network, no model loading)
   - `/readyz` = deeper checks (OK to be slower; add longer `start_period` if used)

4. **Normalize route labels to limit metrics cardinality.**
   - Replace `/sessions/123` → `/sessions/:id` before labeling to keep p95 panels sane.

5. **Add a tiny init & graceful stop** to avoid zombie processes:
   ```yaml
   init: true
   stop_grace_period: 20s
   ```

---

## 10‑Minute Triage
Run these in order; stop when you find the culprit.

### 1) Is it actually restarting or just unhealthy?
```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'
docker inspect -f '{{.State.RestartCount}} {{.State.Status}} {{.State.Health.Status}}' edge-infer
```
- **RestartCount increases** → the process is exiting (crash/OOM/panic) or an external controller is bouncing it.
- **Status=running, Health=unhealthy** → app is up but healthcheck fails (missing tool/endpoint/timeout).

### 2) Why did it restart?
```bash
docker events --since 30m | grep edge-infer || true
docker logs --tail=200 edge-infer
```
- Look for `Exited (..)` with a code, or watchdogs (Portainer/Watchtower) doing restarts.

### 3) Is the health endpoint reachable *inside the container*?
Healthchecks run in the container’s net namespace, so test `localhost:8080`:
```bash
docker exec -it edge-infer sh -lc 'which wget || which curl || echo "no wget/curl"; wget -q -O- http://localhost:8080/healthz | head -c 200 && echo'
```

### 4) Can the host reach it?
```bash
curl -s -w '\nHTTP %{http_code} in %{time_total}s\n' http://<pi-ip>:<host-port>/healthz
curl -s -o /dev/null -w '%{time_total}\n' http://<pi-ip>:<host-port>/metrics
```

### 5) OOM / resource starvation?
```bash
dmesg -T | grep -i -E 'out of memory|killed process' || true
journalctl -k | grep -i -E 'memory|oom' || true
```
If you see OOM kills, lower parallelism and set resource hints (see below).

### 6) Arch / runtime mismatch (Pi 5 is arm64/aarch64)
```bash
docker exec -it edge-infer uname -m
# expect: aarch64 or arm64
```
If you ever see `exec format error`, rebuild with the correct platform:
```bash
docker build --platform=linux/arm64 -t edge-infer .
```

---

## Stable Compose Snippets

### Service hardening (copy‑paste)
```yaml
services:
  edge-infer:
    image: your/edge-infer:latest
    init: true
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "wget -q -O- http://localhost:8080/healthz >/dev/null || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 90s
    # Optional resource guidance (good for Pi warm-up)
    deploy:
      resources:
        limits:
          cpus: '1.5'
          memory: 800M
        reservations:
          cpus: '0.5'
          memory: 256M
    # Example ports/volumes as needed
    ports:
      - "8082:8080"
    volumes:
      - ./appdata/sessions:/app/sessions
```

### Readiness variant
Use a second endpoint with longer `start_period` when doing heavy init (models, DB, etc.).
```yaml
healthcheck:
  test: ["CMD-SHELL", "wget -q -O- http://localhost:8080/readyz >/dev/null || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 6
  start_period: 120s
```

---

## Observability Checks (Prometheus/Grafana)

1. **Metrics endpoint works**
   ```bash
   curl -s http://<pi-ip>:<host-port>/metrics | head
   ```

2. **Prometheus targets are up**
   - Open `http://<pi-ip>:9090/targets`
   - Verify jobs: `pisrv`, `node`, `cadvisor` are **UP**.

3. **p95 latency panel / alert**
   PromQL (adjust labels to your schema):
   ```
   histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[10m])) by (le))
   ```

4. **Verify alert rules are active**
   - `http://<pi-ip>:9090/rules` → your rule group should be listed.
   - To notify, wire Alertmanager; the rule file alone won’t send messages.

---

## Common Failure Modes & Fixes

### Healthcheck fails immediately
- Missing `wget`/`curl` → install in image (see Dockerfile snippet above).
- Wrong port/path → confirm app listens on `0.0.0.0:8080` and endpoint spelling.
- Start-up too slow → increase `start_period` to 90–120s on Pi.

### Container restarts in a loop
- App crash or panic → check `docker logs` and any `panic`/stack traces.
- OOM kills → lower concurrency, set memory limits, and/or add swap.
- External restarter (Portainer/Watchtower) → confirm no policy is bouncing it.

### Metrics missing in Grafana
- Prometheus target is `DOWN` → fix `targets` in `prometheus.yml` and network reachability.
- `http_request_duration_seconds_*` not found → confirm middleware emits histogram/counter and labels match your panel queries.
- High series cardinality → normalize dynamic path segments before labeling.

### Network & ports
- Healthchecks run inside the container → always probe container port, not host-mapped.
- Host conflicts → ensure `8082` (or your chosen host port) isn’t used by another service.
  ```bash
  sudo lsof -iTCP -sTCP:LISTEN -nP | grep 8082 || true
  ```

---

## Temporary Stabilization Moves

- **Disable healthcheck briefly** to prove the app is fine:
  ```yaml
  healthcheck:
    test: ["CMD", "true"]
  ```
- **Increase log detail** on health endpoints; log request time and return code.
- **Throttle concurrency** (threads, queues) during model warm-up.

---

## Session Persistence Recommendation
If restarts cause session loss, move sessions to a persistent store (e.g., Redis) or bind‑mount the session directory as shown above. For Redis, wire a small `redis` service and point Vapor’s sessions to it.

---

## Appendix: Quick Commands

```bash
# Container state & health
docker inspect -f '{{.State.Status}} {{.State.Health.Status}} {{.State.RestartCount}}' edge-infer
docker inspect -f '{{json .State.Health}}' edge-infer | sed 's/},{/}\n{ /g'

# Live restart/health events
docker events --since 30m | egrep 'edge-infer|health_status' || true

# Logs
docker logs --tail=200 -f edge-infer

# Host port conflicts
sudo lsof -iTCP -sTCP:LISTEN -nP | sort -k9
```

---

## Changelog
- **v2 (2025-08-28)**: Converted healthcheck timings to duration strings; added `wget` install note; clarified `unhealthy` vs `restarts`; added init & resource limits; added triage flow, OOM checks, Prometheus/Grafana validation, and copy‑paste Compose snippets.

---

## Notes
This v2 consolidates and clarifies prior notes from the original doc, aligning with the current PiSrv monitoring stack (Prometheus, Grafana, node‑exporter, cAdvisor). Keep `start_period` generous on Pi while Swift warms up, and prefer simple synchronous health endpoints.

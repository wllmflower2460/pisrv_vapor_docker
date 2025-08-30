# PR: Model sidecar integration + test hardening

## What changed
- **Model sidecar** scaffold (FastAPI) + compose override
- **Feature flag**: `USE_REAL_MODEL` with graceful fallback
- **HTTP client timeouts** (connect=1s, read=2s in tests)
- **Metrics**: route latency histogram labeled `useRealModel`
- **Test-mode configure**: in-memory DB/sessions, no file I/O
- **Fixed inference tests**: real `Request`, injectable `Client` mock
- **Switched to test discovery** (removed LinuxMain/manifests)
- **Fast fallback test** added (50ms connect to `127.0.0.1:0`)
- **Excluded Todo sources** from App target (no sample Fluent build)

## Tests (9 total, all green)
- Stub path returns valid JSON
- Fallback path when sidecar unreachable (DNS/conn failure)
- **Fast fallback** path (50ms connect timeout to `127.0.0.1:0`)
- Mocked real path via injected `Client`
- Inference service success
- Inference service non-200 handling
- Inference service malformed JSON handling
- Health endpoint
- Smoke route sanity

## Ops
- `ROLLBACK.md` present (image flip + flag kill switch)
- No prod schema changes

## Follow-ups (separate PRs)
- Remove sample **Todo/Fluent** dependency entirely (if desired)
- Optional: Swift 6 pilot branch (dual-toolchain CI)

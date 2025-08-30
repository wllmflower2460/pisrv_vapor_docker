# PR: Model sidecar integration + test hardening

## What changed
- **Model sidecar** scaffold (FastAPI) + compose override
- **Feature flag**: `USE_REAL_MODEL` with graceful fallback
- **HTTP client timeouts** (connect=1s, read=2s in tests)
- **Metrics**: route latency histogram labeled `useRealModel`
- **Test-mode configure**: in-memory DB/sessions, no file I/O
- **Fixed inference tests**: real `Request`, injectable `Client` mock
- **Switched to test discovery** (removed LinuxMain/manifests)

## Tests (8 total, all green)
- Stub path returns valid JSON
- Fallback path when sidecar unreachable (DNS/conn failure)
- Mocked real path via injected `Client`
- Inference service success
- Inference service non-200 handling
- Inference service malformed JSON handling
- Health endpoint
- Smoke route sanity

## Ops
- `ROLLBACK.md` re-added (image flip + flag kill switch)
- No prod schema changes

## Follow-ups (separate PRs)
- Remove sample **Todo/Fluent** code or exclude it to avoid Swift 6 warnings
- Optional: Swift 6 pilot branch (dual-toolchain CI)

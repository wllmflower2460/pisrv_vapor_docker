# AI Handoff: ChatGPT → Claude Code

**Date**: 2025-09-01  
**Handoff Type**: Strategic→System  
**Project**: PiSrv (Vapor, Swift 6)  
**Feature/Component**: Implement `/analysis/infer` and wire to Hailo sidecar  
**Session Continuity ID**: ADR-0007-pisrv-hailo-2025-09-01

---
**Navigation**: [[Master_MOC]] • [[Operations & Project Management]] • [[AI Collaboration]]

---

## 🔄 Context Transfer

### Previous Work Summary
**Upstream AI Session**: [[PiSrv Hailo Sidecar Integration – Handoff & Instructions]]  
**Key Decisions Made**: Keep sidecar private on the Docker network; standardize **port 8000**; PiSrv proxies to sidecar at `/infer`; iOS client calls PiSrv `/analysis/infer`; maintain contract `IMUWindow (100×9) → latent[64], motif_scores[12]`.  
**Current State**: iOS client is implemented & ready; PiSrv lacks `/analysis/infer`; monitoring stack present; Swift 6 PR in progress.  
**Completion Status**: Design finalized; server endpoint + tests pending.

### Handoff Objective
**Next AI Goal**: Add `POST /analysis/infer` to PiSrv with shape validation, stub mode via `USE_REAL_MODEL=false`, and real proxy to the sidecar when true. Update `.env.example`, add compose override for `hailo-inference`, and create XCTVapor tests.  
**Success Criteria**:  
- Endpoint returns 200 with arrays **64/12** (real or stub).  
- Bad shape returns **400**.  
- With `USE_REAL_MODEL=false` tests pass locally without sidecar.  
- With `USE_REAL_MODEL=true` integration passes against `hailo-inference:8000/infer`.  
**Time Constraint**: Small PR today.  
**Complexity Level**: medium

---

## 🎯 Technical Context for Claude

### Architecture Context
**System Design**: iOS → PiSrv → (internal) Hailo sidecar. Sidecar not exposed publicly.  
**Design Patterns**: feature flag fallback; internal DNS `hailo-inference`; contract-first.  
**Performance Requirements**: No PiSrv p95 regression; sidecar p95 < 50 ms/window on-device.  
**Integration Constraints**: Request: `{{ "x": [[Double]] /* 100×9 */ }}`; Response: `{{ "latent":[Double;64], "motif_scores":[Double;12] }}`.

### Implementation Context
**Code Patterns**: Vapor 4 routing, `Content` models, `Client` for proxying, XCTVapor tests.  
**Style Guidelines**: small, focused diffs; env-driven config; conventional commit.  
**Testing Requirements**: stub-mode test and shape-error test; optional integration test.  
**Documentation Standards**: README note + `.env.example` update + PR checklist.

### Hardware/Environment Context
**Deployment Targets**: GPUSrv (stub mode) and Pi 5 + Hailo-8 (real).  
**Container Dependencies**: `hailo-inference` container (8000); `/dev/hailo0` only on Pi.  
**Cross-Repo Impact**: iOS client expects PiSrv path `/analysis/infer`; `hailo_pipeline` provides the `.hef` for sidecar.

---

## 🧠 Decision Context (Prevent Knowledge Loss)

### Why These Decisions Were Made
**Business Rationale**: Faster iteration, safer rollbacks, clear module ownership.  
**Technical Rationale**: Keeps model execution isolated; metrics and health centralized in PiSrv.  
**Constraint Rationale**: Hailo device only on Pi; keep sidecar private to reduce surface area.  
**Timeline Rationale**: iOS client ready; server needs to unblock field pilots.

### Alternative Approaches Considered
**A**: Direct iOS → sidecar — *Rejected* (exposes port; duplicative config).  
**B**: Embed model in PiSrv — *Rejected* (tight coupling, slower upgrades).  
**C**: Public sidecar port — *Deferred* (internal-only suffices for now).

### Critical Dependencies
**Upstream**: Sidecar image & `.hef` available (integration case).  
**Downstream**: iOS client integration tests; monitoring scrape update.

---

## 📋 Implementation Guidance for Claude

### Specific Instructions
**Approach**:  
1) Add `AnalysisController` with `POST /analysis/infer`.  
2) Add `InferRequest`/`InferResponse` models.  
3) Add `HailoClient` reading `MODEL_BACKEND_URL` (default `http://hailo-inference:8000/infer`) + `BACKEND_TIMEOUT_MS` (default `1500`).  
4) Register routes in `routes.swift`.  
5) Tests: stub success (200, 64/12) and bad shape (400).  
6) Docs: `.env.example` entries + README snippet.

**Focus Areas**: exact **100×9** validation; reliable JSON proxy; clear errors; minimal diff.  
**Avoid**: exposing sidecar publicly; hard-coding URLs; skipping tests.  
**Prioritize**: stub-mode green first; then sidecar integration on Pi.

### Quality Expectations
**Code Quality**: professional  
**Documentation Level**: standard  
**Testing Coverage**: unit + light integration  
**Performance Level**: production

### Success Metrics
**Completion Criteria**: tests pass in stub; optional integration passes on Pi/GPUSrv.  
**Quality Gates**: `swift build` clean; XCTVapor tests green; route registered.  
**Performance Targets**: endpoint added without measurable p95 regression.  
**Integration Validation**: iOS contract test returns proper lengths 64/12.

---

## 🔄 Expected Feedback Collection

### Implementation Reality Check
**Expected Discoveries**: env var names to standardize; timeouts/tuning; monitoring scrape target.  
**Architecture Feedback Needed**: confirm final port **8000**; retry/backoff if needed.  
**Resource Requirements**: none beyond current Docker stack.

### Upstream Planning Impact
**ChatGPT Strategy Updates**: feed latency/timeout findings back to ADR.  
**Claude System Updates**: note any Vapor config tweaks for Swift 6 concurrency.  
**Future Session Planning**: plan health aggregator update to include backend_ok.

---

## 📝 Knowledge Spillover Prevention

### Critical Context (Don't Lose This)
**Paper Note Replacement**: exact env keys + route registration line.  
**Cross-Session Context**: sidecar remains internal-only.  
**Decision Rationale**: minimize change surface; enable client-first testing.  
**Implementation Constraints**: Hailo device path only on Pi.

### Learning Capture
**AI Collaboration Patterns**: smallest PRs; contract-first; stub-first.  
**Effective Prompts**: “shape 100×9 → 64/12; stub when flag false”.  
**Process Improvements**: add health aggregator in a follow-up PR.

---

## 🔗 Handoff Links
**Previous AI Session**: [[PiSrv Hailo Sidecar Integration – iOS Client Ready]]  
**Target AI Session**: [[PiSrv_/analysis/infer_Endpoint-Output-2025-09-01]] *(to be created)*  
**Related Architecture**: [[EdgeInfer_Deployment_Guide]] • [[Integrated_Migration_Swift6_Plan]]  
**Sprint Context**: [[2025-09 S1]]  
**Hardware Context**: [[Pi 5 + Hailo-8]]

---

## 📋 Handoff Checklist

### Pre-Handoff Validation
- [x] Context documented above
- [x] Technical requirements clearly specified
- [x] Success criteria defined and measurable
- [x] Dependencies identified and status confirmed
- [x] Quality expectations communicated

### Post-Handoff Follow-up
- [ ] Target AI session created successfully
- [ ] Implementation progressing as expected
- [ ] Feedback loop established for discoveries
- [ ] Knowledge spillover captured in target session
- [ ] Course corrections documented if needed

---

*AI Handoff: ChatGPT → Claude Code*  
*Session: PiSrv /analysis/infer Endpoint*  
*AI Stack: ChatGPT (Strategic) → Claude Code (System) → Copilot (Implementation)*  
*Handoff Quality: Professional knowledge transfer with spillover prevention*

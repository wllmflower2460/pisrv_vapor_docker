# Copilot Session: PiSrv_Hailo_Sidecar_Integration-Input

**Date**: 2025-09-01
**Status**: Planning
**Session Type**: Feature
**Estimated Time**: 2 hours
**Tags**: #copilot-input #pisrv #hailo-sidecar #vapor #swift6 #development
**Priority**: High
**Sprint**: 2025-09 S1
**Linked Output**: [[PiSrv_Hailo_Sidecar_Integration-Output]]
**Pair ID**: ADR-0007-PiSrv-2025-09-01
**Time Spent**: 0 minutes
**Session Start**: 2025-09-01 10:00
**Session End**: 2025-09-01 12:00

---
**Navigation**: [[Master_MOC]] • [[Operations & Project Management]] • [[Development Sessions]]

**Related**: [[ADR-0007_Refactor_Hailo_Pipeline_to_HailoRT_Sidecar_for_EdgeInfer]] • [[EdgeInfer_Deployment_Guide]] • [[Integrated_Migration_Swift6_Plan]] • [[Master_Task_Board]]

---

## 🤖 AI Collaboration Context

### Strategic Input (ChatGPT → Claude → Copilot)
**High-Level Direction**: Keep PiSrv focused on HTTP; run model in separate Hailo sidecar; connect via internal URL; keep sidecar private; expose metrics.
**Business Context**: Faster, safer deployments; clear ownership; easy rollback.
**System Design Context**: Feature flag (`USE_REAL_MODEL`), backend URL env, aggregate health, Prometheus scrape for both services.
**Cross-Stream Coordination**: Consumes `.hef` from `hailo_pipeline` and shares metrics with monitoring stack.

### Implementation Handoff (Claude → Copilot)
**Architecture Context**: Standardize sidecar on **9000**; DNS name `hailo-inference`; PiSrv client calls `/infer` endpoint directly.
**Code Patterns to Follow**: Vapor `Environment` config, dependency injection for backend client, Prometheus middleware.
**Integration Points**: `MODEL_BACKEND_URL`, `USE_REAL_MODEL`, `BACKEND_TIMEOUT_MS`; Prometheus jobs.

**Hardware Context**: GPUSrv (stub mode), Pi 5 + Hailo-8 (real).

**✅ IMPLEMENTATION STATUS**: Claude has completed all infrastructure setup. Copilot needs to verify and test the integration.

### Expected Feedback (Copilot → Claude/ChatGPT)
- Confirm port, path, and env names used in code.
- Report any latency regressions; note retry/backoff tuning needs.

---

## 🎯 Session Objectives

### Primary Goal
Wire the Hailo sidecar to PiSrv via compose override and env config; add monitoring; provide smoke tests.

### Success Criteria
- [x] `.env.example` updated (`USE_REAL_MODEL=true`, `MODEL_BACKEND_URL=http://hailo-inference:9000/infer`) ✅ DONE
- [x] `docker-compose.hailo.yml` added with sidecar service and `/dev/hailo0` (Pi only) ✅ DONE  
- [x] Prometheus adds job for `hailo-inference:9000`; cAdvisor host port not colliding with 8080 ✅ DONE
- [ ] Smoke tests pass (stub on GPUSrv, device on Pi) ⚠️ NEEDS TESTING

### Context & Background
PiSrv Swift 6 PR is open; integration is independent and low-risk. Monitoring currently scrapes PiSrv; add sidecar target.

**Related Epic/Feature**: EdgeInfer
**Technical Debt Context**: legacy “model runner” references; port inconsistency in docs.
**Business Value**: de-risked deployment; observability from day one.

---

## 📋 Pre-Session Planning

### Current State Assessment
**Files/Components Involved** (✅ COMPLETED BY CLAUDE):
- `docker-compose.yml` — base stack (unchanged)
- `docker-compose.hailo.yml` — ✅ DONE: override with `hailo-inference` service on port 9000
- `.env.example` — ✅ DONE: added `USE_REAL_MODEL`, `MODEL_BACKEND_URL` defaults
- `prometheus.yml` — ✅ DONE: added `hailo-inference:9000` scrape job
- `README.md` — ✅ DONE: comprehensive Docker + Hailo deployment section
- `scripts/smoke_test_hailo.sh` — ✅ DONE: integration testing script

**Known Issues/Technical Debt** (✅ RESOLVED):
- cAdvisor host port collision: ✅ FIXED - already on port 8081 in current setup
- Port standardization: ✅ DONE - standardized on port 9000 (matches existing .env.example)

**Dependencies**:
- Sidecar image tag published in registry.
- `.hef` artifact present on Pi (`./models:/models:ro`).

### Architecture Considerations
**Design Pattern**: sidecar pattern; internal-only service.
**Performance Requirements**: no PiSrv p95 regression; sidecar p95 < 50 ms/window.
**Security Considerations**: keep sidecar private; no host port unless needed.
**Testing Strategy**: stub smoke on GPUSrv; device smoke on Pi; health aggregator check.

---

## 🤖 Copilot Instructions

### Context for AI Assistant
```
PROJECT: pisrv_vapor_docker
COMPONENT: hailo_sidecar_integration
LANGUAGE: Swift 6 (Vapor), YAML
FRAMEWORK: Vapor 4 / Swift 6
AI STACK ROLE: Implementation (Copilot) - tactical code & config
UPSTREAM AI CONTEXT: Claude system design + ChatGPT strategic input
```

**Current Architecture**:
Vapor app exposes `/healthz` `/metrics` and app endpoints; model backend reachable via internal URL; monitoring stack with Prometheus.

**Code Style Preferences**:
- Small, focused diffs
- Env-driven configuration
- Clear README snippets

### Specific Implementation Requirements

#### Core Functionality
```markdown
REQUIREMENT 1: Compose override for sidecar ✅ COMPLETED
- Input: docker-compose.hailo.yml
- Output: ✅ DONE - service 'hailo-inference' on 9000; device mapping with profiles; mounts '/models:ro'
- Status: Complete with stub/device profiles for GPUSrv vs Pi deployment
```
```markdown
REQUIREMENT 2: Env defaults & client wiring ✅ COMPLETED
- Input: .env.example + Vapor Config
- Output: ✅ DONE - USE_REAL_MODEL defaults; MODEL_BACKEND_URL=http://hailo-inference:9000/infer
- Status: Complete with comprehensive configuration documentation
```
```markdown
REQUIREMENT 3: Monitoring update ✅ COMPLETED
- Input: prometheus.yml
- Output: ✅ DONE - scrape job for hailo-inference:9000; cAdvisor already on 8081
- Status: Complete with proper service discovery and labeling
```

#### Error Handling
```markdown
- Backend timeout → set 'backend_ok=false' in /healthz; log warn with correlation id
- Non-2xx from sidecar → return 502 to client; include 'backend_status' field
- Env misconfig (missing URL) → fail startup with clear message
```

#### Performance Targets
- PiSrv p95 unchanged
- Sidecar p95 < 50 ms/window on device

### Integration Points
**APIs to Call**:
- Sidecar: `POST /infer` (JSON body: `{{"x":[[float]*9]*100}}`), no auth internal-only

**Data Models** (Swift):
```swift
struct InferRequest: Content {{ let x: [[Double]] }}  // 100x9
struct InferResponse: Content {{ let latent: [Double]; let motif_scores: [Double] }} // 64, 12
```

**Existing Functions to Leverage**:
- `HealthController` — extend to include `backend_ok`
- Metrics middleware — export `build_info`, `config_ok`

---

## 🔧 Technical Approach

### Implementation Strategy
**Phase 1**: Config & compose
- [ ] Add override file & env defaults
- [ ] Adjust Prometheus jobs + cAdvisor mapping

**Phase 2**: Code wiring
- [ ] Backend client with timeout from env
- [ ] `/healthz` aggregate call to sidecar with short timeout

**Phase 3**: Smoke & docs
- [ ] Stub run on GPUSrv; device run on Pi
- [ ] README updates with `docker compose` commands

### Testing Plan
**Integration Tests**:
- [ ] Stub: POST `/infer` returns correct keys/lengths (64/12)
- [ ] Pi: same contract; check p95 on sample run

**Manual Testing Checklist**:
- [ ] `docker compose config` valid
- [ ] Prometheus shows `hailo-inference` target UP
- [ ] cAdvisor reachable on 8081 (if mapped)

---

## ⚠️ Risk Assessment

**Technical Risks**: misaligned ports/paths (Low/Medium) — Mitigation: standardize 8000 + `/infer`.
**Decision Points**: public port for sidecar? default **No**.
**Fallback**: set `USE_REAL_MODEL=false` to stub; revert compose override.

---

## 📖 Reference Materials

- ADR-0007 (EdgeInfer + Sidecar decisions)
- PiSrv Monitoring readme (Prometheus jobs)
- Hailo Pipeline Docker Installation Plan

---

## 🎮 Session Execution Plan

### Environment Setup
- [ ] `.env` populated
- [ ] Sidecar image tag known
- [ ] `.hef` present on Pi

### Development Workflow
1. Add compose override + env defaults — 30m
2. Monitoring config adjustments — 20m
3. Wire backend client & health aggregator — 40m
4. Smoke tests (stub + device) — 30m

### Validation Steps
- [ ] Contract smoke passes (64/12)
- [ ] Prometheus target UP for sidecar
- [ ] No port collisions; `docker compose ps` healthy

---

## 📝 Implementation Notes

To be filled during dev.

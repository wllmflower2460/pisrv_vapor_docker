# AI Handoff: ChatGPT → Claude Code (PiSrv / Vapor / Swift 6 + Hailo Sidecar)

**Date**: 2025-09-01
**Handoff Type**: Strategic→System
**Project**: PiSrv (Vapor, Swift 6)
**Feature/Component**: Integrate Hailo sidecar + standardize backend wiring & monitoring
**Session Continuity ID**: ADR-0007-pisrv-hailo-2025-09-01

---
**Navigation**: [[Master_MOC]] • [[Operations & Project Management]] • [[AI Collaboration]]

---

## 🔄 Context Transfer

### Previous Work Summary
**Upstream AI Session**: [[ADR-0007_Refactor_Hailo_Pipeline_to_HailoRT_Sidecar_for_EdgeInfer]]
**Key Decisions Made**: decouple model runtime from PiSrv; run Hailo sidecar as a container; expose `/infer` contract (100×9 → latent[64], motif_scores[12]); standardize on port **8000** for the sidecar inside the PiSrv network; feature flag `USE_REAL_MODEL`; Prometheus scrape for both PiSrv and sidecar.
**Current State**: `hailo_pipeline` repo provides `.hef` via artifacts and a runtime image; PiSrv repo upgraded to Swift 6 branch; compose files documented; monitoring stack present.
**Completion Status**: Ready to implement compose override and env wiring in PiSrv; docs mostly aligned.

### Handoff Objective
**Next AI Goal**: Implement the Hailo sidecar integration in **pisrv_vapor_docker** with a compose override, env defaults, health/metrics scraping, and a small smoke test.
**Success Criteria**: (1) PiSrv points to `http://hailo-inference:8000/infer` when `USE_REAL_MODEL=true`; (2) `docker compose -f docker-compose.yml -f docker-compose.hailo.yml up -d` runs cleanly; (3) Prometheus scrapes sidecar; (4) contract smoke passes; (5) cAdvisor port collision resolved.

**Time Constraint**: begin now; aim for same-day PR.
**Complexity Level**: medium

---

## 🎯 Technical Context for Claude

### Architecture Context
**System Design**: PiSrv (Vapor) is the edge API; Hailo sidecar is a sibling container in the same docker network. PiSrv uses an env-configured backend URL and provides aggregate health/metrics.
**Design Patterns**: feature flag fallback (`USE_REAL_MODEL`); sidecar behind internal DNS name `hailo-inference`; contract-first endpoint.
**Performance Requirements**: maintain PiSrv p95 latency with sidecar < 50 ms/window on-device; zero regression in PiSrv request latencies.
**Integration Constraints**: PiSrv must call `/infer` with payload `{{ "x": [[float]*9]*100 }}` and expect `latent[64]`, `motif_scores[12]`.

### Implementation Context
**Code Patterns**: Swift 6 / Vapor environment config, typed clients, structured logging, Prometheus exporter already enabled for PiSrv.
**Style Guidelines**: keep service names/env keys consistent; small PR; conventional commit `chore(scope): enable hailo sidecar`.
**Testing Requirements**: one integration smoke (stub locally), one device smoke on Pi; add `/healthz` aggregator assertion.
**Documentation Standards**: update `.env.example`, README “Run” section, and Monitoring readme.

### Hardware/Environment Context
**Deployment Targets**: GPUSrv (stub) and Pi 5 + Hailo-8 (real).
**Container Dependencies**: sidecar image `ghcr.io/wllmflower2460/hailo-sidecar:<tag>`; volumes `/models:ro` on Pi only.
**Cross-Repo Impact**: consumes `.hef` from `hailo_pipeline`; no changes to `TCN-VAE_models`.

---

## 🧠 Decision Context (Prevent Knowledge Loss)

### Why These Decisions Were Made
**Business**: clear boundaries; faster iterations; safer rollbacks.
**Technical**: decouple model execution; compose override avoids branching the core stack; standard metrics across services.
**Constraints**: Hailo device only on Pi; keep sidecar internal; avoid port collisions.

### Alternatives Considered
**A**: embed model code in PiSrv — rejected (tight coupling, harder upgrades).
**B**: sidecar on 9000 — rejected to minimize doc churn; 8000 matches existing guide.
**C**: public sidecar port — deferred; prefer internal-only + Prometheus network scrape.

### Critical Dependencies
**Upstream**: a versioned `.hef` + checksum and working sidecar image.
**Downstream**: EdgeInfer clients already configurable via `MODEL_BACKEND_URL`.

---

## 📋 Implementation Guidance for Claude

### Specific Instructions
**Approach**: Introduce a compose override and env defaults; update monitoring; add smoke scripts; align docs.
**Focus Areas**: URL/port consistency; health/metrics; cAdvisor port fix; safe fallback.
**Avoid**: baking `.hef` into PiSrv images; exposing sidecar publicly; port 8080 collision with cAdvisor.
**Prioritize**: smallest PR that enables end-to-end flow.

### Quality Expectations
**Code Quality**: professional
**Documentation Level**: standard (README + .env.example + monitoring)
**Testing Coverage**: integration smoke (stub + device)
**Performance Level**: production

### Success Metrics
**Completion Criteria**: compose override runs on both GPUSrv (stub) and Pi (device); Prometheus scrapes `hailo-inference:8000`; contract smoke passes.
**Quality Gates**: `docker compose config` validates; health/metrics reachable; no port clashes.
**Performance Targets**: unchanged PiSrv API p95; sidecar p95 < 50 ms/window (measured on device).
**Integration Validation**: PiSrv `/healthz` shows `backend_ok=true`; curl to `/analysis/*` path exercises sidecar.

---

## 🔄 Expected Feedback Collection

**Expected Discoveries**: any mismatch in port, path (`/infer`), or env naming; Prometheus scrape interval tuning.
**Architecture Feedback Needed**: confirm final decision to standardize on port 8000; report if Vapor client needs retry/backoff tuning.
**Resource Requirements**: none beyond current compose/Prometheus stack.

---

## 📝 Knowledge Spillover Prevention

**Paper Note Replacement**: commit PR description listing env keys and the exact compose command; document `hef_sha256` surface via `/healthz`.
**Cross-Session Context**: ensure README cites the exact sidecar image tag.
**Decision Rationale**: minimize change surface area; keep sidecar private; align monitoring.

---

## 🔗 Handoff Links

**Previous AI Session**: [[ADR-0007_Refactor_Hailo_Pipeline_to_HailoRT_Sidecar_for_EdgeInfer]]
**Target AI Session**: [[PiSrv_Hailo_Sidecar_Integration-Output-2025-09-01]] *(to be created)*
**Related Architecture**: [[EdgeInfer_Deployment_Guide]], [[Integrated_Migration_Swift6_Plan]]
**Sprint Context**: [[2025-09 S1]]
**Hardware Context**: [[Pi 5 + Hailo-8]]

---

## 📋 Handoff Checklist

### Pre-Handoff Validation
- [x] Context documented above
- [x] Technical requirements specified
- [x] Success criteria measurable
- [x] Dependencies identified
- [x] Quality expectations communicated

### Post-Handoff Follow-up
- [ ] Target AI session created
- [ ] Implementation progressing as expected
- [ ] Feedback captured & reflected into ADR
- [ ] Monitoring dashboards updated
- [ ] Course corrections documented

---

*AI Handoff: ChatGPT → Claude Code*
*Session: PiSrv Hailo Sidecar Integration*
*AI Stack: ChatGPT (Strategic) → Claude Code (System) → Copilot (Implementation)*
*Template source:* (See AI handoff template citation in Chat)

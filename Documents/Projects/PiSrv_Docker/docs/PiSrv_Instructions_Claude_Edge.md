# Copilot Session: {{session-name}}

**Date**: {{date:YYYY-MM-DD}}  
**Status**: {{Planning/Active/Complete}}  
**Session Type**: {{Feature/Bug Fix/Refactor/Investigation}}  
**Estimated Time**: {{XX}} hours  
**Tags**: #copilot-input #{{component}} #{{feature}} #development  
**Priority**: {{High/Medium/Low}}  
**Sprint**: {{sprint-name}}  
**Linked Output**: [[{{session-name}}-Output]]  
**Pair ID**: {{pair-id}}  
**Time Spent**: {{0}} minutes  
**Session Start**: {{YYYY-MM-DD HH:MM}}  
**Session End**: {{YYYY-MM-DD HH:MM}}  

---
**Navigation**: [[Master_MOC]] • [[Operations & Project Management]] • [[Development Sessions]]

**Related**: [[{{output-session-name}}-Output]] • [[{{related-feature}}]] • [[Master_Task_Board]]

---

## 🤖 AI Collaboration Context

### Strategic Input (ChatGPT → Claude → Copilot)
**High-Level Direction**: {{strategic-guidance-from-chatgpt}}  
**Business Context**: {{why-this-matters-strategically}}  
**System Design Context**: {{claude-architecture-decisions}}  
**Cross-Stream Coordination**: {{how-this-affects-other-repos}}

### Implementation Handoff (Claude → Copilot)
**Architecture Context**: {{system-design-decisions}}  
**Code Patterns to Follow**: {{existing-patterns-in-codebase}}  
**Integration Points**: {{what-connects-to-what}}  
**Hardware Context**: {{which-environments-affected}}

### Expected Feedback (Copilot → Claude/ChatGPT)
**Implementation Reality Check**: *[To be filled - what actually worked vs planned]*  
**Architecture Impact**: *[To be filled - discoveries affecting system design]*  
**Cross-AI Learning**: *[To be filled - insights for future AI collaboration]*

---

## 🎯 Session Objectives

### Primary Goal
*[What are we trying to accomplish in this coding session?]*

### Success Criteria
- [ ] {{success-criterion-1}}
- [ ] {{success-criterion-2}}
- [ ] {{success-criterion-3}}

### Context & Background
*[Why are we doing this work? What led to this session?]*

**Related Epic/Feature**: [[{{parent-feature}}]]  
**Technical Debt Context**: {{debt-description}}  
**Business Value**: {{value-statement}}  

---

## 📋 Pre-Session Planning

### Current State Assessment
**Files/Components Involved**:
- `{{file-path-1}}` - {{current-state}}
- `{{file-path-2}}` - {{current-state}}
- `{{file-path-3}}` - {{current-state}}

**Known Issues/Technical Debt**:
- {{issue-1}} - {{impact-level}}
- {{issue-2}} - {{impact-level}}

**Dependencies**:
- {{dependency-1}} - {{status}}
- {{dependency-2}} - {{status}}

### Architecture Considerations
**Design Pattern**: {{pattern-choice}}  
**Performance Requirements**: {{requirements}}  
**Security Considerations**: {{security-notes}}  
**Testing Strategy**: {{test-approach}}  

---

## 🤖 Copilot Instructions

### Context for AI Assistant
```
PROJECT: {{project-name}}
COMPONENT: {{component-name}}
LANGUAGE: {{primary-language}}
FRAMEWORK: {{framework-version}}
AI STACK ROLE: Implementation (Copilot) - Focus on tactical code generation
UPSTREAM AI CONTEXT: {{claude-system-design}} | {{chatgpt-strategic-input}}
```

**Current Architecture**:
*[Brief description of existing system structure]*

**Code Style Preferences**:
- {{style-preference-1}}
- {{style-preference-2}}
- {{style-preference-3}}

### Specific Implementation Requirements

#### Core Functionality
```markdown
REQUIREMENT 1: {{requirement-description}}
- Input: {{input-spec}}
- Output: {{output-spec}}  
- Constraints: {{constraints}}
- Edge Cases: {{edge-cases}}
```

#### Error Handling
```markdown
- {{error-condition-1}} → {{handling-strategy}}
- {{error-condition-2}} → {{handling-strategy}}
- {{error-condition-3}} → {{handling-strategy}}
```

#### Performance Targets
- {{metric-1}}: Target {{target-value}}
- {{metric-2}}: Target {{target-value}}
- {{metric-3}}: Target {{target-value}}

### Integration Points
**APIs to Call**:
- {{api-1}} - {{endpoint}} - {{auth-method}}
- {{api-2}} - {{endpoint}} - {{auth-method}}

**Data Models**:
```{{language}}
{{data-structure-1}}
{{data-structure-2}}
```

**Existing Functions to Leverage**:
- `{{function-1}}()` in `{{file-path}}` - {{purpose}}
- `{{function-2}}()` in `{{file-path}}` - {{purpose}}

---

## 🔧 Technical Approach

### Implementation Strategy
**Phase 1**: {{phase-description}}
- [ ] {{task-1}}
- [ ] {{task-2}}

**Phase 2**: {{phase-description}}  
- [ ] {{task-3}}
- [ ] {{task-4}}

**Phase 3**: {{phase-description}}
- [ ] {{task-5}}
- [ ] {{task-6}}

### Testing Plan
**Unit Tests**:
- [ ] {{test-case-1}} - {{expected-behavior}}
- [ ] {{test-case-2}} - {{expected-behavior}}

**Integration Tests**:
- [ ] {{integration-test-1}} - {{scenario}}
- [ ] {{integration-test-2}} - {{scenario}}

**Manual Testing Checklist**:
- [ ] {{manual-test-1}}
- [ ] {{manual-test-2}}
- [ ] {{manual-test-3}}

---

## ⚠️ Risk Assessment

### Technical Risks
- **{{risk-1}}**: {{probability}} / {{impact}} - Mitigation: {{mitigation-strategy}}
- **{{risk-2}}**: {{probability}} / {{impact}} - Mitigation: {{mitigation-strategy}}

### Decision Points
- **{{decision-point-1}}**: {{options}} - Decision criteria: {{criteria}}
- **{{decision-point-2}}**: {{options}} - Decision criteria: {{criteria}}

### Fallback Options
- **Plan B**: {{alternative-approach}}
- **Rollback Strategy**: {{rollback-plan}}

---

## 📖 Reference Materials

### Documentation
- [[{{technical-doc-1}}]] - {{relevance}}
- [[{{technical-doc-2}}]] - {{relevance}}
- {{external-doc-url}} - {{description}}

### Similar Implementations
- `{{reference-file-1}}` - {{similarity}} - {{lessons-learned}}
- `{{reference-file-2}}` - {{similarity}} - {{lessons-learned}}

### Research/Design Decisions
- [[{{research-paper}}]] - {{applicable-technique}}
- [[{{design-decision}}]] - {{architectural-choice}}

---

## 🎮 Session Execution Plan

### Environment Setup
- [ ] {{setup-step-1}}
- [ ] {{setup-step-2}}
- [ ] {{setup-step-3}}

### Development Workflow
1. **{{step-1}}** - {{description}} - Est. {{time}}
2. **{{step-2}}** - {{description}} - Est. {{time}}
3. **{{step-3}}** - {{description}} - Est. {{time}}

### Validation Steps
- [ ] Code compiles without warnings
- [ ] All tests pass
- [ ] Performance benchmarks met
- [ ] Security scan clean
- [ ] Code review ready

---

## 📝 Implementation Notes

### Key Decisions Made
*[To be filled during development]*

### Unexpected Challenges
*[To be filled during development]*

### Performance Observations
*[To be filled during development]*

### Code Quality Metrics
*[To be filled during development]*

---

## 🤖 AI Collaboration Feedback Capture

### Copilot Implementation Reality
**What Actually Worked**: *[Implementation discoveries vs planned approach]*  
**Code Pattern Effectiveness**: *[Which patterns Copilot handled well/poorly]*  
**Architecture Feedback**: *[Implementation insights affecting system design]*

### Cross-AI Learning Insights
**Effective Prompts**: *[What worked well for Copilot in this session]*  
**Integration Points**: *[How well the Claude → Copilot handoff worked]*  
**System Impact**: *[Implementation discoveries that affect Claude/ChatGPT planning]*

### Knowledge Spillover Capture
**Paper Note Replacement**: *[Critical details that would otherwise be lost]*  
**Future Session Inputs**: *[Context that should inform future AI sessions]*  
**Technical Debt Created**: *[Shortcuts or compromises that need future attention]*

---

## 🔗 Session Links

**Output Documentation**: [[{{session-name}}-Output]]  
**Related Sessions**: [[{{previous-session}}]] | [[{{next-session}}]]  
**Feature Epic**: [[{{parent-epic}}]]  
**Sprint Board**: [[{{sprint-board}}]]  
**AI Architecture Session**: [[{{upstream-claude-session}}]]  
**AI Strategic Session**: [[{{upstream-chatgpt-session}}]]

---

## 📋 Session Checklist

### Pre-Development
- [ ] Requirements clearly defined
- [ ] Architecture approach documented
- [ ] Test cases identified
- [ ] Dependencies verified
- [ ] Environment ready
- [ ] AI context handoff complete

### During Development  
- [ ] Code follows style guidelines
- [ ] Error handling implemented
- [ ] Performance targets considered
- [ ] Security requirements met
- [ ] Tests written and passing
- [ ] AI collaboration documented

### Post-Development
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Output session created
- [ ] Git commits well-structured
- [ ] Next steps identified
- [ ] AI feedback captured for upstream planning

---

*Session: {{session-name}}*  
*Developer: {{developer-name}}*  
*AI Stack: ChatGPT (Strategic) → Claude Code (System) → Copilot (Implementation)*  
*Copilot Version: {{copilot-version}}*  
*IDE: {{ide-and-version}}*
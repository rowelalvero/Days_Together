# Roadmap: days_together

## Overview

A two-phase journey from stabilizing the core Supabase streams and database connectivity to polishing the visual and layout elements of the couple's shared memory application.

## Phases

- [x] **Phase 1: Foundation & Stream Stabilization** - Resolve memory leaks, query crashes, rate limit issues, and layout overflows.
- [ ] **Phase 2: UI/UX & Styling Polish** - Clean up hardcoded colors, normalize layout spacing gaps, and refine generic button copy.

## Phase Details

### Phase 1: Foundation & Stream Stabilization
**Goal**: Ensure stream connection stability, prevent rate limit lockouts, and resolve UI crashes.
**Depends on**: Nothing
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FOUND-06
**Success Criteria**:
  1. No unhandled Supabase stream exceptions in logs.
  2. Stream counts remain low and lazy-loaded.
  3. Navigating screens and unlinking couple profile works without crashes.
  4. Header avatar row does not overflow horizontally.
**Plans**: 1 plan

Plans:
- [x] 01-01: Stable cleanup and Postgrest query updates

### Phase 2: UI/UX & Styling Polish
**Goal**: Fully migrate codebases to dynamic themed color variables, normalize layout margins, and specify context buttons.
**Depends on**: Phase 1
**Requirements**: POL-01, POL-02, POL-03
**Success Criteria**:
  1. Changing application theme updates all container, background, and accent colors dynamically.
  2. All padding/margin widgets match 4px/8px multiples.
  3. Onboarding/settings button copy matches user action (e.g. "Join couple", "Sign In").
**Plans**: 1 plan

Plans:
- [ ] 02-01: Style refactoring and copywriting updates

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 1/1 | Complete | 2026-06-19 |
| 2. UI/UX Polish | 0/1 | Not started | - |

# ADR-012: Testing Strategy

## Status
Accepted

## Context
**CURRENT STATE, verified:** the repository has 82 passing tests (`flutter test`), covering model serialization, pure-function correctness (e.g. `StorageUrlService`'s path-classification logic added during the storage-security remediation), and a hydration-preservation regression test for `RelationshipProvider`'s avatar handling. **Zero widget tests exist.** This is not an oversight — it is a direct, structural consequence of ADR-010's finding: with no dependency injection, a widget test would need to exercise a real Supabase client, real platform channels, and real global singletons, which is impractical, so none were written.

The Definition of Done requires three specific categories of new coverage that are currently unreachable: critical state hydration regression tests (item 18), realtime lifecycle regression tests (item 19), and auth/pairing widget or integration coverage (item 20) — plus a mechanism enforcing architectural rules themselves (items 1, 2, 7, 9, 11, 12, 15, 17), which is a category of test that doesn't exist in the current suite at all.

## Problem
Without ADR-002's Riverpod adoption (which enables fakeable dependencies via `ProviderScope` overrides), the three DoD test categories remain structurally unreachable regardless of how much test-writing effort is spent. Separately, several of the DoD's architectural criteria (no Supabase in UI, no cross-feature imports, no `dynamic theme`, all-`final` models) are the kind of rule that manual review reliably lets slip over time unless a machine checks it on every run.

## Options considered

1. **Rely on manual code review for architectural rules; write conventional unit/widget/integration tests only.** Rejected: the audit itself is proof this doesn't hold — several of the violations found (the `love_notes` table-key collision, `RelationshipRepository` going unused for its entire existence, the `dynamic theme` pattern spreading to nearly every widget boundary) are exactly the kind of gradual drift that code review alone failed to catch over the app's actual development history.
2. **A full formal testing pyramid with a target coverage percentage enforced in CI.** Rejected as its own goal: the planning brief explicitly asks to avoid "arbitrary rules that do not provide practical value," and a coverage-percentage target divorced from *what* is covered would incentivize testing the easiest code (models, pure functions — already well-covered) rather than the hardest, highest-risk code (hydration, realtime lifecycle, auth/pairing — currently at zero).
3. **A right-sized pyramid targeted at the app's actual risk areas, plus a dedicated architecture-test suite as a distinct, always-run category.** Chosen.

## Decision

**Pyramid shape**, by layer:

- **Unit tests (base, largest volume):** pure functions (`DateHelper`, the consolidated duration/milestone math per ADR-009), model serialization round-trips (existing pattern, keep), repository row-mapping against fake row maps — no network (ADR-003's three repositories; this is called out in the migration roadmap as "the highest-value tests available" for that phase), and `AppFailure` mapping logic (ADR-011).
- **Widget tests (middle):** newly possible once `CoupleSession` exists behind `ProviderScope` (Phase 1) — specifically, pumping `AppHome`/the router against a faked `CoupleSession` across all 7 `SessionStage` values and asserting the correct screen/redirect, satisfying DoD item 20's "auth/pairing widget coverage" directly. This becomes the template for testing any screen whose content depends on session/pairing state.
- **Integration tests (top, smallest volume, most expensive):** end-to-end flows through real widget trees with faked data sources — pairing (create code → join → paired), disconnect/re-pair, and the scrapbook-share cross-feature transaction (ADR-009's `ScrapbookShareUseCase`) once extracted, since it is the one process worth testing as a whole sequence rather than as isolated units.

**A fourth, parallel category — architecture tests** (`test/architecture_test.dart`, introduced empty-but-real in Migration Phase 0, tightened as each phase lands): filesystem/import-graph assertions that directly encode the Definition-of-Done's structural criteria (no Supabase import in `screens/`/`widgets/`, no cross-feature imports, no `dynamic theme` parameter, all-`final` models, no raw `SharedPreferences` string literal outside `PrefsKeys`). These run under plain `flutter test` — no new tooling — and are the mechanism that converts eight DoD checklist items from "true right now, hopefully still true later" into "the test suite fails the moment it becomes false."

**The two specifically named DoD test artifacts:**
- **Item 18 (hydration regression):** one test seeding `SharedPreferences.setMockInitialValues` with a realistic, full 41-key map captured from a real device, asserting every state-ownership unit from ADR-002/Phase 5 (`CoupleSession`, `LicenseController`, `ProfileController`, `WorkspaceController`, `PresenceController`) hydrates identically before and after each extraction step. Written **before** the second extraction, not after all five — it is the safety net the extraction relies on, not a final check.
- **Item 19 (realtime lifecycle):** tests against `RealtimeSubscriptionManager` (kept as infrastructure per ADR-005) asserting single-subscription-per-key under concurrent listeners, teardown on last-listener-removed, no duplicate on rapid re-subscribe, and full teardown on disconnect/logout.

**Mocking approach:** no new mocking library is introduced (`mockito`/`mocktail` are absent from `dev_dependencies` today). Riverpod's `ProviderScope(overrides: [...])` is the fake-injection mechanism throughout — consistent with ADR-002 and ADR-010, and sufficient for the app's needs without adding a codegen-adjacent dependency.

## Reasons

- The three currently-missing test categories (hydration, realtime lifecycle, auth/pairing) are structurally blocked by the absence of DI, not by a lack of effort — sequencing this strategy to land alongside Riverpod (ADR-002) is what makes it achievable at all, rather than aspirational.
- Manual review has already been shown, by the app's own development history, not to reliably catch structural drift (the `love_notes` collision, the unused `RelationshipRepository`, the spreading `dynamic theme` pattern) — an automated architecture-test suite closes exactly that gap.
- Targeting tests at the app's actual risk concentration (session/auth/realtime) rather than a coverage percentage directs limited solo-developer testing effort where a regression would be most costly.

## Consequences

**Positive:** the three currently-unreachable DoD test categories become reachable as a direct, sequenced consequence of the Riverpod migration rather than requiring separate infrastructure work. The architecture-test category gives eight DoD items permanent, automatic enforcement instead of one-time verification at migration completion.

**Negative:** the pyramid's widget/integration tiers cannot be built before Phase 1 completes (they depend on `ProviderScope` existing) — meaning DoD items 18–20 are necessarily mid-to-late-roadmap deliverables, not something addressable in Phase 0. This is accepted as a sequencing consequence of ADR-002, not a flaw in this ADR.

## Rejected alternatives
- Manual review only, no architecture-test suite (option 1) — demonstrated insufficient by the app's own development history.
- Coverage-percentage-driven testing (option 2) — misaligned incentive relative to the app's actual risk concentration.

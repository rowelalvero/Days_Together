# ADR-003: Repository Pattern — Scoped to Three Tables

## Status
Accepted

## Context
**CURRENT STATE**, verified: `lib/repositories/` contains two files. `relationship_repository.dart` (83 lines) maps Supabase rows to typed domain models (`UserProfile`, `RelationshipWorkspace`, `RelationshipMetadata`) but has **zero call sites anywhere in `lib/`** — it is dead code. Its API is duplicated by `CoupleService` and `ProfileService`, which are used, but return raw `Map<String, dynamic>` rather than typed models. `timeline_repository.dart` (68 lines) has no Supabase dependency at all — it is a SharedPreferences/file-IO helper, and is instantiated by `theme_provider.dart` and `music_provider.dart` solely to reach `AppSettings` persistence, a naming/cohesion mismatch.

Meanwhile, **13 of the 16 providers embed raw Supabase query builders directly** (`.from(...)`, `.rpc(...)`, `.storage`), with no repository or DTO boundary at all.

The service layer, by contrast, is healthy: 15 files, average 145 lines, each with one clear responsibility, no god services.

## Problem
Two failure modes exist simultaneously and pull in opposite directions:
1. A repository pattern was attempted once, built correctly (typed models, clean mapping), and then abandoned in favor of Map-returning services — so simply "using more repositories" repeats a pattern that already failed to stick.
2. Yet the one place a repository boundary would earn its keep — the `users`/`couples`/`license_details` tables, which are read by many consumers and whose columns leak directly into `relationship_license_screen.dart` (5,025 lines) as raw map keys — has no such boundary at all.

## Options considered

1. **Repository per table (16 repositories).** Rejected: this is what the service layer already is, in essence, and the audit found no god-service problem to fix. Sixteen thin wrapper classes over what are frequently 3–5-line query builders is pure ceremony, and mirrors the pattern that was already tried once (item 2 above) and produced Map-returning duplicates rather than adoption.
2. **No repositories; providers keep calling Supabase directly everywhere, formalize services instead.** Rejected: it leaves the one genuine problem — untyped, leaking column names in the highest-fan-in tables (`users`, `couples`, `license_details`, each read by the largest god files) — unaddressed.
3. **Repositories only where the pattern earns its keep, by an explicit rule.** Chosen.

## Decision
**This is a standing test to re-apply as the schema evolves, not a permanent numeric limit.** Adopt a repository **only** when a table satisfies **both**:
(a) it is read by more than one consumer, **and**
(b) its rows must become a typed model that outlives the single query that produced it (i.e., the model is passed around, cached, or compared — not just displayed once).

Repository count is driven by responsibility against this two-part test, not by a fixed target. Applying it to the **current** schema yields exactly **three** repositories:

| Repository | Table(s) | Why it qualifies |
|---|---|---|
| `UserRepository` | `users` | Read by `CoupleSession`, `ProfileController`, `presence`, and `relationship_license_screen.dart` directly. Model (`UserProfile`) already exists. |
| `CoupleRepository` | `couples` | Read by `CoupleSession`, `WorkspaceController`, pairing/recovery flows. Model (`RelationshipWorkspace`) already exists. |
| `LicenseRepository` | `license_details` | Read by `ProfileService.fetchLicenseDetails` today and subscribed to via realtime. **Note, discovered during specification verification (full trail in `migration-roadmap.md`'s Phase 0 section):** despite the name, this repository does **not** back the license screen's 28 `_your*`/`_partner*` fields — those live-write through the `users` table today (`LicenseController` depends on `UserRepository`, not this one — see `state-management.md`). `LicenseRepository`'s actual scope is the narrower certificate-metadata columns (`certificate_number` and others confirmed present in the live database but absent from the tracked migration history — a confirmed case of undocumented schema drift). Model (`RelationshipMetadata`, to be re-verified against the live schema before Phase 4) already exists as a starting point. |

The other 12 couple-scoped tables (`bucket_list`, `calendar_events`, `daily_questions`, `gift_reminders`, `love_notes`, `moods`, `time_capsules`, `timeline_items`, `topic_cards`, `topic_card_likes`, `vault_items`, `love_taps`) keep their single-owner provider calling Supabase inline (or through `SupabaseLifecycleProvider`'s existing abstraction). Each is a one-provider, single-table concern with a 3–8-line query — a repository there would wrap one caller in one interface, which is the ceremony rejected in Option 1.

`relationship_repository.dart`'s row-mapping code (the only correctly-typed prior art in the codebase) is not deleted outright — it is preserved as the starting point for the three new repositories (Migration Phase 0 explicitly copies it to a scratch note before deletion, then Phase 4 builds from it).

## Reasons

- Repository-per-table was already tried once in this codebase (the now-dead `RelationshipRepository`) and was abandoned in favor of Map-returning services — repeating that pattern app-wide would likely fail the same way again.
- The two-part test targets the one real, documented pain point (leaking `license_details` column names into a 5,025-line screen) precisely, without imposing ceremony on the 12 tables that don't exhibit that problem.
- The service layer is already healthy (15 files, no god services) — there is no corresponding problem there for a blanket repository mandate to solve.

## Consequences

**Positive:** the highest-value typing gap (three tables feeding the two largest god files) is closed without repeating the ceremony that failed the first time. `DateHelper`, `AIService`, `MusicService`, `PermissionService`, and the other 11 healthy services remain untouched — no forced repository wrapping.

**Negative:** the rule requires judgment at the margins (e.g., if `topic_card_likes` grows a second consumer later, it would newly qualify) — this is deliberately a living rule re-applied per ADR-001's feature boundaries, not a closed list. **A future repository may be introduced at any point the same two-part test is satisfied; "three" describes today's schema, not a ceiling.**

**Neutral:** this ADR governs *repository existence*, not *model immutability* — immutability is a separate, broader rule (ADR applies to all models; see the model-immutability rule folded into Migration Phase 4 and the architecture test suite in `testing-strategy.md`) covering five specific mutable models beyond just these three tables.

## Rejected alternatives
- Repository-per-table (option 1) — ceremony without a corresponding problem; repeats a pattern that already failed once.
- No repositories at all (option 2) — leaves the one real, documented pain point (leaking `license_details` column names into a 5,025-line screen) unaddressed.

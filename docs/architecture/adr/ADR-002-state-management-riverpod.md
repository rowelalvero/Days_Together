# ADR-002: State Management — Migrate to Riverpod

## Status
Accepted

## Context
Days Together uses `provider`/`ChangeNotifier` with 16 provider classes wired in `lib/main.dart` via `MultiProvider`. 13 of the 16 extend a hand-rolled `SupabaseLifecycleProvider`/`RelationshipLifecycleProvider` base (`lib/services/relationship_lifecycle_manager.dart`, 259 lines) that reimplements:
- realtime-subscription lifetime tied to `addListener`/`removeListener` counts (`SupabaseLifecycleProvider:216-231`),
- a broadcast hub for pair/repair/disconnect/logout (`RelationshipLifecycleManager.handlePair` etc.),
- cache purging on disconnect (`purgeCache`).

**CURRENT STATE:** the app additionally has **13 hand-rolled singletons** across three different idioms (`static final X instance = X._()`; `static final _instance + factory`; `static final instance + factory`) providing what amounts to unmanaged, unmockable dependency injection — this is why `lib/widgets/storage_image.dart` can reach `StorageUrlService.instance` directly, bypassing every provider boundary. There are **zero widget tests** in the 82-test suite, because nothing in the current architecture is fakeable.

All 13 domain providers are wired as `ChangeNotifierProxyProvider<RelationshipProvider, X>` against a 2,143-line god provider — verified to depend on exactly four of its members (`userId`, `coupleId`, `partnerId`, `isSupabaseAvailable`), see ADR-003 for the consequence of that finding.

## Problem
1. No dependency injection → nothing is fakeable → zero widget/integration test coverage is possible today for auth, pairing, or realtime flows (Definition-of-Done items 18–20 are unreachable without it).
2. `relationship_lifecycle_manager.dart` hand-rolls exactly what `ref.onDispose`/`autoDispose`/provider families give for free, and has already produced one real bug class: the `love_notes` table-key collision between `noteit_provider` and `love_chat_provider`.
3. `ProxyProvider` chains encode "watch this, rebuild that" relationships that are Riverpod's `ref.watch` by construction, with compile-time provider references instead of runtime string-keyed lookups.

## Options considered

1. **Stay on Provider, formalize existing patterns.** Lowest migration cost. Rejected: does not solve the DI/testability gap (problem 1), which blocks 3 of the 22 Definition-of-Done items outright, and leaves `relationship_lifecycle_manager.dart`'s hand-rolled lifecycle code as permanent maintenance surface.
2. **Bloc/Cubit.** Rejected: solves DI but adds a stream-based event/state ceremony this app's mutation-heavy CRUD screens (bucket list, calendar, gift reminders — 8 of 13 domain providers are simple single-table CRUD) don't need. The audit found no complex multi-step business processes outside scrapbook sharing that would benefit from Bloc's explicit event modeling.
3. **Riverpod.** Chosen. `ProviderScope` gives real DI and override-based test fakes; `autoDispose` + `ref.onDispose` directly replaces the lifecycle manager's refcounting; `family` providers replace ad-hoc per-couple keying (`RealtimeSubscriptionManager`'s `'${tableName}_$coupleId'` string keys become typed family parameters — though the manager itself is kept, see ADR-005).

## Decision
Migrate fully to Riverpod, but **not as a lift-and-shift**. The ordering constraint (see `migration-roadmap.md` Phases 1–2 vs 5–6) is the actual decision:

- **Do not** wrap the existing 2,143-line `RelationshipProvider` in a `ChangeNotifierProvider` and call it migrated — that ports the god-object problem into new syntax and captures none of Riverpod's benefit.
- **Host Riverpod early** (`ProviderScope` around the existing `MultiProvider` tree, Phase 2) so every subsequently *extracted* unit — starting with `CoupleSession` in Phase 1 — is written as a Riverpod notifier from birth, not written twice.
- **Split state by ownership first** (ADR-003, Phase 5), **then** port the resulting small units, **then** port the 12 domain providers (Phase 6), **then** remove `provider:` from `pubspec.yaml` and delete `relationship_lifecycle_manager.dart`.
- Explicitly **not** adopting `riverpod_generator`/`freezed` (ADR-002 scope note, formalized in ADR-009's sibling decision) — see "Rejected alternatives".

## Reasons

- DI is the prerequisite for three of the Definition-of-Done's test categories, which are currently structurally impossible to satisfy, not merely unwritten.
- `autoDispose`/`ref.onDispose` directly replaces ~130 lines of hand-rolled refcounting lifecycle code with equivalent, framework-maintained semantics.
- Hosting Riverpod before splitting the god provider means every subsequently extracted state unit is written once, correctly, instead of written as a `ChangeNotifier` and migrated a second time later.

## Consequences

**Positive:** `ProviderScope` overrides make Definition-of-Done items 18 (hydration regression tests), 19 (realtime lifecycle tests), and 20 (auth/pairing widget coverage) achievable — they are currently blocked by the absence of any DI. `autoDispose` replaces ~130 lines of hand-rolled lifecycle bookkeeping.

**Negative:** dual-paradigm codebase (Provider + Riverpod coexisting) for the duration of Phases 1–6 (roughly 4–6 weeks solo). The strangler bridge (both-direction `overrideWithValue`/`.value` shims, detailed in `state-management.md`) is itself extra code that gets deleted once migration completes, and must be understood by anyone touching the app mid-migration.

**Neutral:** `RealtimeSubscriptionManager` (67 lines, refcounted multiplexing keyed by `tableName_coupleId`) is kept as-is rather than replaced by a Riverpod-native mechanism — see ADR-005 for why.

## Rejected alternatives
- No migration (option 1) — blocks the testability items in the Definition of Done.
- Bloc/Cubit (option 2) — ceremony mismatch for CRUD-heavy features.

## Code generation — explicitly deferred, not permanently rejected
`freezed` and `riverpod_generator` are **not adopted for this migration**. This is a deferral, not an irreversible architectural rule: code generation may be introduced later if the complexity-reduction and consistency benefits it offers come to outweigh its build-time, tooling, and maintenance costs — that judgment should be revisited against the codebase's actual state at that time, not assumed now.

**Current rationale for deferring:** the app has a solo developer working on a live, already-shipping application; a build-runner step adds a compile-before-you-can-run-tests dependency and a merge-conflict surface for generated files, for a set of state classes (per ADR-003/ADR-005) that are each written once during this bounded migration window rather than iterated on continuously afterward. The migration's ~30 new/ported state classes and 3 repositories are, by hand, a manageable amount of boilerplate given the team size — the volume that would justify codegen's overhead is not present today.


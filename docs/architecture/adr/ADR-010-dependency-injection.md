# ADR-010: Dependency Injection — Riverpod's ProviderScope, No Separate Container

## Status
Accepted

## Context
**CURRENT STATE, verified:** Days Together has **13 hand-rolled singletons** across three inconsistent idioms:
- `static final X instance = X._()` — `AuthService`, `CoupleService`, `ProfileService`, `StorageUrlService`, `RealtimeSubscriptionManager`, `RelationshipLifecycleManager`, `SupabaseSyncService`, `RecentActivityService`, `NoteitSyncManager`.
- `static final _instance = X._internal(); factory X() => _instance` — `MusicService`, `NotificationService`, `PermissionService`.
- `static final instance` + `factory X() => instance` — `HomeWidgetService`.

None are injected. All are globally, statically reachable from anywhere in the codebase — which is precisely how `lib/widgets/storage_image.dart` reaches `StorageUrlService.instance` directly, bypassing every provider boundary (ADR-004's documented exception). None can be swapped for a test fake, which is a direct cause of the **zero widget tests** in the current 82-test suite: nothing that touches a service can be tested without also exercising the real Supabase client, real SharedPreferences, or real platform channels.

## Problem
A dependency-injection decision is needed as part of the Riverpod migration (ADR-002) — but "add DI" could mean several different things with very different costs, and the wrong choice for a solo-developer, mid-sized app would be over-engineering in the opposite direction from the singleton problem.

## Options considered

1. **Introduce a dedicated service-locator package (`get_it`) alongside or instead of Riverpod.** Rejected: this would mean running two DI mechanisms simultaneously (Riverpod for state, `get_it` for services) with no clear rule for which gets used when — pure added complexity, since Riverpod's own `Provider`/`Ref` mechanism already does everything `get_it` would add.
2. **Wrap every one of the 13 singletons in a Riverpod `Provider` immediately, as part of Phase 2.** Rejected: several of these (e.g. `HomeWidgetService`, a thin platform-channel wrapper with no test currently exercising it meaningfully, and `MusicService`, similarly leaf-level) have no test that would benefit from fakeability today, and converting all 13 at once is unnecessary churn disconnected from any concrete need — it inverts the "solve the problem you actually have" principle this whole specification is built on.
3. **Use `ProviderScope` as the sole DI mechanism; convert a singleton to an injected `Provider` only when a specific test needs to fake it.** Chosen.

## Decision
No separate DI container. `ProviderScope` (introduced in Phase 2, ADR-002) is the only injection mechanism. Existing singletons are converted to Riverpod `Provider`s **incrementally, driven by test need**, not as a blanket pass:

- **`StorageUrlService` and `NotificationService` qualify for conversion** as part of the migration — both are exercised by the Definition-of-Done's required test coverage (`StorageUrlService` underlies image-loading behavior touched by hydration/UI tests; `NotificationService` underlies the deep-link/routing tests required by ADR-007) and both currently have real, confirmed cross-cutting reach (`NotificationService` importing 11 screens; `StorageUrlService` being reached directly from a widget) that DI conversion directly remedies.
- **`HomeWidgetService` does not qualify** for this migration — it is a thin, leaf-level platform-channel wrapper with a single, narrow responsibility (format a duration string, write it to platform storage) and no test currently requires faking it. Converting it would be DI for its own sake.
- **The remaining 10 singletons stay as-is** for this migration unless a specific Phase 5/6 extraction (e.g. `ProfileController` needing to fake `ProfileService` for a hydration test) creates a concrete need — at which point that one service is converted, following the same rule.

**The rule, stated generally:** convert a singleton to an injected `Provider` when a specific, real test requires faking it. Do not convert speculatively.

## Reasons

- DI conversion effort should be proportional to demonstrated test need, not performed as a blanket pass across all 13 singletons regardless of whether any test actually requires faking each one.
- The two services converted (`StorageUrlService`, `NotificationService`) are exactly the two with independently confirmed cross-cutting problems this migration is already fixing (the widget-layer leak and the screen-import coupling respectively) — the DI conversion and the architectural fix are the same piece of work, not two separate efforts.
- A separate service-locator package would duplicate capability Riverpod's own `Provider`/`Ref` mechanism already provides, adding a second DI system with no corresponding benefit.

## Consequences

**Positive:** DI work is proportional to actual testing need, not performed as ceremony. The two services with documented, concrete cross-cutting problems (`StorageUrlService`'s widget-layer leak, `NotificationService`'s screen-import coupling) get fixed as a direct consequence of this rule, which is exactly where DI conversion should be spent first.

**Negative:** the codebase temporarily has three states of "how is this dependency obtained" during migration — old singleton, newly-injected Riverpod provider, and (for the 3 domain-provider extractions of ADR-002) Riverpod notifiers reading each other via `ref.watch` — which requires the strangler-bridge documentation (`state-management.md`) to be precise about which mechanism applies where at each point in the migration.

## Rejected alternatives
- A separate service-locator package (option 1) — redundant with Riverpod's own capability.
- Blanket conversion of all 13 singletons upfront (option 2) — unjustified churn without a corresponding test need.

# ADR-005: Realtime Subscription Architecture

## Status
Accepted

## Context
**CURRENT STATE, verified:** `lib/services/realtime_subscription_manager.dart` (67 lines) multiplexes Supabase Realtime `postgres_changes` streams keyed by `'${tableName}_$coupleId'`, using a `StreamController.broadcast` per key with refcounted `onListen`/`onCancel` teardown. `lib/services/relationship_lifecycle_manager.dart`'s `SupabaseLifecycleProvider` base class ties a provider's realtime subscription lifetime to its own `addListener`/`removeListener` count (i.e., to whether any widget is currently watching it) — 12 of 13 domain providers extend this base and get subscription lifecycle "for free."

**A real, confirmed bug this system has already produced:** `noteit_provider.dart` and `love_chat_provider.dart` both declare `tableName = 'love_notes'`. Because the manager keys by table+couple, both providers share exactly one multiplexed subscription slot, and each filters the incoming rows client-side on a `type` column (`chat` vs. everything else) rather than the server doing it. This works today but means neither provider can independently control its own subscription (e.g. pausing chat while keeping scrapbook notes live is impossible), and it is fragile: adding a third `love_notes`-backed feature would silently join the same shared stream.

Zero screens or widgets own a `StreamSubscription`, `.channel(...)`, or `.stream(...)` call directly (confirmed by grep) — Definition-of-Done items 1 and 2 are already met.

## Problem
The refcounted, listener-count-based lifecycle is exactly what Riverpod's `autoDispose` + `ref.onDispose` provides natively (ADR-002). Migrating state management without a plan for this subsystem risks either (a) losing the multiplexing behavior that correctly prevents duplicate WebSocket subscriptions, or (b) a naive per-provider `autoDispose` stream provider re-opening a fresh subscription for every family instance, defeating the multiplexing entirely.

## Options considered

1. **Let each Riverpod `StreamProvider.autoDispose.family` open its own Supabase stream directly, discard the manager.** Rejected: Riverpod's `autoDispose` governs *provider* lifetime, not *shared Supabase channel* lifetime — nothing in Riverpod itself deduplicates two different providers subscribing to the same underlying table+couple realtime channel the way the manager's key-based `Map` does. Removing the manager would either reintroduce duplicate channels or require rebuilding the manager's exact behavior inside Riverpod anyway.
2. **Keep the manager exactly as-is, wrap it with Riverpod providers only at the outer layer.** Chosen for the manager itself; see Decision for the fix to the `love_notes` collision.
3. **Rewrite the manager as a Riverpod-native multiplexer using `ref.listen` fan-out.** Rejected for this migration: it is a rewrite of working, correctly-scoped infrastructure (67 lines, no bugs found beyond the naming collision) with no corresponding problem to solve — the audit found no leak, no excessive-subscription-count issue, no lifecycle bug in the manager itself. Revisit only if Riverpod-native multiplexing becomes needed for a reason not yet identified.

## Decision

**Three standing rules, binding on all future feature work (also recorded in `architecture-rules.md`):**

> **Rule A.** UI widgets and screens must never own a Supabase Realtime subscription. A subscription is opened and closed only by the data/application-state layer.
>
> **Rule B.** A logical realtime stream (one table, scoped to one couple) has exactly one authoritative subscription owner — `RealtimeSubscriptionManager` — regardless of how many features read from it. Two features reading the same underlying table get **distinct, server-side-filtered subscription keys** through that one owner; they never share a raw, client-filtered stream (this is precisely the rule the `love_notes` collision violated — see ADR-013 for the full analysis of that case).
>
> **Rule C.** Realtime lifecycle (when a subscription opens, when it closes) belongs to the data/application-state layer, driven by Riverpod's `autoDispose`/`ref.onDispose`, never triggered directly from widget lifecycle callbacks (`initState`/`dispose`) or imperative UI code.

**Target architecture these rules encode:**

```
Supabase Realtime (postgres_changes)
        ↓
RealtimeSubscriptionManager        ← the one authoritative owner (Rule B); refcounted, deduplicating
        ↓
Repository / Feature Notifier      ← owns lifecycle via autoDispose/ref.onDispose (Rule C)
        ↓
Riverpod (ref.watch)
        ↓
UI                                 ← reads state only; never touches the subscription (Rule A)
```

**Keep `RealtimeSubscriptionManager` as infrastructure, unchanged in its core multiplexing logic**, through the Riverpod migration (Phase 6). Each ported `Notifier`/`StreamProvider` calls into the manager exactly as the current `SupabaseLifecycleProvider.initRealtime()` does today; `autoDispose` + `ref.onDispose` replaces the `addListener`/`removeListener` refcounting as the *trigger* for calling the manager's subscribe/unsubscribe, not as a replacement for the manager's deduplication logic.

**Fix the `love_notes` collision** as part of the same phase: give `noteit_provider`'s successor and `love_chat_provider`'s successor distinct subscription keys (e.g. `'love_notes:scrapbook_$coupleId'` / `'love_notes:chat_$coupleId'`), with the `type` filter moved server-side into the query each stream issues, rather than relying on identical raw streams filtered client-side.

**Ownership rule going forward:** a feature's Notifier owns exactly one subscription key; if two features must read the same table, they get distinct keys with server-side filters, never a shared key with client-side filtering (codifying the fix above as the standing rule, not a one-time patch).

**Cleanup triggers**, formalized (previously implicit in `handleDisconnect`/`handleLogout`):
- Pairing (`onPair`/`onRepair`): subscribe.
- Disconnect/unpair: unsubscribe + purge cached rows for that couple.
- Logout: unsubscribe all + `RealtimeSubscriptionManager` full clear (mirroring the `StorageUrlService.clearAll()` pattern already used for signed-URL caches on logout).
- Widget/notifier disposal with zero remaining listeners: unsubscribe (already the manager's behavior via refcounting; preserved).

**Error/reconnection behavior:** unchanged from today — errors surface via the stream's `onError` and are handled per-provider (each provider's `onRealtimeError` override); this ADR does not introduce new reconnection logic, only relocates the trigger mechanism.

**`keepAlive` requirement:** two subscriptions are specifically exempted from `autoDispose`'s default "tear down when the last listener leaves" behavior, via `ref.keepAlive()`: chat and scrapbook. Both are the two most likely to be watched intermittently (a user backgrounds the app mid-conversation, or switches tabs briefly) where losing and re-establishing the subscription would visibly drop incoming messages during the gap. All other features' subscriptions use plain `autoDispose` — the default, correct choice for data that is cheap to re-fetch on next watch.

## Reasons

- `RealtimeSubscriptionManager` has no confirmed bug beyond the table-key naming collision — rewriting working, correctly-scoped infrastructure would be unjustified churn with no offsetting benefit.
- Riverpod's `autoDispose` solves *provider* lifetime, not *shared-channel* deduplication — the two mechanisms are complementary, not substitutes, so keeping both is the technically correct choice, not a compromise.
- The `love_notes` collision is a real, if currently benign, bug (a silent third feature could join the shared stream unnoticed) and deserves an explicit fix rather than being carried forward as accepted debt.

## Consequences

**Positive:** no regression risk to the one piece of realtime infrastructure that already works correctly. The `love_notes` collision — a real, if currently benign, bug — gets fixed as part of the migration rather than carried forward indefinitely.

**Negative:** the manager remains a non-Riverpod-native singleton bridging into the Riverpod world, which is a permanent (not transitional) piece of "impedance mismatch" — accepted because rewriting it has no offsetting benefit per Option 3's rejection.

**Validation (Definition-of-Done item 19):** regression tests assert (a) exactly one subscription exists per table+couple key under two concurrent listeners, (b) teardown occurs when the last listener is removed, (c) no duplicate subscription is created on rapid re-subscribe (tab switch), and (d) full teardown occurs on disconnect and on logout.

## Rejected alternatives
- Discarding the manager for pure per-provider `autoDispose` streams (option 1) — loses channel deduplication.
- Rewriting the manager as Riverpod-native (option 3) — unjustified churn on working infrastructure.

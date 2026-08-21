# Realtime Architecture

**PROPOSED** target, anchored to **CURRENT STATE** infrastructure that is kept, not replaced. See ADR-005 for the decision record, and ADR-013 for the dedicated analysis of the `love_notes` table collision referenced throughout this document.

## The three standing rules

> **Rule A.** UI widgets and screens must never own a Supabase Realtime subscription.
> **Rule B.** A logical realtime stream has exactly one authoritative subscription owner (`RealtimeSubscriptionManager`); two features reading the same table get distinct, server-side-filtered keys through that one owner, never a shared client-filtered stream.
> **Rule C.** Realtime lifecycle belongs to the data/application-state layer (`autoDispose`/`ref.onDispose`), never to widget lifecycle callbacks.

These are binding rules, not aspirations — see `architecture-rules.md` for their canonical statement and enforcement status, and ADR-005 for the full reasoning.

## What exists today and is kept

`lib/services/realtime_subscription_manager.dart` (67 lines) multiplexes Supabase Realtime `postgres_changes` streams. Its key insight, verified as correct and preserved: a `Map<String, StreamController.broadcast>` keyed by `'${tableName}_$coupleId'`, with `onListen`/`onCancel` refcounting, so that two providers/widgets independently interested in the same couple's same table share **one** underlying WebSocket subscription rather than opening two.

`lib/services/relationship_lifecycle_manager.dart`'s `SupabaseLifecycleProvider` base class ties a provider's call into the manager to that provider's own `addListener`/`removeListener` count — i.e., a provider only holds an open subscription while some widget is actually watching it.

**Confirmed, currently-live bug this system produced:** `noteit_provider` and `love_chat_provider` both declare `tableName = 'love_notes'`. They therefore share exactly one multiplexed slot and each independently filters the *same* raw stream client-side on a `type` column. It works, but it means neither feature can subscribe or unsubscribe independently, and a third `love_notes`-backed feature would silently join the same shared stream with no warning.

## Subscription ownership

**Rule (post-migration):** one feature Notifier owns exactly one subscription key. If two features must read from the same underlying table, they get **distinct keys with server-side filters** — never a shared key with client-side filtering. This directly fixes the `love_notes` collision:

| Before | After |
|---|---|
| `noteit_provider` → key `love_notes_$coupleId`, filters `type != 'chat'` client-side | `scrapbook` feature → key `love_notes:scrapbook_$coupleId`, server-side `.eq('type', 'scrapbook')` (or equivalent) |
| `love_chat_provider` → key `love_notes_$coupleId`, filters `type == 'chat'` client-side | `chat` feature → key `love_notes:chat_$coupleId`, server-side `.eq('type', 'chat')` |

## Subscription lifecycle

```
Pairing (onPair/onRepair)
        ↓
Feature Notifier created → autoDispose ref.watch(coupleSessionProvider) has a couple
        ↓
Notifier calls RealtimeSubscriptionManager.subscribe(key: 'feature:table_$coupleId')
        ↓
Manager: key already has a subscriber? → share existing broadcast stream
         key is new?                   → open a new postgres_changes subscription
        ↓
Widget builds, watches the Notifier → Notifier gets a listener → ref stays alive
        ↓
Last widget stops watching → autoDispose fires → Notifier's ref.onDispose → manager.unsubscribe(key)
        ↓
Manager: any other subscriber for this key remains?  → keep the shared stream open
         no subscribers remain?                        → close the underlying WebSocket subscription
```

**Riverpod's role, precisely:** `autoDispose` + `ref.onDispose` is the *trigger* — it decides *when* a given Notifier calls `manager.subscribe`/`manager.unsubscribe`, replacing the old `addListener`/`removeListener` refcounting at that layer. The manager itself still does the cross-Notifier *deduplication* — Riverpod has no native concept of "two different providers should share one underlying WebSocket connection," so the manager is not redundant with Riverpod and is not replaced by it (ADR-005's explicit rejection of Option 1: "let each `autoDispose.family` provider open its own stream").

## Cleanup triggers, exhaustively

| Event | Action |
|---|---|
| Widget stops watching a feature (tab switch, screen pop) | If it was the last listener, that feature's subscription closes (via `autoDispose`) |
| Partner disconnects/unpairs | All couple-scoped subscriptions for the old couple close; cached rows for that couple are purged from each Notifier's state |
| Logout | All subscriptions close app-wide; `RealtimeSubscriptionManager`'s internal map is fully cleared (mirroring `StorageUrlService.clearAll()`'s existing pattern) |
| Re-pair with a different couple | Same as disconnect, then fresh subscriptions open under the new couple's keys |
| Network error on an open subscription | Surfaces via the stream's `onError`; handled per-feature (each Notifier's own error state) — this migration does not introduce new reconnection logic, only relocates *where* the subscribe/unsubscribe call originates from |

## Authentication's effect on subscriptions

Subscriptions never open before `CoupleSession.stage == ready` (i.e., a `coupleId` exists) — this was implicitly true before (via the `SupabaseLifecycleProvider.updateRelationship` guard checking `coupleId != null`) and remains an explicit precondition on every feature Notifier's subscription call after the migration.

## Offline behavior

Not new: when the realtime connection is down, each Notifier's last-known state remains visible (it's just cached provider state, no separate offline store per ADR-006), and the Supabase client's own reconnection logic re-establishes the WebSocket when connectivity returns, at which point the manager's existing subscriptions resume delivering events. No app-level offline queue exists for realtime data, matching ADR-006's decision not to introduce a local database.

## Validation (Definition-of-Done item 19)

Four regression tests, introduced in Migration Phase 6, against `RealtimeSubscriptionManager` directly (no real network needed — a fake stream source is injected):

1. **Deduplication:** two concurrent "listeners" for the same `tableName_coupleId` key result in exactly one underlying subscription being opened.
2. **Teardown on last-listener-removed:** removing both listeners closes the underlying subscription.
3. **No duplicate on rapid re-subscribe:** simulating a fast tab-switch-away-and-back does not open a second subscription for a key that's still within its teardown grace period (if the manager introduces one) or does correctly reopen exactly once if it doesn't.
4. **Full teardown on disconnect/logout:** triggering `handleDisconnect`/`handleLogout` closes every open subscription, verified by asserting the manager's internal key count returns to zero.

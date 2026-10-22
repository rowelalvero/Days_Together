# ADR-006: Caching and Local Persistence Strategy

## Status
Accepted

## Context
**CURRENT STATE, verified:** local persistence in Days Together is already split across three real mechanisms with distinct, appropriate jobs:
- **SharedPreferences** — 41 keys hydrating identity, session, and license state (`'your_name'`, `'couple_id'`, `'relationship_start_date'`, 28 `_your*`/`_partner*` license fields, etc.). This is the primary local cache and the live data contract for existing installed users (see ADR-002/Phase 0's `PrefsKeys` decision).
- **sqflite** — `RecentActivityService` (126 lines) logs an on-device activity feed.
- **In-memory, TTL-based** — `StorageUrlService` (379 lines) caches signed Supabase Storage URLs with a positive TTL (successful signs) and negative TTL (failed signs, e.g. RLS-denied), cleared on logout/disconnect via `clearAll()`.

Additionally, `timeline_repository.dart` (misnamed — no Supabase dependency, see ADR-003) persists `AppSettings` (theme, music) via SharedPreferences and local image files via `path_provider`.

There is no local relational database (Hive/Isar/Drift/plain sqlite beyond the one `sqflite` activity table), and the audit found no evidence that one is needed: each of the 12 single-owner-table domain providers already gets a live realtime stream from Supabase as its primary data source, with SharedPreferences used only for the identity/session/license slice that must survive a cold start before any network round-trip completes.

## Problem
Two things need a decision, not because they're broken today, but because the migration (state-ownership split in ADR-002/ADR-003, and the introduction of proper cache-invalidation semantics under Riverpod) needs an explicit answer: (1) should a heavier local-database solution be introduced for offline support, and (2) what exactly gets purged, and when, across logout/disconnect/re-pairing — today this is implicit and scattered (`purgeCache()` overrides across 12 providers, `StorageUrlService.clearAll()`, `HomeWidgetService.clearWidget()`, each called from slightly different points).

## Options considered

1. **Introduce Hive/Isar/Drift as a general local cache layer for all couple-scoped data.** Rejected: no requirement analysis in the codebase or its history suggests genuine offline-write support is needed (this is a two-person household app expected to be used with connectivity); the existing realtime-stream-as-source-of-truth pattern already gives instant UI updates once online, and 12 tables' worth of schema migration into a new local DB is a large, unjustified undertaking for a problem that doesn't exist yet. "Offline support sounds useful" is explicitly the trap this ADR is written to avoid, per the planning brief.
2. **Keep the three-mechanism split (SharedPreferences / sqflite / in-memory TTL), formalize what each is for and the purge contract.** Chosen.
3. **Consolidate everything into SharedPreferences (including the activity log and signed-URL cache).** Rejected: SharedPreferences is a poor fit for the activity log's query/append pattern (sqflite is correctly chosen there) and for the signed-URL cache's TTL/eviction semantics (in-memory is correct — persisting a signed URL to disk would write a bearer token to storage and go stale, a mistake already deliberately avoided in the current `StorageUrlService` design).

## Decision
Keep the three-mechanism split, and make explicit what belongs in each:

| Mechanism | What it holds | Lifetime | Owner |
|---|---|---|---|
| SharedPreferences (`PrefsKeys`) | Session identity, workspace/license fields, theme/music settings, feature drafts (e.g. the noteit canvas draft) | Survives app restart; cleared on logout (see Purge rules) | `CoupleSession` + the state-ownership units from ADR-002/Phase 5 |
| sqflite | On-device activity log | Survives app restart; cleared on logout | `RecentActivityService` (unchanged) |
| In-memory, TTL-keyed | Signed Storage URLs (positive + negative cache) | Process lifetime only, TTL-bounded within that | `StorageUrlService` (unchanged) |
| None (source of truth is the realtime stream) | The 12 single-owner-table domains (bucket list, calendar, vault, etc.) | N/A — always live from Supabase once online; the in-memory provider state itself *is* the cache, no separate persistence layer | Each feature's Notifier |

**No new local database is introduced.** If a genuine offline-write requirement emerges later (e.g. compose-while-offline for chat), it should be evaluated then, scoped to the one feature that needs it — not adopted app-wide pre-emptively.

**Purge contract, formalized** (currently scattered across `purgeCache()` overrides, `StorageUrlService.clearAll()`, `HomeWidgetService.clearWidget()`):

| Event | SharedPreferences | sqflite activity log | Signed-URL cache | Realtime subscriptions |
|---|---|---|---|---|
| Logout | Full clear | Full clear | `clearAll()` | Unsubscribe all |
| Disconnect/unpair | Clear couple-scoped keys only (identity keys like `your_name` persist) | Full clear | `clearAll()` | Unsubscribe couple-scoped |
| Re-pair with a different couple | Same as disconnect, then re-hydrate | Full clear | Already cleared by prior disconnect | Re-subscribe with new key |

**Optimistic updates:** the existing pattern (mutate local provider state immediately, reconcile on the realtime echo) is preserved as-is — the audit found no systemic problem with it, only the isolated `_sendCanvas()` multi-provider-transaction issue addressed separately (see `god-file-decomposition.md`, not a caching concern).

## Reasons

- No evidence in the codebase or its history demonstrates a genuine offline-write requirement — introducing a local database pre-emptively would be solving a problem that hasn't been shown to exist, the exact trap this ADR is written to avoid.
- Each of the three existing mechanisms (SharedPreferences, sqflite, in-memory TTL) is already the correct fit for its specific access pattern; consolidating them would trade real fitness for superficial consistency.
- Formalizing the purge contract closes a real, currently scattered gap (inconsistent cleanup across `purgeCache()` overrides) without requiring any new storage technology.

## Consequences

**Positive:** no large, speculative local-database migration. The purge contract, once written down and enforced by a test, closes a real (if currently low-severity) class of bug: stale couple-scoped data surviving a disconnect because one of the 12 providers' `purgeCache()` was forgotten or incomplete.

**Negative:** the three-mechanism split remains "three things to remember" rather than one unified cache API — accepted because each mechanism is the right tool for its specific job (per Option 3's rejection), and unifying them would trade clarity for false consistency.

## Rejected alternatives
- A general local database (option 1) — solves a problem not evidenced by the app's actual requirements.
- Consolidation into SharedPreferences (option 3) — wrong fit for the activity log and signed-URL cache's actual access patterns.

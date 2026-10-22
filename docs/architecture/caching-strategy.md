# Caching & Offline Strategy

**PROPOSED**, built on **CURRENT STATE** mechanisms that are formalized rather than replaced. See ADR-006 for the decision record and the explicit rejection of introducing a local database.

## What is cached, where, and why

Three mechanisms, each already the right tool for its specific job:

### 1. SharedPreferences — the identity/session/settings cache
**What:** 41 keys (centralized in `PrefsKeys`, Migration Phase 0) covering session identity (`couple_id`, `partner_id`, `is_paired`, ...), the 28 license fields, theme/music settings, and feature drafts (e.g. the noteit canvas draft key).
**Why this mechanism:** must survive a cold app start before any network round-trip completes — this is the app's bootstrap data source, read synchronously on launch to compute the initial `SessionStage` before Supabase has answered anything.
**Owner:** `CoupleSession` and the four state-ownership controllers from Migration Phase 5, each owning a disjoint slice of the 41 keys.

### 2. sqflite — the activity log
**What:** `RecentActivityService`'s on-device activity feed (unchanged by this migration).
**Why this mechanism:** an append/query access pattern SharedPreferences is a poor fit for.

### 3. In-memory, TTL-keyed — the signed-URL cache
**What:** `StorageUrlService`'s positive cache (successfully signed URLs, time-boxed) and negative cache (failed signs, e.g. RLS-denied objects, time-boxed shorter).
**Why this mechanism:** a signed URL embeds a bearer token and expires — persisting it to disk would leak the token into storage and go stale regardless. Process-lifetime, in-memory caching is the only correct choice here, and is already what the current implementation does.

### 4. No cache at all — the 12 single-owner-table domains
**What:** bucket list, calendar, vault, gift reminders, topic cards, mood, currently, timeline (its metadata; images go through mechanism 3).
**Why:** each feature's realtime subscription (see `realtime-architecture.md`) IS the live source of truth once online; the in-memory Riverpod Notifier state that holds the current rows *is* the cache — there is no separate persistence layer, and none is introduced by this migration.

## What is deliberately NOT cached, and why no local database is introduced

**PROPOSED, explicit rejection:** Hive/Isar/Drift/a general local relational store is not adopted. The audit found no evidence of a genuine offline-*write* requirement anywhere in the app's history or current design — Days Together is built around live realtime sync between two specific, known partners who are expected to have connectivity in normal use. Introducing a general local database "because offline support sounds useful" (the specific trap this document is written to avoid, per the planning brief) would mean building and maintaining a second schema mirroring 12 Supabase tables for a requirement that has not been demonstrated. If a genuine offline-write need emerges for one specific feature later (e.g., "let me compose a chat message with no signal"), it should be scoped and built for that one feature at that time, not adopted app-wide pre-emptively.

## Cache lifetime & invalidation

| Cache | Invalidated by |
|---|---|
| SharedPreferences (session/settings) | Explicit purge on logout; couple-scoped subset purged on disconnect (see Purge contract below) |
| sqflite activity log | Explicit purge on logout and on disconnect |
| Signed-URL cache | TTL expiry (positive/negative, per `StorageUrlService`'s existing design); explicit `clearAll()` on logout/disconnect |
| Feature Notifier state (the 12 domains) | Realtime echo reconciles it continuously while subscribed; `ref.invalidate` (Riverpod) or `purgeCache()` (today) on disconnect/logout |

## Optimistic updates

Unchanged pattern, confirmed working correctly by the audit with one isolated exception (the scrapbook cross-feature transaction, addressed separately in `god-file-decomposition.md` §2, not a caching-architecture problem): a feature Notifier mutates its local state immediately on user action, then reconciles against the realtime echo of that same write when it arrives from Supabase. No new optimistic-update infrastructure is introduced by this migration.

## Purge contract

**PROPOSED**, formalizing what is currently scattered across per-provider `purgeCache()` overrides, `StorageUrlService.clearAll()`, and `HomeWidgetService.clearWidget()` calls made from slightly different points in the lifecycle code:

| Event | SharedPreferences | sqflite activity log | Signed-URL cache | Realtime subscriptions | Feature Notifier state |
|---|---|---|---|---|---|
| **Logout** | Full clear | Full clear | `clearAll()` | Unsubscribe all | `ref.invalidate` all |
| **Disconnect / unpair** | Clear couple-scoped keys only (identity keys like `your_name` — the user's own name, not couple-specific — persist) | Full clear | `clearAll()` | Unsubscribe couple-scoped | `ref.invalidate` all couple-scoped |
| **Re-pair with a different couple** | Same as disconnect, then re-hydrate under the new `coupleId` | Full clear | Already cleared by the preceding disconnect | Re-subscribe under new keys | Fresh state under new `coupleId` |

This table is the specification the architecture test suite and the Migration Phase 6 realtime-lifecycle tests (`realtime-architecture.md`, Definition-of-Done item 19) verify against — "full teardown on disconnect/logout" is checkable precisely because this table exists and is unambiguous about what "full" means per mechanism.

## The SharedPreferences contract, formalized

**This is a data-compatibility contract with real, already-installed users, not a convenience constants file.** `PrefsKeys` (Migration Phase 0) is the single, centralized identifier registry for all 41 keys; the rule this section formalizes: **existing key strings are never renamed during refactoring** unless a deliberate, explicit migration mechanism (read-old-key-write-new-key-delete-old-key, executed once on the affected users' next launch) is designed and reviewed as its own change — never as an incidental rename during a state-ownership split.

**Key ownership**, by the Migration Phase 5 state-ownership units (ADR-002/`state-management.md`):

| Owning unit | Representative keys | Category |
|---|---|---|
| `CoupleSession` | `couple_id`, `partner_id`, `is_paired`, `is_creator`, `onboarding_completed` | Session identity |
| `LicenseController` | 28 keys, one pair per license field (`your_gender`/`partner_gender`, `your_birthdate`/`partner_birthdate`, `your_signature`/`partner_signature`, …) | License/registry data |
| `ProfileController` | `your_name`, `partner_name`, `your_avatar_path`, `partner_avatar_path`, join-date keys | Profile identity |
| `WorkspaceController` | `couple_code`, `start_date`, `start_time`, `story_title`, `status`, `is_premium` | Workspace/pairing |
| `PresenceController` | (none persisted — presence is realtime-only, no prefs keys) | — |
| `core/app_settings_store` (post-Phase-0 rename of `timeline_repository.dart`) | theme selection, music settings | App-wide settings |
| `scrapbook` | `noteit_draft_canvas` | Feature draft |

Every key's owner is exactly one of the above — no key is written by two different units. This 1:1 ownership is itself an architecture-test-checkable property once `PrefsKeys` exists with each entry annotated by owner (a doc comment is sufficient; no runtime enforcement needed beyond "only the owning class's file references this constant," which the existing `test/architecture_test.dart` literal-check already implies by construction).

**Hydration order on cold start:** `CoupleSession`'s identity keys hydrate first and synchronously (before the first frame, from the existing `_loadLocalData()` pattern preserved through the migration) — they are what `SessionStage`'s initial value is computed from. `LicenseController`/`ProfileController`/`WorkspaceController` hydrate next, in parallel with each other (no ordering dependency between them). This ordering is not new — it mirrors `RelationshipProvider`'s existing `_loadLocalData()` sequence — but is made explicit here because the state-ownership split (Phase 5) must preserve it exactly, verified by the hydration fixture test.

**Persistence responsibilities:** each owning unit persists its own keys on every mutation (unchanged pattern from today — write-through on every setter call, not batched/debounced). No unit ever writes to a key it does not own, even transiently.

**Logout / unlink / re-pairing:** governed by the Purge contract table above — SharedPreferences column specifically: full clear on logout; couple-scoped-keys-only clear on disconnect (identity keys like the user's own name persist, since they describe the user, not the relationship); full clear-then-rehydrate on re-pairing with a different couple.

**Versioning/migration strategy, if a key must ever change:** (1) add the new key alongside the old one, (2) on next hydration read the old key if the new key is absent and write it forward to the new key, (3) after a deprecation window (a full release cycle, minimum), stop reading the old key and remove it from `PrefsKeys`. This mirrors standard mobile local-storage migration practice and is documented here so that "we need to rename a key" has a designed answer available rather than being solved ad hoc under time pressure if it comes up during Phase 5.

## Re-pairing behavior

A user disconnecting and then joining a *different* couple must not see any residual state from the previous couple. The purge contract above (disconnect row) followed by fresh hydration under the new `coupleId` is the mechanism; this is testable directly via the hydration fixture test introduced in Migration Phase 5 (seed prefs for couple A, trigger disconnect + re-pair to couple B, assert zero residual couple-A-scoped keys remain).

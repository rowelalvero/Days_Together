# State Management

**PROPOSED** target state, with **CURRENT STATE** noted where it anchors the design. See ADR-002 for the decision record; this document is the working reference for *how* to use it day to day.

## State taxonomy

Every piece of state in the app falls into exactly one of these categories. Mixing categories in one class is the specific mistake `RelationshipProvider` made (server state, session state, and UI-adjacent flags like `_isGeneratingCode` all lived together) — the taxonomy exists to prevent repeating it.

| Category | Examples | Where it lives | Lifetime |
|---|---|---|---|
| **Global/app state** | Theme selection, music playback, app-wide settings | `core/` Riverpod providers | App process lifetime |
| **Session state** | `userId`, `coupleId`, `partnerId`, `SessionStage` | `CoupleSession` (Phase 1) | Until logout |
| **Server/domain state** | Timeline items, bucket list, vault items, license fields | Feature Notifiers, backed by a realtime `StreamProvider` or a repository | Synced with Supabase; cached in the notifier's state |
| **Ephemeral UI state** | Selected tab index, modal visibility, hover/press state | Local `useState`/`StateProvider` scoped to the widget, or plain `setState` where a Riverpod provider would be overkill | Widget lifetime |
| **Form state** | Text field contents mid-edit, validation errors before submit | Local to the form widget (`TextEditingController`, local `StateProvider`) — never promoted to a feature Notifier until submitted | Form lifetime |
| **Editor state** | Selected canvas tool, current drawing color, selected scrapbook element | Local to the editor widget/its own small Notifier, scoped to `scrapbook` feature | Editor session lifetime |
| **Realtime state** | Live subscription status, presence online/offline flag | Feature Notifier, sourced from `RealtimeSubscriptionManager` (ADR-005) | Tied to `autoDispose`/listener count |
| **Cache state** | Signed Storage URLs | `StorageUrlService`, in-memory TTL (ADR-006) | Process lifetime, TTL-bounded |

**The rule that prevents server state and UI state from mixing again:** a feature's Notifier holds only server/domain state plus the realtime-sync bookkeeping needed to maintain it. Anything a widget needs only for its own rendering (is a dialog open, which tab is selected, what's currently typed in a field before submit) is local widget state or a narrowly-scoped `StateProvider`, never added to the feature Notifier "because it's convenient."

## Why `RelationshipProvider`'s split failed once, and how this avoids repeating it

**CURRENT STATE** (see ADR-002's context in full): the June 2026 refactor extracted `AuthService`/`CoupleService`/`ProfileService` as pure operation wrappers, and `RelationshipProvider` shrank only ~10% because all the *fields* — 28 paired license fields, session identity, presence flags, ~45 getters — stayed in the provider regardless of which service now performed the underlying Supabase call.

The state-ownership split (Migration Phase 5, detailed in `migration-roadmap.md`) is designed around the corrective lesson: **each new unit is defined by which fields and which `PrefsKeys` entries it owns**, not by which operations it performs. `LicenseController` owns the 28 license fields and their prefs keys — full stop, regardless of how many different service calls maintaining them requires. This is verifiably different from the failed refactor because the fields physically move, not just the code that mutates them.

## Riverpod topology

```
ProviderScope
├── coupleSessionProvider          (Notifier<CoupleSession>)      — Phase 1/2
├── licenseControllerProvider      (Notifier<LicenseDetails>)     — Phase 5, depends on coupleSessionProvider + userRepositoryProvider
├── profileControllerProvider      (Notifier<ProfileState>)       — Phase 5, depends on coupleSessionProvider + userRepositoryProvider
├── workspaceControllerProvider    (Notifier<WorkspaceState>)     — Phase 5, depends on coupleSessionProvider + coupleRepositoryProvider
├── presenceControllerProvider     (Notifier<PresenceState>)      — Phase 5, depends on coupleSessionProvider
├── <12 domain feature providers>  (Notifier + StreamProvider.family) — Phase 6, each depends on coupleSessionProvider
├── userRepositoryProvider, coupleRepositoryProvider, licenseRepositoryProvider  — Phase 4
└── storageUrlServiceProvider, notificationServiceProvider        — Phase 6, injected per ADR-010's test-driven rule
```

**Correction, discovered during Phase 0 planning verification (full trail in `migration-roadmap.md`'s Phase 0 formal row-mapping section):** `LicenseController` depends on `userRepositoryProvider`, not `licenseRepositoryProvider` — despite the name, the app's 28 `_your*`/`_partner*` license fields are read/written through the **`users`** table in the live code path today (`ProfileService.updateUserDetails`/the `update_partner_profile` RPC), not through `license_details`, even though `license_details`'s original schema has similarly-named paired columns. `licenseRepositoryProvider`/`LicenseRepository` remains one of the three repositories (ADR-003) but backs a narrower, separate "certificate metadata" concern (`certificate_number` and other columns confirmed present in the live database but absent from the tracked migration history) — a genuinely different responsibility than `LicenseController`'s field set, despite the naming similarity. Phase 4 must verify `license_details`'s actual live schema directly (not just the migrations directory, which is confirmed incomplete for this one table) before finalizing `LicenseRepository`'s shape.

Every feature Notifier reads `ref.watch(coupleSessionProvider)` for the four identity fields it needs (the same four fields the fan-out audit found — nothing has changed about *what* is depended on, only *how* cleanly it is expressed). `ref.watch` on a `Notifier` provider is Riverpod's structural equivalent of today's `ChangeNotifierProxyProvider<RelationshipProvider, X>` — the topology is the same shape, deliberately, so the migration is a faithful port of a now-correct dependency graph rather than a redesign.

**⚠️ Corrected on implementation (Phase 6a) — two compounding reasons this section's plan does not work as written, both discovered only once the first bridge (`_DomainProvidersBridge`) eagerly created several dependent providers against the real, full production widget tree rather than an isolated `ProviderContainer`:**

1. **`ref.watch(coupleSessionProvider)` does not give the reactivity this section implies.** `coupleSessionProvider` is a plain `Provider<CoupleSession>`, overridden via `coupleSessionProvider.overrideWithValue(session)` — a bare *value* override, not a listenable-aware one. `session` is the *same* `CoupleSession` instance on every rebuild of the nested `ProviderScope` (only its internal fields mutate, via `CoupleSession.notifyListeners()`); Riverpod's plain-value override only re-notifies watchers when the override call supplies a *different* reference, so `ref.watch(coupleSessionProvider)` never fires again after the first build no matter how many times `CoupleSession`'s own fields change. This was true from Phase 2 onward and would have affected any code that actually tried the `ref.watch` pattern this section prescribes — nothing did until Phase 6a, since Phase 5's mirror controllers (`ProfileController`/`WorkspaceController`/`PresenceController`) never read `coupleSessionProvider` and `LicenseController`'s only read of it is a one-shot `ref.read` inside a UI-triggered write, not a `build()`-time `ref.watch`.
2. **A provider with no explicit `dependencies:` declaration is homed in the *root* `ProviderContainer`, not whichever nested `ProviderScope` a caller happens to read it through.** `coupleSessionProvider`'s override exists only in `main.dart`'s *inner*, nested `ProviderScope` — the outer one (created once at `runApp`, before `CoupleSession` even exists) never overrides it. Any provider that itself calls `ref.read(coupleSessionProvider)` (every Phase 6a domain controller, via `SupabaseLifecycleNotifier.initSessionLifecycle`/`updateSession`, plus `LicenseController.updateFields`) is — absent a `dependencies:` declaration — created in the *root* container the first time anything reads it, and its own internal `ref.read(coupleSessionProvider)` therefore also resolves against the *root*, where the override doesn't exist, throwing `UnimplementedError` every time. This is invisible to a bare `ProviderContainer(overrides: [coupleSessionProvider.overrideWithValue(...)])` test (every controller test file in this migration uses exactly that pattern) since a flat container has no root/nested distinction to get wrong — the bug only surfaces when the *real*, two-`ProviderScope` production tree is pumped, which `test/riverpod_bridge_test.dart` is the only test in the suite that does.

**The fix, applied to every affected provider declaration:** add `dependencies: [coupleSessionProvider]` to the `NotifierProvider`/`AsyncNotifierProvider` constructor call — e.g. `NotifierProvider.autoDispose<X, XState>(X.new, dependencies: [coupleSessionProvider])`. This is Riverpod's built-in "automatic scoping" mechanism (`ProviderOrFamily.$allTransitiveDependencies`, verified directly against the installed `riverpod` 3.3.2 package source): a provider that declares a dependency on an overridden provider is itself automatically created *within that same override's scope*, so its internal reads of that dependency resolve correctly. Applied retroactively to `licenseControllerProvider` (Phase 5) and to all Phase 6a domain controllers that read `coupleSessionProvider`; not needed by `profileControllerProvider`/`workspaceControllerProvider`/`presenceControllerProvider`, which never read it. `ref.watch(coupleSessionProvider)` for reactivity, as this section originally prescribed, is not used anywhere — session-change propagation is instead an explicit push from a `main.dart` bridge widget calling each controller's own `updateSession(CoupleSession)` method (see `migration-roadmap.md`'s Phase 5/6a correction entries for `_ProfileControllerBridge`/`_DomainProvidersBridge`), sidestepping problem 1 entirely rather than working around it.

**Anyone adding a new provider that reads `coupleSessionProvider` (directly or transitively) after this correction lands must add `dependencies: [coupleSessionProvider]` to its declaration** — there is no compiler or analyzer check that catches the omission; it only fails at runtime, and only when read through the real nested-`ProviderScope` tree, not through an isolated test container.

## The strangler bridge (Migration Phase 2)

Both Provider and Riverpod trees are live simultaneously from Phase 2 through Phase 6. Two bridging mechanisms, used depending on direction:

**Provider → Riverpod (new Riverpod code needs to read old Provider state):**
```dart
// main.dart, inside the existing MultiProvider tree:
Consumer<CoupleSession>(
  builder: (context, session, _) => ProviderScope(
    overrides: [coupleSessionProvider.overrideWithValue(session)],
    child: /* the rest of the app */,
  ),
)
```
This makes Riverpod code read the exact same live `CoupleSession` instance the Provider tree already holds — one instance, two containers, no state can diverge between them.

**Riverpod → Provider (old, unconverted screens need to read a newly-Riverpod-native notifier):**
```dart
// A temporary shim in MultiProvider, deleted once its last consumer converts:
ChangeNotifierProvider.value(
  value: /* adapter reading the Riverpod container */,
)
```
Each shim is scoped to exactly one converted unit and is deleted individually as soon as `grep` shows no remaining `context.watch<ThatUnit>()` call — the bridge shrinks monotonically across Phases 5b and 6, never grows.

## What does NOT get a Riverpod provider

Per ADR-010: a singleton converts to an injected provider only when a specific test needs to fake it. `HomeWidgetService` stays a plain singleton throughout this migration — no test requires faking it, and converting it would be DI performed for its own sake rather than in service of a concrete need.

## Testing implication

Every Notifier introduced by this migration is, by construction, testable via `ProviderScope(overrides: [...])` without touching a real Supabase client — this is what makes Definition-of-Done items 18–20 achievable at all (`state-management.md`'s topology is the prerequisite `testing-strategy.md`'s pyramid depends on).

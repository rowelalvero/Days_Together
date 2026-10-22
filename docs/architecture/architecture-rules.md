# Architecture Rules

**PROPOSED.** The concise, standing "rules of the road" for all future Days Together development — not a restatement of the ADRs' reasoning (see `adr/`), but the enforceable, quotable conclusions a developer should be able to check a change against without reading the full specification. Rules marked **[enforced]** are checked by `test/architecture_test.dart` (introduced Migration Phase 0, tightened through later phases per `testing-strategy.md`); rules marked **[reviewed]** rely on code review because they aren't (yet, or ever) mechanically checkable.

Days Together is a **feature-oriented modular architecture with lightweight domain/business logic where complexity warrants it** — not a Domain-Driven Design implementation. See the main specification's "Architectural Philosophy" section for the full distinction. These rules follow from that framing.

---

### 1. UI must not directly access Supabase. **[enforced]**
No file under `lib/screens/`, `lib/widgets/`, or (post-relocation) `lib/features/**/presentation/` imports `supabase_flutter`. **CURRENT STATE:** already true today (verified: 0 of 23 Supabase-importing files are in the UI layer) — this rule protects that fact going forward. See ADR-004.

### 2. UI must not own Supabase Realtime subscriptions. **[enforced]**
No `StreamSubscription`, `.channel(...)`, or `.stream(...)` call in a screen or widget. **CURRENT STATE:** already true today. See ADR-005.

### 3. New feature state must use Riverpod after the Riverpod foundation phase (Migration Phase 2). **[reviewed]**
Once `ProviderScope` is hosted, no new `ChangeNotifier`-based state class is introduced for a *new* feature. Existing `ChangeNotifier` providers are ported per the roadmap's schedule (Phases 5–6), not all at once. See ADR-002.

### 4. Provider is legacy-only during migration and must not be used for new development. **[reviewed]**
The `provider` package remains a dependency only until Migration Phase 6 removes it. Any code written *during* the migration window for a feature not yet ported still uses `provider`, consistent with its current pattern, to avoid a half-ported feature straddling two paradigms — but no feature newly created during the migration starts on `provider`.

### 5. Business rules must not live inside widgets. **[reviewed, guided by the test in Rule §3 of the main specification]**
See the main specification's "UI Logic vs. Business Logic" section for the concrete test ("if the Flutter UI were completely replaced, would this rule still need to exist?") and worked Days Together examples. Confirmed current violations this rule targets: the O(days) date-math loop in `relationship_duration_screen.dart`, the scrapbook-sharing transaction in `noteit_screen.dart`.

### 6. UI/presentation logic is allowed — and expected — in the presentation layer. **[reviewed]**
This is the necessary counterpart to Rule 5, stated explicitly so Rule 5 is not over-applied. Tab selection, dialog visibility, animation state, temporary form state, and display formatting belong in widgets or their local state. Not every line of logic in a `build()` method is a violation — see the main specification's worked examples for the line.

### 7. Repositories are created based on data ownership/reuse, not one repository per database table. **[reviewed]**
A repository is justified when a table is read by more than one consumer **and** its rows must become a typed model that outlives the query. For the current schema this yields exactly three repositories (`users`, `couples`, `license_details`) — not a permanent ceiling, but the correct count *today*; future tables may qualify under the same test. See ADR-003.

### 8. Use cases require business-orchestration justification. **[reviewed]**
A use case is justified by genuine cross-feature coordination or a meaningful multi-step state transition — not merely because an operation exists. `GetTimelineUseCase`, `GetProfileUseCase`, and similar single-call wrappers are explicitly rejected patterns. `ScrapbookShareUseCase` is the one current exception, because it coordinates a real cross-feature transaction (scrapbook note creation + chat notification + draft cleanup). See ADR-009.

### 9. Shared design-system components require genuine multi-feature reuse. **[enforced, from Phase 7b]**
A component enters `lib/shared/` only when a **second** feature actually needs it — never speculatively. See ADR-008.

### 10. Feature-specific components remain inside their feature. **[enforced, from Phase 7b]**
The corollary of Rule 9: a component built for one feature stays in that feature's `presentation/` directory, full stop, until Rule 9's condition is met.

### 11. Features must not introduce circular dependencies. **[enforced]**
See `feature-boundaries.md`'s feature dependency matrix and the explicit prohibition of cycles such as `timeline → scrapbook → chat → relationship → timeline`.

### 12. `shared/` and `core/` must not depend on feature implementations. **[enforced]**
Dependency flows one direction only: `features/**` may depend on `shared/` and `core/`; neither `shared/` nor `core/` may import anything from `features/**`. This is what makes `shared/`/`core/` genuinely reusable rather than accidentally feature-coupled.

### 13. Supabase SDK types must not leak into domain entities. **[reviewed, partially enforced via Rule 1]**
A model (`UserProfile`, `LicenseDetails`, etc.) never has a field typed as a raw Supabase/Postgrest type. Row-to-model mapping happens once, at the repository boundary (ADR-003), converting to plain Dart types before the model is constructed.

### 14. SharedPreferences key strings are immutable data-contract identifiers. **[enforced, incrementally]**
No key string is ever renamed without an explicit, documented migration mechanism — this protects real, already-installed users' local data and applies from Phase 0 onward, unconditionally.

The "no raw literal outside `PrefsKeys`" half of this rule is **centralized incrementally, phase by phase**, not enforced app-wide starting at Phase 0. `PrefsKeys` (Phase 0) registers exactly the 41 keys already owned by `RelationshipProvider`; existing call sites in that file keep their literals until Phase 5 extracts each field into its owning controller, which is when each literal is actually replaced. Vault PIN keys, theme/music settings, and the noteit draft key are centralized when their owning feature is touched in a later phase, not retrofitted early. `test/architecture_test.dart` only gains a "no raw prefs literal outside `PrefsKeys`" check once a given area's keys are fully migrated — checking it earlier would fail against code that hasn't been touched yet for no benefit. See `caching-strategy.md`'s SharedPreferences contract section for the full ownership table and hydration order.

### 15. Services must not directly navigate to screens. **[enforced, from Phase 3]**
No file under `lib/services/` imports a screen file or constructs a `MaterialPageRoute`/calls `Navigator`/`context.go` directly. A service that needs to trigger navigation (e.g. `NotificationService`) emits a navigation intent (a route string or a typed intent object) that the router layer resolves — it does not push a screen itself. See ADR-007 and Rule 16.

### 16. Navigation decisions belong to the navigation/session architecture. **[enforced, from Phase 3]**
Exactly one mechanism decides "what screen should the user see right now": the `go_router` `redirect`, driven by `CoupleSession.stage`. No second, independent readiness check is written anywhere else in the codebase. See ADR-007.

### 17. Feature state should remain feature-local unless it is genuinely application-wide. **[reviewed]**
`CoupleSession` (session identity) and theme/settings are the only state promoted to app-wide scope. A feature's domain data (timeline items, bucket list entries, etc.) stays owned by that feature's Notifier and is never duplicated into a global provider "for convenience."

### 18. Avoid god widgets, god providers, and god services. **[reviewed, with concrete precedent]**
The audit found and fixed (via `god-file-decomposition.md`'s plans) three god-file failure modes: god by class count, god by single-class size, god by fan-in. A new file exhibiting any of these three patterns should be split before it grows further, using the same file-by-file playbook.

### 19. Do not introduce abstractions without a concrete architectural reason. **[reviewed]**
The main specification's "No Over-Engineering" section is the standing checklist of specific abstractions intentionally avoided (generic base repositories, generic CRUD, DI containers beyond `ProviderScope`, code generation without demonstrated benefit, etc.) and the test to apply before adding a new one: *does this reduce real complexity, isolate a meaningful boundary, or enable a concrete testing/maintenance benefit?*

### 20. Preserve existing behavior unless a migration phase explicitly changes that behavior. **[reviewed]**
Refactoring (moving code, splitting files, renaming internal symbols) must not change what the app does from a user's perspective, except where a migration phase's scope explicitly documents an intentional behavior change (e.g. Phase 0's `countWeekends` closed-form replacement, verified equivalent to the original loop by a dedicated test before the loop is deleted).

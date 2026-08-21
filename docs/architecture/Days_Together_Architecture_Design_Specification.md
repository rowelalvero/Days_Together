# Days Together — Architecture & Design Specification

**Status:** Planning phase. **No application source code has been modified to produce this document.** Every claim below is tagged **CURRENT STATE** (verified against the repository, with `file:line` evidence), **PROPOSED** (a recommendation this specification makes), or **OPEN QUESTION** (a decision deliberately left open, with the reasoning for leaving it open).

This document is the top-level entry point. It is deliberately not the only document — deep dives on specific concerns live in the satellite documents listed in §29, and every significant decision has a full Architecture Decision Record in `adr/`. This document's job is to state the philosophy, tie the decisions together, and be readable end-to-end without requiring every satellite document to be open at the same time.

---

## 1. Executive Summary

Days Together is a live Flutter + Supabase application (137 files, 49,236 lines in `lib/`, 16 Provider-based state classes, 15 services, 28 SQL migrations, 82 passing tests, `flutter analyze` clean) built for two partners to share a relationship timeline, memories, and communication. It grew feature-first with no written architecture, and a prior refactor attempt (June 2026) partially failed in an instructive way — see §4.

This specification defines a **feature-oriented modular architecture with lightweight domain/business logic where complexity warrants it**, migrating state management to Riverpod, navigation to `go_router`, and introducing exactly three data repositories, one use case, and an expanded design-token system — each justified by a specific, verified problem in the current codebase, not adopted as generic best practice. The migration is phased (§31, full detail in `migration-roadmap.md`) so the app remains shippable at every step.

**The two findings that shape the entire plan:**
1. The feared "everything depends on the 2,143-line god provider" problem is, when actually measured, a **four-field dependency** (`userId`, `coupleId`, `partnerId`, `isSupabaseAvailable`) — extracting those four fields is the highest-leverage single change available and is done first (Migration Phase 1).
2. A prior refactor extracted operation-wrapper *services* from the god provider and only shrank it ~10%, because it moved *statements*, not *fields*. This specification's state-splitting approach is explicitly designed around that lesson (§13, ADR-002).

---

## 2. Architectural Goals

- Maintainability: no file should require reading four unrelated top-level directories to understand one feature.
- Testability: dependency injection sufficient to fake auth, pairing, and realtime state in tests — currently impossible (0 widget tests exist).
- Scalability: adding a feature should not require touching a god provider or a god widget.
- Clear feature ownership: one feature, one directory, one set of owned tables/state.
- Low coupling, high cohesion: enforced, not just documented — see `architecture-rules.md` and the architecture-test harness (§26).
- Reusable UI without an uncontrolled shared folder: a promotion rule, not a free-for-all (ADR-008).
- Predictable state management: one taxonomy, one topology (§13, `state-management.md`).
- Safe Supabase integration: a boundary that already mostly holds today (§16, ADR-004) and is protected from regressing.
- Controlled realtime subscriptions: one authoritative owner, lifecycle-safe (§17, ADR-005, ADR-013).
- Good local caching without inventing an offline-write requirement that doesn't exist (§18, ADR-006).
- Easy onboarding for a future developer (or the same developer, six months later).

## 3. Non-Goals

- **Not** a full Domain-Driven Design implementation — see §6.1 for the explicit distinction.
- **Not** a rewrite. Every phase in §31 is incremental and independently shippable on a live app with real user data.
- **Not** a visual redesign — the existing visual identity (themes, typography, layout) is formalized (§22), not changed.
- **Not** an exhaustive test-coverage mandate — testing effort is targeted at the app's actual risk concentration (§26, ADR-012), not a coverage percentage.
- **Not** an offline-first rewrite — no local database is introduced (§18, ADR-006) absent a demonstrated write-offline requirement.

---

## 4. Current Architecture Assessment

**CURRENT STATE**, verified directly against the repository (full detail and file:line evidence throughout the satellite documents; summarized here).

**The good news, which changes the whole risk profile of this migration:** zero files under `lib/screens/` or `lib/widgets/` import Supabase. The feared "UI talks directly to the database" anti-pattern does not exist. The real coupling is **Provider → Supabase SDK**: 13 of 16 providers embed raw query builders with no repository boundary. This is a materially cheaper problem to fix than UI-layer coupling would have been.

**The god provider:** `lib/providers/relationship_provider.dart` is 2,143 lines across 20 distinct responsibility clusters (auth, pairing, presence, 28 license fields, avatar handling, duration math, and more). Verified by grep: every one of the 13 domain providers wired to it via `ChangeNotifierProxyProvider` reads exactly four of its members. The June 2026 refactor (`docs/superpowers/specs/2026-06-30-architecture-uiux-refactoring-design.md`) extracted `AuthService`/`CoupleService`/`ProfileService` as operation wrappers and only reduced the provider ~10%, because the 28 license fields and their state never moved — only the code calling Supabase on their behalf did.

**Repositories:** `lib/repositories/relationship_repository.dart` (83 lines) correctly maps three tables to typed models but has zero call sites — dead code, superseded by Map-returning services. `lib/repositories/timeline_repository.dart` has no Supabase dependency at all; it's a misnamed SharedPreferences helper.

**Services:** 15 files, average 145 lines, no god services — the healthiest layer in the codebase, and treated as such (not wrapped in unnecessary repositories, §12).

**Navigation:** ~261 imperative call sites across 44 files, zero named routes, four independent restatements of "is the user ready," two conflicting post-destructive-action strategies, a service (`notification_service.dart`) importing 11 screens directly through a global `navigatorKey`.

**Design system:** an 8-field theme object (6 colors, a name, a brightness flag) is the entire token vocabulary, passed as `dynamic` at nearly every widget boundary — the direct cause of ~986 hardcoded color literals across the UI.

**God files, four distinct failure modes:** `relationship_license_screen.dart` (5,025 lines, god by class count), `noteit_screen.dart` (2,571 lines, god by single-class size, containing an untransactional multi-provider write sequence), `bento_grid.dart` (2,390 lines, god by fan-in, parsing an untyped string protocol), `relationship_duration_screen.dart` (1,259 lines, an O(days) loop re-executing inside `build()` on every rebuild). A fifth candidate, `relationship_profile_screen.dart` (1,652 lines), was investigated and confirmed **not** a real architectural problem — see `god-file-decomposition.md`.

**A specific, confirmed bug this architecture produced:** `noteit_provider` and `love_chat_provider` both declare `tableName = 'love_notes'`, sharing one realtime subscription key and each filtering client-side — see §17 and ADR-013 for the full analysis.

### Current State → Target State mapping

| Concern | CURRENT | TARGET | Delivered by |
|---|---|---|---|
| State management | `provider`/`ChangeNotifier`, 16 classes, no DI | Riverpod, `ProviderScope`, injected fakeable dependencies | Phases 2, 6 |
| Session/identity | Buried as 4 fields inside a 2,143-line god provider | `CoupleSession` + `SessionStage`, ~150 lines, owns exactly session identity | Phase 1 |
| God provider | `RelationshipProvider`, 2,143 lines, 20 responsibility clusters | Deleted; replaced by 5 state-ownership units (`CoupleSession`, `LicenseController`, `ProfileController`, `WorkspaceController`, `PresenceController`) | Phases 5, 5b |
| Repositories | 1 dead (83 lines, 0 call sites), 1 misnamed | 3 live (`users`, `couples`, `license_details`), typed, tested | Phase 4 |
| Supabase access | 13 providers with raw inline query builders | Repository (3 tables) or direct service call (12 single-owner tables) per ADR-003's explicit rule | Phases 4, 6 |
| Realtime | Hand-rolled lifecycle manager; one confirmed table-key collision | `RealtimeSubscriptionManager` kept, lifecycle via `autoDispose`; collision fixed with distinct keys + server-side filters | Phase 6, ADR-005/013 |
| Navigation | ~261 imperative call sites, 4 competing readiness checks, global `navigatorKey` | `go_router`, one `redirect` on `SessionStage`, `navigatorKey` deleted | Phase 3 |
| Cross-feature protocol | `'[scrapbook]:...'` string, parsed ad hoc in 2 files | `ScrapbookRef`, typed, round-trip tested | Phase 8, ADR-013 |
| Cross-feature transaction | `_sendCanvas()`, 5 untransactional steps inside a widget `State` method | `ScrapbookShareUseCase`, testable, explicit partial-failure handling | Phase 8, ADR-009 |
| Theme tokens | 8 fields (color-only), `dynamic theme` at nearly every boundary | `ThemeExtension` with spacing/radius/elevation/motion/semantic tokens, typed `LoveStoryTheme theme` everywhere | Phase 7 |
| Widget organization | `lib/widgets/`: 12% generic, 73% misplaced, 15% misfiled screens | `lib/shared/` (generic only, promotion-rule gated) + `lib/features/**/presentation/` | Phases 0, 7b |
| Models | DTO == entity everywhere; 5 mutable models with `copyWith` contradiction | Same DTO==entity pattern (kept, ADR-003) for 12 features; all-`final` immutability app-wide | Phase 4 |
| SharedPreferences | 41 ad hoc string literals, scattered ownership | `PrefsKeys` registry, 1:1 ownership by state unit, documented hydration order | Phase 0, `caching-strategy.md` |
| Error handling | Inconsistent per-file `try/catch`, raw exceptions surfacing | `AppFailure` taxonomy, mapped once at the repository/service boundary | Phases 4, 6, ADR-011 |
| Testing | 82 tests, 0 widget tests (structurally impossible without DI) | Full pyramid + architecture-test harness (§26) | Phases 1–8 |

---

## 5. Proposed Architecture

```
lib/
├── app/            bootstrap, app.dart, ProviderScope root
├── core/            errors (AppFailure), constants (PrefsKeys), design_system, routing infra
├── features/
│   ├── authentication/   relationship/   timeline/   vault/   scrapbook/   chat/
│   ├── bucket_list/      calendar/       gift_reminders/  topic_cards/  mood/
│   ├── currently/        love_studio/    wrapped/     dashboard/    settings/
└── shared/           only components meeting the promotion rule (ADR-008)
```

Within a feature that needs it:
```
feature/
├── presentation/    screens, widgets, Riverpod state (always present)
├── domain/          entities/usecases — OPTIONAL, only where justified (§10, ADR-009)
└── data/            repository (if justified, ADR-003) or direct service calls
```

Full per-feature detail (owns / depends on / must-not-depend-on / data owned) is in `feature-boundaries.md`, including the explicit dependency matrix and the forbidden-cycle rule. Diagrams for every layer are in `architecture-overview.md`.

---

## 6. Architectural Principles

### 6.1 Feature-oriented, not Domain-Driven Design

**This distinction is stated explicitly because the term "domain-based" is easy to over-read as "adopt full DDD," which this specification does not do.**

Days Together is organized around **product capabilities/features** — Relationship, Timeline, Scrapbook, Chat, Love Studio, Profile — not around deep, independently-evolving business domains of the kind DDD's bounded-context/aggregate/ubiquitous-language machinery is built for. Contrast: an application with genuinely complex business domains (invoicing/reconciliation-style systems, for instance, where "Advances" or "Billing" are domains with their own intricate rules, invariants, and specialist vocabulary independent of any UI) benefits from full DDD because the domain complexity exists whether or not there's a UI in front of it at all.

Days Together's complexity is overwhelmingly **UI and data-synchronization complexity** (glassmorphic theming across 6 palettes, realtime sync between two devices, canvas/drawing tools, navigation state) with a comparatively thin layer of actual business rules underneath. The rule this produces (§10, ADR-009): **a `domain/` layer is introduced per-feature only when that specific feature demonstrates meaningful business logic that benefits from isolation from its UI and its data access** — not by default, not for consistency, not because the folder structure diagram has a slot for it. Today, exactly one feature (`scrapbook`, for `ScrapbookShareUseCase`) meets that bar.

### 6.2 UI Logic vs. Business Logic

**Not all logic is business logic**, and the architecture must allow — expect — normal presentation logic to live in the presentation layer without being treated as a violation.

**The test:** *if the Flutter UI were completely replaced (a different framework, a different platform, a CLI), would this rule still need to exist?*
- If **yes** — it's business/domain logic, and it belongs outside the widget.
- If **no** — it's presentation logic, and a widget (or its local state) is exactly where it belongs.

**Presentation/UI logic — belongs in `presentation/`, expected, not a smell:**
UI state, tab selection, dialog visibility, animation state, temporary form state before submission, widget interaction/selection state, loading/error *presentation* (as opposed to error *classification*, which is business logic — see `AppFailure`, ADR-011), display formatting, calling a controller/notifier method in response to a gesture.

**Business/domain logic — must not live inside a widget:**
Relationship eligibility/lifecycle rules (can this user pair, recover, disconnect), authorization rules (is this the right partner), data-ownership rules (which fields belong to which state unit — §13), persistence decisions (when does a write happen, in what order), cross-feature transactions (scrapbook sharing), the license-QR wire format, milestone/duration date math.

**Worked Days Together example, applying the test:**
- `_calculateAge()` (`relationship_license_screen.dart:153`, duplicated at `:4123`) — replace the UI framework entirely and "how old is someone born on this date, as of today" is still a true, needed calculation. **Business logic** → `DateHelper` (Phase 0).
- Which tab is currently selected in `LoveStoryScreen` — replace the UI framework and this concept doesn't even make sense anymore; it's an artifact of *this specific UI's* navigation model. **Presentation logic** → stays local widget state, unaffected by this migration.
- `_sendCanvas()`'s five-step sequence (render → write file → send to scrapbook → mirror to chat → clear draft, `noteit_screen.dart:606-696`) — replace the UI and "sharing a scrapbook note should also notify the partner in chat, and a failure at either step needs distinct handling" is still a true business rule about how the app's two features relate. **Business logic** → `ScrapbookShareUseCase` (Phase 8, ADR-009).
- Whether the export-studio bottom sheet is currently open in `relationship_license_screen.dart` — purely a fact about the current widget tree. **Presentation logic**, stays as-is.

### 6.3 No Over-Engineering

Days Together is explicitly **not** being architected as a clone of an enterprise system with genuinely deep business domains. The following are deliberately avoided **unless a future, concrete requirement demonstrates otherwise** — this list exists precisely so a future contributor (including a future instance of the same developer) can check a proposed abstraction against it before adding one:

- Full DDD (§6.1).
- Repository-per-table (ADR-003) — repositories exist for 3 of 15 tables, by an explicit two-part test, not a blanket rule.
- Use-case-per-operation (ADR-009) — `GetTimelineUseCase`/`GetProfileUseCase`-style wrappers around a single call are explicitly rejected; one use case exists, for a genuine cross-feature transaction.
- Service-per-feature beyond what already exists — the current 15-service layer is healthy and is not restructured wholesale.
- Generic base repositories / generic base controllers / generic CRUD abstractions — three repositories, hand-written, is not enough volume to justify a generic base class; revisit if the count grows substantially.
- Excessive interfaces — Dart's structural typing and Riverpod's provider-swapping already give test-fakeability without an `abstract class IUserRepository` ceremony layer for every repository.
- A generic DI container beyond `ProviderScope` (ADR-010) — singletons convert to injected providers only when a specific test needs to fake one.
- Premature package/module extraction (e.g. turning `core/` into a separate pub package) — no current need; the app is a single Flutter project and stays one until a concrete reuse case (e.g. a second app sharing this design system) exists.
- Atomic Design applied to every widget — ~12% of the widget tree qualifies as design-system material; the rest lives in its feature (ADR-008).
- Code generation (`freezed`/`riverpod_generator`) without demonstrated benefit — deferred, not rejected forever (ADR-002's amended scope note); revisit if the team grows or the hand-written boilerplate volume becomes genuinely burdensome.

**The standing test for any new abstraction:** *does it reduce real, currently-existing complexity, isolate a meaningful boundary that's actually being crossed today, or enable a concrete testing/maintenance benefit that's currently blocked?* If the honest answer is "it might be nice to have" rather than "this solves a problem I can point to," it doesn't get added.

---

## 7. Feature/Domain Boundaries

Full detail — including the feature dependency matrix, the "profile is not a separate feature" and "doodle_notes is the same feature as scrapbook" naming clarifications, and how `scrapbook`↔`chat` communicate without circular coupling — is in `feature-boundaries.md`. Summary: 15 features, one aggregation-only pair (`dashboard`, `wrapped`) with sanctioned broad read-only fan-in, and a strictly acyclic dependency graph enforced by the architecture-test harness.

## 8. Module Structure

See §5 above for the top-level layout and `architecture-overview.md` Diagram 7 for the per-feature internal structure (`presentation/` mandatory, `domain/` optional, `data/` present where a repository or direct service call lives).

## 9. Presentation Layer

Responsible for: screens, widgets, Riverpod Notifiers acting as the UI's direct state source, UI state (§6.2), user interaction, presentation-level formatting (date display strings, not date *math* — §6.2's test again). Every screen/widget in this layer is subject to Rules 1, 2, 5, 6 (`architecture-rules.md`): no Supabase, no owned realtime subscription, no business rules, UI logic freely allowed.

## 10. Domain Layer

**OPTIONAL, per feature**, per ADR-009 and §6.1/§6.3. Responsible, where it exists, for: business rules genuinely independent of both the UI and the specific data source, meaningful state-transition logic, cross-feature orchestration. Today: exactly one instance (`features/scrapbook/domain/scrapbook_share_use_case.dart`). Pure date/duration math is **not** placed here — per ADR-009 it becomes plain functions in `DateHelper` (a `core`/service-layer location), because it has no orchestration to warrant a use-case wrapper.

## 11. Data Layer

Responsible for: the 3 justified repositories (`UserRepository`, `CoupleRepository`, `LicenseRepository` — ADR-003) mapping Supabase rows to typed, immutable models; the 12 remaining single-owner-table features calling Supabase directly from their Notifier (also an acceptable, explicitly sanctioned pattern per ADR-003 — not a layering violation, a deliberate choice); the 15-service layer (`DateHelper`, `AIService`, `StorageUrlService`, etc.), unchanged in shape, injected via Riverpod only where a specific test requires a fake (ADR-010).

## 12. Repository Pattern

Full decision record: ADR-003. The two-part test (multi-consumer **and** typed-model-that-outlives-the-query) applied to the current schema yields exactly three repositories today — explicitly **not** a permanent ceiling (see ADR-003's amended Decision section); a fourth may qualify later under the same test. Repositories must never leak Supabase SDK types into their return values (Rule 13) — mapping happens once, at the repository boundary.

## 13. State Management

Full taxonomy (global/session/server/UI/form/editor/realtime/cache state) and the Riverpod topology diagram are in `state-management.md`. Summary of the decision (ADR-002): migrate fully to Riverpod, but host it *before* porting the god provider (Phase 2 before Phase 5/6), and split `RelationshipProvider` **by state ownership** — which fields and which `PrefsKeys` entries a unit owns — not by which service performs the underlying operation, directly correcting the failure mode of the June 2026 refactor (§4).

Five state-ownership units replace the god provider: `CoupleSession`, `LicenseController`, `ProfileController`, `WorkspaceController`, `PresenceController` — each independently extracted, each validated against a real-device hydration fixture (§26) before and after extraction.

## 14. Dependency Injection

Full decision record: ADR-010. `ProviderScope` is the sole DI mechanism — no separate service-locator package. Of the 13 current hand-rolled singletons, only `StorageUrlService` and `NotificationService` convert to injected providers as part of this migration, because only those two have a concrete, DoD-driven test need; the rest stay as-is, converted individually only when a future test requires it. This is deliberately proportional, not a blanket conversion pass.

## 15. Navigation

Full decision record: ADR-007. Adopt `go_router`, scoped to the 56 `MaterialPageRoute`/41 screen-level `Navigator.push` sites — explicitly **not** the 104 `Navigator.pop` sites (equivalent under `context.pop()`) or any dialog/bottom-sheet. One `redirect`, driven by `CoupleSession.stage`, replaces all four current readiness checks. Services (concretely, `NotificationService`) stop importing screens; they resolve a **navigation intent** and hand it to the router — a distinction elevated to a standing rule (`architecture-rules.md` Rule 15/16) because it is exactly the pattern that currently gives a service a compile-time dependency on 11 screen files. Deep links arriving before `CoupleSession` finishes hydrating are held pending against `SessionStage.loading`, not dropped.

## 16. Supabase Integration

Full decision record: ADR-004. The boundary that already mostly holds (§4) is formalized: `Screen/Widget → Provider/Notifier → Repository (3 tables) or Service (12 tables) → Supabase`, enforced by the architecture test forbidding a Supabase import outside `providers/`/`services/`/`repositories/` (post-migration: outside `features/**/data/` and `core/`). The one documented, temporary exception (`storage_image.dart` calling `StorageUrlService` directly) is closed when Phase 6's DI conversion of that service completes.

## 17. Realtime Architecture

Full decision record: ADR-005, plus the dedicated data-model analysis in ADR-013 for the confirmed `love_notes` table collision. Three standing rules (also in `architecture-rules.md`): UI never owns a subscription (Rule A); one authoritative owner, `RealtimeSubscriptionManager`, kept unchanged as infrastructure through the migration (Rule B); lifecycle belongs to the state layer via `autoDispose`/`ref.onDispose`, replacing the current listener-count refcounting mechanism 1:1 (Rule C). Full lifecycle table (pairing/disconnect/logout/re-pair/error/reconnection/`keepAlive`) is in `realtime-architecture.md`.

## 18. Caching / Offline Strategy

Full decision record: ADR-006. Three existing mechanisms (SharedPreferences for identity/session/settings, sqflite for the activity log, in-memory TTL for signed Storage URLs) are kept and formalized, each already the right tool for its job. **No local database is introduced** — no evidence of a genuine offline-write requirement exists; the realtime stream is the source of truth for the 12 single-owner-table domains once online. The 41-key SharedPreferences contract, its ownership table, hydration order, and purge rules are fully specified in `caching-strategy.md`.

## 19. Authentication

Owned by the `authentication` feature via `CoupleSession` (Phase 1), which absorbs the current `onAuthStateChange` listener and becomes the emitter for pair/repair/disconnect/logout lifecycle events. `SessionStage` is the single computed readiness value the rest of the app (particularly navigation, §15) consumes.

## 20. Security / RLS

**Out of scope for this architecture migration** — Supabase RLS policies, storage bucket security, and recovery/pairing-code hardening were the subject of a separate, prior full-codebase security audit and a dedicated remediation plan (already executed: see the `20260820000000_protect_couple_id.sql`/`20260820000001_avatars_read_policy.sql` migrations and the `supabase/manual/` sequenced storage-lockdown scripts). This specification does not modify Supabase schema, RLS, or storage policy — consistent with the explicit "do not modify the database" constraint on this planning phase, and because that work is already tracked and largely complete separately from the application-architecture concerns this document addresses.

## 21. Storage Architecture

`StorageUrlService` (signed-URL resolution/caching for private Supabase Storage buckets) and `StorageImage`/`StorageImageBuilder` (the display-layer widgets) are kept as-is — both were built and hardened during the prior security remediation and are already the correct architecture for private-bucket image display. This migration's only change to storage is converting `StorageUrlService` to an injected Riverpod provider (§14, ADR-010) so its widget-layer usage (`storage_image.dart`) can go through a proper feature dependency instead of a global singleton reach.

## 22. Design System

Full detail: `design-system.md`, ADR-008. The 8-field `LoveStoryTheme` becomes a `ThemeExtension` with spacing/radius/elevation/blur/motion/semantic-state tokens added; `AppTypography`'s 15 methods (with confirmed duplicates and a mislabeled "mono" pair) collapse to ~6 real roles; every `dynamic theme` parameter becomes a typed `LoveStoryTheme theme`. **The existing visual identity — colors, gradients, the 6 named themes, the glassmorphic aesthetic — is not changed**, only formalized and given room to express tokens beyond color.

## 23. Atomic Design Strategy

Full decision record: ADR-008. Selective, not wholesale: only the ~12% of `lib/widgets/` confirmed genuinely generic is promoted into `lib/shared/`. The promotion rule — a component enters `shared/` only when a **second** feature needs it — is the enforcement mechanism (`architecture-rules.md` Rules 9–10) that prevents `shared/` from re-accumulating into the uncontrolled dumping ground `lib/widgets/` currently is (73% misplaced, by the audit's classification).

## 24. Error Handling

Full decision record: ADR-011. A single shared `AppFailure` taxonomy (network/auth/authorization/validation/not-found/storage/unknown — the four to seven categories the app's actual failure surface exhibits, not a speculative larger hierarchy), mapped once at the repository/service boundary, generalizing the one already-good recoverable/non-recoverable pattern found in `NoteitSyncManager` into an app-wide convention. UI never sees a raw Supabase exception type.

## 25. Loading/Empty/Error States

Standardized states (`Initial / Loading / Refreshing / Loaded / Empty / Error / Offline / Retrying`) apply per-feature Notifier, consistent with the existing pattern in the codebase's better-built providers (e.g. `NoteitSyncManager`'s queue states). This is not a new mechanism — it is the expected shape of any Riverpod `AsyncValue`-backed state after the Phase 6 port, and is not separately specified beyond noting that `AsyncValue`'s native `data`/`error`/`loading` states cover most of this taxonomy directly, with `Empty`/`Offline`/`Retrying` as feature-specific refinements on top where a feature's UX calls for distinguishing them.

## 26. Testing Strategy

Full detail: `testing-strategy.md`, ADR-012. A right-sized pyramid (unit base, widget middle, integration top, each targeted at the app's actual risk concentration rather than a coverage percentage) plus a fourth, parallel category — the architecture-test suite (`test/architecture_test.dart`) — that converts eight of the 25 Definition-of-Done items from "true when we checked" into "the test suite fails the moment it stops being true." No new mocking library; `ProviderScope(overrides:)` is the sole fake-injection mechanism (consistent with §14).

## 27. Performance Strategy

Two concrete, already-identified performance fixes are folded into Phase 0: the O(days) date-iteration loop in `relationship_duration_screen.dart` (re-executed on every `build()`) becomes a closed-form calculation, and duplicate `_formatRelativeTime`/`_calculateAge` implementations are consolidated rather than each independently maintained (and potentially independently performance-tuned or not). No broader performance-architecture change (e.g. widget rebuild profiling, list virtualization audit) is in scope for this migration — the audit found no systemic performance problem beyond these two specific, already-scoped fixes.

## 28. Code Quality

`flutter_lints` (already the sole lint dependency) remains the baseline; this migration does not introduce a stricter custom lint set, consistent with §6.3's no-over-engineering principle — `flutter analyze` clean is a hard gate on every phase (Definition-of-Done item 24), but no new static-analysis tooling is added beyond the architecture-test suite (§26), which is plain Dart test code, not a linter plugin.

## 29. Dependency/Library Matrix

**CURRENT STATE baseline:** `pubspec.yaml` declares 34 runtime dependencies (including the Flutter SDK itself) and exactly 2 dev dependencies (`flutter_test`, `flutter_lints`) — no router, no state-management library beyond `provider`, no code generation, no mocking library.

| Package | Purpose | Classification | Replaces | Migration priority |
|---|---|---|---|---|
| `flutter_riverpod` | State management + DI (ADR-002, ADR-010) | **Required** | `provider` | Phase 2 (host), fully replacing by Phase 6 |
| `go_router` | Declarative navigation (ADR-007) | **Required** | Imperative `Navigator`/`MaterialPageRoute` (screen-level only) | Phase 3 |
| `provider` | Legacy state management | **Avoid** (for new code, per Rule 4) — kept only until Phase 6 removes it entirely | — | Removed Phase 6 |
| `supabase_flutter` | Backend SDK | **Required**, unchanged | — | N/A |
| `cached_network_image` / `flutter_cache_manager` | Image caching, underlies `StorageImage` | **Required**, unchanged (already correctly used post-security-remediation) | — | N/A |
| `freezed` / `riverpod_generator` / `build_runner` | Code generation for immutable state | **Optional** — explicitly deferred, not rejected (ADR-002 amendment) | Hand-written `copyWith`/immutable classes | Revisit only if hand-written volume becomes burdensome or the team grows |
| `mockito` / `mocktail` | Test mocking | **Avoid** — `ProviderScope(overrides:)` is sufficient (ADR-012) | — | N/A, not adopted |
| `get_it` / other service locators | Dependency injection | **Avoid** — redundant with Riverpod (ADR-010) | — | N/A, not adopted |
| `flutter_secure_storage` | Sensitive local storage | **Required**, unchanged | — | N/A |
| `sqflite` | Activity log persistence | **Required**, unchanged (ADR-006) | — | N/A |
| Every other current runtime dependency (`image_picker`, `share_plus`, `qr_flutter`, `flutter_painter_v2`, `home_widget`, `firebase_core`/`firebase_messaging`, etc.) | Feature-specific, already in use, no architectural bearing | **Required**, unchanged | — | N/A |

## 30. ADR Index

| ADR | Title |
|---|---|
| [001](adr/ADR-001-feature-based-architecture.md) | Feature-Based Architecture |
| [002](adr/ADR-002-state-management-riverpod.md) | State Management — Migrate to Riverpod |
| [003](adr/ADR-003-repository-pattern-scope.md) | Repository Pattern — Scoped to Three Tables |
| [004](adr/ADR-004-supabase-integration.md) | Supabase Integration Boundaries |
| [005](adr/ADR-005-realtime-architecture.md) | Realtime Subscription Architecture |
| [006](adr/ADR-006-caching-and-persistence.md) | Caching and Local Persistence Strategy |
| [007](adr/ADR-007-navigation-go-router.md) | Navigation — Adopt go_router |
| [008](adr/ADR-008-atomic-design-scope.md) | Atomic Design — Selective Scope with a Promotion Rule |
| [009](adr/ADR-009-domain-layer-usage.md) | Domain Layer — Optional, and Rarely Justified |
| [010](adr/ADR-010-dependency-injection.md) | Dependency Injection — Riverpod's ProviderScope, No Separate Container |
| [011](adr/ADR-011-error-handling.md) | Error Handling |
| [012](adr/ADR-012-testing-strategy.md) | Testing Strategy |
| [013](adr/ADR-013-scrapbook-chat-data-model.md) | The `love_notes` Table Collision — Data Model Analysis |

## 31. Migration Strategy

Full detail, including per-phase scope/why-this-order/files-affected/risk/validation/exit-criteria, is in `migration-roadmap.md`. Summary: 11 phases (0, 1, 2, 3, 4, 5, 5b, 6, 7, 7b, 8), each independently shippable, ordered by two verified facts — the god-provider fan-out is a 4-field dependency (Phase 1 comes first) and the state splits cleanly along 3 tables + 41 prefs keys (Phase 5's extraction order). Concrete per-file decomposition plans for the four real god files are in `god-file-decomposition.md`.

## 32. Risks

The highest-risk individual phases, called out explicitly rather than buried in the roadmap:
- **Phase 1** (`CoupleSession` extraction) — auth-listener timing errors could cause duplicate subscriptions or a false `unauthenticated` flash on cold start. Mitigated by being scheduled first, while the app is simplest, and by the app's first widget tests.
- **Phase 3** (`go_router` adoption) — a deep link arriving mid-hydration must not be dropped; the new route guards are strictly stronger than today's presentational-only degradation and could newly block a state that was previously (accidentally) reachable.
- **Phase 5** (state-ownership split) — the 41-`PrefsKeys` data contract with real, already-installed users; mitigated by the hydration fixture test, written before the second of five extractions, not after all five.
- **Phase 6** (`autoDispose` realtime port) — a subscription torn down on a tab switch that the old refcounting kept alive, silently dropping incoming messages; mitigated by `ref.keepAlive()` specifically on `chat` and `scrapbook`.

## 33. Open Questions

- **Should `love_notes` eventually split into two tables (chat vs. scrapbook)?** Explicitly left open in ADR-013 — no concrete pain point currently demonstrates the need; the application-layer fix (typed discriminator, server-side filtering, distinct subscription keys) fully resolves the confirmed bug without a schema migration on live data. Revisit only if a genuine divergence (different RLS/retention needs) emerges.
- **Should `HomeWidgetService` ever be converted to an injected provider?** Currently no — no test requires faking it (ADR-010). Revisit if a future test does.
- **When, if ever, does code generation (`freezed`/`riverpod_generator`) become worth adopting?** Explicitly deferred (ADR-002 amendment), not decided against permanently — revisit against the codebase's actual state at that time, not pre-committed now.
- **Should a fourth/fifth repository ever be introduced?** Governed by ADR-003's living two-part test, re-applied whenever the schema or a table's consumer count changes — not a question this specification resolves once and for all.

## 34. Architecture Decision Summary

**The complete Definition of Done** (full traceability table with owning phase and verification method for each item: `migration-roadmap.md`):

```
[ ] No feature screen directly accesses Supabase.
[ ] No feature screen owns Realtime subscriptions.
[ ] Provider is removed.
[ ] RelationshipProvider is removed.
[ ] CoupleSession owns application session state.
[ ] SessionStage is the single readiness state.
[ ] go_router owns navigation decisions.
[ ] navigatorKey is removed if no longer required.
[ ] Services do not import/push screens.
[ ] Feature boundaries are documented and enforced.
[ ] Repository boundaries are documented.
[ ] Three current shared repositories exist.
[ ] Domain models are immutable where required.
[ ] SharedPreferences keys are centralized and preserved.
[ ] ScrapbookShareUseCase owns cross-feature scrapbook sharing.
[ ] ScrapbookRef replaces the string protocol.
[ ] Realtime ownership is centralized and lifecycle-safe.
[ ] Dynamic theme usage is removed.
[ ] Design tokens are centralized.
[ ] Shared components follow the promotion rule.
[ ] Critical hydration behavior has regression tests.
[ ] Realtime lifecycle has regression tests.
[ ] Authentication/pairing flows have appropriate tests.
[ ] flutter analyze is clean.
[ ] Full test suite passes.
```

**Decisions requiring no further approval to begin executing** (all 13 ADRs are Accepted): the phased migration in §31 may begin at Phase 0 as soon as implementation is authorized — this specification is planning-only and does not itself start that work.

**Decisions that remain explicitly open** (§33) are not blockers to beginning Phase 0–4 execution; each is scoped to a later phase or a hypothetical future trigger, and none gates the work that starts immediately.

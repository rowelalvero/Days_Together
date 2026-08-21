# ADR-007: Navigation — Adopt go_router

## Status
Accepted

## Context
**CURRENT STATE, verified:** navigation in Days Together is entirely imperative — ~261 call sites across 44 files (56 `MaterialPageRoute`, 41 `Navigator.push`, 104 `Navigator.pop`, 32 `showDialog`, 14 `showModalBottomSheet`), zero named routes, zero route table.

Specific, confirmed problems:
- `lib/services/notification_service.dart` is the **single largest route producer** in the app (12 `MaterialPageRoute` construction sites) and directly imports **11 screen files** to do it, giving a non-widget singleton service a compile-time dependency on the entire UI surface. It reaches navigation exclusively through a global `GlobalKey<NavigatorState>` (`lib/navigator_key.dart`, 3 lines) that exists for no other purpose.
- **Four independent restatements** of "is the user ready for the main app" exist: `main.dart:197` (`AppHome`'s switch), `avatar_creation_screen.dart:250-255`, `recover_relationship_screen.dart:71`, and `notification_service.dart:219` — each a separate, hand-written condition that must be kept in sync manually.
- **Two conflicting strategies** for returning to a known-good screen after a destructive action: logout does `Navigator.pushAndRemoveUntil(AppHome)` (requiring `settings_tab.dart` to `import '../main.dart'`, a screen importing the app entry point); account deletion does `Navigator.popUntil(isFirst)` instead.
- `calendar_screen.dart:581` pushes a **second, redundant instance of the app's own shell** (`LoveStoryScreen`) onto the navigation stack from inside a detail screen.
- **Zero route guards** exist. No couple-scoped screen (vault, chat, calendar, etc.) checks pairing state on entry; each instead independently renders a degraded "waiting for partner" UI if unpaired. This means an unpaired user *can* reach every screen — protection, where it exists, lives in the data layer (providers early-returning on `coupleId == null`), not in navigation.

## Problem
The absence of a route table means every navigational decision is duplicated by hand at its call site, which has already produced measurable drift (four readiness checks, two destructive-action strategies). Adding or restructuring a screen requires finding and updating every imperative reference to it, including from a service file that shouldn't need to know about screens at all.

## Options considered

1. **Keep `Navigator` imperative, just centralize the readiness/guard logic into one function called from each site.** Rejected: this fixes the duplication of *logic* but not the structural coupling — `notification_service.dart` would still need to import 11 screens to push them, and there would still be no declarative record of what routes exist.
2. **Adopt `go_router` for the full navigation surface, including every `showDialog`/`showModalBottomSheet`.** Rejected (the "including" part): converting all 32 dialogs and 14 bottom sheets into routes is over-engineering — these are not navigational destinations a deep link or back button should target, and go_router's core value (declarative routes, redirects, guards) doesn't apply to transient overlays.
3. **Adopt `go_router` for screen-level navigation only; leave `Navigator.pop`, dialogs, and bottom sheets as-is.** Chosen.

## Decision

**The single readiness pipeline, replacing all four current restatements:**

```
CoupleSession
      ↓
SessionStage            ← the one enum computed from session identity (ADR-002, Phase 1)
      ↓
go_router redirect      ← the one function consuming SessionStage
      ↓
Route
      ↓
Screen
```

**Services emit navigation intents; they do not push screens.** Stated as a standing rule (also recorded in `architecture-rules.md` Rule 15): a service (concretely, `notification_service.dart`) never imports a screen file or constructs a `MaterialPageRoute`/calls `Navigator`/`context.go` directly. It resolves whatever triggered it (a notification payload) to a **navigation intent** — in this codebase's case, simply a type-safe route string or a small `NavigationIntent` value object — and hands that to the router, which is the only layer that knows how to turn it into a screen:

```
NotificationService
      ↓
NavigationIntent  (e.g. Routes.timelineMemory(itemId), or Routes.pairing if unready)
      ↓
GoRouter.go(intent)
      ↓
Screen
```

This replaces the current, rejected shape:

```
NotificationService  →  MaterialPageRoute(builder: (_) => SomeScreen(...))  →  Screen
```

**Deep links arriving during hydration:** a notification tap can arrive before `CoupleSession` finishes its first hydration (`SessionStage.loading`). The intent is not discarded — `NotificationService` still resolves and hands off the `NavigationIntent`, but the router's `redirect` treats `loading` as "defer, do not redirect yet," and the intent is replayed (held as pending, applied once `stage` leaves `loading`) rather than being silently dropped by an early `unauthenticated`/`WelcomeScreen` bounce. This is the concrete mechanism that satisfies the "how is a deep link preserved while `CoupleSession` is still hydrating" question — a real, previously-unaddressed gap, since today's four independent readiness checks each handle (or fail to handle) this moment differently.

Adopt `go_router`, scoped as follows:

- **In scope:** all 56 `MaterialPageRoute` sites and the 41 `Navigator.push` calls that navigate to a distinct screen. These become named routes in a single `lib/routing/routes.dart` registry.
- **Out of scope, deliberately:** the 104 `Navigator.pop` sites (`context.pop()` under go_router is a drop-in equivalent, no conversion needed beyond the API rename), and all `showDialog`/`showModalBottomSheet` call sites (dialogs are not routes in this app's model).
- **One `redirect` function** on the router replaces all four readiness checks. Its input is `CoupleSession.stage` (the `SessionStage` enum introduced alongside `CoupleSession` — see ADR-002/Phase 1), so the redirect and the state split land together.
- **Guards:** every couple-scoped route gets a redirect clause returning the pairing route when `coupleId == null`, replacing the current per-screen presentational degradation for the *navigation* decision (individual screens may still show a lighter "partner hasn't joined yet" state for partial data, which is a UI concern, not a routing one).
- **Destructive actions** (logout, account deletion, disconnect) stop choosing their own return-to-root strategy; they clear the relevant state and let the single redirect recompute the correct destination — eliminating the two-strategies problem and the `import '../main.dart'` layering violation.
- **`notification_service.dart`** stops importing screens. It resolves a notification payload to a **route string** (e.g. `Routes.timelineMemory(itemId)`) and calls `_router.go(route)`. The global `navigatorKey` is deleted — go_router's own router-scoped navigation replaces its one and only use case.
- **`calendar_screen.dart`'s** second-shell push becomes `context.go(Routes.home)`, eliminating the duplicate shell.

## Reasons

- The four competing readiness checks and two conflicting destructive-action strategies are confirmed, measurable drift directly caused by having no single declarative source of truth — this is not a hypothetical future risk, it has already happened.
- Scoping adoption to screen-level navigation only (not dialogs/bottom sheets) matches where `go_router`'s actual value — declarative routes, redirects, deep-link resolution — applies, rather than forcing every transient overlay into a model built for navigational destinations.
- A single `redirect` function is testable in a way that four scattered imperative checks never could be, directly enabling the auth/pairing test coverage the Definition of Done requires.

## Consequences

**Positive:** Definition-of-Done items 6, 7, and 8 are satisfied directly by this decision. A new screen is added in one place (the route registry) rather than wired by hand at each call site. Deep-linking (a notification opening a specific memory) becomes a first-class, testable concern (`redirect`/route-resolution unit tests) instead of embedded imperative logic.

**Negative:** this is the largest single mechanical migration in the whole roadmap by call-site count (56+41 conversions across 44 files) — mitigated by doing it early (Migration Phase 3, right after `CoupleSession` exists) specifically so it isn't compounded with the later state-ownership split's own risk.

**Risk called out explicitly:** a deep link (notification tap) arriving before `CoupleSession` has finished hydrating must not silently drop the link. The `redirect` treats `SessionStage.loading` as a state that redirects to nothing (defers), rather than bouncing to `WelcomeScreen` and losing the pending route.

## Rejected alternatives
- Centralize logic only, keep imperative `Navigator` (option 1) — doesn't fix the structural service→screens coupling.
- Route-ify dialogs and bottom sheets (option 2) — over-engineering; these aren't navigational destinations.

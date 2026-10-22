# ADR-001: Feature-Based Architecture

## Status
Accepted

## Context
Days Together's `lib/` (137 files, 49,236 lines) is organized by **technical type** — `providers/`, `screens/`, `services/`, `widgets/`, `models/` — not by feature. A single feature (e.g. "vault") has its provider in `providers/vault_provider.dart`, its screen in `screens/together/vault_screen.dart`, and its model in `models/vault_item_model.dart`, with no directory grouping that reflects the feature boundary.

**CURRENT STATE** consequences of this, verified against the repo:
- `lib/widgets/dashboard/bento_grid.dart` (2,390 lines) imports 8 providers and 7 screens because it is the Home tab's composition root with nowhere feature-scoped to live.
- `lib/widgets/` mixes truly generic components (~12%, e.g. `glass_container.dart`) with feature-specific ones (~73%, e.g. `music_controls.dart`, `raster_canvas.dart`) with no directory signal distinguishing them.
- Two files declare full-screen route targets while living in `widgets/`: `theme_selector.dart` (`ThemeSelectorScreen`) and `timeline_item.dart` (`MemoryDetailScreen`), the latter imported by `services/notification_service.dart`.
- There is no enforced boundary preventing one feature's provider from reaching into another feature's internals — the only reason it hasn't happened more is discipline, not structure.

## Problem
As the app grows, technical-type organization means understanding or changing a single feature requires touching 4–5 unrelated top-level directories, and nothing stops accidental cross-feature coupling.

## Options considered

1. **Keep technical-type layout.** Zero migration cost. Rejected: it is the direct cause of the `bento_grid.dart`/`storage_image.dart` coupling problems documented above, and it will only get worse as features are added.
2. **Full Clean Architecture per feature** (`data/domain/presentation` with mandatory use-cases for every feature). Rejected: the audit found the service layer is already healthy (15 files, avg. 145 lines, no god services) and only one feature (scrapbook sharing) has a genuine multi-provider transaction that needs a use-case. Mandating a domain layer everywhere would add ceremony with no corresponding problem to solve — see ADR-009.
3. **Feature-based + modular, with an explicit, enforced promotion rule for shared code.** Chosen.

## Decision
Reorganize `lib/` around feature boundaries:

```
lib/
├── app/            # bootstrap, app.dart
├── core/            # cross-cutting: design_system, errors, routing infra, prefs keys
├── features/
│   ├── authentication/   # CoupleSession, sign-in/up, Google auth
│   ├── relationship/     # pairing, workspace, license, profile
│   ├── timeline/
│   ├── vault/
│   ├── scrapbook/         # noteit
│   ├── chat/              # love_chat (shares the love_notes table with scrapbook — see ADR-005)
│   ├── bucket_list/
│   ├── calendar/
│   ├── gift_reminders/
│   ├── topic_cards/
│   ├── mood/               # daily_mood + love_meter
│   ├── currently/          # love_taps
│   ├── love_studio/         # ai_love_letter, time_capsule, relationship_insights
│   ├── wrapped/
│   ├── dashboard/            # the Home tab composition
│   └── settings/
└── shared/           # only components promoted per ADR-008
```

Each feature owns its provider(s)/notifier(s), screens, feature-specific widgets, and models. See `feature-boundaries.md` for the per-feature "owns / must not contain" contract.

**Enforced, not aspirational.** A `test/architecture_test.dart` rule (introduced in Migration Phase 0) forbids a file in `lib/features/<A>/**` from importing a non-public path in `lib/features/<B>/**`. This rule ships **empty of features to move** in Phase 0 and is tightened as each feature is relocated (Phase 7b) — it is a ratchet, not a one-time review.

## Reasons

- Matches the app's actual complexity, which is organized around product capabilities (Vault, Timeline, Scrapbook), not deep, independently-evolving business domains.
- Makes already-confirmed coupling (`bento_grid.dart`'s 8-provider/7-screen fan-in, the `widgets/` dumping ground) a visible, governable fact instead of an accident with no structural signal.
- The enforcement mechanism (architecture test) makes the boundary durable rather than aspirational — it survives beyond the one-time migration effort.

## Consequences

**Positive:** a developer working on "vault" touches one directory. `bento_grid.dart`'s 8-provider/7-screen fan-in becomes visible as a `dashboard` feature legitimately depending on 8 others — a fact, not an accident. The promotion rule (ADR-008) stops the shared folder from becoming a second dumping ground.

**Negative:** the relocation itself (Phase 7b, moving ~73% of `lib/widgets/`) is a large mechanical diff across many files, done after routing (Phase 3) and state (Phase 5/5b) so it isn't compounded with behavioral risk.

**Neutral:** `authentication` and `relationship` overlap conceptually (both derive from the god `RelationshipProvider` split in ADR-002) — the boundary is drawn along the state-ownership split from Phase 1/5: `authentication` owns `CoupleSession` (identity/session), `relationship` owns `WorkspaceController`/`LicenseController`/`ProfileController` (the couple's shared data).

## Rejected alternatives
- Full Clean Architecture (option 2) — over-engineered for a 2-developer household app with a healthy service layer.
- No reorganization (option 1) — status quo is the documented problem, not a neutral baseline.

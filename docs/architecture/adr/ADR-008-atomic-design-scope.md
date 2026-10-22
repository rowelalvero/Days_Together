# ADR-008: Atomic Design — Selective Scope with a Promotion Rule

## Status
Accepted

## Context
**CURRENT STATE, verified:** `lib/widgets/` (37 files, 10,564 lines across the root and its `dashboard/`/`wrapped/` subdirectories) was classified file-by-file during the audit:

- **~12% (~1,244 lines, 11–12 files)** are genuinely generic and reusable across any feature: `glass_container.dart` (the closest thing to a real design-system primitive — a parameterized glassmorphism box), `cached_avatar.dart`, `app_avatar.dart` (two files independently claiming to be "the single source of truth" for avatars — a duplication this ADR's scope also surfaces for cleanup), `shimmer_loader.dart`, `safe_loading_dialog.dart`, `online_glow.dart`, `pulsing_logo.dart`, `burst_hearts.dart`, `confetti_overlay.dart`, `color_picker_dialog.dart`, `storage_image.dart`.
- **~73% (~7,700 lines)** are feature-specific but currently live in the shared `widgets/` tree anyway — all 9 files of `widgets/dashboard/` (led by `bento_grid.dart` at 2,390 lines), most of `widgets/wrapped/`, plus `add_item_dialog.dart` (a timeline feature), `memory_notes_section.dart` (memory-detail feature), `music_controls.dart` (music feature), `raster_canvas.dart`/`rich_text_editor_overlay.dart`/`custom_backgrounds.dart`/`text_overlay_widget.dart` (all noteit/canvas feature), `ruler_picker_scrubber.dart` (timeline-only, embedded directly in the app shell).
- **~15%** are full route-target screens misfiled as widgets: `theme_selector.dart` declares `ThemeSelectorScreen` (pushed as a route from `settings_tab.dart`); `timeline_item.dart` declares not just its card widget but also `MemoryDetailScreen` (a full screen, imported by `notification_service.dart`) and `_EditItemDialog`.

Separately, the app's actual design tokens are minimal: `LoveStoryTheme` has 8 fields (6 colors, a name, a brightness bool) — no spacing, radius, elevation, or motion tokens exist to build true "atoms" against.

## Problem
Naively applying textbook Atomic Design (atoms/molecules/organisms as the organizing principle for the *entire* UI) to a codebase where 88% of the shared-widgets folder is actually feature-specific would misclassify most of the app and create a shared folder that is really just a second, less-organized copy of `lib/screens/`. That is close to what has already happened: `widgets/` today already functions as an uncontrolled dumping ground where 73% of its content has no business being shared.

## Options considered

1. **Full Atomic Design as the primary organizing structure for all UI code.** Rejected: the audit's own classification shows only ~12% of existing widgets fit the atoms/molecules/organisms model meaningfully; forcing the other 88% into that taxonomy would be artificial, and the app doesn't have enough truly generic components (the 8-field theme has no room for atoms like spacing/radius to be built consistently — see ADR design-system.md) to justify it as the primary structure.
2. **No shared component tier at all — every widget lives inside its owning feature, full stop.** Rejected: this would force genuine duplication of the ~12% that *is* legitimately generic (e.g. every feature reimplementing its own glass container or loading skeleton), which is worse than the current single (if overstuffed) shared folder.
3. **Selective Atomic Design: promote only what's already generic, apply a strict promotion rule to prevent re-accumulation, relocate everything else into features.** Chosen.

## Decision
`lib/shared/` (replacing the current flat `lib/widgets/`) holds only components meeting the promotion rule below, organized loosely as atoms/molecules/organisms where that grouping is genuinely informative (it is optional structure within `shared/`, not mandatory):

- **Atoms** — smallest, style-only primitives: candidates from the ~12% include a consolidated avatar component (merging `cached_avatar.dart`/`app_avatar.dart`'s duplicated "source of truth" claim into one), loading/shimmer primitives, the glass container.
- **Molecules** — small compositions of atoms with minor logic: `safe_loading_dialog.dart`'s async-wrapper pattern, `online_glow.dart`'s presence indicator.
- **Organisms** — larger, still feature-agnostic compositions: none currently qualify; this tier exists for future components that earn it.

**Promotion rule (the actual enforcement mechanism):** a component is promoted into `lib/shared/` **only when a second feature genuinely needs it** — not speculatively, not because "it might be reusable." A component built for one feature stays in that feature's `presentation/` directory until a second, real consumer exists. This is deliberately the opposite of designing a shared component library up front.

**Everything in the ~73% and ~15% buckets relocates into its owning feature** (Migration Phase 7b, per ADR-001's feature-based reorganization): `widgets/dashboard/*` → `features/dashboard/presentation/`; `widgets/wrapped/*` → `features/wrapped/presentation/`; `music_controls.dart` → `features/settings/presentation/` (or wherever music lives); the noteit-canvas cluster (`raster_canvas.dart`, `rich_text_editor_overlay.dart`, `custom_backgrounds.dart`, `text_overlay_widget.dart`) → `features/scrapbook/presentation/`; `ruler_picker_scrubber.dart` → `features/timeline/presentation/`; `add_item_dialog.dart` → `features/timeline/presentation/`; `memory_notes_section.dart` → `features/timeline/presentation/` (memory detail). `theme_selector.dart`'s `ThemeSelectorScreen` and `timeline_item.dart`'s `MemoryDetailScreen` are extracted into `lib/screens/` (or their owning feature's `presentation/screens/`) as part of Phase 0's mechanical cleanup, ahead of the broader relocation.

**Enforcement:** the architecture test suite (`testing-strategy.md`) forbids a file under `lib/features/<A>/**` from importing a non-`shared` file under `lib/features/<B>/**` — this makes accidental cross-feature widget reuse a compile-time-adjacent failure (test failure) rather than a silent, unreviewed dependency, and is what makes the promotion rule actually stick going forward rather than degrading back into an uncontrolled shared folder over time.

## Reasons

- The audit's own classification shows only ~12% of the existing widget tree is genuinely generic — applying full Atomic Design to the other 88% would be artificial, describing components as reusable that in fact serve exactly one feature.
- The promotion rule targets the confirmed failure mode directly: `lib/widgets/` already functions as an uncontrolled dumping ground today (73% misplaced content), and a rule requiring a second real consumer before promotion is what stops that from recurring in `lib/shared/`.
- Forcing every feature-specific widget into a shared taxonomy it doesn't belong to would make features harder to understand in isolation, undermining the feature-boundary goal of ADR-001.

## Consequences

**Positive:** Definition-of-Done item 17 is satisfied by construction — "follows promotion rules" is enforced, not just documented. `bento_grid.dart`'s 8-provider/7-screen fan-in, once relocated into `features/dashboard/`, becomes a legible fact about the dashboard feature's legitimate breadth rather than an anomaly in a shared folder. The `cached_avatar.dart`/`app_avatar.dart` duplication is surfaced for resolution (one becomes the promoted atom, the other is deleted) as a direct consequence of applying the promotion rule.

**Negative:** the relocation of ~73% of `widgets/` is a large mechanical diff (Phase 7b, ~3–5 days) — deliberately sequenced after routing and state-ownership work so it doesn't compound with behavioral risk, per the migration roadmap's ordering rationale.

## Rejected alternatives
- Full Atomic Design as primary structure (option 1) — doesn't match the codebase's actual composition (88% non-generic).
- No shared tier at all (option 2) — forces real duplication of genuinely reusable primitives.

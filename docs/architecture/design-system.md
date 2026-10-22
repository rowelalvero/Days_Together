# Design System

**PROPOSED** expansion, built on **CURRENT STATE** visual identity, which is **formalized, not redesigned** — no color, gradient, or typeface choice in this document changes what the app looks like today.

## Current tokens (CURRENT STATE)

`lib/themes/theme_manager.dart` defines exactly one token class, `LoveStoryTheme`, with 8 fields:

```dart
class LoveStoryTheme {
  final String name;
  final Color primaryColor, secondaryColor, backgroundColor, textColor, cardColor, accentColor;
  final bool isDark;
}
```

Six named themes resolve to this shape (`midnightRose`/"Midnight Glass", `liquidGlass`/"Azure Liquid", `pink`/"Rose Quartz", `deepPurple`/"Neon Violet", `offWhite`/"Lovely Off-White", plus a runtime-built `custom` theme). A single gradient shape is derived from three of these colors (`ThemeManager.getGradient`).

**This is why ~986 hardcoded color literals exist across the UI, verified by grep** (top offenders: `relationship_license_screen.dart` at 123 combined hits, `noteit_screen.dart` at 103, `rich_text_editor_overlay.dart` at 47): there is **no token for anything except color**. A developer needing a border radius, a blur amount, an elevation, or an animation duration has no design-system value to reach for, so every one becomes a raw literal at its call site.

**The `dynamic theme` problem, verified:** the theme object is passed as `dynamic` at nearly every widget boundary — `_buildFeatureCard({required dynamic theme})`, `_buildNavItem(..., dynamic theme)`, `_showPremiumPaywall(BuildContext, dynamic theme)`, and similarly across `love_story_screen.dart`, `together_tab.dart`, `studio_tab.dart`, `settings_tab.dart`. This isn't a style preference — it silently discards Dart's type checking on every single token access at every one of those boundaries, meaning a typo like `theme.pirmaryColor` compiles and fails only at runtime.

`AppTypography` (`lib/themes/app_typography.dart`, 148 lines) has 15 static methods, all routed through `GoogleFonts.spectral(...)` — including methods named `lora`, `cormorant`, and `spectral`, which are legacy typeface aliases that all now resolve to the same font, a residue of the app's font-consolidation history. `mainCounter` and `pageTitle` are byte-for-byte identical (28pt, weight 700). `bodyMono`/`captionMono` are not actually monospace. Every call site overrides `fontSize`/`fontWeight` via optional parameters, so in practice there is no enforced scale — the 15 method names function more as loose presets than a real type system.

## Proposed token expansion

`LoveStoryTheme` becomes a `ThemeExtension<LoveStoryTheme>` (Flutter's own mechanism for app-specific theme tokens, integrating with `Theme.of(context)` rather than being hand-drilled as a parameter — closing the second half of the `dynamic theme` problem, not just its typing) with the existing 8 fields plus:

```dart
class LoveStorySpacing {
  final double xs, sm, md, lg, xl, xxl;   // e.g. 4, 8, 16, 24, 32, 48
}
class LoveStoryRadii {
  final double sm, md, lg, pill;           // e.g. 8, 16, 24, 999
}
class LoveStoryElevation {
  final double flat, low, medium, high;
}
class LoveStoryMotion {
  final Duration fast, normal, slow;       // e.g. 150ms, 300ms, 500ms
  final Curve standard, emphasized;
}
class LoveStorySemantic {
  final Color success, warning, error, info;   // distinct from the 6 aesthetic colors — see note below
}
```

**Semantic color is explicitly separate from the accent/aesthetic palette** — the 6 existing `LoveStoryTheme` colors (`primaryColor` etc.) express the app's romantic visual identity per selected theme; `LoveStorySemantic` expresses state (a destructive-action confirmation, a sync error, a success toast) and must read correctly regardless of which of the 6 aesthetic themes is active. Conflating the two is a common source of accidentally-unreadable error states when a theme's accent color happens to be red-adjacent.

## Typography consolidation

`AppTypography`'s 15 methods collapse to roughly 6 real, distinct roles, matching how the app actually uses type rather than how it currently names it:

| New role | Replaces | Notes |
|---|---|---|
| `display` | `mainCounter` + `pageTitle` (currently identical — one role, not two) | |
| `heading` | `sectionHeader` | |
| `title` | `cardTitle` | |
| `body` | `body` + `bodyLarge` + `bodyMedium` + `lora`/`cormorant`/`spectral` (all now the same font family) | |
| `label` | `cardCategory` + `button` + `caption` | |
| `mono` | `bodyMono` + `captionMono`, **actually set to a monospace font family** — the current bug (not-actually-monospace) is fixed as part of this consolidation, not carried forward under a new name |

Every role keeps the existing optional-override parameters (`{Color?, double? fontSize, FontWeight? fontWeight}`) — the consolidation removes *redundant/misleading names*, not the flexibility that makes the current system usable.

## Atomic Design boundaries and the promotion rule

Full detail in ADR-008; summarized here as the working reference:

- **Atoms/molecules/organisms live in `lib/shared/`** and cover only the ~12% of current `lib/widgets/` content confirmed genuinely generic: a consolidated avatar component (merging the current duplicated `cached_avatar.dart`/`app_avatar.dart`), the glass container primitive, loading/shimmer primitives, the async-safe-loading-dialog pattern, the presence-glow indicator.
- **Everything else relocates into its owning feature** (Migration Phase 7b) — dashboard widgets, wrapped widgets, the noteit canvas cluster, music controls, the timeline scrubber, etc.
- **Promotion rule:** a component enters `lib/shared/` only when a **second** feature genuinely needs it. No speculative "this might be reusable" promotion. This is the mechanism that stops `lib/shared/` from re-accumulating into the uncontrolled dumping ground `lib/widgets/` currently is (73% misplaced content, by the audit's classification).

## Dark/light

**CURRENT STATE:** 5 of 6 named themes are `isDark: true`; only `offWhite`/"Lovely Off-White" is light. This asymmetry is preserved as-is — it reflects a deliberate design choice (the app's aesthetic is predominantly dark/glassmorphic), not an oversight, and this migration does not add a formal "light mode" requirement beyond what already exists.

## Material 3 / Google Fonts configuration

**CURRENT STATE, unchanged by this document:** `main.dart` builds a Material `ThemeData` from the active `LoveStoryTheme` via `ColorScheme.fromSeed`, with `GoogleFonts.spectralTextTheme` as the base and a fallback to `interTextTheme` if the network font fetch fails. This remains the correct pattern; the `ThemeExtension` addition composes with it rather than replacing it — `Theme.of(context).extension<LoveStoryTheme>()` becomes the typed accessor, while Material's own `ColorScheme`/`TextTheme` continue governing default widget chrome (buttons, app bars) that doesn't need the app-specific tokens.

## What is explicitly NOT touched

`screens/wrapped/**`'s separate `WrappedGradients` palette (`widgets/wrapped/wrapped_cinematic_bg.dart`) is not merged into `ThemeProvider`. It is an intentional, self-contained seasonal aesthetic (in the spirit of Spotify Wrapped's own theme-independent visual identity) — unifying it with the app's day-to-day theme system would remove the deliberate visual distinction between "using the app" and "viewing your yearly recap," for no architectural benefit.

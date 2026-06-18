# Phase 2: UI/UX & Styling Polish - Context

**Gathered:** 2026-06-19
**Status:** Ready for planning
**Source:** UI Review Findings (1-UI-REVIEW.md)

<domain>
## Phase Boundary

This phase covers systematic UI/UX refinements to styling and copywriting:
1. Migration of remaining 218 occurrences of hardcoded colors to the ThemeProvider dynamic system.
2. Normalization of layout padding, margins, and spacing to the 4px/8px design scale.
3. Revision of generic onboarding/settings button copywriting to be descriptive.

</domain>

<decisions>
## Implementation Decisions

### 1. Dynamic Color Migration
- All screens must reference the current theme colors: `Provider.of<ThemeProvider>(context).currentLoveTheme` instead of hardcoded hex values (e.g., `Color(0xFF1A1B41)`) or standard `Colors.redAccent`/`Colors.teal` elements.
- Maintain dark/light accessibility.

### 2. Spacing Normalization
- Normalization of minor layout gaps:
  - Normalize any margins/padding of `15` to `16`.
  - Normalize margins/padding of `14` to `16`.
  - Normalize arbitrary spacing of `3` or `5` to `4` or `8`.
- Apply spacing rules across all screen views.

### 3. Copywriting Upgrades
- Generic button text in onboarding screens (e.g. "Submit") should be updated to descriptive labels like "Sign In" or "Join Couple".
- Settings screen controls updated to descriptive action terms.

### Claude's Discretion
- Code refactoring of helper UI widgets if spacing normalization can be consolidated.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Styling & Theme System
- `lib/providers/theme_provider.dart` — Custom dynamic themes definitions
- `lib/main.dart` — App initialization and material theme fallbacks

### Target Screens for Polish
- `lib/screens/onboarding/auth_screen.dart` — Auth inputs & action buttons
- `lib/screens/onboarding/join_couple_code_screen.dart` — Code verification & input spacing
- `lib/screens/onboarding/genesis_screen.dart` — Setup screens styling
- `lib/screens/settings/relationship_profile_screen.dart` — Profile settings details
- `lib/screens/settings_tab.dart` — Settings action controls
- `lib/screens/love_story_screen.dart` — Memory display styling

</canonical_refs>

<deferred>
## Deferred Ideas

- None — Phase covers full scope of styling cleanup.

</deferred>

---
*Phase: 02-ui-ux-styling-polish*
*Context gathered: 2026-06-19*

# Phase 2 Research: UI/UX & Styling Analysis

**Completed:** 2026-06-19
**Scope:** Hardcoded colors, non-standard spacings, and generic button copywriting.

## Codebase Scan Findings

### 1. Hardcoded Color Occurrences
A scan of `lib/` identified 190 occurrences of hardcoded colors, primarily:
- `Color(0xFF1A1B41)` (deep blue background/surface) used in:
  - `lib/screens/onboarding/auth_screen.dart` (line 320)
  - `lib/screens/onboarding/genesis_screen.dart` (lines 89, 119)
  - `lib/screens/settings/relationship_profile_screen.dart` (lines 281, 310)
- `Colors.teal` and `Colors.lightBlueAccent` used in:
  - `lib/screens/onboarding/auth_screen.dart` (line 48)
  - `lib/screens/onboarding/pairing_selection_screen.dart` (line 70)

*Note: Preset colors used as user-selectable note backgrounds in `lib/providers/noteit_provider.dart` (e.g. `Color(0xFF9D4EDD)`) are functional parameters and should remain preserved as selectable options, but visual UI panels wrapping them should consume theme tokens.*

### 2. Spacing Normalization Gaps
Identified 9 occurrences of non-standard `SizedBox` dimensions:
- `SizedBox(height: 15)` / `SizedBox(width: 15)` (should be normalized to `16` or `12`):
  - `lib/screens/love_story_screen.dart` (lines 217, 221, 276, 467, 473, 605)
  - `lib/screens/onboarding/create_couple_code_screen.dart` (line 145)
- `SizedBox(height: 3)` (should be normalized to `4` or `2`):
  - `lib/screens/together/relationship_license_screen.dart` (lines 2587, 2743)

### 3. Copywriting & Action Callouts
The following buttons use generic labels that reduce interaction context:
- `auth_screen.dart`: "Submit" -> "Sign In" / "Sign Up"
- `join_couple_code_screen.dart`: "Submit" -> "Link Couple Code"
- `settings_tab.dart`: "Save Changes" -> "Save Profile Details", "Cancel" -> "Discard Changes"

---

## Validation Architecture

### Automated Verification
- Verify the build compiles without any layout exceptions or type warnings:
  ```bash
  flutter test
  ```

### Manual Visual Verification
1. Open the app, login, and access Settings.
2. Toggle between various themes (Midnight Rose, Sunset Glow, etc.) and check that:
   - Onboarding welcome screen buttons match the selected primary/accent colors.
   - Profile card containers and forms update their backgrounds and border colors dynamically.
   - Spacing is uniformly aligned to the 4px/8px grid.

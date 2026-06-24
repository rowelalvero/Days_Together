# Typography Centralization & Design System Spec

## Goal Description
Centralize and wire up all typography styles throughout the `ashwel_anniversary` application by introducing a shared `AppTypography` helper system. This eliminates hardcoded `GoogleFonts` calls in UI widgets, ensuring typographic consistency, custom styling overrides, and a single source of truth for font families, sizes, weights, and line heights.

- [x] **Task 3: Refactor Dashboard Sub-Widgets Typography**
  - [x] Step 1: Replace GoogleFonts calls in dashboard helper widgets
  - [x] Step 2: Run static analysis
  - [x] Step 3: Run unit tests
  - [x] Step 4: Commit

---

## 1. AppTypography Architecture
A new design system class `AppTypography` will be defined in `lib/themes/app_typography.dart`. It hosts semantic text styles categorized by UI roles:

- `pageTitle`: Large headers for main screens and onboarding.
- `sectionHeader`: Mid-size headers for dialogs, settings sections, and tabs.
- `cardTitle`: Bento grid card headers.
- `cardCategory`: Monospace capsule badges.
- `bodyLarge`: Primary text lists, chat bubbles.
- `bodyMedium`: Secondary readouts and details.
- `bodyMono`: Code blocks or status logs.
- `button`: Monospace interactive links and button actions.
- `caption`: Normal metadata, relative times.
- `captionMono`: Monospace indices and tiny count readouts.
- `lora`: Serif styling for letters, passages, and story highlights.

### Interface Spec:
Each getter/method returns a `TextStyle` and accepts optional parameters (`color`, `fontSize`, `fontWeight`, `height`, etc.) to provide complete override support without needing verbose `.copyWith` chains:
```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextStyle pageTitle({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize ?? 28.0,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
      height: height,
    );
  }
  // ... (methods for all categories)
}
```

---

## 2. Refactoring Scope
We will refactor all Dart files in the codebase that contain hardcoded `GoogleFonts` calls. Key files to transition include:
1. `lib/widgets/dashboard/bento_grid.dart`
2. `lib/screens/love_story_screen.dart`
3. `lib/screens/settings_tab.dart`
4. `lib/screens/together_tab.dart`
5. `lib/screens/studio_tab.dart`
6. `lib/screens/together/*.dart` (screens for Noteit, Calendar, Vault, Love Chat, etc.)
7. `lib/screens/onboarding/*.dart` (Welcome, pairing, and authentication screens)
8. `lib/widgets/*.dart` (Milestone cards, ruler picker, storybook view, etc.)

---

## 3. Verification Plan
- **Static Analysis**: Run `flutter analyze` after refactoring each layer to ensure correct imports and method invocations.
- **Unit & Widget Tests**: Run `flutter test` to ensure that standard providers and widgets compile and function correctly.

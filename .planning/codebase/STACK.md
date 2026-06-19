# Technology Stack

**Analysis Date:** 2026-06-19

## Languages

**Primary:**
- Dart (SDK ^3.10.0) - Core application logic, models, providers, services, screens, and custom widgets.

**Secondary:**
- Kotlin / Java - Android-specific configuration and platform builds under `android/`.
- Swift / Objective-C - iOS-specific configuration and platform builds under `ios/`.
- C++ / C - Desktop native wrappers under `windows/`, `linux/`, and `macos/`.
- HTML / JavaScript - Web deployment templates under `web/`.

## Runtime

**Environment:**
- Flutter SDK (minimum compatible version 3.10.0)

**Package Manager:**
- Flutter Pub
- Lockfile: `pubspec.lock` (present)

## Frameworks

**Core:**
- Flutter Framework - Cross-platform UI development with Material Design.

**Testing:**
- Flutter Test - Standard unit and widget testing library.

**Build/Dev:**
- Flutter CLI - Compilation, package management, and device runners.

## Key Dependencies

**Critical:**
- `provider: ^6.1.1` - State management and dependency injection wrapper.
- `supabase_flutter: ^2.6.0` - Backend services including auth, database synchronisation, and realtime channels.
- `shared_preferences: ^2.2.2` - Key-value storage for offline local settings and offline caching.
- `path_provider: ^2.1.0` - Path detection for local file storage (e.g. caches, local files).
- `google_sign_in: ^6.2.1` - Authentication integration with Google Identity.

**UX & Animations:**
- `animations: ^2.0.7` - Smooth material motion transitions.
- `lottie: ^2.7.0` - Vector animation support.
- `shimmer: ^3.0.0` - Shimmer effects for loading states.
- `google_fonts: ^6.2.1` - Dynamic custom typography loading.
- `confetti: ^0.8.0` - Confetti celebration overlays.
- `fl_chart: ^0.70.2` - Interactive charts.
- `audioplayers: ^6.5.1` - Music playing capabilities.
- `qr_flutter: ^4.1.0` - Couples' pairing via QR codes.

## Configuration

**Environment:**
- Configured in code in `lib/main.dart` with standard Supabase URL and anon client keys.
- SharedPreferences is initialized asynchronously to load user preferences.

**Build:**
- Gradle configuration in `android/build.gradle.kts` and `android/app/build.gradle`.
- Xcode projects configured in `ios/Runner.xcodeproj`.
- Web templates configured in `web/index.html`.

## Platform Requirements

**Development:**
- Flutter SDK installed.
- Android Studio / VS Code with Dart & Flutter extensions.
- CocoaPods (for macOS/iOS development).

**Production:**
- Android SDK 21+ (minSdkVersion).
- iOS 11.0+ (minimum platform version).

---

*Stack analysis: 2026-06-19*

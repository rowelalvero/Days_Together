# Codebase Structure

**Analysis Date:** 2026-06-19

## Directory Layout

```text
ashwel_anniversary/
├── assets/                     # Static media and configurations
│   ├── animations/             # Lottie animations (.json)
│   ├── fonts/                  # Custom typographic assets (.ttf)
│   ├── images/                 # Image assets and placeholders
│   └── music/                  # Audio tracks (.mp3)
├── lib/                        # Flutter core application source code
│   ├── models/                 # Immutable data transfer objects (DTOs)
│   ├── providers/              # ChangeNotifier state modules
│   ├── repositories/           # Local storage cache services
│   ├── screens/                # UI Screens grouped by application flow
│   │   ├── onboarding/         # Onboarding, pairing, and pairing codes
│   │   ├── settings/           # Configurations and profile customizations
│   │   └── studio/             # Interactive games and letter generators
│   ├── services/               # Infrastructure, music playback, and AI integrations
│   ├── themes/                 # Glassmorphic themes definitions
│   └── widgets/                # Reusable visual widgets and UI elements
├── test/                       # Unit and widget verification suites
├── android/                    # Android-specific Gradle configurations
├── ios/                        # iOS-specific build configs (Runner)
├── web/                        # Web HTML5 index file
├── windows/                    # Windows desktop compilation build
├── macos/                      # macOS desktop compilation build
├── linux/                      # Linux desktop compilation build
├── firebase.json               # Firebase deployment targets
├── firestore.rules             # Firestore security rules configurations
├── storage.rules               # Storage bucket security specifications
└── pubspec.yaml                # Flutter project dependencies and metadata
```

## Directory Purposes

**lib/models/:**
- Purpose: Contains simple data classes representing app states.
- Contains: Model definition Dart files.
- Key files: `lib/models/timeline_model.dart`, `lib/models/vault_item_model.dart`.

**lib/providers/:**
- Purpose: Orchestrates UI updates, user events, and database integrations.
- Contains: ChangeNotifier files subscribing to Supabase connections.
- Key files: `lib/providers/relationship_provider.dart`, `lib/providers/timeline_provider.dart`.

**lib/screens/:**
- Purpose: View files rendering pages for the users.
- Contains: Screen-level widgets and layout wrappers.
- Key files: `lib/screens/love_story_screen.dart`, `lib/screens/onboarding/welcome_screen.dart`.

**lib/widgets/:**
- Purpose: Hosts reusable sub-components.
- Contains: Button components, custom animations, overlays, and styles.
- Key files: `lib/widgets/glass_container.dart`, `lib/widgets/shake_to_hug.dart`, `lib/widgets/burst_hearts.dart`.

## Key File Locations

**Entry Points:**
- `lib/main.dart`: Direct entry point initiating system loops, loading dependencies, and launching the initial route.

**Configuration:**
- `pubspec.yaml`: Contains metadata, runtime rules, assets, font bindings, and package constraints.
- `analysis_options.yaml`: Sets standard linting guidelines.

**Core Logic:**
- `lib/providers/relationship_provider.dart`: Owns authentication status, couple code creation, and pairing validation.

**Testing:**
- `test/models_test.dart`: Standard unit test class confirming models immutability and copy configurations.

## Naming Conventions

**Files:**
- snake_case: All Dart source files and directories must be named in snake_case format (e.g., `timeline_item.dart`, `avatar_creation_screen.dart`).

**Directories:**
- snake_case: Subdirectories match lowercase snake_case (e.g., `onboarding`, `together`).

## Where to Add New Code

**New Feature Screen:**
- Primary code: Create files inside `lib/screens/` under the appropriate sub-category (e.g., `lib/screens/together/`).
- State / Business Logic: Register a new `ChangeNotifier` in `lib/providers/` and expose it in the `MultiProvider` array inside `lib/main.dart`.

**New Reusable Component:**
- Implementation: Add to `lib/widgets/` using descriptive, camelCase naming inside class declarations.

**Utilities & Repositories:**
- Local storage operations: Add a new repository to `lib/repositories/`.
- Device integrations: Add to `lib/services/`.

## Special Directories

**assets/themes/:**
- Purpose: Stores custom theme configurations and styling guidelines.
- Generated: No.
- Committed: Yes.

---

*Structure analysis: 2026-06-19*

<!-- refreshed: 2026-06-19 -->
# Architecture

**Analysis Date:** 2026-06-19

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                       Presentation Layer                    │
│    `lib/screens/` (Dashboard, Onboarding, Tab Views)        │
│    `lib/widgets/` (Glass container, Custom Animations)      │
└────────┬───────────────────────┬────────────────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    State & Business Logic                   │
│    `lib/providers/` (ChangeNotifier, ChangeNotifierProxy)    │
│    `lib/themes/` (ThemeManager, ThemeProvider)              │
└────────┬───────────────────────┬────────────────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────────────────────────────────────────────────┐
│                 Data Access & Infrastructure                │
│    `lib/repositories/` (TimelineRepository - SharedPrefs)    │
│    `lib/services/` (AIService, MusicService)                │
└────────┬───────────────────────┬────────────────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────────────────────────────────────────────────┐
│                       Backend Services                      │
│    Supabase API (`supabase_flutter` remote database)         │
│    SharedPreferences (local key-value cache)                │
└─────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Presentation (Screens) | Handles navigation, UI layouts, and user interactions. | `lib/screens/love_story_screen.dart` |
| Presentation (Widgets) | Provides reusable visual widgets, micro-animations, and custom designs. | `lib/widgets/glass_container.dart` |
| State Providers | Manages business logic, authentication states, and sync triggers. | `lib/providers/relationship_provider.dart` |
| Data Repositories | Abstracts persistent storage reading and writing from providers. | `lib/repositories/timeline_repository.dart` |
| Infrastructure Services | Interfaces with device/external APIs (Music, simulated AI generation). | `lib/services/ai_service.dart` |
| Themes & Styles | Manages the custom Glassmorphism and color palette configurations. | `lib/themes/theme_manager.dart` |

## Pattern Overview

**Overall:** Model-View-ViewModel (MVVM) / Provider-centric state management architecture.

**Key Characteristics:**
- **Proxy Injection:** Sub-providers inherit couple ID and relationship state from the parent `RelationshipProvider` via `ChangeNotifierProxyProvider` update bindings.
- **Offline Cache Fallback:** Local data is preserved via SharedPreferences repositories so the app starts up instantaneously before Supabase remote connections synchronize.
- **Glassmorphism Theme System:** A custom theme system utilizing `LoveStoryTheme` presets to style visual containers with translucency and gradient backdrops.

## Layers

**Presentation Layer:**
- Purpose: Render couple widgets and accept user input.
- Location: `lib/screens/` and `lib/widgets/`
- Contains: Flutter widgets (`StatelessWidget`, `StatefulWidget`), animations, navigation controllers.
- Depends on: `lib/providers/`, `lib/models/`, `lib/themes/`

**State Management Layer:**
- Purpose: Encapsulate shared states (e.g., Couple status, Auth user, Timeline lists) and dispatch changes to listeners.
- Location: `lib/providers/`
- Contains: `ChangeNotifier` and `ChangeNotifierProxyProvider` subclasses.
- Depends on: `lib/models/`, `lib/repositories/`, `lib/services/`, `supabase_flutter`
- Used by: Presentation Layer

**Data & Service Layer:**
- Purpose: Perform I/O operations (fetching from Supabase, saving to local preferences, playing music).
- Location: `lib/repositories/` and `lib/services/`
- Contains: Local filesystem APIs, network endpoints, repository caches.
- Depends on: `lib/models/`, `shared_preferences`, `path_provider`, `audioplayers`
- Used by: State Management Layer

## Data Flow

### Primary Couple Connection & Pairing Flow
1. Onboarding starts in `lib/screens/onboarding/welcome_screen.dart` checking relationship pairing status in `RelationshipProvider`.
2. Unpaired users are redirected to `pairing_selection_screen.dart` where they can either generate a Couple Code (`create_couple_code_screen.dart`) or join with an existing code (`join_couple_code_screen.dart`).
3. Generating a code creates an invite entry in the database. Joining a code updates both users' records in the `couples` table via `RelationshipProvider.joinWithCode`.
4. Once paired, the app navigates to `lib/screens/love_story_screen.dart` where proxy providers initialize dependent databases using the shared `coupleId`.

### Data Synchronization Path
1. Local edits trigger provider methods (e.g., `TimelineProvider.addItem`).
2. The item is added to the local cache and written asynchronously to Supabase.
3. Supabase realtime stream notifies active channels, triggering updates in both partner apps.

**State Management:**
- Application state is managed via `package:provider`. Views consume states using `context.watch<T>()` or `Consumer<T>()`, and update state via `context.read<T>().action()`.

## Key Abstractions

**Models Immutability:**
- Purpose: Prevent side-effects when modifying local states.
- Examples: `lib/models/timeline_model.dart`, `lib/models/vault_item_model.dart`
- Pattern: Auto-generated/manual `fromJson`, `toJson`, and `copyWith` modifiers.

**Proxy Providers:**
- Purpose: Distribute coupling context down the provider tree.
- Examples: `ChangeNotifierProxyProvider` updates in `lib/main.dart`.

## Entry Points

**main():**
- Location: `lib/main.dart`
- Triggers: System startup.
- Responsibilities: Pre-initializes `WidgetsFlutterBinding`, connects to Supabase, binds all Providers, and mounts `MultiProvider` wrapper.

## Architectural Constraints

- **Single Active Relationship:** A user can only belong to one couple record (`coupleId`) at a time.
- **Naming Legacy:** Legacy names referring to "Firebase" (like `isFirebaseAvailable`) are used to check Supabase client status.
- **Realtime Sync Overhead:** Heavily relies on Supabase database streams; offline modifications require internet connection to synchronize with the partner device.

## Anti-Patterns

### Firebase/Supabase Name Pollution
- **What happens:** Classes and methods use "Firebase" in names but interact with the "Supabase" SDK (e.g. `RelationshipProvider._initFirebaseSync`).
- **Why it's wrong:** Causes developer confusion regarding which cloud platform is active.
- **Do this instead:** Refactor legacy helper functions to reflect the active `Supabase` backend.

### Inline Business Logic inside Providers
- **What happens:** Data manipulation and networking logic are fully written inside `ChangeNotifier` classes, skipping repository layers.
- **Why it's wrong:** Increases provider class size and makes unit testing difficult.
- **Do this instead:** Extract data fetching/saving tasks into dedicated repositories similar to `lib/repositories/timeline_repository.dart`.

## Error Handling

**Strategy:** Fail-silent / User notification fallback.

**Patterns:**
- Try/catch blocks wrap Supabase calls, logging details via `debugPrint` and displaying alerts when UI-critical operations fail.

---

*Architecture analysis: 2026-06-19*

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

**Days Together** is a Flutter app (Dart SDK ^3.10.0) for couples: a shared relationship timeline, calendar, bucket list, note-its, love chat, AI-generated love letters, time capsules, daily moods, topic cards, a relationship "license", and a year-in-review "Wrapped". It's backed by Supabase (Postgres + Realtime + Auth + Storage + Edge Functions).

State management is **Riverpod** (`flutter_riverpod` 3.x) and routing is **go_router** 17.x. Every feature is scoped to exactly two paired users (a "couple").

## Common commands

```bash
flutter pub get                    # install dependencies
flutter run                        # run on connected device/emulator
flutter test                       # run all tests
flutter test test/some_test.dart   # run a single test file
flutter test test/architecture_test.dart   # the architectural guardrails (see below)
flutter analyze                    # static analysis (flutter_lints via analysis_options.yaml)
dart format lib/ test/             # both are formatted; keep them that way
supabase start && supabase db reset   # local Postgres with every migration applied
supabase test db                   # pgTAP security suite (supabase/tests/) -- see docs/security/security-invariants.md
flutter build appbundle            # Android release build
flutter build ipa                  # iOS release build
```

### Environment configuration

Supabase/Google OAuth credentials are compile-time `--dart-define` values consumed by [lib/app/config/app_config.dart](lib/app/config/app_config.dart), each with a hardcoded fallback (the Supabase anon key is safe to expose — access is enforced by Postgres RLS policies, not by key secrecy). To point at a different backend:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=GOOGLE_CLIENT_ID_WEB=your-google-web-client-id \
  --dart-define=GOOGLE_CLIENT_ID_IOS=your-google-ios-client-id
```

Never put a Supabase `service_role` key in the client. See [BUILD_AND_RUN.md](BUILD_AND_RUN.md) for the VS Code `launch.json` equivalent.

### Supabase backend

- [supabase/migrations/](supabase/migrations/) is the source of truth for schema, RLS policies, and RPCs — sequential, timestamp-named SQL files. **Never edit an already-applied migration; add a new one.** (An unapplied migration that failed to push is fair game to fix in place.)
- [supabase/functions/](supabase/functions/) holds Edge Functions (e.g. `send-push-notification`).
- Tables: `users`, `couples`, `couple_key_exchanges`, `timeline_items`, `bucket_list`, `calendar_events`, `moods`, `daily_questions`, `gift_reminders`, `love_notes`, `love_taps`, `license_details`, `topic_cards`, `topic_card_likes`, `time_capsules`, `user_fcm_tokens`, `user_notification_preferences`, plus the rate-limiting/bookkeeping tables `failed_pairing_attempts`, `failed_recovery_attempts`, `user_recovery_attempts`, `storage_cleanup_queue`.
- Storage buckets: `avatars`, `timeline`, `love-notes` (see `StorageBuckets` in [lib/core/storage/storage_url_service.dart](lib/core/storage/storage_url_service.dart)).
- RLS is the actual security boundary: every table's policies key off `couple_id` so only the two paired partners can read or write a couple's rows. When adding a feature/table, a migration with correct RLS is not optional.
- Supabase blocks direct SQL DML against the `storage` schema. Deleting stored objects is a Storage API operation (`supabase storage rm ss:///bucket/prefix -r --experimental --yes`), not something a migration can express.

## Architecture

`lib/` is feature-first with four top-level directories. **Do not add global `screens/`, `models/`, `services/`, or `providers/` folders** — those were dissolved and the architecture test guards against their return in spirit.

```
lib/
├── app/            # application composition, not business logic
│   ├── config/     # AppConfig (dart-define plumbing)
│   ├── router/     # app_router.dart (go_router) + route_names.dart
│   ├── shell/      # LoveStoryScreen — the four-tab scaffold + its tabs
│   └── theme/      # theme_manager.dart (LoveStoryTheme) + app_typography.dart
├── core/           # infrastructure several unrelated features need
│   ├── session/    # CoupleSession, key exchange, presence, lifecycle manager
│   ├── network/    # Supabase clients, RealtimeSubscriptionManager
│   ├── storage/    # StorageUrlService, EncryptedStorageService, local persistence
│   ├── security/   # KeyManagementService, PhotoEncryptionService (E2EE)
│   ├── riverpod/   # SupabaseLifecycleNotifier
│   ├── notifications/, permissions/, activity/, constants/, errors/, models/, utils/
├── features/       # one directory per business feature (see lib/features/README.md)
└── shared/         # cross-feature widgets (shared/widgets/) and data contracts (shared/models/)
```

### Session and the lifecycle system

The entire app hangs off one couple relationship. [lib/core/session/couple_session.dart](lib/core/session/couple_session.dart) (`CoupleSession`, a `ChangeNotifier`) owns auth state, both partners' profile data, pairing/recovery codes, and the `users`/`couples` realtime streams. It mirrors state to `SharedPreferences` for instant offline resume.

It lives in `core/`, not in a feature, because `core/riverpod/supabase_lifecycle_notifier.dart` depends on it and most feature controllers read it — a feature home would invert the "core must not import features" rule.

`_CoupleSessionBridge` in [lib/main.dart](lib/main.dart) is the single subscription to `CoupleSession`. On every change it pushes into the hub controllers (`session`, `workspace`, `profile`, `presence`, `license`) via `updateFromSession`, and into every domain controller via `updateSession`.

Feature controllers mix in `SupabaseLifecycleNotifier<T>` ([lib/core/riverpod/supabase_lifecycle_notifier.dart](lib/core/riverpod/supabase_lifecycle_notifier.dart)), which requires:

- `String get tableName` — the Supabase table to subscribe to
- `Future<void> syncInitialData()` — called on pair/repair, under a timeout
- `Future<void> purgeCache()` — called on disconnect/logout
- `void onRealtimeData(List<Map<String, dynamic>>)` — realtime rows

`RelationshipLifecycleManager` ([lib/core/session/relationship_lifecycle_manager.dart](lib/core/session/relationship_lifecycle_manager.dart)) is the pair/repair/disconnect/logout event bus, so a partner unlinking or an account deletion propagates to every feature's cache without features referencing each other.

### Realtime subscription multiplexing

[lib/core/network/realtime_subscription_manager.dart](lib/core/network/realtime_subscription_manager.dart) deduplicates Supabase Realtime subscriptions: everything asking for the same `tableName_coupleId` shares one broadcast stream and one underlying Postgres changes subscription (opened on first listener, torn down on last). Don't subscribe to Supabase tables directly — go through this manager (`SupabaseLifecycleNotifier.initRealtime()` already does).

### Adding a couple-scoped feature

```
lib/features/<feature>/
├── <feature>_controller.dart   # the feature's PUBLIC surface (Riverpod Notifier)
├── <feature>_state.dart        # the typed state it exposes
├── data/                       # repositories, datasources, sync managers
├── domain/entities/            # models (all-final; see Rule below)
└── presentation/
    ├── pages/                  # screens
    └── widgets/                # this feature's own widgets
```

Use only the layers the feature actually needs — layering is not applied ceremonially. Controllers and state stay at the **feature root**, not under `presentation/providers/`: they are the feature's public API and they own REST sync and realtime, so they aren't purely presentational.

Then: declare the provider with `dependencies: [coupleSessionProvider]`, wire its `updateSession` into `_CoupleSessionBridge` in `main.dart`, and add a route in [lib/app/router/route_names.dart](lib/app/router/route_names.dart) + [lib/app/router/app_router.dart](lib/app/router/app_router.dart).

### Cross-feature rule

A feature may depend on another feature **only** through that feature's `*_controller.dart` or `*_state.dart`. Reaching into another feature's `presentation/`, `data/`, or `domain/` fails the architecture test.

Anything genuinely shared goes up, not sideways: `core/` for infrastructure, `shared/` for cross-feature widgets and the data contracts more than one feature speaks. **`core/` and `shared/` must never import from `features/`.**

### Architecture test

[test/architecture_test.dart](test/architecture_test.dart) mechanically enforces 11 groups of invariants and fails the build on violation. Among them: UI must not import `supabase_flutter`; models must be immutable and must not import Flutter's rendering layer; `core/`/`shared/` must not import `features/`; cross-feature imports must go through controller/state; `SharedPreferences` keys must be centralized in `PrefsKeys`; go_router owns screen-level navigation (`MaterialPageRoute` is confined to a documented allowlist of dialog-shaped call sites).

If a change breaks one of these, fix the code — or, when a path genuinely moved, retarget the rule's path glob while preserving its strength. Don't weaken or delete a rule to get green.

### Routing

[lib/app/router/app_router.dart](lib/app/router/app_router.dart) owns navigation. `appRedirect` is the single place that decides where an in-flight navigation lands, driven by `computeSessionStage()` in `couple_session.dart` (`loading` / `unauthenticated` / `needsWorkspace` / `needsCouple` / `needsGenesis` / `needsAvatar` / `ready`). Add new onboarding states there rather than introducing a second redirect mechanism.

### E2EE photo encryption

Photo uploads are end-to-end encrypted: X25519 key agreement + HKDF-SHA256 with domain separation, AES-256-GCM with fresh nonces. `KeyManagementService` and `PhotoEncryptionService` ([lib/core/security/](lib/core/security/)) hold the primitives; `EncryptedStorageService` ([lib/core/storage/](lib/core/storage/)) wraps every upload call site (avatars, note-its, timeline photos). `CoupleKeyExchange` ([lib/core/session/couple_key_exchange.dart](lib/core/session/couple_key_exchange.dart)) handles wrapping the couple key for the partner's device and unwrapping theirs.

### Native platform integration

- [lib/core/notifications/notification_service.dart](lib/core/notifications/notification_service.dart) + Firebase Messaging handle push. FCM tokens sync to Supabase per-user; partner notifications go through the `send-push-notification` edge function. It resolves payloads to **routes**, never importing a screen.
- Five themes (Midnight Glass, Azure Liquid, Rose Quartz, Neon Violet, Lovely Off-White) plus a user-defined Custom theme live in [lib/app/theme/theme_manager.dart](lib/app/theme/theme_manager.dart), served through `themeControllerProvider`.

## Testing notes

Tests live in [test/](test/). Conventions worth copying:

- `SharedPreferences.setMockInitialValues({})` in `setUp`, plus mocked platform channels where a service touches one (see [test/hydration_fixture_test.dart](test/hydration_fixture_test.dart)).
- Controller tests use `ProviderContainer(overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())])` and a `container.listen(...)` to keep an `autoDispose` provider alive.
- To seed a controller with fixed state, subclass it and override `build()` — no Supabase client or realtime subscription involved. See [test/daily_mood_bento_card_test.dart](test/daily_mood_bento_card_test.dart) for the widget-test version.
- `ProviderScope(overrides: [...])` is the only fake-injection mechanism; `mockito`/`mocktail` are deliberately absent.
- Never hit real Supabase from a test.

When writing a test that asserts something is *absent*, also assert something is *present*, so the test can't pass vacuously on a failed build.

## Further reading

[docs/architecture/](docs/architecture/) holds the ADRs and the design docs (`feature-boundaries.md`, `state-management.md`, `testing-strategy.md`, `realtime-architecture.md`, and others). They are detailed and mostly accurate, but predate some later changes — notably they still describe the Secret Vault and Home Screen Widget features, both of which were removed outright. Treat this file as the current map and those as background.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

**Days Together** is a Flutter app (Dart SDK ^3.10.0) for couples: a shared relationship timeline, vault, calendar, bucket list, note-its, love chat, AI-generated love letters, time capsules, and more. It's backed by Supabase (Postgres + Realtime + Auth + Storage + Edge Functions). State management is `provider`. Every feature is scoped to exactly two paired users (a "couple").

## Common commands

```bash
flutter pub get                    # install dependencies
flutter run                        # run on connected device/emulator (see env vars below)
flutter test                       # run all tests
flutter test test/some_test.dart   # run a single test file
flutter analyze                    # static analysis (flutter_lints via analysis_options.yaml)
flutter build appbundle            # Android release build
flutter build ipa                  # iOS release build
```

### Environment configuration

Supabase/Google OAuth credentials are compile-time `--dart-define` values consumed by [lib/app_config.dart](lib/app_config.dart), each with a hardcoded fallback (the Supabase anon key is safe to expose — access is enforced by Postgres RLS policies, not by key secrecy). To point at a different backend:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=GOOGLE_CLIENT_ID_WEB=your-google-web-client-id \
  --dart-define=GOOGLE_CLIENT_ID_IOS=your-google-ios-client-id
```

Never put a Supabase `service_role` key in the client. See [BUILD_AND_RUN.md](BUILD_AND_RUN.md) for the VS Code `launch.json` equivalent.

### Supabase backend

- [supabase/migrations/](supabase/migrations/) is the source of truth for schema, RLS policies, and RPCs — sequential, timestamp-named SQL files. Never edit an already-applied migration; add a new one.
- [supabase/functions/](supabase/functions/) holds Edge Functions (e.g. `send-push-notification`).
- Key tables: `users`, `couples`, `pairing_codes`, `timeline_items`, `vault_items`, `bucket_list`, `calendar_events`, `moods`, `daily_questions`, `gift_reminders`, `love_notes`, `license_details`, `topic_cards`, `time_capsules`. Storage buckets: `avatars`, `vault-photos`.
- RLS is the actual security boundary: every table's policies key off `couple_code`/`couple_id` so only the two paired partners can read or write a couple's rows. When adding a feature/table, a migration with correct RLS is not optional.

## Architecture

### Pairing and the lifecycle system

The entire app hangs off one couple relationship. [lib/providers/relationship_provider.dart](lib/providers/relationship_provider.dart) (`RelationshipProvider`) owns auth state, the current user's and partner's profile/license data, pairing/recovery codes, and partner online presence (via a Supabase Realtime presence channel). It listens to Supabase auth changes and streams the `users` → `couples` → `license_details` tables, and mirrors state to `SharedPreferences` for instant offline resume.

Every other feature provider (`TimelineProvider`, `BucketListProvider`, `VaultProvider`, `CalendarProvider`, `NoteitProvider`, `LoveChatProvider`, `TimeCapsuleProvider`, `TopicCardsProvider`, `DailyMoodProvider`, `GiftReminderProvider`, `CurrentlyProvider`, `NotificationPreferencesProvider`) is wired in [lib/main.dart](lib/main.dart) as a `ChangeNotifierProxyProvider<RelationshipProvider, X>` and extends the base classes in [lib/services/relationship_lifecycle_manager.dart](lib/services/relationship_lifecycle_manager.dart):

- `RelationshipLifecycleProvider` — reacts to `updateRelationship()` calls (fired whenever `RelationshipProvider` changes) by diffing `coupleId`/`userId` and calling `syncInitialData()` (pair/repair) or `purgeCache()` (disconnect/logout), each under a 15s timeout.
- `SupabaseLifecycleProvider` extends that and adds realtime: implement `tableName` and `onRealtimeData()`, and it automatically subscribes/unsubscribes from that table's changes as widgets add/remove listeners.

`RelationshipLifecycleManager` (singleton) is the pair/repair/disconnect/logout event bus all lifecycle-aware providers register with — this is how a partner unlinking, an account being deleted, or a fresh pairing propagates to every feature's cache without them holding a direct reference to each other.

When adding a couple-scoped feature, follow this existing pattern (new model in `models/`, new provider extending `SupabaseLifecycleProvider`, wire it into `main.dart`'s `MultiProvider`) rather than inventing a new sync mechanism.

### Realtime subscription multiplexing

[lib/services/realtime_subscription_manager.dart](lib/services/realtime_subscription_manager.dart) (`RealtimeSubscriptionManager`) deduplicates Supabase Realtime subscriptions: multiple providers/widgets asking for the same `tableName_coupleId` share one broadcast stream and one underlying Postgres changes subscription (opened on first listener, torn down on last). Don't subscribe to Supabase tables directly from a provider — go through this manager (`SupabaseLifecycleProvider.initRealtime()` already does).

### Directory layout

```
lib/
├── models/         # Data classes mapping Supabase tables (Timeline, Vault, BucketList, TimeCapsule, etc.)
├── providers/       # ChangeNotifiers — business logic + Supabase stream orchestration
├── repositories/    # Data-fetching layer between providers and Supabase (e.g. TimelineRepository)
├── screens/
│   ├── onboarding/  # Welcome, pairing/couple-code, genesis, avatar creation
│   ├── settings/    # Couple profile & app settings
│   ├── studio/      # AI love letters, time capsules, insights
│   └── together/    # Vault, bucket list, love meter, calendar, license, note-its
├── services/        # Auth, couple pairing, AI synthesis, notifications, home widget, music, sync
├── themes/          # LoveStoryTheme definitions (4 glassmorphism themes) + ThemeManager
└── widgets/         # Reusable UI (glass containers, avatars, shimmer loaders, dashboard, wrapped/)
```

### App boot / routing

[lib/main.dart](lib/main.dart)'s `AppHome` is the single top-level router, driven entirely by `RelationshipProvider` getters (`isInitialized`, `userId`, `isOnboardingComplete`, `relationshipId`, `isCreator`, `isPaired`, `startDate`) — there is no named-route navigator for the onboarding flow; add new onboarding states there rather than introducing a separate router.

### Native platform integration

- [lib/services/home_widget_service.dart](lib/services/home_widget_service.dart) drives an Android/iOS home-screen widget (via `home_widget`) showing days-together, updated whenever the start date/time changes.
- [lib/services/notification_service.dart](lib/services/notification_service.dart) + Firebase Messaging handle push notifications; FCM tokens are synced to Supabase per-user and partner notifications are sent through `send-push-notification` edge function.
- Four themes (Midnight Glass, Azure Liquid, Rose Quartz, Neon Violet) live in [lib/themes/theme_manager.dart](lib/themes/theme_manager.dart) and drive `MaterialApp.theme` via `ThemeProvider`.

## Testing notes

Tests live in [test/](test/) and use `flutter_test` with `SharedPreferences.setMockInitialValues({})` and mocked platform channels (see [test/relationship_provider_test.dart](test/relationship_provider_test.dart)) since providers touch `SharedPreferences` and platform plugins on construction — follow that setup pattern for new provider tests rather than hitting real Supabase/plugins.

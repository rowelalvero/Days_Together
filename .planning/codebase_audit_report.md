# Codebase Audit Report: Bugs, Security, UI Standards, and Memory Leaks

**Analysis Date:** 2026-06-19
**Scope:** Core Dart codebase in `lib/` and project configurations

---

## 1. Memory Leaks (High Risk)

The audit identified a systematic memory leak pattern affecting all state management classes (Providers) and key animation wrappers.

### Missing Stream Subscription Cancellations
Multiple long-lived providers listen to Supabase real-time stream updates. While they check `_disposed` to prevent `notifyListeners()` crashes, they **never cancel the stream subscriptions** when `dispose()` is triggered. The active socket channels remain open, consuming network data and keeping provider memory allocated.

| Component | Class Name | File | Affected Field | Line |
|---|---|---|---|---|
| Provider | `RelationshipProvider` | `lib/providers/relationship_provider.dart` | `_userSub`, `_coupleSub`, `_licenseSub` | L38-40 |
| Provider | `BucketListProvider` | `lib/providers/bucket_list_provider.dart` | `_syncSub` | L9 |
| Provider | `CalendarProvider` | `lib/providers/calendar_provider.dart` | `_syncSub` | L9 |
| Provider | `DailyMoodProvider` | `lib/providers/daily_mood_provider.dart` | `_moodsSub`, `_questionSub` | L13-14 |
| Provider | `GiftReminderProvider` | `lib/providers/gift_reminder_provider.dart` | `_syncSub` | L9 |
| Provider | `NoteitProvider` | `lib/providers/noteit_provider.dart` | `_syncSub` | L10 |
| Provider | `TimelineProvider` | `lib/providers/timeline_provider.dart` | `_syncSub` | L10 |
| Provider | `TimeCapsuleProvider` | `lib/providers/time_capsule_provider.dart` | `_syncSub` | L9 |
| Provider | `TopicCardsProvider` | `lib/providers/topic_cards_provider.dart` | `_syncSub` | L17 |
| Provider | `VaultProvider` | `lib/providers/vault_provider.dart` | `_syncSub` | L16 |

> [!IMPORTANT]
> **RelationshipProvider** does not define a `dispose()` method at all. This means its multiple active Supabase subscriptions and presence channels (`_presenceChannel`) leak whenever the provider is unmounted or reinitialized.

### Recommendation
1. Overwrite/add the `dispose()` method in all providers to cancel subscriptions.
2. Example fix for `RelationshipProvider`:
   ```dart
   @override
   void dispose() {
     _userSub?.cancel();
     _coupleSub?.cancel();
     _licenseSub?.cancel();
     _presenceChannel?.unsubscribe();
     super.dispose();
   }
   ```

---

## 2. Hidden Bugs (Medium Risk)

### Unhandled Stream Listener Exceptions
Supabase real-time streams are listened to without registering `onError` handler callbacks. If a network disruption occurs, or database permissions change, these streams throw uncaught exceptions that can crash the app or put it in an unrecoverable state.

- **File:** `lib/providers/relationship_provider.dart` (L225, L291, L334)
- **Problem:**
  ```dart
  _userSub = Supabase.instance.client
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', _userId!)
      .listen((dataList) async { ... }); // Missing onError handler
  ```
- **Fix:** Add `onError` callbacks to streams:
  ```dart
  .listen((dataList) async { ... }, onError: (error) {
    debugPrint('User stream error: $error');
  });
  ```

---

## 3. UI Standards & Theme Violations

The codebase has custom theme configurations (`LoveStoryTheme` presets) that support Glassmorphism and unique aesthetic styles. However, screens and widgets systematically override these preferences.

### Hardcoded Color Declarations
Over 260 occurrences of hardcoded colors (like `const Color(0xFF1A1B41)` or `Colors.redAccent`) were detected within UI widgets. Hardcoding background or primary container colors directly overrides the theme configured by the user, rendering custom themes broken or inconsistent on specific screens.

#### Examples of Theme-Breaking Colors:
- **`lib/screens/love_story_screen.dart`** (L270, L677): Uses hardcoded dark color `Color(0xFF10122B)` for containers and layouts instead of pulling `theme.backgroundColor` or `theme.cardColor` from the active theme.
- **`lib/screens/onboarding/welcome_screen.dart`** (L167): Hardcodes button colors `Color(0xFF1A1B41)` instead of using `theme.primaryColor`.
- **`lib/screens/onboarding/genesis_screen.dart`** (L89, L119): Hardcodes container background colors.

### Recommendation
Replace hardcoded colors in views with dynamic context lookups:
```dart
// Instead of:
color: const Color(0xFF1A1B41)

// Use:
color: Provider.of<ThemeProvider>(context).currentLoveTheme.primaryColor
```

---

## 4. Security Considerations (Low/Medium Risk)

### Hardcoded Client Credentials
- **File:** `lib/providers/relationship_provider.dart` (L1726)
- **Problem:** The codebase relies on hardcoded checks and placeholders for credentials (e.g. `YOUR_IOS_CLIENT_ID` and `YOUR_WEB_CLIENT_ID`). Checking files with actual client IDs into version control presents a vulnerability.
- **Fix:** Extract client credentials into build-time variables via `--dart-define` config parameters:
  ```dart
  const String iosClientId = String.fromEnvironment('GOOGLE_CLIENT_ID_IOS');
  ```

---

*End of Audit Report*

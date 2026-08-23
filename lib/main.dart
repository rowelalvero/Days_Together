import 'dart:ui';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/relationship/license_controller.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/relationship/presence_controller.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/bucket_list/bucket_list_controller.dart';
import 'package:days_together/features/gift_reminders/gift_reminder_controller.dart';
import 'package:days_together/features/calendar/calendar_controller.dart';
import 'package:days_together/features/love_studio/time_capsule_controller.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/vault/vault_controller.dart';
import 'package:days_together/features/scrapbook/noteit_controller.dart';
import 'package:days_together/features/chat/love_chat_controller.dart';
import 'package:days_together/features/topic_cards/topic_cards_controller.dart';
import 'package:days_together/features/mood/daily_mood_controller.dart';
import 'package:days_together/features/currently/currently_controller.dart';
import 'package:days_together/features/settings/notification_preferences_controller.dart';
import 'package:days_together/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState, ConsumerWidget, WidgetRef, ProviderScope;
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/app_config.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/services/home_widget_service.dart';

@pragma('vm:entry-point')
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Handle Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Captured FlutterError: ${details.exception}');
    debugPrintStack(stackTrace: details.stack, label: 'FlutterError stack');
  };

  // Handle platform errors
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Captured PlatformDispatcher error: $error');
    debugPrintStack(stackTrace: stack, label: 'PlatformDispatcher stack');
    return true;
  };

  _initializeApp();
}

Future<void> _initializeApp() async {
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
    await NotificationService().init();
    await HomeWidgetService.instance.initialize();
  } catch (e) {
    debugPrint('Initialization error: $e');
  }

  runApp(buildAppRoot(child: const MyApp()));
}

/// The app's full widget root: a single `ProviderScope` -- the entire
/// `provider`-package tree (`MultiProvider`/`ChangeNotifierProvider`/the
/// nested `ProviderScope` + `Consumer<CoupleSession>` strangler bridge from
/// Phase 2, ADR-002) is gone as of Item 3 gap-fix Phase 3 (front 4 of the
/// architecture migration's `provider`-removal item): [coupleSessionProvider]
/// now constructs the single, process-lifetime `CoupleSession` instance
/// itself (see `couple_session.dart`), so there is no second container to
/// bridge into. Factored out of [runApp] so `test/riverpod_bridge_test.dart`
/// can pump the exact production wiring around a probe widget of its
/// choosing instead of a hand-maintained duplicate that could drift.
Widget buildAppRoot({required Widget child}) {
  return ProviderScope(
    child: _CoupleSessionBridge(child: child),
  );
}

/// The single bridge from `CoupleSession`'s raw `ChangeNotifier` world into
/// every Riverpod hub/domain controller (Item 3 gap-fix, Phase 3, front 4 of
/// the architecture migration's `provider`-removal item). Replaces the 5
/// separate `provider`-package bridge widgets this migration built up over
/// Phases 5/6a/6b-1 (`_LicenseLifecycleBridge`, `_ProfileControllerBridge`,
/// `_WorkspaceControllerBridge`, `_PresenceControllerBridge`,
/// `_DomainProvidersBridge`) -- those each independently subscribed to
/// `CoupleSession` via `context.watch<CoupleSession>()`, so a single
/// `notifyListeners()` call triggered 5 separate widget rebuilds, each
/// scheduling its own `postFrameCallback`. Now that `provider` is gone
/// entirely, this registers exactly one `CoupleSession.addListener` in
/// `initState` and pushes into every controller from one place, preserving
/// the old bridges' combined behavior and ordering exactly:
///
/// 1. `_LicenseLifecycleBridge`'s identity-cleared-invalidate check
///    (logout/unlink/account deletion invalidates [licenseControllerProvider]
///    so a signed-out user's cached license data can never leak into a
///    second account signed into the same app session).
/// 2. `profileControllerProvider`/`workspaceControllerProvider`/
///    `presenceControllerProvider`/`sessionControllerProvider`'s
///    `updateFromSession` mirrors (Phase 5/6b-1's four-plus-one hub
///    controllers).
/// 3. All 12 domain controllers' `SupabaseLifecycleNotifier.updateSession`
///    (Phase 6a) -- REST sync/cache-purge still runs unconditionally on
///    every session change regardless of which screen is open, exactly as
///    before, since `ref.read(x.notifier)` creates an `autoDispose`
///    controller on demand even with no active watcher.
///
/// The identity-diff bookkeeping (`_lastUserId`/`_lastCoupleId`/`_seeded`)
/// runs synchronously in [_onSessionChanged] (cheap, pure `State` fields,
/// not a Riverpod mutation); the actual provider-affecting calls stay
/// deferred to a `postFrameCallback`, matching the old bridges' reasoning
/// for using one at all (avoiding "modify a provider during build" -- moot
/// here since `_onSessionChanged` runs from a raw `ChangeNotifier` callback,
/// not from inside a widget's `build()`, but kept anyway as the
/// conservative, behavior-preserving choice for this migration's riskiest
/// rewrite).
class _CoupleSessionBridge extends ConsumerStatefulWidget {
  final Widget child;
  const _CoupleSessionBridge({required this.child});

  @override
  ConsumerState<_CoupleSessionBridge> createState() => _CoupleSessionBridgeState();
}

class _CoupleSessionBridgeState extends ConsumerState<_CoupleSessionBridge> {
  // Cached rather than re-read via `ref.read(coupleSessionProvider)` on every
  // use: `ref` is unsafe to touch inside `dispose()` (Riverpod asserts on
  // it, since the widget may already be deactivated by then) and a
  // postFrameCallback can likewise fire after unmount -- a plain field
  // holding the instance itself has no such lifecycle restriction.
  late final CoupleSession _session;
  String? _lastUserId;
  String? _lastCoupleId;
  int? _lastPartnerProfileVersion;
  bool _seeded = false;
  // Coalesces every notifyListeners() firing that happens before the next
  // frame into a single push. CoupleSession methods commonly call
  // notifyListeners() 2-3 times per logical operation (start/success/
  // finally); the old 5-separate-bridge-widget design coalesced these for
  // free via Flutter's own widget-rebuild batching (multiple
  // context.watch<CoupleSession>()-driven rebuilds requested before the next
  // frame collapse into one). A single addListener callback has no such
  // batching, so without this flag every one of those 2-3 calls would
  // independently schedule its own postFrameCallback, multiplying how many
  // concurrent in-flight `updateSession()` calls run against the 12
  // autoDispose domain controllers and increasing the odds one gets disposed
  // by Riverpod while still awaiting a network call mid-`syncInitialData()`
  // -- which poisons that controller into a cached error state visible the
  // next time any screen actually watches it (found via a manual on-device
  // smoke test: BentoGrid/TogetherTab throwing "Tried to use a provider that
  // is in error state" after creating a workspace).
  bool _updateScheduled = false;
  bool _pendingInvalidateLicense = false;

  @override
  void initState() {
    super.initState();
    _session = ref.read(coupleSessionProvider);
    _session.addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onSessionChanged();
    });
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    final session = _session;
    final userId = session.userId;
    final coupleId = session.coupleId;

    if (!_seeded) {
      // First call: record the starting identity without treating it as a
      // transition (there is nothing to invalidate on cold start).
      _seeded = true;
      _lastUserId = userId;
      _lastCoupleId = coupleId;
      _lastPartnerProfileVersion = session.partnerProfileVersion;
    } else if (userId != _lastUserId || coupleId != _lastCoupleId) {
      final identityCleared =
          (_lastUserId != null && userId == null) || (_lastCoupleId != null && coupleId == null);
      _lastUserId = userId;
      _lastCoupleId = coupleId;
      if (identityCleared) {
        _pendingInvalidateLicense = true;
      }
    }

    // The partner's Relationship License fields (gender..signature) are
    // mirrored into SharedPreferences by CoupleSession._applyPartnerUserFields
    // but LicenseController only reads those on its own build() -- it has no
    // live subscription of its own. Bumping this version whenever a field
    // actually changed (not on every unrelated presence/activity ping) is
    // what lets a completed license actually appear without the user
    // needing to leave and re-enter the License screen.
    if (session.partnerProfileVersion != _lastPartnerProfileVersion) {
      _lastPartnerProfileVersion = session.partnerProfileVersion;
      _pendingInvalidateLicense = true;
    }

    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (!mounted) return;
      final shouldInvalidateLicense = _pendingInvalidateLicense;
      _pendingInvalidateLicense = false;
      if (shouldInvalidateLicense) {
        ref.invalidate(licenseControllerProvider);
      }
      ref.read(profileControllerProvider.notifier).updateFromSession(session);
      ref.read(workspaceControllerProvider.notifier).updateFromSession(session);
      ref.read(presenceControllerProvider.notifier).updateFromSession(session);
      ref.read(sessionControllerProvider.notifier).updateFromSession(session);
      ref.read(bucketListControllerProvider.notifier).updateSession(session);
      ref.read(giftReminderControllerProvider.notifier).updateSession(session);
      ref.read(calendarControllerProvider.notifier).updateSession(session);
      ref.read(timeCapsuleControllerProvider.notifier).updateSession(session);
      ref.read(timelineControllerProvider.notifier).updateSession(session);
      ref.read(vaultControllerProvider.notifier).updateSession(session);
      ref.read(noteitControllerProvider.notifier).updateSession(session);
      ref.read(loveChatControllerProvider.notifier).updateSession(session);
      ref.read(topicCardsControllerProvider.notifier).updateSession(session);
      ref.read(dailyMoodControllerProvider.notifier).updateSession(session);
      ref.read(currentlyControllerProvider.notifier).updateSession(session);
      ref.read(notificationPreferencesControllerProvider.notifier).updateSession(session);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The app's top-level widget. Navigation is now entirely `go_router`'s
/// responsibility (Phase 3 of the architecture migration, ADR-007) --
/// `AppHome`'s old inline `SessionStage` switch is gone; the identical
/// mapping now lives once, in `lib/routing/app_router.dart`'s
/// `appRedirect`/route table, which is also what `notification_service.dart`
/// and every screen-to-screen push now goes through instead of constructing
/// `MaterialPageRoute`s by hand.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  TextTheme _resolveTextTheme(Brightness brightness) {
    final baseTheme = ThemeData(brightness: brightness).textTheme;
    try {
      return GoogleFonts.spectralTextTheme(baseTheme);
    } catch (_) {
      return GoogleFonts.interTextTheme(baseTheme);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final theme = themeState.currentLoveTheme;
    final brightness = theme.isDark ? Brightness.dark : Brightness.light;

    // Read (not watch) deliberately: this is the app's single,
    // process-lifetime session instance -- ensureAppRouter only needs it
    // once, to build the Listenable the router re-evaluates its redirect
    // against on every change. `CoupleSession` stays a real ChangeNotifier
    // (its ~1400 lines of Supabase auth/realtime logic are unchanged by the
    // provider-removal migration -- only who constructs/reads it changed),
    // so it remains a valid `Listenable` reached via Riverpod instead of
    // `provider`. `app_router.dart`'s `appRedirect` reads the same session's
    // mirrored fields via `sessionControllerProvider`/`workspaceControllerProvider`
    // instead of this raw instance, for real Riverpod reactivity.
    final session = ref.read(coupleSessionProvider);
    final router = ensureAppRouter(refreshListenable: session);

    return MaterialApp.router(
      routerConfig: router,
      title: 'Days Together',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Spectral',
        textTheme: _resolveTextTheme(brightness),
        useMaterial3: true,
        brightness: brightness,
        scaffoldBackgroundColor: theme.backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.primaryColor,
          brightness: brightness,
        ),
        cardColor: theme.cardColor,
        // Registers the full LoveStoryTheme (including the Phase 7 design
        // tokens) as a typed accessor via Theme.of(context).extension<LoveStoryTheme>(),
        // composing with Material's own ColorScheme/TextTheme above rather
        // than replacing them -- see docs/architecture/design-system.md.
        extensions: <ThemeExtension<dynamic>>[theme],
      ),
    );
  }
}

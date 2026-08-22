import 'dart:ui';
import 'package:days_together/providers/bucket_list_provider.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/providers/daily_mood_provider.dart';
import 'package:days_together/providers/gift_reminder_provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/time_capsule_provider.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/vault_provider.dart';
import 'package:days_together/providers/calendar_provider.dart';
import 'package:days_together/providers/topic_cards_provider.dart';
import 'package:days_together/providers/noteit_provider.dart';
import 'package:days_together/providers/love_chat_provider.dart';
import 'package:days_together/providers/notification_preferences_provider.dart';
import 'package:days_together/providers/currently_provider.dart';
import 'package:days_together/features/relationship/license_controller.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/relationship/presence_controller.dart';
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
    show ConsumerStatefulWidget, ConsumerState, ProviderScope;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
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
  };

  // Handle platform errors
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Captured PlatformDispatcher error: $error');
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

/// The app's full widget root: the outer `ProviderScope` every Riverpod
/// provider needs somewhere above it, [buildAppProviders]'s Provider tree,
/// and the nested `ProviderScope` that bridges the live `CoupleSession`
/// instance onto [coupleSessionProvider] -- the "Provider -> Riverpod"
/// direction of the strangler bridge (Phase 2 of the architecture migration,
/// ADR-002; see docs/architecture/state-management.md). Factored out of
/// [runApp] so `test/riverpod_bridge_test.dart` can pump the exact
/// production wiring around a probe widget of its choosing instead of a
/// hand-maintained duplicate that could drift.
Widget buildAppRoot({required Widget child}) {
  return ProviderScope(
    child: MultiProvider(
      providers: buildAppProviders(),
      child: Consumer<CoupleSession>(
        builder: (context, session, _) => ProviderScope(
          overrides: [coupleSessionProvider.overrideWithValue(session)],
          child: _LicenseLifecycleBridge(
            child: _ProfileControllerBridge(
              child: _WorkspaceControllerBridge(
                child: _PresenceControllerBridge(
                  child: _DomainProvidersBridge(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Invalidates [licenseControllerProvider] whenever `CoupleSession`'s
/// identity fields clear (logout, account deletion, or a partner
/// disconnect), so a signed-out user's cached license data can never leak
/// into a second account signed into the same app session -- see
/// `license_controller.dart`'s doc comment on why a default (non-
/// `autoDispose`) `AsyncNotifierProvider` needs this hook at all.
class _LicenseLifecycleBridge extends ConsumerStatefulWidget {
  final Widget child;
  const _LicenseLifecycleBridge({required this.child});

  @override
  ConsumerState<_LicenseLifecycleBridge> createState() => _LicenseLifecycleBridgeState();
}

class _LicenseLifecycleBridgeState extends ConsumerState<_LicenseLifecycleBridge> {
  String? _lastUserId;
  String? _lastCoupleId;
  bool _seeded = false;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CoupleSession>();
    final userId = session.userId;
    final coupleId = session.coupleId;

    if (!_seeded) {
      // First build: record the starting identity without treating it as a
      // transition (there is nothing to invalidate on cold start).
      _seeded = true;
      _lastUserId = userId;
      _lastCoupleId = coupleId;
    } else if (userId != _lastUserId || coupleId != _lastCoupleId) {
      final identityCleared =
          (_lastUserId != null && userId == null) || (_lastCoupleId != null && coupleId == null);
      _lastUserId = userId;
      _lastCoupleId = coupleId;
      if (identityCleared) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.invalidate(licenseControllerProvider);
        });
      }
    }

    return widget.child;
  }
}

/// Mirrors `CoupleSession`'s 6 profile fields (name, avatar path, join
/// date) into [profileControllerProvider] on every `CoupleSession` change,
/// so Riverpod consumers can read them without holding a `provider`
/// package `context.watch`. Watches `CoupleSession` directly, not
/// `RelationshipProvider`, since Phase 6b-1 made `CoupleSession` the real
/// owner of these fields (`RelationshipProvider` is now just a
/// pass-through facade over it) -- reading the hub directly removes a
/// layer of indirection. Deliberately does not invalidate/reset on
/// logout/disconnect the way [_LicenseLifecycleBridge] does: since this is
/// a pure mirror, the next `updateFromSession` call (e.g. with all-null
/// fields after a logout) already overwrites any stale state, so there is
/// nothing extra to clear.
class _ProfileControllerBridge extends ConsumerStatefulWidget {
  final Widget child;
  const _ProfileControllerBridge({required this.child});

  @override
  ConsumerState<_ProfileControllerBridge> createState() => _ProfileControllerBridgeState();
}

class _ProfileControllerBridgeState extends ConsumerState<_ProfileControllerBridge> {
  @override
  Widget build(BuildContext context) {
    final session = context.watch<CoupleSession>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(profileControllerProvider.notifier).updateFromSession(session);
    });
    return widget.child;
  }
}

/// Mirrors `CoupleSession`'s 7 workspace fields (pairing code, story title,
/// start date/time, premium flag, status, recovery code) into
/// [workspaceControllerProvider] on every `CoupleSession` change. Watches
/// `CoupleSession` directly, not `RelationshipProvider`, since Phase 6b-1
/// unit 3 made `WorkspaceController` real -- see `workspace_controller.dart`'s
/// doc comment. Same shape as [_ProfileControllerBridge]: no
/// invalidate-on-logout hook needed, since the next `updateFromSession` call
/// already overwrites stale state with the post-logout/disconnect values.
class _WorkspaceControllerBridge extends ConsumerStatefulWidget {
  final Widget child;
  const _WorkspaceControllerBridge({required this.child});

  @override
  ConsumerState<_WorkspaceControllerBridge> createState() => _WorkspaceControllerBridgeState();
}

class _WorkspaceControllerBridgeState extends ConsumerState<_WorkspaceControllerBridge> {
  @override
  Widget build(BuildContext context) {
    final session = context.watch<CoupleSession>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(workspaceControllerProvider.notifier).updateFromSession(session);
    });
    return widget.child;
  }
}

/// Mirrors `CoupleSession`'s 3 presence fields (`isPartnerOnline`,
/// `yourActivity`, `partnerActivity`) into [presenceControllerProvider] on
/// every `CoupleSession` change. Watches `CoupleSession` directly, not
/// `RelationshipProvider`, since Phase 6b-1 unit 4 made `PresenceController`
/// real -- see `presence_controller.dart`'s doc comment. Same shape as
/// [_ProfileControllerBridge]/[_WorkspaceControllerBridge]: no
/// invalidate-on-logout hook needed, since the next `updateFromSession` call
/// already overwrites stale state with the post-logout/disconnect values.
class _PresenceControllerBridge extends ConsumerStatefulWidget {
  final Widget child;
  const _PresenceControllerBridge({required this.child});

  @override
  ConsumerState<_PresenceControllerBridge> createState() => _PresenceControllerBridgeState();
}

class _PresenceControllerBridgeState extends ConsumerState<_PresenceControllerBridge> {
  @override
  Widget build(BuildContext context) {
    final session = context.watch<CoupleSession>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(presenceControllerProvider.notifier).updateFromSession(session);
    });
    return widget.child;
  }
}

/// Pushes every `CoupleSession` change into each ported domain provider's
/// [SupabaseLifecycleNotifier.updateSession] -- the Riverpod-native
/// equivalent of the old `ChangeNotifierProxyProvider<CoupleSession,
/// X>.update: (_, session, provider) => provider!..updateSession(session)`
/// chain (Phase 6a of the architecture migration). Watches `CoupleSession`
/// directly (not `RelationshipProvider`, unlike the Phase 5 bridges above)
/// since that's what the old domain providers watched too, and it's what
/// `coupleSessionProvider`'s Riverpod-side bridge exposes.
///
/// Each provider here is `autoDispose`: calling `ref.read(x.notifier)` on
/// one with no active widget watcher still creates it, runs its update, and
/// lets Riverpod dispose it again shortly after -- so REST sync/cache-purge
/// still happens for every provider on every session change regardless of
/// which screen is open (matching the old behavior, where all 12 providers
/// lived for the whole app session), while realtime subscriptions are only
/// ever held open while some widget is actually watching, exactly like the
/// old `hasListeners`-gated `initRealtime()`.
///
/// New domain providers are added to this single bridge as they're ported;
/// it is not one bridge per provider like the Phase 5 mirrors, since these
/// all react to the identical `CoupleSession` trigger with no per-provider
/// divergence in when they should update.
class _DomainProvidersBridge extends ConsumerStatefulWidget {
  final Widget child;
  const _DomainProvidersBridge({required this.child});

  @override
  ConsumerState<_DomainProvidersBridge> createState() => _DomainProvidersBridgeState();
}

class _DomainProvidersBridgeState extends ConsumerState<_DomainProvidersBridge> {
  @override
  Widget build(BuildContext context) {
    final session = context.watch<CoupleSession>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
    return widget.child;
  }
}

/// The app's full provider tree, factored out of [runApp] so it has a single
/// source of truth rather than a hand-maintained duplicate that could drift.
///
/// `CoupleSession` is the real engine (Phase 6b-1 of the architecture
/// migration, "make CoupleSession real"): it owns the Supabase auth listener
/// and every field it drives. The 12 domain feature providers depend on it
/// directly, unchanged since Phase 1. `RelationshipProvider`, the facade
/// that used to sit in front of it for UI files not yet converted, was
/// deleted once item 4 of the Definition-of-Done sweep converted the last
/// remaining readers directly to `CoupleSession`.
List<SingleChildWidget> buildAppProviders() {
  return [
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => CoupleSession()),
    ChangeNotifierProxyProvider<CoupleSession, TimelineProvider>(
      create: (_) => TimelineProvider(),
      update: (_, session, provider) => provider!..updateSession(session),
    ),
    ChangeNotifierProxyProvider<CoupleSession, BucketListProvider>(
      create: (_) => BucketListProvider(),
      update: (_, session, provider) => provider!..updateSession(session),
    ),
    ChangeNotifierProxyProvider<CoupleSession, TimeCapsuleProvider>(
      create: (_) => TimeCapsuleProvider(),
      update: (_, session, provider) => provider!..updateSession(session),
    ),
    ChangeNotifierProxyProvider<CoupleSession, DailyMoodProvider>(
      create: (_) => DailyMoodProvider(),
      update: (_, session, provider) => provider!..updateSession(session),
    ),
    ChangeNotifierProxyProvider<CoupleSession, GiftReminderProvider>(
      create: (_) => GiftReminderProvider(),
      update: (_, session, provider) => provider!..updateSession(session),
    ),
    ChangeNotifierProxyProvider<CoupleSession, VaultProvider>(
      create: (_) => VaultProvider(),
      update: (_, session, provider) => provider!..updateSession(session),
    ),
    ChangeNotifierProxyProvider<CoupleSession, CalendarProvider>(
      create: (_) => CalendarProvider(),
      update: (_, session, provider) => provider!..updateSession(session),
    ),
    ChangeNotifierProxyProvider<CoupleSession, TopicCardsProvider>(
      create: (_) => TopicCardsProvider(),
      update: (_, session, provider) => provider!..updateSession(session),
    ),
    ChangeNotifierProxyProvider<CoupleSession, NoteitProvider>(
      create: (_) => NoteitProvider(),
      update: (_, session, provider) => provider!..updateSession(session),
    ),
    ChangeNotifierProxyProvider<CoupleSession, LoveChatProvider>(
      create: (_) => LoveChatProvider(),
      update: (_, session, provider) => provider!..updateSession(session),
    ),
    ChangeNotifierProxyProvider<CoupleSession, CurrentlyProvider>(
      create: (_) => CurrentlyProvider(),
      update: (_, session, provider) => provider!..updateSession(session),
    ),
    ChangeNotifierProxyProvider<CoupleSession, NotificationPreferencesProvider>(
      create: (_) => NotificationPreferencesProvider(),
      update: (_, session, provider) => provider!..updateSession(session),
    ),
  ];
}

/// The app's top-level widget. Navigation is now entirely `go_router`'s
/// responsibility (Phase 3 of the architecture migration, ADR-007) --
/// `AppHome`'s old inline `SessionStage` switch is gone; the identical
/// mapping now lives once, in `lib/routing/app_router.dart`'s
/// `appRedirect`/route table, which is also what `notification_service.dart`
/// and every screen-to-screen push now goes through instead of constructing
/// `MaterialPageRoute`s by hand.
class MyApp extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentLoveTheme;
    final brightness = theme.isDark ? Brightness.dark : Brightness.light;

    // Read (not watch) deliberately: this is the app's single,
    // process-lifetime session instance -- ensureAppRouter only needs it
    // once, to build the Listenable the router re-evaluates its redirect
    // against on every change (see app_router.dart's appRedirect, which
    // reads this same CoupleSession instance directly).
    final session = context.read<CoupleSession>();
    final router = ensureAppRouter(refreshListenable: session);

    return MaterialApp.router(
      routerConfig: router,
      title: 'Our Love Story',
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

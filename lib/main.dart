import 'dart:ui';
import 'package:days_together/providers/bucket_list_provider.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/providers/daily_mood_provider.dart';
import 'package:days_together/providers/gift_reminder_provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/time_capsule_provider.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/providers/vault_provider.dart';
import 'package:days_together/providers/calendar_provider.dart';
import 'package:days_together/providers/topic_cards_provider.dart';
import 'package:days_together/providers/noteit_provider.dart';
import 'package:days_together/providers/recent_activity_provider.dart';
import 'package:days_together/providers/love_chat_provider.dart';
import 'package:days_together/providers/notification_preferences_provider.dart';
import 'package:days_together/providers/currently_provider.dart';
import 'package:days_together/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
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
          child: child,
        ),
      ),
    ),
  );
}

/// The app's full provider tree, factored out of [runApp] so it has a single
/// source of truth rather than a hand-maintained duplicate that could drift.
///
/// `CoupleSession` sits between `RelationshipProvider` and the 12 domain
/// feature providers: it owns exactly the four fields those providers
/// actually depend on (`userId`, `coupleId`, `partnerId`,
/// `isSupabaseAvailable` -- verified by grep, see
/// docs/architecture/migration-roadmap.md's "Fact 1") plus the three
/// closely-related pairing/onboarding flags. `RelationshipProvider` itself
/// keeps its four matching getters as pass-throughs, so no other UI file
/// needs to change in this phase (Phase 1 of the architecture migration).
List<SingleChildWidget> buildAppProviders() {
  return [
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => RelationshipProvider()),
    ChangeNotifierProvider(create: (_) => RecentActivityProvider()),
    ChangeNotifierProxyProvider<RelationshipProvider, CoupleSession>(
      create: (_) => CoupleSession(),
      update: (_, relationship, session) =>
          session!..updateFromRelationship(relationship),
    ),
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
    // process-lifetime relationship instance -- ensureAppRouter only needs
    // it once, to build the Listenable the router re-evaluates its redirect
    // against on every change (see app_router.dart, which reads
    // RelationshipProvider directly rather than through CoupleSession's
    // one-frame-delayed mirror, for exactly this reactivity).
    final relationshipProvider = context.read<RelationshipProvider>();
    final router = ensureAppRouter(refreshListenable: relationshipProvider);

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
      ),
    );
  }
}

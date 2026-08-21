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
import 'package:days_together/screens/love_story_screen.dart';
import 'package:days_together/screens/onboarding/welcome_screen.dart';
import 'package:days_together/screens/onboarding/pairing_selection_screen.dart';
import 'package:days_together/screens/onboarding/loading_screen.dart';
import 'package:days_together/screens/onboarding/create_couple_code_screen.dart';
import 'package:days_together/screens/onboarding/genesis_screen.dart';
import 'package:days_together/screens/onboarding/avatar_creation_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/app_config.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/navigator_key.dart';
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

  runApp(
    MultiProvider(
      providers: buildAppProviders(),
      child: const MyApp(),
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

    return MaterialApp(
      navigatorKey: navigatorKey,
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
      home: const AppHome(),
    );
  }
}

class AppHome extends StatelessWidget {
  const AppHome({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<CoupleSession>(context);
    // startDate isn't yet a CoupleSession field -- see SessionStage's doc
    // comment in couple_session.dart -- so it's read from RelationshipProvider
    // directly until Phase 5's WorkspaceController absorbs it.
    final startDate = Provider.of<RelationshipProvider>(context).startDate;

    final stage = computeSessionStage(
      isInitialized: session.isInitialized,
      userId: session.userId,
      coupleId: session.coupleId,
      isCreator: session.isCreator,
      isPaired: session.isPaired,
      onboardingCompleted: session.onboardingCompleted,
      startDate: startDate,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _buildHomeContent(stage),
    );
  }

  Widget _buildHomeContent(SessionStage stage) {
    switch (stage) {
      case SessionStage.loading:
        return const LoadingScreen(key: ValueKey('loading'));
      case SessionStage.unauthenticated:
        return const WelcomeScreen(key: ValueKey('welcome'));
      case SessionStage.ready:
        return const LoveStoryScreen(key: ValueKey('home'));
      case SessionStage.needsWorkspace:
        return const CreateCoupleCodeScreen(key: ValueKey('couple_code'));
      case SessionStage.needsGenesis:
        return const GenesisScreen(key: ValueKey('genesis'));
      case SessionStage.needsAvatar:
        return const AvatarCreationScreen(key: ValueKey('avatar'));
      case SessionStage.needsCouple:
        return const PairingSelectionScreen(key: ValueKey('pairing'));
    }
  }
}

import 'package:days_together/providers/bucket_list_provider.dart';
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
import 'package:days_together/providers/love_chat_provider.dart';
import 'package:days_together/screens/love_story_screen.dart';
import 'package:days_together/screens/onboarding/welcome_screen.dart';
import 'package:days_together/screens/onboarding/pairing_selection_screen.dart';
import 'package:days_together/screens/onboarding/loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:days_together/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
    await NotificationService().init();
  } catch (e) {
    debugPrint('Supabase failed to initialize: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => RelationshipProvider()),
        ChangeNotifierProxyProvider<RelationshipProvider, TimelineProvider>(
          create: (_) => TimelineProvider(),
          update: (_, relationship, provider) =>
              provider!..updateRelationship(relationship),
        ),
        ChangeNotifierProxyProvider<RelationshipProvider, BucketListProvider>(
          create: (_) => BucketListProvider(),
          update: (_, relationship, provider) =>
              provider!..updateRelationship(relationship),
        ),
        ChangeNotifierProxyProvider<RelationshipProvider, TimeCapsuleProvider>(
          create: (_) => TimeCapsuleProvider(),
          update: (_, relationship, provider) =>
              provider!..updateRelationship(relationship),
        ),
        ChangeNotifierProxyProvider<RelationshipProvider, DailyMoodProvider>(
          create: (_) => DailyMoodProvider(),
          update: (_, relationship, provider) =>
              provider!..updateRelationship(relationship),
        ),
        ChangeNotifierProxyProvider<RelationshipProvider, GiftReminderProvider>(
          create: (_) => GiftReminderProvider(),
          update: (_, relationship, provider) =>
              provider!..updateRelationship(relationship),
        ),
        ChangeNotifierProxyProvider<RelationshipProvider, VaultProvider>(
          create: (_) => VaultProvider(),
          update: (_, relationship, provider) =>
              provider!..updateRelationship(relationship),
        ),
        ChangeNotifierProxyProvider<RelationshipProvider, CalendarProvider>(
          create: (_) => CalendarProvider(),
          update: (_, relationship, provider) =>
              provider!..updateRelationship(relationship),
        ),
        ChangeNotifierProxyProvider<RelationshipProvider, TopicCardsProvider>(
          create: (_) => TopicCardsProvider(),
          update: (_, relationship, provider) =>
              provider!..updateRelationship(relationship),
        ),
        ChangeNotifierProxyProvider<RelationshipProvider, NoteitProvider>(
          create: (_) => NoteitProvider(),
          update: (_, relationship, provider) =>
              provider!..updateRelationship(relationship),
        ),
        ChangeNotifierProxyProvider<RelationshipProvider, LoveChatProvider>(
          create: (_) => LoveChatProvider(),
          update: (_, relationship, provider) =>
              provider!..updateRelationship(relationship),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Safely load a Google Fonts text theme; falls back to default if font name
  /// is not available.
  TextTheme _resolveTextTheme(String fontName, Brightness brightness) {
    final baseTheme = ThemeData(brightness: brightness).textTheme;
    try {
      return GoogleFonts.getTextTheme(fontName, baseTheme);
    } catch (_) {
      return GoogleFonts.interTextTheme(baseTheme);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final relationshipProvider = Provider.of<RelationshipProvider>(context);
    final theme = themeProvider.currentLoveTheme;

    final brightness = theme.isDark ? Brightness.dark : Brightness.light;
    final fontName = themeProvider.settings.customFont;

    return MaterialApp(
      title: 'Our Love Story',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: _resolveTextTheme(fontName, brightness),
        useMaterial3: true,
        brightness: brightness,
        scaffoldBackgroundColor: theme.backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.primaryColor,
          brightness: brightness,
        ),
        cardColor: theme.cardColor,
      ),
      home: !relationshipProvider.isInitialized
          ? const LoadingScreen()
          : (relationshipProvider.userId != null
              ? (relationshipProvider.isPaired
                  ? const LoveStoryScreen()
                  : const PairingSelectionScreen())
              : const WelcomeScreen()),
    );
  }
}

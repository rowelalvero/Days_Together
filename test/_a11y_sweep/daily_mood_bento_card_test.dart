// Widget tests for DailyMoodBentoCard's note preview -- the dashboard's only
// surface for the words written during a mood check-in (the score boxes show
// a number and an emoji, never the note).
//
// Each controller is seeded through a subclass whose build() returns a fixed
// state, so no Supabase client, SharedPreferences read, or realtime
// subscription is involved -- the same subclass-fake technique the migration
// used for LoveChatProvider.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as ft show testWidgets;
import 'dart:async' show Completer, runZonedGuarded;
import 'dart:convert' show jsonEncode;
import 'dart:io' show File, FileMode;
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;
import 'package:days_together/shared/models/app_settings.dart' show AppSettings, ThemeType;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/dashboard/presentation/cards/daily_mood_bento_card.dart';
import 'package:days_together/features/mood/daily_mood_controller.dart';
import 'package:days_together/features/mood/daily_mood_state.dart';
import 'package:days_together/features/mood/domain/entities/daily_mood_model.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/relationship/profile_state.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/session_state.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/models/app_settings.dart';

class _SeededMood extends DailyMoodController {
  _SeededMood(this._seed);
  final DailyMoodState _seed;
  @override
  DailyMoodState build() => _seed;
}

class _SeededProfile extends ProfileController {
  _SeededProfile(this._seed);
  final ProfileState _seed;
  @override
  ProfileState build() => _seed;
}

class _SeededSession extends SessionController {
  _SeededSession(this._seed);
  final SessionState _seed;
  @override
  SessionState build() => _seed;
}

DailyMood _mood({required int score, String? note}) =>
    DailyMood(date: DailyMoodState.todayString, moodScore: score, note: note);

Future<void> _pump(
  WidgetTester tester, {
  required DailyMoodState mood,
  required bool isPaired,
  String? partnerName,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleSessionProvider.overrideWithValue(CoupleSession()),
        dailyMoodControllerProvider.overrideWith(() => _SeededMood(mood)),
        profileControllerProvider.overrideWith(
          () => _SeededProfile(ProfileState(partnerName: partnerName)),
        ),
        sessionControllerProvider.overrideWith(
          () => _SeededSession(SessionState(isPaired: isPaired)),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DailyMoodBentoCard(
              theme: ThemeManager.getTheme(ThemeType.midnightRose),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DailyMoodBentoCard note preview', () {
    testWidgets("shows the partner's note in preference to your own", (
      tester,
    ) async {
      await _pump(
        tester,
        isPaired: true,
        partnerName: 'Ashley',
        mood: DailyMoodState(
          isLoading: false,
          moods: [_mood(score: 8, note: 'Mine, which I already know')],
          partnerMoods: [_mood(score: 10, note: 'I got passed on interview!')],
        ),
      );

      expect(find.text('"I got passed on interview!"'), findsOneWidget);
      expect(find.text('"Mine, which I already know"'), findsNothing);
      expect(
        find.text('ASHLEY'),
        findsOneWidget,
        reason:
            'the quote must be attributed -- a YOU box and a PARTNER box '
            'sit directly above it, so an unlabelled note is ambiguous',
      );
    });

    testWidgets('falls back to your own note when the partner wrote none', (
      tester,
    ) async {
      await _pump(
        tester,
        isPaired: true,
        partnerName: 'Ashley',
        mood: DailyMoodState(
          isLoading: false,
          moods: [_mood(score: 8, note: 'Long day but a good one')],
          partnerMoods: [_mood(score: 10)],
        ),
      );

      expect(find.text('"Long day but a good one"'), findsOneWidget);
      expect(find.text('YOU'), findsWidgets);
    });

    testWidgets('renders no note block when neither partner wrote one', (
      tester,
    ) async {
      await _pump(
        tester,
        isPaired: true,
        partnerName: 'Ashley',
        mood: DailyMoodState(
          isLoading: false,
          moods: [_mood(score: 8)],
          partnerMoods: [_mood(score: 10)],
        ),
      );

      // Proves the card actually rendered, so the absence assertions below
      // are real rather than vacuously true on a failed build.
      expect(find.text('DAILY MOOD'), findsOneWidget);

      expect(
        find.textContaining('"'),
        findsNothing,
        reason:
            'with nothing written the card must keep its original height, '
            'not reserve an empty quote box',
      );
    });

    testWidgets('ignores a whitespace-only note', (tester) async {
      await _pump(
        tester,
        isPaired: true,
        partnerName: 'Ashley',
        mood: DailyMoodState(
          isLoading: false,
          moods: [_mood(score: 8)],
          partnerMoods: [_mood(score: 10, note: '   ')],
        ),
      );

      // Proves the card actually rendered, so the absence assertions below
      // are real rather than vacuously true on a failed build.
      expect(find.text('DAILY MOOD'), findsOneWidget);

      expect(find.textContaining('"'), findsNothing);
    });

    testWidgets("does not show a partner's note while unpaired", (
      tester,
    ) async {
      await _pump(
        tester,
        isPaired: false,
        mood: DailyMoodState(
          isLoading: false,
          moods: [_mood(score: 8)],
          partnerMoods: [_mood(score: 10, note: 'stale partner row')],
        ),
      );

      // Proves the card actually rendered, so the absence assertions below
      // are real rather than vacuously true on a failed build.
      expect(find.text('DAILY MOOD'), findsOneWidget);

      expect(find.text('"stale partner row"'), findsNothing);
    });
  });
}

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'daily_mood_bento_card_test.dart';

void testWidgets(
  String description,
  WidgetTesterCallback callback, {
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  dynamic tags,
  int? retry,
}) {
  ft.testWidgets(description, (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'app_settings',
      jsonEncode(
        AppSettings(currentTheme: ThemeType.values.byName(_sweepTheme)).toJson(),
      ),
    );
    await callback(tester);
    final done = Completer<void>();
    runZonedGuarded(() async {
      try {
        await _evaluate(tester, description);
      } finally {
        done.complete();
      }
    }, (e, _) {
      // google_fonts can't download in tests; its failed loads surface
      // during the contrast check's real-async rendering. Anything else is
      // a genuine failure.
      if (!'$e'.contains('Failed to load font')) throw e;
    });
    await done.future;
  }, skip: skip, timeout: timeout, semanticsEnabled: semanticsEnabled, variant: variant, tags: tags);
}

Future<void> _evaluate(WidgetTester tester, String description) async {
    final handle = tester.ensureSemantics();
    await tester.pump();
    for (final g in <String, AccessibilityGuideline>{
      'tap-android': androidTapTargetGuideline,
      'tap-ios': iOSTapTargetGuideline,
      'labeled': labeledTapTargetGuideline,
      'contrast': textContrastGuideline,
    }.entries) {
      Evaluation result;
      try {
        result = await g.value.evaluate(tester);
      } catch (e) {
        result = Evaluation.fail('evaluate threw: $e');
      }
      if (!result.passed) {
        File('build/a11y_sweep.txt').writeAsStringSync(
          '${[_sweepTheme, _sweepFile, description, g.key, (result.reason ?? '').replaceAll('\n', ' | ')].join('\t')}\n',
          mode: FileMode.append,
        );
      }
    }
    handle.dispose();
}

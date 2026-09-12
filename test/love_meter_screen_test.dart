// Widget tests for LoveMeterScreen, written before extracting its ~5
// _buildX methods into real widget classes -- these pin the screen's
// current rendered behavior so the extraction can be verified rather than
// assumed safe.
//
// DailyMoodController is seeded through a subclass whose build() returns a
// fixed state, so no Supabase client or realtime subscription is involved --
// the same technique calendar_screen_test.dart uses. logMood/
// answerDailyQuestion are exercised for real (not mocked) since both no-op
// their Supabase branch when coupleId is null, which it is for every seeded
// state here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/mood/daily_mood_controller.dart';
import 'package:days_together/features/mood/daily_mood_state.dart';
import 'package:days_together/features/mood/domain/entities/daily_mood_model.dart';
import 'package:days_together/features/mood/presentation/pages/love_meter_screen.dart';

class _SeededMood extends DailyMoodController {
  _SeededMood(this._seed);
  final DailyMoodState _seed;
  @override
  DailyMoodState build() => _seed;
}

Future<void> _pump(
  WidgetTester tester, {
  DailyMoodState mood = const DailyMoodState(isLoading: false),
}) async {
  // The mood logger/summary + sync question + chart cards overflow the
  // default 800x600 test surface -- a real phone screen is taller.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleSessionProvider.overrideWithValue(CoupleSession()),
        dailyMoodControllerProvider.overrideWith(() => _SeededMood(mood)),
      ],
      child: const MaterialApp(home: LoveMeterScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LoveMeterScreen', () {
    testWidgets('shows the mood logger when no mood is logged today', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('How is your mood today?'), findsOneWidget);
      expect(find.text("Save Today's Mood"), findsOneWidget);
    });

    testWidgets('logging a mood switches to the today-summary card', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text("Save Today's Mood"));
      await tester.pumpAndSettle();

      expect(find.text('How is your mood today?'), findsNothing);
      expect(find.text("Today's Mood"), findsOneWidget);
      expect(find.text('Score: 7/10'), findsOneWidget);
    });

    testWidgets('shows the today-summary card with note when already logged', (
      tester,
    ) async {
      await _pump(
        tester,
        mood: DailyMoodState(
          isLoading: false,
          moods: [
            DailyMood(
              date: DailyMoodState.todayString,
              moodScore: 9,
              note: 'Great day together',
            ),
          ],
        ),
      );

      expect(find.text("Today's Mood"), findsOneWidget);
      expect(find.text('Score: 9/10'), findsOneWidget);
      expect(find.text('"Great day together"'), findsOneWidget);

      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      expect(find.text('How is your mood today?'), findsOneWidget);
    });

    testWidgets('answering the sync question shows the answer', (tester) async {
      await _pump(
        tester,
        mood: DailyMoodState(
          isLoading: false,
          todayQuestion: DailySyncQuestion(
            question: 'What made you smile today?',
            date: DailyMoodState.todayString,
          ),
        ),
      );

      expect(find.text('What made you smile today?'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Write your response here...'),
        'Your good morning text',
      );
      await tester.tap(find.text('Share Response'));
      // The "waiting for partner" state that follows has an indeterminate
      // CircularProgressIndicator, which never settles.
      await tester.pump();
      await tester.pump();

      expect(find.text('Your Answer:'), findsOneWidget);
      expect(find.text('Your good morning text'), findsOneWidget);
      expect(find.text('⏳ Waiting for partner to reply...'), findsOneWidget);
    });

    testWidgets('shows both answers once the partner has replied too', (
      tester,
    ) async {
      await _pump(
        tester,
        mood: DailyMoodState(
          isLoading: false,
          todayQuestion: DailySyncQuestion(
            question: 'What made you smile today?',
            date: DailyMoodState.todayString,
            myAnswer: 'Coffee in bed',
            partnerAnswer: 'Our morning call',
          ),
        ),
      );

      expect(find.text('Coffee in bed'), findsOneWidget);
      expect(find.text('Our morning call'), findsOneWidget);
      expect(find.text("Partner's Answer:"), findsOneWidget);
    });

    testWidgets('shows the placeholder when fewer than 2 moods are logged', (
      tester,
    ) async {
      await _pump(tester);

      expect(
        find.textContaining('Log your mood for a few days'),
        findsOneWidget,
      );
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('renders the chart once 2 or more moods are logged', (
      tester,
    ) async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      await _pump(
        tester,
        mood: DailyMoodState(
          isLoading: false,
          moods: [
            DailyMood(date: fmt(yesterday), moodScore: 6),
            DailyMood(date: fmt(today), moodScore: 8),
          ],
        ),
      );

      expect(find.byType(LineChart), findsOneWidget);
    });
  });
}

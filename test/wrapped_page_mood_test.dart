// Widget tests for WrappedPageMood, written before extracting its
// `_buildBarChart`, `_buildStatChip`, and `_emptyMoodState` methods into
// real widget classes -- these pin the page's current rendered behavior
// so the extraction can be verified rather than assumed safe.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:days_together/features/wrapped/domain/wrapped_data.dart';
import 'package:days_together/features/wrapped/presentation/pages/wrapped_page_mood.dart';

WrappedData _baseData({
  List<MonthlyMood> monthlyMoods = const [],
  double avgMoodScore = 0.0,
  int topMoodScore = 0,
  String? bestMoodMonth,
}) => WrappedData(
  year: 2024,
  yourName: 'Alex',
  partnerName: 'Sam',
  totalDays: 365,
  durationYears: 1,
  durationMonths: 0,
  durationDays: 0,
  totalMemories: 0,
  memoriesThisYear: 0,
  totalNotes: 0,
  notesThisYear: 0,
  bucketTotal: 0,
  bucketCompleted: 0,
  bucketCompletedThisYear: 0,
  monthlyMoods: monthlyMoods,
  avgMoodScore: avgMoodScore,
  topMoodScore: topMoodScore,
  bestMoodMonth: bestMoodMonth,
  calendarEventsThisYear: 0,
  specialDatesThisYear: const [],
  capsulesCreated: 0,
  capsulesOpened: 0,
  upcomingCapsules: 0,
  totalPhotos: 0,
  totalCapsules: 0,
  milestonesAchievedThisYear: const [],
  letterTemplateIndex: 0,
);

Future<void> _pump(WidgetTester tester, WrappedData data) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: WrappedPageMood(data: data),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('WrappedPageMood', () {
    testWidgets('shows the empty state when there is no mood data', (
      tester,
    ) async {
      await _pump(tester, _baseData());

      expect(find.text('Mood Journey'), findsOneWidget);
      expect(find.text('How did this year feel?'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets('renders the bar chart and stat chips when mood data exists', (
      tester,
    ) async {
      await _pump(
        tester,
        _baseData(
          monthlyMoods: const [
            MonthlyMood(month: 1, avgScore: 7.5, count: 4),
            MonthlyMood(month: 2, avgScore: 8.0, count: 3),
          ],
          avgMoodScore: 7.8,
          topMoodScore: 8,
          bestMoodMonth: 'February',
        ),
      );

      expect(find.text('Mood Journey'), findsOneWidget);
      expect(find.text('😊 Most common'), findsOneWidget);
      expect(find.text('😊 Happy'), findsOneWidget);
      expect(find.text('🌟 Best month'), findsOneWidget);
      expect(find.text('February'), findsOneWidget);
      expect(find.text('💕 Avg mood score'), findsOneWidget);
      expect(find.text('7.8 / 10'), findsOneWidget);
    });

    testWidgets('omits the best-month chip when none is set', (tester) async {
      await _pump(
        tester,
        _baseData(
          monthlyMoods: const [MonthlyMood(month: 1, avgScore: 7.5, count: 4)],
          avgMoodScore: 7.5,
          topMoodScore: 7,
        ),
      );

      expect(find.text('🌟 Best month'), findsNothing);
    });
  });
}

// Widget tests for WrappedPageMilestones, written before extracting its
// `_buildMilestoneTile` and `_emptyMilestonesState` methods into real
// widget classes -- these pin the page's current rendered behavior so
// the extraction can be verified rather than assumed safe.
//
// Uses explicit pump() calls rather than pumpAndSettle: the confetti
// package schedules its own particle-physics timers independent of a
// bounded AnimationController, so waiting for "everything to settle"
// isn't a safe assumption here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:days_together/features/wrapped/domain/wrapped_data.dart';
import 'package:days_together/features/wrapped/presentation/pages/wrapped_page_milestones.dart';

WrappedData _baseData({
  List<String> milestonesAchievedThisYear = const [],
  int totalDays = 365,
}) => WrappedData(
  year: 2024,
  yourName: 'Alex',
  partnerName: 'Sam',
  totalDays: totalDays,
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
  monthlyMoods: const [],
  avgMoodScore: 0.0,
  topMoodScore: 0,
  calendarEventsThisYear: 0,
  specialDatesThisYear: const [],
  capsulesCreated: 0,
  capsulesOpened: 0,
  upcomingCapsules: 0,
  totalPhotos: 0,
  totalCapsules: 0,
  milestonesAchievedThisYear: milestonesAchievedThisYear,
  letterTemplateIndex: 0,
);

Future<void> _pump(WidgetTester tester, WrappedData data) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: WrappedPageMilestones(data: data),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1500));
}

void main() {
  group('WrappedPageMilestones', () {
    testWidgets('shows the empty state when there are no milestones', (
      tester,
    ) async {
      await _pump(tester, _baseData());

      expect(find.text('🏆 Milestones'), findsOneWidget);
      expect(
        find.text('The next milestone is just around the corner'),
        findsOneWidget,
      );
      expect(find.text('Your next milestone is coming.'), findsOneWidget);
      expect(find.text('365 days of unbroken love 💜'), findsOneWidget);
    });

    testWidgets('renders each achieved milestone as a tile', (tester) async {
      await _pump(
        tester,
        _baseData(
          milestonesAchievedThisYear: const ['First Anniversary', '100 Days'],
        ),
      );

      expect(find.text('🏆 Milestones Unlocked'), findsOneWidget);
      expect(find.text('Achievements you reached in 2024'), findsOneWidget);
      expect(find.text('First Anniversary'), findsOneWidget);
      expect(find.text('100 Days'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    });
  });
}

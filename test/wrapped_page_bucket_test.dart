// Widget tests for WrappedPageBucket, written before extracting its
// inline progress-bar/completed-card/favorite-item blocks and
// `_emptyBucketState` method into real widget classes -- these pin the
// page's current rendered behavior so the extraction can be verified
// rather than assumed safe.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:days_together/features/wrapped/domain/wrapped_data.dart';
import 'package:days_together/features/wrapped/presentation/pages/wrapped_page_bucket.dart';

WrappedData _baseData({
  int bucketTotal = 0,
  int bucketCompleted = 0,
  int bucketCompletedThisYear = 0,
  String? favoriteBucketItem,
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
  bucketTotal: bucketTotal,
  bucketCompleted: bucketCompleted,
  bucketCompletedThisYear: bucketCompletedThisYear,
  favoriteBucketItem: favoriteBucketItem,
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
  milestonesAchievedThisYear: const [],
  letterTemplateIndex: 0,
);

Future<void> _pump(WidgetTester tester, WrappedData data) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: WrappedPageBucket(data: data),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('WrappedPageBucket', () {
    testWidgets('shows the empty state when there is no bucket list', (
      tester,
    ) async {
      await _pump(tester, _baseData());

      expect(find.text('Bucket List'), findsOneWidget);
      expect(find.text('Dream big together next year.'), findsOneWidget);
      expect(find.text('% complete'), findsNothing);
    });

    testWidgets('renders progress, the completed-this-year card, and the '
        'favorite item', (tester) async {
      await _pump(
        tester,
        _baseData(
          bucketTotal: 10,
          bucketCompleted: 4,
          bucketCompletedThisYear: 2,
          favoriteBucketItem: 'Visit Japan',
        ),
      );

      expect(find.text('40% complete'), findsOneWidget);
      expect(find.text('4 / 10'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('dreams completed in 2024'), findsOneWidget);
      expect(find.text('⭐ First dream of the year'), findsOneWidget);
      expect(find.text('Visit Japan'), findsOneWidget);
    });

    testWidgets('uses singular copy for exactly one dream completed', (
      tester,
    ) async {
      await _pump(
        tester,
        _baseData(
          bucketTotal: 5,
          bucketCompleted: 1,
          bucketCompletedThisYear: 1,
        ),
      );

      expect(find.text('dream completed in 2024'), findsOneWidget);
    });

    testWidgets('omits the favorite-item card when none is set', (
      tester,
    ) async {
      await _pump(tester, _baseData(bucketTotal: 5, bucketCompleted: 1));

      expect(find.text('⭐ First dream of the year'), findsNothing);
    });
  });
}

// Widget tests for WrappedPageMemories, written before extracting its
// featured-memory card and `_emptyImageBox`/`_emptyMemoriesState` methods
// into real widget classes -- these pin the page's current rendered
// behavior so the extraction can be verified rather than assumed safe.
//
// Featured memories in these tests never set featuredMemoryImageUrl, so
// StorageImage's network path is never exercised -- only the no-image and
// asset-image (imagePath) branches are covered.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:days_together/features/wrapped/domain/wrapped_data.dart';
import 'package:days_together/features/wrapped/presentation/pages/wrapped_page_memories.dart';

WrappedData _baseData({
  int memoriesThisYear = 0,
  int totalMemories = 0,
  String? featuredMemoryTitle,
  String? featuredMemoryDescription,
  DateTime? featuredMemoryDate,
}) => WrappedData(
  year: 2024,
  yourName: 'Alex',
  partnerName: 'Sam',
  totalDays: 365,
  durationYears: 1,
  durationMonths: 0,
  durationDays: 0,
  totalMemories: totalMemories,
  memoriesThisYear: memoriesThisYear,
  featuredMemoryTitle: featuredMemoryTitle,
  featuredMemoryDescription: featuredMemoryDescription,
  featuredMemoryDate: featuredMemoryDate,
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
  milestonesAchievedThisYear: const [],
  letterTemplateIndex: 0,
);

Future<void> _pump(WidgetTester tester, WrappedData data) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: WrappedPageMemories(data: data),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('WrappedPageMemories', () {
    testWidgets('shows the empty memories state when there is none featured', (
      tester,
    ) async {
      await _pump(tester, _baseData(memoriesThisYear: 0, totalMemories: 0));

      expect(find.text('Your story starts here'), findsOneWidget);
      expect(find.text('new memories in 2024'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('renders the featured memory card without an image', (
      tester,
    ) async {
      await _pump(
        tester,
        _baseData(
          memoriesThisYear: 3,
          totalMemories: 12,
          featuredMemoryTitle: 'Beach Day',
          featuredMemoryDescription: 'We watched the sunset together.',
          featuredMemoryDate: DateTime(2024, 6, 15),
        ),
      );

      expect(find.text('new memories in 2024'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Beach Day'), findsOneWidget);
      expect(find.text('We watched the sunset together.'), findsOneWidget);
      expect(
        find.text(DateFormat('MMM d, y').format(DateTime(2024, 6, 15))),
        findsOneWidget,
      );
      expect(
        find.text('12 memories in your timeline total 📸'),
        findsOneWidget,
      );
    });

    testWidgets('uses singular copy for exactly one new memory', (
      tester,
    ) async {
      await _pump(
        tester,
        _baseData(memoriesThisYear: 1, featuredMemoryTitle: 'Beach Day'),
      );

      expect(find.text('new memory in 2024'), findsOneWidget);
    });
  });
}

// Widget test for WrappedPageFinale, written before extracting its
// `_buildShareCard`/`_shareChip` methods into real widget classes -- this
// pins the page's current rendered behavior so the extraction can be
// verified rather than assumed safe.
//
// The pulsing heart's AnimationController repeats forever
// (`..repeat(reverse: true)`), so this test never calls pumpAndSettle --
// it would hang waiting for an animation that never stops, the same
// indeterminate-animation issue this app's other tests work around with
// plain pump() calls. The Share Story button is never tapped: it renders
// a RepaintBoundary to a real PNG file and calls share_plus, neither of
// which is mocked here.
//
// The share card's header row (AppTypography.body/caption, both
// GoogleFonts.spectral) overflows its fixed 340px width here -- this
// app's tests never load real Google Fonts (the documented gap noted in
// app_router_test.dart), so the fallback system font measures wider than
// the production font and the row that fits on-device doesn't fit in
// this environment. Known cosmetic-only, test-environment-specific, and
// unrelated to this extraction, so it's suppressed rather than
// "fixed" here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:days_together/features/wrapped/domain/wrapped_data.dart';
import 'package:days_together/features/wrapped/presentation/pages/wrapped_page_finale.dart';

final _data = WrappedData(
  year: 2024,
  yourName: 'Alex',
  partnerName: 'Sam',
  totalDays: 365,
  durationYears: 1,
  durationMonths: 0,
  durationDays: 0,
  startDate: DateTime(2023, 1, 1),
  totalMemories: 42,
  memoriesThisYear: 10,
  totalNotes: 7,
  notesThisYear: 3,
  bucketTotal: 10,
  bucketCompleted: 4,
  bucketCompletedThisYear: 2,
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

Future<void> _pump(WidgetTester tester, {VoidCallback? onReplay}) async {
  // The finale page's stacked content (heart, copy, share card, action
  // row) overflows the default 800x600 test surface -- a real phone
  // screen is taller.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: WrappedPageFinale(data: _data, onReplay: onReplay ?? () {}),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
}

void _ignoreOverflowErrors() {
  final originalOnError = FlutterError.onError!;
  FlutterError.onError = (details) {
    final message = details.exception.toString();
    if (message.contains('overflowed')) return;
    originalOnError(details);
  };
}

void main() {
  group('WrappedPageFinale', () {
    testWidgets('renders the thank-you copy and share-card stats', (
      tester,
    ) async {
      _ignoreOverflowErrors();
      await _pump(tester);

      expect(find.text('Thank You'), findsOneWidget);
      expect(find.text('Alex & Sam'), findsOneWidget);
      expect(find.text('Wrapped 2024'), findsOneWidget);
      expect(find.text('365 Days'), findsOneWidget);
      expect(find.text('42 Memories'), findsOneWidget);
      expect(find.text('7 Notes'), findsOneWidget);
      expect(find.text('4 Goals'), findsOneWidget);
      expect(
        find.text(
          'Together since ${DateFormat('MMM d, y').format(_data.startDate!)}',
        ),
        findsOneWidget,
      );
      expect(find.text('Replay'), findsOneWidget);
      expect(find.text('Share Story'), findsOneWidget);
    });

    testWidgets('tapping Replay invokes the onReplay callback', (tester) async {
      _ignoreOverflowErrors();
      var replayed = false;
      await _pump(tester, onReplay: () => replayed = true);

      await tester.tap(find.text('Replay'));
      await tester.pump();

      expect(replayed, isTrue);
    });
  });
}

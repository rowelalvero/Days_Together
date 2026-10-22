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
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as ft show testWidgets;
import 'dart:async' show Completer, runZonedGuarded;
import 'dart:convert' show jsonEncode;
import 'dart:io' show File, FileMode;
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;
import 'package:days_together/shared/models/app_settings.dart' show AppSettings, ThemeType;

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

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'wrapped_page_milestones_test.dart';

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

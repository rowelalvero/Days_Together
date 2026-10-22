// Widget tests for WrappedPageBucket, written before extracting its
// inline progress-bar/completed-card/favorite-item blocks and
// `_emptyBucketState` method into real widget classes -- these pin the
// page's current rendered behavior so the extraction can be verified
// rather than assumed safe.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as ft show testWidgets;
import 'dart:async' show Completer, runZonedGuarded;
import 'dart:convert' show jsonEncode;
import 'dart:io' show File, FileMode;
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;
import 'package:days_together/shared/models/app_settings.dart' show AppSettings, ThemeType;

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

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'wrapped_page_bucket_test.dart';

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

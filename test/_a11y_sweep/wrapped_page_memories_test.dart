// Widget tests for WrappedPageMemories, written before extracting its
// featured-memory card and `_emptyImageBox`/`_emptyMemoriesState` methods
// into real widget classes -- these pin the page's current rendered
// behavior so the extraction can be verified rather than assumed safe.
//
// Featured memories in these tests never set featuredMemoryImageUrl, so
// StorageImage's network path is never exercised -- only the no-image and
// asset-image (imagePath) branches are covered.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as ft show testWidgets;
import 'dart:async' show Completer, runZonedGuarded;
import 'dart:convert' show jsonEncode;
import 'dart:io' show File, FileMode;
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;
import 'package:days_together/shared/models/app_settings.dart' show AppSettings, ThemeType;
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

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'wrapped_page_memories_test.dart';

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

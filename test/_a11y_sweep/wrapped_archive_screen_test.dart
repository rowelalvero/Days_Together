// Widget tests for WrappedArchiveScreen, written before extracting its
// `_buildYearCard` and `_emptyState` methods into real widget classes --
// these pin the screen's current rendered behavior so the extraction can
// be verified rather than assumed safe.
//
// WrappedService is a pure SharedPreferences-backed service (no network),
// so archived years are seeded directly via
// SharedPreferences.setMockInitialValues -- a raw placeholder string is
// enough for getArchivedYears() to find them, since loadArchive() (which
// would need to parse real WrappedData JSON) is only called when a year
// card is tapped. Year cards are never tapped here: doing so calls
// context.push, and this suite deliberately never mounts a real
// GoRouter, matching this app's other screen tests.

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

import 'package:days_together/features/wrapped/presentation/pages/wrapped_archive_screen.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: WrappedArchiveScreen())),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WrappedArchiveScreen', () {
    testWidgets('shows the empty state when there are no archives', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester);

      expect(find.text('Wrapped Archive'), findsOneWidget);
      expect(find.text('No archives yet'), findsOneWidget);
    });

    testWidgets('renders archived years sorted newest-first', (tester) async {
      SharedPreferences.setMockInitialValues({
        'wrapped_archive_2023': 'placeholder',
        'wrapped_archive_2024': 'placeholder',
      });
      await _pump(tester);

      expect(find.text('Wrapped 2024'), findsOneWidget);
      expect(find.text('Wrapped 2023'), findsOneWidget);
      expect(find.text('Your year in review'), findsNWidgets(2));

      final firstYear = tester.getTopLeft(find.text('Wrapped 2024'));
      final secondYear = tester.getTopLeft(find.text('Wrapped 2023'));
      expect(firstYear.dy, lessThan(secondYear.dy));
    });

    testWidgets('the back button pops the screen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WrappedArchiveScreen(),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Wrapped Archive'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Wrapped Archive'), findsNothing);
    });
  });
}

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'wrapped_archive_screen_test.dart';

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

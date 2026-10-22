// Widget tests for GenesisScreen, written before extracting its
// `_buildPickerTile` method (used twice, for the date and time pickers)
// into a real widget class -- these pin the screen's current rendered
// behavior so the extraction can be verified rather than assumed safe.
//
// The Continue button is never tapped: past its workspace writes (which
// are safe -- see workspace_controller_test.dart's coverage of
// setStartDate/setStartTime writing through to CoupleSession for an
// unpaired session), it calls context.push, and this suite -- like this
// app's other screen tests -- never mounts a real GoRouter.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as ft show testWidgets;
import 'dart:async' show Completer, runZonedGuarded;
import 'dart:convert' show jsonEncode;
import 'dart:io' show File, FileMode;
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;
import 'package:days_together/shared/models/app_settings.dart' show AppSettings, ThemeType;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/features/authentication/presentation/pages/genesis_screen.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: GenesisScreen())),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GenesisScreen', () {
    testWidgets("renders the header and today's date/time tiles", (
      tester,
    ) async {
      await _pump(tester);

      final now = DateTime.now();
      expect(find.text('When did your\nstory begin?'), findsOneWidget);
      expect(find.text('DATE'), findsOneWidget);
      expect(find.text('TIME'), findsOneWidget);
      expect(
        find.text(DateFormat('MMMM dd, yyyy').format(now)),
        findsOneWidget,
      );
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('tapping the date tile opens the date picker', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('DATE'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('tapping the time tile opens the time picker', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('TIME'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
    });
  });
}

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'genesis_screen_test.dart';

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

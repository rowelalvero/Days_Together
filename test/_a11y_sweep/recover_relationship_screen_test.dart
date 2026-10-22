// Widget tests for RecoverRelationshipScreen, written before extracting its
// ~330-line single-literal build() (header, glassmorphic recovery-code
// card, submit button) into real widget classes -- these pin the screen's
// current rendered behavior so the extraction can be verified rather than
// assumed safe.
//
// Every test here stays on the client-side-validation path
// (_formKey.currentState!.validate() failing before any network call) --
// SessionController.recoverRelationship delegates straight to
// CoupleSession.recoverRelationship, which unconditionally hits real
// Supabase (key generation + an RPC call), so this suite deliberately
// never completes a valid submission.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as ft show testWidgets;
import 'dart:async' show Completer, runZonedGuarded;
import 'dart:convert' show jsonEncode;
import 'dart:io' show File, FileMode;
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;
import 'package:days_together/shared/models/app_settings.dart' show AppSettings, ThemeType;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/features/authentication/presentation/pages/recover_relationship_screen.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: RecoverRelationshipScreen())),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RecoverRelationshipScreen', () {
    testWidgets('renders the header, hint text, and submit button', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Recover your workspace'), findsOneWidget);
      expect(find.text('RECOVERY CODE'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Recover Workspace'), findsOneWidget);
    });

    testWidgets('submitting an empty code shows a required-field error', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Recover Workspace'));
      await tester.pumpAndSettle();

      expect(find.text('Recovery code is required'), findsOneWidget);
    });

    testWidgets('a code without a hyphen shows a format error', (tester) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextFormField), 'ABC123');
      await tester.tap(find.text('Recover Workspace'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('doesn\'t look like a recovery code'),
        findsOneWidget,
      );
    });

    testWidgets('a validly-formatted code shows no validation error', (
      tester,
    ) async {
      await _pump(tester);

      await tester.enterText(
        find.byType(TextFormField),
        'ABC123-RVT7-H9MK-PQ82-JXW5',
      );
      await tester.tap(find.text('Recover Workspace'));
      await tester.pump();

      expect(find.text('Recovery code is required'), findsNothing);
      expect(
        find.textContaining('doesn\'t look like a recovery code'),
        findsNothing,
      );
      expect(find.text('ABC123-RVT7-H9MK-PQ82-JXW5'), findsWidgets);
    });

    testWidgets('the paste button fills the field from the clipboard', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': 'abc123-rvt7-h9mk-pq82-jxw5'};
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await _pump(tester);

      await tester.tap(find.byTooltip('Paste recovery code'));
      await tester.pumpAndSettle();

      expect(find.text('ABC123-RVT7-H9MK-PQ82-JXW5'), findsOneWidget);
    });

    testWidgets('typing upper-cases and drops characters a code never has', (
      tester,
    ) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextFormField), 'abc 12_3-rvt7');
      await tester.pump();

      expect(find.text('ABC123-RVT7'), findsOneWidget);
      expect(find.text('abc 12_3-rvt7'), findsNothing);
    });

    testWidgets('the submit button stays pinned and labelled', (tester) async {
      await _pump(tester);

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Recover Workspace'),
      );
      expect(button.onPressed, isNotNull);
      expect(find.byTooltip('Back'), findsOneWidget);
    });
  });
}

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'recover_relationship_screen_test.dart';

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

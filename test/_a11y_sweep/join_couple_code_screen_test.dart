// Widget tests for JoinCoupleCodeScreen's 8-character input
// (20261003000200_harden_pairing.sql widened pairing codes from 6 to 8).
//
// CoupleSession() is constructed offline (Supabase never initialized), so
// joinWithCode returns false without a network call -- the screen then shows
// its not-found message, which is how these tests observe that validation
// fired at the 8th character and not before.

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

import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/authentication/presentation/pages/join_couple_code_screen.dart';
import 'package:days_together/shared/widgets/otp_input.dart';

const _notFound =
    'Hmm, we couldn\'t find that connection code. Please check it with your partner.';

Future<void> _pump(WidgetTester tester, {required double width}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
      child: const MaterialApp(home: JoinCoupleCodeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Types one character at a time into OtpInput's single hidden field.
Future<void> _typeCode(WidgetTester tester, String code) async {
  for (final ch in code.split('')) {
    await tester.enterText(find.byType(TextField), ch);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows eight character boxes and fits a 360dp-wide phone', (
    tester,
  ) async {
    await _pump(tester, width: 360);

    expect(find.byType(OtpInput), findsOneWidget);
    expect(tester.widget<OtpInput>(find.byType(OtpInput)).length, 8);
    expect(
      find.text('Enter the 8-character connection code sent by your partner.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not submit after only six characters', (tester) async {
    await _pump(tester, width: 400);

    await _typeCode(tester, 'ABC123');

    expect(find.text(_notFound), findsNothing);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('submits once all eight characters are entered', (tester) async {
    await _pump(tester, width: 400);

    await _typeCode(tester, 'ABCD1234');

    expect(find.text(_notFound), findsOneWidget);
  });

  testWidgets('a pasted lower-case code fills every slot and submits', (
    tester,
  ) async {
    await _pump(tester, width: 400);

    await tester.enterText(find.byType(TextField), 'abcd1234');
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text(_notFound), findsOneWidget);
  });
}

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'join_couple_code_screen_test.dart';

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

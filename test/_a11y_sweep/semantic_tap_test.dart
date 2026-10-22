// SemanticTap: the shared wrapper that makes a custom-drawn tap target a
// real control for screen readers (label, role, state, tap action) and can
// grow its hit area without changing its look.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as ft show testWidgets;
import 'dart:async' show Completer, runZonedGuarded;
import 'dart:convert' show jsonEncode;
import 'dart:io' show File, FileMode;
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;
import 'package:days_together/shared/models/app_settings.dart' show AppSettings, ThemeType;

import 'package:days_together/shared/widgets/semantic_tap.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

const _dot = SizedBox(
  width: 20,
  height: 20,
  child: ColoredBox(color: Colors.pink),
);

void main() {
  testWidgets('is one labeled button node that performs the tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _host(
        SemanticTap(label: 'Send message', onTap: () => taps++, child: _dot),
      ),
    );

    expect(
      tester.getSemantics(find.byType(SemanticTap)),
      matchesSemantics(
        label: 'Send message',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.byType(SemanticTap));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('a checked value makes it a checkbox, not a button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        SemanticTap(
          label: 'Visit Paris',
          checked: true,
          onTap: () {},
          child: _dot,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(SemanticTap)),
      matchesSemantics(
        label: 'Visit Paris',
        hasCheckedState: true,
        isChecked: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('reports selected state and is disabled without onTap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const SemanticTap(
          label: 'Show both licenses',
          selected: true,
          onTap: null,
          child: _dot,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(SemanticTap)),
      matchesSemantics(
        label: 'Show both licenses',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('minTapTarget grows the hit area, not the visual', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        SemanticTap(
          label: 'Clear',
          minTapTarget: 48,
          onTap: () {},
          child: _dot,
        ),
      ),
    );
    expect(tester.getSize(find.byType(SemanticTap)), const Size(48, 48));
    expect(
      tester.getSize(
        find.descendant(
          of: find.byType(SemanticTap),
          matching: find.byType(ColoredBox),
        ),
      ),
      const Size(20, 20),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'semantic_tap_test.dart';

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

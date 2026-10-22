// The reduced-motion helpers: decorative loops stop on a still frame and
// one-shot flourishes jump to their end when the OS asks for reduced motion
// (MediaQuery.disableAnimations), and follow the setting live.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as ft show testWidgets;
import 'dart:async' show Completer, runZonedGuarded;
import 'dart:convert' show jsonEncode;
import 'dart:io' show File, FileMode;
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;
import 'package:days_together/shared/models/app_settings.dart' show AppSettings, ThemeType;

import 'package:days_together/shared/widgets/reduced_motion.dart';

class _Pulse extends StatefulWidget {
  const _Pulse({required this.onController});
  final void Function(AnimationController) onController;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void initState() {
    super.initState();
    widget.onController(_c);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c.repeatUnlessReducedMotion(context, reverse: true, restValue: 0.25);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Widget _app({required bool reduce, required Widget child}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduce),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

void main() {
  testWidgets('loops normally when motion is allowed', (tester) async {
    late AnimationController c;
    await tester.pumpWidget(
      _app(reduce: false, child: _Pulse(onController: (x) => c = x)),
    );
    expect(c.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.value, isNot(0.25));
  });

  testWidgets('parks on the rest frame under reduced motion', (tester) async {
    late AnimationController c;
    await tester.pumpWidget(
      _app(reduce: true, child: _Pulse(onController: (x) => c = x)),
    );
    expect(c.isAnimating, isFalse);
    expect(c.value, 0.25);
    await tester.pump(const Duration(seconds: 2));
    expect(c.value, 0.25);
  });

  testWidgets('follows the setting when it changes while open', (tester) async {
    late AnimationController c;
    final pulse = _Pulse(onController: (x) => c = x);
    await tester.pumpWidget(_app(reduce: false, child: pulse));
    expect(c.isAnimating, isTrue);

    await tester.pumpWidget(_app(reduce: true, child: pulse));
    expect(c.isAnimating, isFalse);
    expect(c.value, 0.25);

    await tester.pumpWidget(_app(reduce: false, child: pulse));
    expect(c.isAnimating, isTrue);
  });

  testWidgets('a one-shot flourish jumps to its end under reduced motion', (
    tester,
  ) async {
    final c = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 3),
    );
    addTearDown(c.dispose);
    Future<void> play(bool reduce) => tester.pumpWidget(
      _app(
        reduce: reduce,
        child: Builder(
          builder: (context) {
            c.playUnlessReducedMotion(context, from: 0);
            return const SizedBox();
          },
        ),
      ),
    );

    await play(true);
    expect(c.isAnimating, isFalse);
    expect(c.value, 1.0);

    await play(false);
    expect(c.isAnimating, isTrue);
    expect(c.value, lessThan(1.0));
    c.stop();
  });
}

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'reduced_motion_test.dart';

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

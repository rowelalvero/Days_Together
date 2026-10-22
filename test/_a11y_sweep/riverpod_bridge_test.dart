// Validates that buildAppRoot() (the exact production widget-tree wiring,
// factored out of main.dart's runApp) exposes a working coupleSessionProvider.
//
// This test previously validated Phase 2 of the architecture migration
// (ADR-002): a `provider`-package Provider tree bridged into a second,
// nested Riverpod ProviderScope via coupleSessionProvider.overrideWithValue,
// asserting both containers resolved to the identical CoupleSession
// instance. That whole two-container strangler bridge was retired in Item 3
// gap-fix Phase 3 (front 4 of the architecture migration's `provider`-
// removal item): coupleSessionProvider now constructs the single
// CoupleSession instance itself, so there is only ever one container and
// nothing left to compare identity across. This file instead confirms the
// single remaining, actually load-bearing property: reading
// coupleSessionProvider through the production widget tree returns a live,
// stable CoupleSession -- the same instance on every read, not reconstructed
// per call (which would silently break every hub/domain controller's
// `dependencies: [coupleSessionProvider]` wiring).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as ft show testWidgets;
import 'dart:async' show Completer, runZonedGuarded;
import 'dart:convert' show jsonEncode;
import 'dart:io' show File, FileMode;
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;
import 'package:days_together/shared/models/app_settings.dart' show AppSettings, ThemeType;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/main.dart';
import 'package:days_together/core/session/couple_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'coupleSessionProvider resolves to a live, stable CoupleSession instance through the production widget tree',
    (tester) async {
      late BuildContext probeContext;

      await tester.pumpWidget(
        buildAppRoot(
          child: Builder(
            builder: (context) {
              probeContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      final container = ProviderScope.containerOf(probeContext);
      final first = container.read(coupleSessionProvider);
      final second = container.read(coupleSessionProvider);

      expect(
        identical(first, second),
        isTrue,
        reason:
            'coupleSessionProvider must return the same CoupleSession '
            'instance on every read within the same container -- a plain '
            'Provider constructs its value exactly once and caches it.',
      );
    },
  );
}

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'riverpod_bridge_test.dart';

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

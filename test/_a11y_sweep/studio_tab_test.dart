// Widget tests for StudioTab, written before extracting its ~4 _buildX
// methods and its inline `_showPremiumPaywall` bottom sheet into real
// widget classes -- these pin the tab's current rendered behavior so the
// extraction can be verified rather than assumed safe.
//
// Cards that navigate via go_router when already unlocked (Future Time
// Capsule always, the two premium cards when isPremium is true) are
// checked for correct rendering only, never tapped -- this app
// deliberately avoids pumping a real GoRouter in widget tests (see
// test/app_router_test.dart's own doc comment). WorkspaceController.
// setPremium delegates straight to CoupleSession.setPremium, so the
// "unlock" test asserts against the CoupleSession instance directly
// rather than the rebuilt tab, matching test/settings_tab_test.dart's
// same finding.

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

import 'package:days_together/app/shell/tabs/studio_tab.dart';
import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/relationship/workspace_state.dart';

class _SeededWorkspace extends WorkspaceController {
  _SeededWorkspace(this._seed);
  final WorkspaceState _seed;
  @override
  WorkspaceState build() => _seed;
}

Future<void> _pump(
  WidgetTester tester, {
  CoupleSession? session,
  bool isPremium = false,
}) async {
  // The studio card list overflows the default 800x600 test surface -- a
  // real phone screen is taller.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleSessionProvider.overrideWithValue(session ?? CoupleSession()),
        workspaceControllerProvider.overrideWith(
          () => _SeededWorkspace(WorkspaceState(isPremium: isPremium)),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: StudioTab())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StudioTab', () {
    testWidgets('renders the header and all three studio cards', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Love Studio'), findsOneWidget);
      expect(find.text('Powered by AI'), findsOneWidget);
      expect(find.text('AI Love Letter Generator'), findsOneWidget);
      expect(find.text('Future Time Capsule'), findsOneWidget);
      expect(find.text('Relationship Insights'), findsOneWidget);
    });

    testWidgets('shows the premium banner and lock icons when unpremium', (
      tester,
    ) async {
      await _pump(tester, isPremium: false);

      expect(find.text('Unlock Love Studio Premium'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(2));
    });

    testWidgets('hides the premium banner and shows star icons when premium', (
      tester,
    ) async {
      await _pump(tester, isPremium: true);

      expect(find.text('Unlock Love Studio Premium'), findsNothing);
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    });

    testWidgets('tapping a locked card opens the premium paywall sheet', (
      tester,
    ) async {
      await _pump(tester, isPremium: false);

      await tester.tap(find.text('AI Love Letter Generator'));
      await tester.pumpAndSettle();

      expect(find.text('✨ Love Studio Premium'), findsOneWidget);
      expect(find.text('AI Love Letter Generator'), findsNWidgets(2));
      expect(find.text('Deep Relationship Insights'), findsOneWidget);
      expect(find.text('Unlimited Future Time Capsules'), findsOneWidget);
      expect(find.text('Exclusive App Themes'), findsOneWidget);
    });

    testWidgets('tapping Upgrade Now on the banner opens the same sheet', (
      tester,
    ) async {
      await _pump(tester, isPremium: false);

      await tester.tap(find.text('Upgrade Now'));
      await tester.pumpAndSettle();

      expect(find.text('✨ Love Studio Premium'), findsOneWidget);
    });

    testWidgets('unlocking premium writes through and shows a confirmation', (
      tester,
    ) async {
      final session = CoupleSession();
      await _pump(tester, session: session, isPremium: false);

      await tester.tap(find.text('Upgrade Now'));
      await tester.pumpAndSettle();

      expect(session.isPremium, isFalse);

      await tester.tap(find.text('Unlock Premium — \$0.00 (Free Test)'));
      await tester.pumpAndSettle();

      expect(session.isPremium, isTrue);
      expect(find.text('✨ Welcome to Love Studio Premium!'), findsOneWidget);
      expect(find.text('✨ Love Studio Premium'), findsNothing);
    });
  });
}

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'studio_tab_test.dart';

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

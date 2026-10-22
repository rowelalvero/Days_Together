// PairingSelectionScreen's cards must stay tappable after coming back from
// a screen they opened. go_router drops a push's Future when the router
// refreshes while the pushed screen is open -- the app's router refreshes on
// every session change -- so a "navigating" flag cleared by that Future used
// to stay stuck and make every card ignore taps.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as ft show testWidgets;
import 'dart:async' show Completer, runZonedGuarded;
import 'dart:convert' show jsonEncode;
import 'dart:io' show File, FileMode;
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;
import 'package:days_together/shared/models/app_settings.dart' show AppSettings, ThemeType;
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/app/router/route_names.dart';
import 'package:days_together/features/authentication/presentation/pages/pairing_selection_screen.dart';

Widget _stub(String label) => Builder(
  builder: (context) => Scaffold(
    body: TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(label),
    ),
  ),
);

Future<ValueNotifier<int>> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final refresh = ValueNotifier(0);
  addTearDown(refresh.dispose);
  final router = GoRouter(
    initialLocation: Routes.pairing,
    refreshListenable: refresh,
    routes: [
      GoRoute(
        path: Routes.pairing,
        builder: (_, _) => const PairingSelectionScreen(),
      ),
      GoRoute(path: Routes.joinCode, builder: (_, _) => _stub('join page')),
      GoRoute(path: Routes.recover, builder: (_, _) => _stub('recover page')),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
  return refresh;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('cards still work after going back from a pushed screen', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Join with Pairing Code'));
    await tester.pumpAndSettle();
    expect(find.text('join page'), findsOneWidget);

    await tester.tap(find.text('join page'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recover Existing Relationship'));
    await tester.pumpAndSettle();
    expect(find.text('recover page'), findsOneWidget);
  });

  testWidgets('cards still work when the router refreshed meanwhile', (
    tester,
  ) async {
    final refresh = await _pump(tester);

    await tester.tap(find.text('Recover Existing Relationship'));
    await tester.pumpAndSettle();
    expect(find.text('recover page'), findsOneWidget);

    // A session change while the pushed screen is open.
    refresh.value++;
    await tester.pumpAndSettle();

    await tester.tap(find.text('recover page'));
    await tester.pumpAndSettle();
    expect(find.text('recover page'), findsNothing);

    await tester.tap(find.text('Join with Pairing Code'));
    await tester.pumpAndSettle();
    expect(find.text('join page'), findsOneWidget);
  });

  testWidgets('a double tap opens the screen only once', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Join with Pairing Code'));
    await tester.tap(find.text('Join with Pairing Code'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('join page'), findsOneWidget);

    // One pop returns to the selection screen -- there was no second copy.
    await tester.tap(find.text('join page'));
    await tester.pumpAndSettle();
    expect(find.text('Join with Pairing Code'), findsOneWidget);
    expect(find.text('join page'), findsNothing);
  });
}

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'pairing_selection_screen_test.dart';

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

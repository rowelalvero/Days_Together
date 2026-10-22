// Widget tests for TimeCapsuleScreen, written before extracting its ~5
// _buildX methods, its inline `_showCreateCapsuleSheet` (showModalBottomSheet
// + StatefulBuilder closure), and its `_showCapsuleDetailDialog` into real
// widget classes -- these pin the screen's current rendered behavior so the
// extraction can be verified rather than assumed safe.
//
// TimeCapsuleController is seeded through a subclass whose build() returns
// a fixed state, so no Supabase client or realtime subscription is
// involved -- the same technique calendar_screen_test.dart uses.
// createCapsule/openCapsule/deleteCapsule are exercised for real (not
// mocked) since they all apply their local state change unconditionally
// when coupleId is null, which it is for every seeded state here.

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
import 'package:days_together/features/love_studio/domain/entities/time_capsule_model.dart';
import 'package:days_together/features/love_studio/presentation/pages/time_capsule_screen.dart';
import 'package:days_together/features/love_studio/time_capsule_controller.dart';
import 'package:days_together/features/love_studio/time_capsule_state.dart';

class _SeededTimeCapsule extends TimeCapsuleController {
  _SeededTimeCapsule(this._seed);
  final TimeCapsuleState _seed;
  @override
  TimeCapsuleState build() => _seed;
}

Future<void> _pump(
  WidgetTester tester, {
  TimeCapsuleState capsule = const TimeCapsuleState(
    capsules: [],
    isLoading: false,
  ),
}) async {
  // The section headers + capsule cards overflow the default 800x600 test
  // surface -- a real phone screen is taller.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleSessionProvider.overrideWithValue(CoupleSession()),
        timeCapsuleControllerProvider.overrideWith(
          () => _SeededTimeCapsule(capsule),
        ),
      ],
      child: const MaterialApp(home: TimeCapsuleScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TimeCapsuleScreen', () {
    testWidgets('shows the empty state with no capsules', (tester) async {
      await _pump(tester);

      expect(find.text('Send a message to the future.'), findsOneWidget);
    });

    testWidgets('groups capsules into ready/sealed/opened sections', (
      tester,
    ) async {
      final now = DateTime.now();
      await _pump(
        tester,
        capsule: TimeCapsuleState(
          isLoading: false,
          capsules: [
            TimeCapsule(
              message: 'Ready message',
              openDate: now.subtract(const Duration(days: 1)),
            ),
            TimeCapsule(
              message: 'Locked message',
              openDate: now.add(const Duration(days: 30)),
            ),
            TimeCapsule(
              message: 'Already opened',
              openDate: now.subtract(const Duration(days: 10)),
              isOpened: true,
            ),
          ],
        ),
      );

      expect(find.text('🔓 Ready to Open'), findsOneWidget);
      expect(find.text('🔒 Sealed & Waiting'), findsOneWidget);
      expect(find.text('📖 Opened Memories'), findsOneWidget);
      expect(find.text('Ready to open now!'), findsOneWidget);
      expect(find.text('Already opened'), findsOneWidget);
    });

    testWidgets('creating a new capsule seals it and shows a confirmation', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('✉️ Create Time Capsule'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'Dear future us, we made it.',
      );
      await tester.tap(find.text('Select Unlock Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Seal Time Capsule'));
      await tester.pumpAndSettle();

      expect(find.text('✉️ Create Time Capsule'), findsNothing);
      expect(
        find.text('🔒 Time Capsule sealed and locked away!'),
        findsOneWidget,
      );
    });

    testWidgets(
      'opening a ready capsule shows its message and marks it opened',
      (tester) async {
        await _pump(
          tester,
          capsule: TimeCapsuleState(
            isLoading: false,
            capsules: [
              TimeCapsule(
                message: 'You made it to the future!',
                openDate: DateTime.now().subtract(const Duration(days: 1)),
              ),
            ],
          ),
        );

        await tester.tap(find.byIcon(Icons.arrow_forward_ios_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Opened Capsule'), findsOneWidget);
        expect(find.text('You made it to the future!'), findsWidgets);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        expect(find.text('📖 Opened Memories'), findsOneWidget);
      },
    );

    testWidgets('deleting a capsule confirms, then removes it', (tester) async {
      await _pump(
        tester,
        capsule: TimeCapsuleState(
          isLoading: false,
          capsules: [
            TimeCapsule(
              message: 'Locked message',
              openDate: DateTime.now().add(const Duration(days: 30)),
            ),
          ],
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Delete Time Capsule?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('🔒 Sealed & Waiting'), findsNothing);
      expect(find.text('Send a message to the future.'), findsOneWidget);
    });
  });
}

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'time_capsule_screen_test.dart';

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

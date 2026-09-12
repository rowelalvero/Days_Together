// Widget tests for CreateCoupleCodeScreen, written before extracting its
// inline connection-code/recovery-code cards and its `_buildButton` helper
// into real widget classes -- these pin the screen's current rendered
// behavior so the extraction can be verified rather than assumed safe.
//
// The seeded WorkspaceState always includes a non-null coupleCode: with a
// null one, initState's `_code = coupleCode ?? workspace.generateCoupleCode()`
// falls through to CoupleSession.generateCoupleCode(), which calls
// createRelationshipWorkspace() -- a real Supabase RPC plus key-management
// I/O this test environment never initializes. workspace.refreshPairingCode()
// (also fired from initState) is safe: it returns immediately whenever
// CoupleSession.coupleId is null, which it is for every seeded session
// here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/authentication/presentation/pages/create_couple_code_screen.dart';
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
  WorkspaceState workspace = const WorkspaceState(
    coupleCode: 'ABC123',
    recoveryCode: 'XYZ-000',
  ),
}) async {
  // The code card + recovery card + continue button overflow the default
  // 800x600 test surface -- a real phone screen is taller.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleSessionProvider.overrideWithValue(session ?? CoupleSession()),
        workspaceControllerProvider.overrideWith(
          () => _SeededWorkspace(workspace),
        ),
      ],
      child: const MaterialApp(home: CreateCoupleCodeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CreateCoupleCodeScreen', () {
    testWidgets('renders the code, recovery code, and continue button', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('ABC123'), findsOneWidget);
      expect(find.text('XYZ-000'), findsOneWidget);
      expect(find.text('Copy Code'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Generate New Code'), findsOneWidget);
      expect(find.text('Copy Recovery Code'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      final continueButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continue'),
      );
      expect(continueButton.onPressed, isNull);
    });

    testWidgets('copying the code shows a confirmation, then reverts', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Copy Code'));
      await tester.pump();

      expect(find.text('✓ Copied'), findsOneWidget);
      expect(find.text('Copy Code'), findsNothing);

      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Copy Code'), findsOneWidget);
    });

    testWidgets('copying the recovery code shows a confirmation', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Copy Recovery Code'));
      await tester.pump();

      expect(find.text('Copied!'), findsOneWidget);

      // Let the 2-second revert timer fire so it isn't still pending when
      // the test ends.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'checking the recovery confirmation enables the continue button',
      (tester) async {
        await _pump(tester);

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        final continueButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Continue'),
        );
        expect(continueButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'tapping Continue clears the recovery code and moves to Genesis',
      (tester) async {
        final session = CoupleSession();
        await _pump(tester, session: session);

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(session.recoveryCode, isNull);
        expect(find.text('Your unique\nconnection code.'), findsNothing);
      },
    );
  });
}

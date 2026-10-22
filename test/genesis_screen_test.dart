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
import 'package:flutter_test/flutter_test.dart';
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

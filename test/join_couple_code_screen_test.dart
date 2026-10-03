// Widget tests for JoinCoupleCodeScreen's 8-character input
// (20261003000200_harden_pairing.sql widened pairing codes from 6 to 8).
//
// CoupleSession() is constructed offline (Supabase never initialized), so
// joinWithCode returns false without a network call -- the screen then shows
// its not-found message, which is how these tests observe that validation
// fired at the 8th character and not before.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/authentication/presentation/pages/join_couple_code_screen.dart';

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

Future<void> _typeCode(WidgetTester tester, String code) async {
  final fields = find.byType(TextField);
  for (var i = 0; i < code.length; i++) {
    await tester.enterText(fields.at(i), code[i]);
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

    expect(find.byType(TextField), findsNWidgets(8));
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
}

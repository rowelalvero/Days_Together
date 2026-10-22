// OtpInput: slot-based code entry over one hidden TextField. Typing,
// backspacing (holes stay in place), paste/autofill, charset filtering,
// the completion callback, and the status message.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/models/app_settings.dart';
import 'package:days_together/shared/widgets/otp_input.dart';

class _Calls {
  final changes = <String>[];
  final completions = <String>[];
}

Future<_Calls> _pump(
  WidgetTester tester, {
  int length = 4,
  OtpCharset charset = OtpCharset.digits,
  OtpStatus status = OtpStatus.idle,
  bool obscure = false,
}) async {
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: OtpInput(
            theme: ThemeManager.getTheme(ThemeType.offWhite),
            length: length,
            charset: charset,
            status: status,
            obscure: obscure,
            hint: 'Check your messages',
            errorMessage: 'That code did not work',
            successMessage: 'Verified',
            onChanged: calls.changes.add,
            onCompleted: calls.completions.add,
          ),
        ),
      ),
    ),
  );
  return calls;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

Future<void> _backspace(WidgetTester tester) => _type(tester, '');

void main() {
  testWidgets('typing fills slots in order and completes once', (tester) async {
    final calls = await _pump(tester);

    for (final ch in ['1', '2', '3', '4']) {
      await _type(tester, ch);
    }

    for (final ch in ['1', '2', '3', '4']) {
      expect(find.text(ch), findsOneWidget);
    }
    expect(calls.changes.last, '1234');
    expect(calls.completions, ['1234']);
  });

  testWidgets('backspace clears in place, then steps back', (tester) async {
    final calls = await _pump(tester);
    await _type(tester, '12');

    // Active slot is the empty third one: backspace steps back to clear '2'.
    await _backspace(tester);
    expect(find.text('2'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(calls.changes.last, '1');
  });

  testWidgets('a full-length paste fills from the first slot', (tester) async {
    final calls = await _pump(tester);
    await _type(tester, '9');

    await _type(tester, '5678');

    expect(find.text('9'), findsNothing);
    expect(find.text('5'), findsOneWidget);
    expect(calls.completions, ['5678']);
  });

  testWidgets('editing an already-full code does not complete again', (
    tester,
  ) async {
    final calls = await _pump(tester);
    await _type(tester, '1234');

    // The active slot is the last one; typing overwrites it in place, so the
    // code goes full -> full.
    await _type(tester, '7');

    expect(calls.changes.last, '1237');
    expect(calls.completions, ['1234']);
  });

  testWidgets('digits charset drops letters', (tester) async {
    final calls = await _pump(tester);

    await _type(tester, 'a1b2');

    expect(calls.changes, ['12']);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('a'), findsNothing);
  });

  testWidgets('alphanumeric charset upper-cases letters', (tester) async {
    final calls = await _pump(tester, charset: OtpCharset.alphanumeric);

    await _type(tester, 'ab-1');

    expect(calls.changes, ['AB1']);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('a'), findsNothing);
  });

  testWidgets('obscure shows dots instead of characters', (tester) async {
    await _pump(tester, obscure: true);

    await _type(tester, '12');

    expect(find.text('•'), findsNWidgets(2));
    expect(find.text('1'), findsNothing);
  });

  testWidgets('the message follows the status', (tester) async {
    await _pump(tester);
    expect(find.text('Check your messages'), findsOneWidget);

    await _pump(tester, status: OtpStatus.error);
    await tester.pumpAndSettle();
    expect(find.text('That code did not work'), findsOneWidget);
    expect(find.text('Check your messages'), findsNothing);

    await _pump(tester, status: OtpStatus.success);
    await tester.pumpAndSettle();
    expect(find.text('Verified'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}

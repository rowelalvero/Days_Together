// Widget tests for RecoverRelationshipScreen, written before extracting its
// ~330-line single-literal build() (header, glassmorphic recovery-code
// card, submit button) into real widget classes -- these pin the screen's
// current rendered behavior so the extraction can be verified rather than
// assumed safe.
//
// Every test here stays on the client-side-validation path
// (_formKey.currentState!.validate() failing before any network call) --
// SessionController.recoverRelationship delegates straight to
// CoupleSession.recoverRelationship, which unconditionally hits real
// Supabase (key generation + an RPC call), so this suite deliberately
// never completes a valid submission.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/features/authentication/presentation/pages/recover_relationship_screen.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: RecoverRelationshipScreen())),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RecoverRelationshipScreen', () {
    testWidgets('renders the header, hint text, and submit button', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Recover your workspace'), findsOneWidget);
      expect(find.text('RECOVERY CODE'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Recover Workspace'), findsOneWidget);
    });

    testWidgets('submitting an empty code shows a required-field error', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Recover Workspace'));
      await tester.pumpAndSettle();

      expect(find.text('Recovery code is required'), findsOneWidget);
    });

    testWidgets('a code without a hyphen shows a format error', (tester) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextFormField), 'ABC123');
      await tester.tap(find.text('Recover Workspace'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('doesn\'t look like a recovery code'),
        findsOneWidget,
      );
    });

    testWidgets('a validly-formatted code shows no validation error', (
      tester,
    ) async {
      await _pump(tester);

      await tester.enterText(
        find.byType(TextFormField),
        'ABC123-RVT7-H9MK-PQ82-JXW5',
      );
      await tester.tap(find.text('Recover Workspace'));
      await tester.pump();

      expect(find.text('Recovery code is required'), findsNothing);
      expect(
        find.textContaining('doesn\'t look like a recovery code'),
        findsNothing,
      );
      expect(find.text('ABC123-RVT7-H9MK-PQ82-JXW5'), findsWidgets);
    });

    testWidgets('the paste button fills the field from the clipboard', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': 'abc123-rvt7-h9mk-pq82-jxw5'};
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await _pump(tester);

      await tester.tap(find.byTooltip('Paste recovery code'));
      await tester.pumpAndSettle();

      expect(find.text('ABC123-RVT7-H9MK-PQ82-JXW5'), findsOneWidget);
    });

    testWidgets('typing upper-cases and drops characters a code never has', (
      tester,
    ) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextFormField), 'abc 12_3-rvt7');
      await tester.pump();

      expect(find.text('ABC123-RVT7'), findsOneWidget);
      expect(find.text('abc 12_3-rvt7'), findsNothing);
    });

    testWidgets('the submit button stays pinned and labelled', (tester) async {
      await _pump(tester);

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Recover Workspace'),
      );
      expect(button.onPressed, isNotNull);
      expect(find.byTooltip('Back'), findsOneWidget);
    });
  });
}

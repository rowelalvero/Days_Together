import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/presentation/profile/delete_account_confirmation_dialog.dart';

class _FakeDeleteSessionController extends SessionController {
  static Future<void> Function()? delete;

  @override
  Future<void> deleteAccount() => delete!();
}

void main() {
  testWidgets('failed deletion keeps the confirmation open and allows retry', (
    tester,
  ) async {
    final pending = Completer<void>();
    _FakeDeleteSessionController.delete = () => pending.future;
    addTearDown(() => _FakeDeleteSessionController.delete = null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(
            _FakeDeleteSessionController.new,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => DeleteAccountConfirmationDialog.show(
                  context,
                  ThemeManager.themes.values.first,
                ),
                child: const Text('Open confirmation'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);

    pending.completeError(StateError('offline'));
    await tester.pump();
    expect(
      find.textContaining('Could not delete your account'),
      findsOneWidget,
    );
    expect(find.text('Delete'), findsOneWidget);

    _FakeDeleteSessionController.delete = () async {};
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountConfirmationDialog), findsNothing);
  });
}

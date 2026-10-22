// Widget tests for AuthScreen, written before extracting its ~510-line
// single-literal build() (header, Log In/Sign Up toggle, form fields,
// submit button, and Google sign-in button) into real widget classes --
// these pin the screen's current rendered behavior so the extraction can
// be verified rather than assumed safe.
//
// Every test here stays on the client-side-validation path
// (_formKey.currentState!.validate() failing before any network call), or
// never taps submit/Google sign-in at all -- SessionController's
// signUpWithEmail/signInWithEmail/signInWithGoogle hit real Supabase/
// Google auth (unlike the feature controllers elsewhere in this app, they
// are not gated behind a safe-when-unpaired branch), so this suite
// deliberately never completes a valid submission.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/features/authentication/presentation/pages/auth_screen.dart';

Future<void> _pump(WidgetTester tester) async {
  // The form card + Google button overflow the default 800x600 test
  // surface -- a real phone screen is taller.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: AuthScreen())),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthScreen', () {
    testWidgets('starts in Log In mode with the sign-in copy', (tester) async {
      await _pump(tester);

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        findsNothing,
      );
    });

    testWidgets(
      'switching to Sign Up shows the create-account copy and a confirm field',
      (tester) async {
        await _pump(tester);

        await tester.tap(find.text('Sign Up'));
        await tester.pumpAndSettle();

        expect(find.text('Create Your Shared Space'), findsOneWidget);
        expect(find.text('Create Account'), findsOneWidget);
        expect(
          find.widgetWithText(TextFormField, 'Confirm Password'),
          findsOneWidget,
        );
      },
    );

    testWidgets('submitting an empty form shows validation errors', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
    });

    testWidgets('an invalid email shows its validation error', (tester) async {
      await _pump(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'not-an-email',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('mismatched confirm-password shows its validation error', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'me@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'different',
      );
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('the password visibility toggle switches the obscure icon', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('renders the Google sign-in button', (tester) async {
      await _pump(tester);

      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });
}

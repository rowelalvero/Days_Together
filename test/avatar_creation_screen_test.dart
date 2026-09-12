// Widget tests for AvatarCreationScreen, written before extracting its
// inline avatar picker circle and `_buildNameField` method into real
// widget classes -- these pin the screen's current rendered behavior so
// the extraction can be verified rather than assumed safe.
//
// The avatar picker itself is never tapped (ImagePicker's platform channel
// isn't mocked here), so `_avatarPath` stays null throughout -- which also
// means the completion flow never reaches `waitForCoupleKey`/`setAvatars`
// (both gated behind `_avatarPath != null`). ProfileController.setYourName
// and SessionController.completeOnboarding both delegate straight to
// CoupleSession, which only touches Supabase when `isSupabaseAvailable &&
// _userId != null` -- false for a fresh, unpaired CoupleSession() -- so
// completing setup with just a name is safe to exercise here. Neither
// controller's own Riverpod state is wired to rebuild in this isolated
// widget test (no main.dart bridge), so the write is asserted against the
// shared CoupleSession instance directly, matching settings_tab_test.dart's
// pattern.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/authentication/presentation/pages/avatar_creation_screen.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/relationship/profile_state.dart';

Future<void> _pump(
  WidgetTester tester, {
  required CoupleSession session,
  String? seededName,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleSessionProvider.overrideWithValue(session),
        profileControllerProvider.overrideWith(
          () => _SeededProfile(ProfileState(yourName: seededName)),
        ),
      ],
      child: const MaterialApp(home: AvatarCreationScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _SeededProfile extends ProfileController {
  _SeededProfile(this._seed);
  final ProfileState _seed;
  @override
  ProfileState build() => _seed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AvatarCreationScreen', () {
    testWidgets('renders the header, avatar placeholder, and name field', (
      tester,
    ) async {
      await _pump(tester, session: CoupleSession());

      expect(find.text("Let's add a face\nto your name."), findsOneWidget);
      expect(find.text('Add Photo'), findsOneWidget);
      expect(find.text('YOUR NAME'), findsOneWidget);
      expect(find.text('Complete Setup'), findsOneWidget);
    });

    testWidgets('pre-fills the name field from the profile controller', (
      tester,
    ) async {
      await _pump(tester, session: CoupleSession(), seededName: 'Alex');

      expect(find.text('Alex'), findsOneWidget);
    });

    testWidgets('submitting an empty name shows a snackbar and no name', (
      tester,
    ) async {
      final session = CoupleSession();
      await _pump(tester, session: session);

      await tester.tap(find.text('Complete Setup'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please share your name to complete your profile.'),
        findsOneWidget,
      );
      expect(session.onboardingCompleted, isFalse);
    });

    testWidgets(
      'completing setup with a name writes through to CoupleSession',
      (tester) async {
        // On success, _isSaving is never reset back to false -- in the
        // real app, completeOnboarding() flips CoupleSession's stage to
        // `ready` and the router redirects away before it would matter.
        // There's no real go_router here, so the screen (and its
        // indeterminate spinner) stays mounted -- pumpAndSettle would
        // hang waiting for an animation that never stops.
        final session = CoupleSession();
        await _pump(tester, session: session);

        await tester.enterText(find.byType(TextField), 'Jordan');
        await tester.tap(find.text('Complete Setup'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(session.yourName, 'Jordan');
        expect(session.onboardingCompleted, isTrue);
      },
    );
  });
}

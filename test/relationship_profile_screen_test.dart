// Widget tests for RelationshipProfileScreen, written before extracting its
// ~10 _buildX methods (app bar, header, avatars, info card, bento sections,
// danger-zone rows, auth debug footer) into real widget classes -- these pin
// the screen's current rendered behavior so the extraction can be verified
// rather than assumed safe.
//
// Every controller is seeded through a subclass whose build() returns a
// fixed state, so no Supabase client or realtime subscription is involved --
// the same technique calendar_screen_test.dart uses.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/features/relationship/presentation/profile/delete_account_confirmation_dialog.dart';
import 'package:days_together/features/relationship/presentation/profile/edit_profile_dialog.dart';
import 'package:days_together/features/relationship/presentation/profile/relationship_profile_screen.dart';
import 'package:days_together/features/relationship/presentation/profile/unlink_confirmation_dialog.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/relationship/profile_state.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/session_state.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/relationship/workspace_state.dart';

class _SeededSession extends SessionController {
  _SeededSession(this._seed);
  final SessionState _seed;
  @override
  SessionState build() => _seed;
}

class _SeededProfile extends ProfileController {
  _SeededProfile(this._seed);
  final ProfileState _seed;
  @override
  ProfileState build() => _seed;
}

class _SeededWorkspace extends WorkspaceController {
  _SeededWorkspace(this._seed);
  final WorkspaceState _seed;
  @override
  WorkspaceState build() => _seed;
}

Future<void> _pump(
  WidgetTester tester, {
  SessionState session = const SessionState(
    userId: 'user-12345678',
    coupleId: 'couple-12345678',
  ),
  ProfileState profile = const ProfileState(yourName: 'Alex'),
  WorkspaceState workspace = const WorkspaceState(),
}) async {
  // The screen's scroll column (header + info card + danger zone) overflows
  // the default 800x600 test surface -- a real phone screen is taller.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(() => _SeededSession(session)),
        profileControllerProvider.overrideWith(() => _SeededProfile(profile)),
        workspaceControllerProvider.overrideWith(
          () => _SeededWorkspace(workspace),
        ),
      ],
      child: const MaterialApp(home: RelationshipProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RelationshipProfileScreen', () {
    testWidgets('renders the app bar and both names when paired', (
      tester,
    ) async {
      await _pump(
        tester,
        session: const SessionState(
          userId: 'user-12345678',
          coupleId: 'couple-12345678',
          partnerId: 'partner-1234',
        ),
        profile: const ProfileState(yourName: 'Alex', partnerName: 'Sam'),
      );

      expect(find.text('Relationship Profile'), findsOneWidget);
      expect(find.text('Alex & Sam'), findsOneWidget);
      expect(find.text('CONNECTED & IN LOVE'), findsOneWidget);
      expect(find.text('Unlink Relationship'), findsOneWidget);
    });

    testWidgets(
      'shows the waiting state and pairing options when unpaired with a code',
      (tester) async {
        await _pump(
          tester,
          session: const SessionState(
            userId: 'user-12345678',
            coupleId: 'couple-12345678',
          ),
          profile: const ProfileState(yourName: 'Alex'),
          workspace: const WorkspaceState(coupleCode: 'ABC123'),
        );

        expect(find.text('Alex'), findsWidgets);
        expect(
          find.text('Waiting for your partner to connect...'),
          findsOneWidget,
        );
        expect(find.text('PROVIDE YOUR CODE'), findsOneWidget);
        expect(find.text('ABC123'), findsOneWidget);
        expect(find.text('Unlink Relationship'), findsNothing);
      },
    );

    testWidgets('the foundation and registry cards show formatted values', (
      tester,
    ) async {
      await _pump(
        tester,
        workspace: WorkspaceState(
          startDate: DateTime(2020, 3, 15),
          startTime: const TimeOfDay(hour: 9, minute: 30),
        ),
        profile: ProfileState(
          yourName: 'Alex',
          yourJoinDate: DateTime(2020, 3, 15),
          partnerJoinDate: DateTime(2020, 3, 20),
        ),
      );

      expect(find.text('March 15, 2020'), findsOneWidget);
      expect(find.text('9:30 AM'), findsOneWidget);
      expect(find.text('Mar 15, 2020'), findsOneWidget);
      expect(find.text('Mar 20, 2020'), findsOneWidget);
      expect(find.text('TIME TOGETHER'), findsOneWidget);
    });

    testWidgets('the auth debug footer shows truncated ids', (tester) async {
      await _pump(
        tester,
        session: const SessionState(
          userId: 'user-12345678',
          coupleId: 'couple-12345678',
        ),
      );

      expect(find.textContaining('UID: user-123'), findsOneWidget);
      expect(find.textContaining('CID: couple-1'), findsOneWidget);
    });

    testWidgets('tapping Edit Profile opens the edit-profile dialog', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileDialog), findsOneWidget);
    });

    testWidgets('tapping Unlink Relationship opens the unlink dialog', (
      tester,
    ) async {
      await _pump(
        tester,
        session: const SessionState(
          userId: 'user-12345678',
          coupleId: 'couple-12345678',
          partnerId: 'partner-1234',
        ),
      );

      await tester.tap(find.text('Unlink Relationship'));
      await tester.pumpAndSettle();

      expect(find.byType(UnlinkConfirmationDialog), findsOneWidget);
    });

    testWidgets('tapping Delete Account opens the delete-account dialog', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      expect(find.byType(DeleteAccountConfirmationDialog), findsOneWidget);
    });
  });
}

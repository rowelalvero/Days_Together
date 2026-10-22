// Widget tests for SettingsTab, written before extracting its ~7 _buildX
// methods (and its inline logout confirmation dialog) into real widget
// classes -- these pin the tab's current rendered behavior so the
// extraction can be verified rather than assumed safe.
//
// Tiles that navigate via go_router (Theme, Notifications, Relationship
// Profile, Wrapped, Wrapped Archive) are checked for correct rendering
// only, never tapped -- this app deliberately avoids pumping a real
// GoRouter in widget tests (see test/app_router_test.dart's own doc
// comment: every real destination screen renders themed text, which hits
// a documented GoogleFonts-in-tests gap). Similarly, SessionController's
// logout() calls AuthService.instance.signOut() when Supabase is
// available, so this suite opens the confirmation dialog and dismisses it
// via "Keep Logged In" rather than completing a real logout.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/app/shell/tabs/settings_tab.dart';
import 'package:days_together/core/session/couple_session.dart';
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
    userId: 'user-1',
    coupleId: 'couple-1',
  ),
  ProfileState profile = const ProfileState(yourName: 'Alex'),
  WorkspaceState workspace = const WorkspaceState(),
}) async {
  // The full settings list overflows the default 800x600 test surface --
  // a real phone screen is taller.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleSessionProvider.overrideWithValue(CoupleSession()),
        sessionControllerProvider.overrideWith(() => _SeededSession(session)),
        profileControllerProvider.overrideWith(() => _SeededProfile(profile)),
        workspaceControllerProvider.overrideWith(
          () => _SeededWorkspace(workspace),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: SettingsTab())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsTab', () {
    testWidgets('renders the profile card and section headers', (tester) async {
      await _pump(
        tester,
        profile: const ProfileState(yourName: 'Alex', partnerName: 'Sam'),
        session: const SessionState(
          userId: 'user-1',
          coupleId: 'couple-1',
          partnerId: 'partner-1',
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('EXPERIENCE'), findsOneWidget);
      expect(find.text('CONNECTION'), findsOneWidget);
    });

    testWidgets('shows "Waiting..." for the partner avatar when unpaired', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Waiting...'), findsOneWidget);
    });

    testWidgets(
      'the Relationship Profile tile shows connected copy when paired',
      (tester) async {
        await _pump(
          tester,
          session: const SessionState(
            userId: 'user-1',
            coupleId: 'couple-1',
            partnerId: 'partner-1',
          ),
        );

        expect(find.text('Connected with partner'), findsOneWidget);
      },
    );

    testWidgets(
      'the Relationship Profile tile shows waiting copy when unpaired',
      (tester) async {
        await _pump(
          tester,
          session: const SessionState(userId: 'user-1', coupleId: 'couple-1'),
        );

        expect(find.text('Waiting for connection'), findsOneWidget);
      },
    );

    testWidgets('shows the current year in the Wrapped tile', (tester) async {
      await _pump(tester);

      expect(
        find.text('Your ${DateTime.now().year} year in review'),
        findsOneWidget,
      );
    });

    testWidgets('toggling Premium Studio writes through to CoupleSession', (
      tester,
    ) async {
      // WorkspaceController.setPremium delegates straight to
      // CoupleSession.setPremium (see workspace_controller.dart) -- the
      // Riverpod state this screen watches only updates via main.dart's
      // _WorkspaceControllerBridge, which isn't wired up in this isolated
      // widget test, so the rendered Switch itself won't flip here. Assert
      // the write against the CoupleSession instance directly instead.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = CoupleSession();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coupleSessionProvider.overrideWithValue(session),
            workspaceControllerProvider.overrideWith(
              () => _SeededWorkspace(const WorkspaceState(isPremium: false)),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: SettingsTab())),
        ),
      );
      await tester.pumpAndSettle();

      expect(session.isPremium, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(session.isPremium, isTrue);
    });

    testWidgets(
      'tapping Log Out opens a confirmation, and Keep Logged In dismisses it',
      (tester) async {
        await _pump(tester);

        await tester.tap(find.text('Log Out').first);
        await tester.pumpAndSettle();

        expect(
          find.text(
            'This will erase all your local data including memories, settings, and theme preferences.\n\nAre you sure?',
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Keep Logged In'));
        await tester.pumpAndSettle();

        expect(find.text('Keep Logged In'), findsNothing);
      },
    );
  });
}

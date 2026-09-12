// Widget tests for CurrentlyCard's unpaired state, added alongside the
// PartnerInvitePrompt feature: while session.partnerId is null, the whole
// live-presence layout (partner avatar, Love Tap button, activity box,
// streak row) is replaced by the couple code itself plus copy/send
// actions, instead of showing that layout with placeholder copy or
// sending the user to a separate screen just to see a code that already
// exists.
//
// The prompt's send button is never tapped: it calls Share.share, whose
// platform channel isn't mocked here. The copy button is safe to tap --
// it only writes to the clipboard.
//
// CurrentlyCard's _pulseController repeats forever regardless of pairing
// state (created unconditionally in initState), so pumpAndSettle would
// hang -- plain pump() calls are used instead, the same
// indeterminate-animation workaround this app's other tests use.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/features/dashboard/presentation/widgets/currently_card.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/relationship/profile_state.dart';
import 'package:days_together/features/relationship/presence_controller.dart';
import 'package:days_together/features/relationship/presence_state.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/session_state.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/relationship/workspace_state.dart';
import 'package:days_together/features/currently/currently_controller.dart';
import 'package:days_together/features/currently/currently_state.dart';

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

class _SeededPresence extends PresenceController {
  _SeededPresence(this._seed);
  final PresenceState _seed;
  @override
  PresenceState build() => _seed;
}

class _SeededCurrently extends CurrentlyController {
  _SeededCurrently(this._seed);
  final CurrentlyState _seed;
  @override
  CurrentlyState build() => _seed;
}

class _SeededWorkspace extends WorkspaceController {
  _SeededWorkspace(this._seed);
  final WorkspaceState _seed;
  @override
  WorkspaceState build() => _seed;
}

Future<void> _pump(
  WidgetTester tester, {
  required SessionState session,
  ProfileState profile = const ProfileState(),
  PresenceState presence = const PresenceState(),
  CurrentlyState currently = const CurrentlyState(),
  WorkspaceState workspace = const WorkspaceState(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(() => _SeededSession(session)),
        profileControllerProvider.overrideWith(() => _SeededProfile(profile)),
        presenceControllerProvider.overrideWith(
          () => _SeededPresence(presence),
        ),
        currentlyControllerProvider.overrideWith(
          () => _SeededCurrently(currently),
        ),
        workspaceControllerProvider.overrideWith(
          () => _SeededWorkspace(workspace),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: CurrentlyCard())),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CurrentlyCard', () {
    testWidgets(
      'shows the couple code and send action, and no live-presence UI, when unpaired',
      (tester) async {
        await _pump(
          tester,
          session: const SessionState(userId: 'user-1', coupleId: 'couple-1'),
          workspace: const WorkspaceState(coupleCode: 'ABC123'),
        );

        expect(find.text('Waiting for your partner'), findsOneWidget);
        expect(
          find.text('Share your code so they can join your story.'),
          findsOneWidget,
        );
        expect(find.text('YOUR CODE'), findsOneWidget);
        expect(find.text('ABC123'), findsOneWidget);
        expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
        expect(find.byIcon(Icons.send_rounded), findsOneWidget);

        expect(find.text('Love Tap'), findsNothing);
        expect(find.text('No activity shared yet'), findsNothing);
        expect(find.text('Waiting for partner...'), findsNothing);
      },
    );

    testWidgets(
      'shows a placeholder and disables copy/send while the code is not yet ready',
      (tester) async {
        await _pump(
          tester,
          session: const SessionState(userId: 'user-1', coupleId: 'couple-1'),
          workspace: const WorkspaceState(),
        );

        expect(find.text('· · · · · ·'), findsOneWidget);

        final copyButton = tester.widget<GestureDetector>(
          find.ancestor(
            of: find.byIcon(Icons.copy_rounded),
            matching: find.byType(GestureDetector),
          ),
        );
        expect(copyButton.onTap, isNull);

        final sendButton = tester.widget<GestureDetector>(
          find.ancestor(
            of: find.byIcon(Icons.send_rounded),
            matching: find.byType(GestureDetector),
          ),
        );
        expect(sendButton.onTap, isNull);
      },
    );

    testWidgets(
      'tapping copy shows a checkmark that reverts after a couple of seconds',
      (tester) async {
        await _pump(
          tester,
          session: const SessionState(userId: 'user-1', coupleId: 'couple-1'),
          workspace: const WorkspaceState(coupleCode: 'ABC123'),
        );

        await tester.tap(find.byIcon(Icons.copy_rounded));
        await tester.pump();

        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(find.byIcon(Icons.copy_rounded), findsNothing);

        await tester.pump(const Duration(seconds: 2));

        expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
      },
    );

    testWidgets('shows the live-presence layout once a partner has joined', (
      tester,
    ) async {
      await _pump(
        tester,
        session: const SessionState(
          userId: 'user-1',
          coupleId: 'couple-1',
          partnerId: 'partner-1',
          isPaired: true,
        ),
        profile: const ProfileState(partnerName: 'Sam'),
      );

      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('Love Tap'), findsOneWidget);
      expect(find.text('No activity shared yet'), findsOneWidget);
      expect(find.text('Waiting for your partner'), findsNothing);
      expect(find.text('YOUR CODE'), findsNothing);
    });
  });
}

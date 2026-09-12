// Widget tests for RelationshipLicenseScreen, written before extracting its
// `_buildCreationForm` (the first-time license application Scaffold) and
// the main license view's "Configure License Details" card / card canvas /
// action-buttons blocks into real widget classes -- these pin the screen's
// current rendered behavior so the extraction can be verified rather than
// assumed safe.
//
// Every controller is seeded through a subclass whose build() returns a
// fixed state, so no Supabase client, SharedPreferences read, or realtime
// subscription is involved -- the same technique calendar_screen_test.dart
// uses. LicenseController is an AsyncNotifier, so its seeded build() is
// still async (returning the seed synchronously resolves it on the next
// pump/settle).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/features/relationship/license_controller.dart';
import 'package:days_together/features/relationship/license_details.dart';
import 'package:days_together/features/relationship/presentation/license/enlarged_license_dialog.dart';
import 'package:days_together/features/relationship/presentation/license/license_screen.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/relationship/profile_state.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/session_state.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/relationship/workspace_state.dart';

class _SeededLicense extends LicenseController {
  _SeededLicense(this._seed);
  final LicenseDetails _seed;
  @override
  Future<LicenseDetails> build() async => _seed;
}

class _SeededProfile extends ProfileController {
  _SeededProfile(this._seed);
  final ProfileState _seed;
  @override
  ProfileState build() => _seed;
}

class _SeededSession extends SessionController {
  _SeededSession(this._seed);
  final SessionState _seed;
  @override
  SessionState build() => _seed;
}

class _SeededWorkspace extends WorkspaceController {
  _SeededWorkspace(this._seed);
  final WorkspaceState _seed;
  @override
  WorkspaceState build() => _seed;
}

Future<void> _pump(
  WidgetTester tester, {
  LicenseDetails license = const LicenseDetails(),
  SessionState session = const SessionState(
    userId: 'user-1',
    coupleId: 'couple-1',
    partnerId: 'partner-1',
  ),
  ProfileState profile = const ProfileState(
    yourName: 'Alex',
    partnerName: 'Sam',
  ),
  // WaitingForPartnerScreen's indeterminate CircularProgressIndicator
  // animates forever, so pumpAndSettle would time out whenever that screen
  // is what's showing.
  bool settle = true,
}) async {
  // The main license view's card canvas + action buttons overflow the
  // default 800x600 test surface -- a real phone screen is taller.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        licenseControllerProvider.overrideWith(() => _SeededLicense(license)),
        profileControllerProvider.overrideWith(() => _SeededProfile(profile)),
        sessionControllerProvider.overrideWith(() => _SeededSession(session)),
        workspaceControllerProvider.overrideWith(
          () => _SeededWorkspace(const WorkspaceState()),
        ),
      ],
      child: const MaterialApp(home: RelationshipLicenseScreen()),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // Let the AsyncNotifier's Future resolve without waiting for the
    // never-ending progress-indicator animation to settle.
    await tester.pump();
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RelationshipLicenseScreen', () {
    testWidgets('shows the "No License Found" welcome screen first', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('No License Found'), findsOneWidget);
      expect(find.text('Create License ID'), findsOneWidget);
    });

    testWidgets(
      'tapping Create License ID opens the creation form with validation',
      (tester) async {
        await _pump(tester);

        await tester.tap(find.text('Create License ID'));
        await tester.pumpAndSettle();

        expect(find.text('License Application'), findsOneWidget);
        expect(find.text('Generate Relationship License ID'), findsOneWidget);

        await tester.tap(find.text('Generate Relationship License ID'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter Your Name first! ✍️'), findsOneWidget);
      },
    );

    testWidgets('submitting a name starts the license-generation animation', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Create License ID'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Alex');
      await tester.tap(find.text('Generate Relationship License ID'));
      await tester.pump();

      expect(
        find.text('Initializing Love Registry Database...'),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows the waiting screen when the partner has not completed setup',
      (tester) async {
        await _pump(
          tester,
          license: LicenseDetails(yourDateIssued: DateTime(2024, 1, 1)),
          settle: false,
        );

        expect(find.text('Waiting for Partner'), findsOneWidget);
      },
    );

    testWidgets('renders the main license view once both are issued', (
      tester,
    ) async {
      await _pump(
        tester,
        license: LicenseDetails(
          yourDateIssued: DateTime(2024, 1, 1),
          partnerDateIssued: DateTime(2024, 1, 2),
        ),
      );

      expect(find.text('Relationship License'), findsOneWidget);
      expect(find.text('Configure License Details'), findsOneWidget);
      expect(find.text('Flip Cards'), findsOneWidget);
      expect(find.text('Enlarge ID'), findsOneWidget);
      expect(find.text('Share License'), findsOneWidget);
    });

    testWidgets('tapping Enlarge ID opens the enlarged license dialog', (
      tester,
    ) async {
      await _pump(
        tester,
        license: LicenseDetails(
          yourDateIssued: DateTime(2024, 1, 1),
          partnerDateIssued: DateTime(2024, 1, 2),
        ),
      );

      await tester.tap(find.text('Enlarge ID'));
      await tester.pumpAndSettle();

      expect(find.byType(EnlargedLicenseDialog), findsOneWidget);
    });
  });
}

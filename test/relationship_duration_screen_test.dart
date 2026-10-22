// Widget test for RelationshipDurationScreen, written before extracting
// its inline SliverAppBar hero-counter block into a real widget class --
// this pins the screen's current rendered behavior so the extraction can
// be verified rather than assumed safe. The rest of the screen is already
// composed of dedicated components under presentation/duration/components/,
// so this is a single-literal-build() extraction like auth_screen.dart's,
// not a `_buildX` sprawl case.
//
// Every controller is seeded through a subclass whose build() returns a
// fixed state (the same technique license_screen_test.dart and
// calendar_screen_test.dart use), so no Supabase client, SharedPreferences
// read, or realtime subscription is involved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/features/relationship/license_controller.dart';
import 'package:days_together/features/relationship/license_details.dart';
import 'package:days_together/features/relationship/presentation/duration/relationship_duration_screen.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/relationship/workspace_state.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/timeline/timeline_state.dart';

class _SeededLicense extends LicenseController {
  _SeededLicense(this._seed);
  final LicenseDetails _seed;
  @override
  Future<LicenseDetails> build() async => _seed;
}

class _SeededWorkspace extends WorkspaceController {
  _SeededWorkspace(this._seed);
  final WorkspaceState _seed;
  @override
  WorkspaceState build() => _seed;
}

class _SeededTimeline extends TimelineController {
  _SeededTimeline(this._seed);
  final TimelineState _seed;
  @override
  TimelineState build() => _seed;
}

Future<void> _pump(WidgetTester tester) async {
  final startDate = DateTime.now().subtract(const Duration(days: 100));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workspaceControllerProvider.overrideWith(
          () => _SeededWorkspace(WorkspaceState(startDate: startDate)),
        ),
        timelineControllerProvider.overrideWith(
          () => _SeededTimeline(const TimelineState(isLoading: false)),
        ),
        licenseControllerProvider.overrideWith(
          () => _SeededLicense(const LicenseDetails()),
        ),
      ],
      child: const MaterialApp(home: RelationshipDurationScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RelationshipDurationScreen', () {
    testWidgets('renders the hero counter header', (tester) async {
      await _pump(tester);

      expect(find.text('TOGETHER FOR'), findsOneWidget);
      expect(find.text('Days'), findsWidgets);
      expect(find.textContaining('Since '), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('the back button pops the screen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workspaceControllerProvider.overrideWith(
              () => _SeededWorkspace(
                WorkspaceState(
                  startDate: DateTime.now().subtract(const Duration(days: 5)),
                ),
              ),
            ),
            timelineControllerProvider.overrideWith(
              () => _SeededTimeline(const TimelineState(isLoading: false)),
            ),
            licenseControllerProvider.overrideWith(
              () => _SeededLicense(const LicenseDetails()),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RelationshipDurationScreen(),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('TOGETHER FOR'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('TOGETHER FOR'), findsNothing);
    });
  });
}

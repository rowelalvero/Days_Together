// Tests for WorkspaceController (Phase 6b-1 of the architecture migration,
// unit 3 -- "WorkspaceController real"). Since this unit, the controller
// mirrors CoupleSession directly (not RelationshipProvider, which is now
// just a facade over it) and gains real write methods that delegate to the
// live CoupleSession instance -- see workspace_controller.dart's doc
// comment for why delegation, not duplication, including for
// createRelationshipWorkspace's entangled RPC.

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/providers/couple_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );
  });

  group('WorkspaceController.updateFromSession mirroring', () {
    test('build() starts as an empty WorkspaceState with defaults', () {
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
      );
      addTearDown(container.dispose);

      final state = container.read(workspaceControllerProvider);
      expect(state.coupleCode, isNull);
      expect(state.storyTitle, 'Our Story');
      expect(state.startDate, isNull);
      expect(state.startTime, isNull);
      expect(state.isPremium, false);
      expect(state.status, RelationshipStatus.disconnected);
      expect(state.recoveryCode, isNull);
    });

    test('a call with unchanged fields does not notify again', () async {
      final session = CoupleSession();
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      container.read(workspaceControllerProvider.notifier).updateFromSession(session);

      var notifyCount = 0;
      container.listen(workspaceControllerProvider, (prev, next) => notifyCount++);
      container.read(workspaceControllerProvider.notifier).updateFromSession(session);

      expect(notifyCount, 0);
    });

    test('mirrors pairing/story/date/premium fields and notifies exactly once when they change', () async {
      SharedPreferences.setMockInitialValues({
        'couple_code': 'ABC123',
        'story_title': 'Us, Forever',
        'relationship_start_date': DateTime(2022, 6, 15).toIso8601String(),
        'relationship_start_hour': 9,
        'relationship_start_minute': 30,
        'is_premium': true,
      });

      final session = CoupleSession();
      await Future.delayed(Duration.zero);
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);
      var notifyCount = 0;
      container.listen(workspaceControllerProvider, (prev, next) => notifyCount++);

      container.read(workspaceControllerProvider.notifier).updateFromSession(session);

      final state = container.read(workspaceControllerProvider);
      expect(notifyCount, 1);
      expect(state.coupleCode, 'ABC123');
      expect(state.storyTitle, 'Us, Forever');
      expect(state.startDate, DateTime(2022, 6, 15));
      expect(state.startTime, const TimeOfDay(hour: 9, minute: 30));
      expect(state.isPremium, true);

      // A second call with unchanged fields must not notify again.
      container.read(workspaceControllerProvider.notifier).updateFromSession(session);
      expect(notifyCount, 1);
    });
  });

  group('WorkspaceController write methods delegate to CoupleSession', () {
    test('setStoryTitle writes through to the live CoupleSession instance', () async {
      final session = CoupleSession();
      await Future.delayed(Duration.zero);
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      await container.read(workspaceControllerProvider.notifier).setStoryTitle('Us, Forever');

      expect(session.storyTitle, 'Us, Forever');
    });

    test('setStartDate and setStartTime write through to the live CoupleSession instance', () async {
      final session = CoupleSession();
      await Future.delayed(Duration.zero);
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      await container.read(workspaceControllerProvider.notifier).setStartDate(DateTime(2022, 6, 15));
      await container.read(workspaceControllerProvider.notifier).setStartTime(const TimeOfDay(hour: 9, minute: 30));

      expect(session.startDate, DateTime(2022, 6, 15));
      expect(session.startTime, const TimeOfDay(hour: 9, minute: 30));
    });

    test('setPremium writes through to the live CoupleSession instance', () async {
      final session = CoupleSession();
      await Future.delayed(Duration.zero);
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      await container.read(workspaceControllerProvider.notifier).setPremium(true);

      expect(session.isPremium, true);
    });

    test('clearRecoveryCode clears the live CoupleSession instance', () async {
      final session = CoupleSession();
      await Future.delayed(Duration.zero);
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      container.read(workspaceControllerProvider.notifier).clearRecoveryCode();

      expect(session.recoveryCode, isNull);
    });
  });
}

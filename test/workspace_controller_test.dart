// Tests for WorkspaceController (Phase 5 of the architecture migration,
// unit 4 -- a Riverpod-native mirror of RelationshipProvider's 7 workspace
// fields, NOT a cutover: see workspace_controller.dart's doc comment for
// why, including recoveryCode despite it not being realtime-synced. Follows
// the same "notify only on change" contract as
// CoupleSession.updateFromRelationship (couple_session_test.dart) and
// ProfileController (profile_controller_test.dart), via ProviderContainer +
// container.listen instead of ChangeNotifier's addListener.

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/providers/relationship_provider.dart';

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

  group('WorkspaceController.updateFromRelationship mirroring', () {
    test('build() starts as an empty WorkspaceState with defaults', () {
      final container = ProviderContainer();
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
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final rp = RelationshipProvider();
      await Future.delayed(Duration.zero);

      container.read(workspaceControllerProvider.notifier).updateFromRelationship(rp);

      var notifyCount = 0;
      container.listen(workspaceControllerProvider, (prev, next) => notifyCount++);
      container.read(workspaceControllerProvider.notifier).updateFromRelationship(rp);

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

      final container = ProviderContainer();
      addTearDown(container.dispose);
      var notifyCount = 0;
      container.listen(workspaceControllerProvider, (prev, next) => notifyCount++);

      final rp = RelationshipProvider();
      await Future.delayed(Duration.zero);
      container.read(workspaceControllerProvider.notifier).updateFromRelationship(rp);

      final state = container.read(workspaceControllerProvider);
      expect(notifyCount, 1);
      expect(state.coupleCode, 'ABC123');
      expect(state.storyTitle, 'Us, Forever');
      expect(state.startDate, DateTime(2022, 6, 15));
      expect(state.startTime, const TimeOfDay(hour: 9, minute: 30));
      expect(state.isPremium, true);

      // A second call with unchanged fields must not notify again.
      container.read(workspaceControllerProvider.notifier).updateFromRelationship(rp);
      expect(notifyCount, 1);
    });
  });
}

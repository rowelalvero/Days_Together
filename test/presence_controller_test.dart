// Tests for PresenceController (Phase 5 of the architecture migration,
// unit 5 -- the last unit -- a Riverpod-native mirror of
// RelationshipProvider's 3 presence fields, NOT a cutover: see
// presence_controller.dart's doc comment for why. Follows the same "notify
// only on change" contract as CoupleSession.updateFromRelationship
// (couple_session_test.dart), ProfileController (profile_controller_test.dart),
// and WorkspaceController (workspace_controller_test.dart), via
// ProviderContainer + container.listen instead of ChangeNotifier's
// addListener.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/relationship/presence_controller.dart';
import 'package:days_together/providers/couple_session.dart';
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

  group('PresenceController.updateFromRelationship mirroring', () {
    test('build() starts as an empty PresenceState with defaults', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(presenceControllerProvider);
      expect(state.isPartnerOnline, false);
      expect(state.yourActivity, isNull);
      expect(state.partnerActivity, isNull);
    });

    test('a call with unchanged fields does not notify again', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final rp = RelationshipProvider(CoupleSession());
      await Future.delayed(Duration.zero);

      container.read(presenceControllerProvider.notifier).updateFromRelationship(rp);

      var notifyCount = 0;
      container.listen(presenceControllerProvider, (prev, next) => notifyCount++);
      container.read(presenceControllerProvider.notifier).updateFromRelationship(rp);

      expect(notifyCount, 0);
    });

    test('mirrors yourActivity set locally via updateCurrentActivity and notifies exactly once', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final rp = RelationshipProvider(CoupleSession());
      await Future.delayed(Duration.zero);
      container.read(presenceControllerProvider.notifier).updateFromRelationship(rp);

      var notifyCount = 0;
      container.listen(presenceControllerProvider, (prev, next) => notifyCount++);

      await rp.updateCurrentActivity('Reading together');
      container.read(presenceControllerProvider.notifier).updateFromRelationship(rp);

      final state = container.read(presenceControllerProvider);
      expect(notifyCount, 1);
      expect(state.yourActivity, 'Reading together');
      expect(state.isPartnerOnline, false);
      expect(state.partnerActivity, isNull);

      // A second call with unchanged fields must not notify again.
      container.read(presenceControllerProvider.notifier).updateFromRelationship(rp);
      expect(notifyCount, 1);
    });
  });
}

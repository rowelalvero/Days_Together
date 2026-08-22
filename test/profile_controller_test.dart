// Tests for ProfileController (Phase 5 of the architecture migration,
// unit 3 -- a Riverpod-native mirror of RelationshipProvider's 6 profile
// fields, NOT a cutover: see profile_controller.dart's doc comment for why.
// Follows the same "notify only on change" contract as
// CoupleSession.updateFromRelationship (couple_session_test.dart), adapted
// to Riverpod's Notifier via ProviderContainer + container.listen instead
// of ChangeNotifier's addListener.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
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

  group('ProfileController.updateFromRelationship mirroring', () {
    test('build() starts as an empty ProfileState', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(profileControllerProvider);
      expect(state.yourName, isNull);
      expect(state.partnerName, isNull);
      expect(state.yourAvatarPath, isNull);
      expect(state.partnerAvatarPath, isNull);
      expect(state.yourJoinDate, isNull);
      expect(state.partnerJoinDate, isNull);
    });

    test('a call with unchanged fields does not notify again', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final rp = RelationshipProvider(CoupleSession());
      await Future.delayed(Duration.zero);

      container.read(profileControllerProvider.notifier).updateFromRelationship(rp);

      var notifyCount = 0;
      container.listen(profileControllerProvider, (prev, next) => notifyCount++);
      container.read(profileControllerProvider.notifier).updateFromRelationship(rp);

      expect(notifyCount, 0);
    });

    test('mirrors name/avatar/join-date fields and notifies exactly once when they change', () async {
      SharedPreferences.setMockInitialValues({
        'your_name': 'Alex',
        'partner_name': 'Sam',
        'your_avatar_path': '/avatars/alex.png',
        'partner_avatar_path': '/avatars/sam.png',
        'your_join_date': DateTime(2022, 1, 1).toIso8601String(),
        'partner_join_date': DateTime(2022, 1, 2).toIso8601String(),
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      var notifyCount = 0;
      container.listen(profileControllerProvider, (prev, next) => notifyCount++);

      final rp = RelationshipProvider(CoupleSession());
      await Future.delayed(Duration.zero);
      container.read(profileControllerProvider.notifier).updateFromRelationship(rp);

      final state = container.read(profileControllerProvider);
      expect(notifyCount, 1);
      expect(state.yourName, 'Alex');
      expect(state.partnerName, 'Sam');
      expect(state.yourAvatarPath, '/avatars/alex.png');
      expect(state.partnerAvatarPath, '/avatars/sam.png');
      expect(state.yourJoinDate, DateTime(2022, 1, 1));
      expect(state.partnerJoinDate, DateTime(2022, 1, 2));

      // A second call with unchanged fields must not notify again.
      container.read(profileControllerProvider.notifier).updateFromRelationship(rp);
      expect(notifyCount, 1);
    });
  });
}

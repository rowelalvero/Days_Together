// Tests for ProfileController (Phase 6b-1 of the architecture migration,
// unit 2 -- "ProfileController real"). Since this unit, the controller
// mirrors CoupleSession directly (not RelationshipProvider, which is now
// just a facade over it) and gains real write methods that delegate to the
// live CoupleSession instance -- see profile_controller.dart's doc comment
// for why delegation, not duplication.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
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

  group('ProfileController.updateFromSession mirroring', () {
    test('build() starts as an empty ProfileState', () {
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
      );
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
      final session = CoupleSession();
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      container.read(profileControllerProvider.notifier).updateFromSession(session);

      var notifyCount = 0;
      container.listen(profileControllerProvider, (prev, next) => notifyCount++);
      container.read(profileControllerProvider.notifier).updateFromSession(session);

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

      final session = CoupleSession();
      await Future.delayed(Duration.zero);
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);
      var notifyCount = 0;
      container.listen(profileControllerProvider, (prev, next) => notifyCount++);

      container.read(profileControllerProvider.notifier).updateFromSession(session);

      final state = container.read(profileControllerProvider);
      expect(notifyCount, 1);
      expect(state.yourName, 'Alex');
      expect(state.partnerName, 'Sam');
      expect(state.yourAvatarPath, '/avatars/alex.png');
      expect(state.partnerAvatarPath, '/avatars/sam.png');
      expect(state.yourJoinDate, DateTime(2022, 1, 1));
      expect(state.partnerJoinDate, DateTime(2022, 1, 2));

      // A second call with unchanged fields must not notify again.
      container.read(profileControllerProvider.notifier).updateFromSession(session);
      expect(notifyCount, 1);
    });
  });

  group('ProfileController write methods delegate to CoupleSession', () {
    test('setYourName writes through to the live CoupleSession instance', () async {
      final session = CoupleSession();
      await Future.delayed(Duration.zero);
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      await container.read(profileControllerProvider.notifier).setYourName('Ashwel');

      expect(session.yourName, 'Ashwel');
    });

    test('setNames writes through both sides to the live CoupleSession instance', () async {
      final session = CoupleSession();
      await Future.delayed(Duration.zero);
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      await container.read(profileControllerProvider.notifier).setNames('Ashwel', 'Rowel');

      expect(session.yourName, 'Ashwel');
      expect(session.partnerName, 'Rowel');
    });

    test('setAvatars writes through to the live CoupleSession instance without a Supabase pairing', () async {
      final session = CoupleSession();
      await Future.delayed(Duration.zero);
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      // Offline/unpaired path (no Supabase, no coupleId): setAvatars falls
      // through to the plain local-write branch, matching
      // couple_session.dart's own behavior.
      await container.read(profileControllerProvider.notifier).setAvatars(yourPath: '/mock/avatars/ashwel.jpg');

      expect(session.yourAvatarPath, '/mock/avatars/ashwel.jpg');
    });
  });
}

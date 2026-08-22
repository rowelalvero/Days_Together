// Tests for PresenceController (Phase 6b-1 of the architecture migration,
// unit 4 -- the last of the four, "PresenceController real"). Since this
// unit, the controller mirrors CoupleSession directly (not
// RelationshipProvider, which is now just a facade over it) and gains a
// real write method (updateCurrentActivity) that delegates to the live
// CoupleSession instance -- see presence_controller.dart's doc comment for
// why delegation, not duplication, and why isPartnerOnline/partnerActivity
// have no write method at all (purely realtime-driven).

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/relationship/presence_controller.dart';
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

  group('PresenceController.updateFromSession mirroring', () {
    test('build() starts as an empty PresenceState with defaults', () {
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
      );
      addTearDown(container.dispose);

      final state = container.read(presenceControllerProvider);
      expect(state.isPartnerOnline, false);
      expect(state.yourActivity, isNull);
      expect(state.partnerActivity, isNull);
    });

    test('a call with unchanged fields does not notify again', () async {
      final session = CoupleSession();
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      container.read(presenceControllerProvider.notifier).updateFromSession(session);

      var notifyCount = 0;
      container.listen(presenceControllerProvider, (prev, next) => notifyCount++);
      container.read(presenceControllerProvider.notifier).updateFromSession(session);

      expect(notifyCount, 0);
    });

    test('mirrors yourActivity set locally via updateCurrentActivity and notifies exactly once', () async {
      final session = CoupleSession();
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      container.read(presenceControllerProvider.notifier).updateFromSession(session);

      var notifyCount = 0;
      container.listen(presenceControllerProvider, (prev, next) => notifyCount++);

      await session.updateCurrentActivity('Reading together');
      container.read(presenceControllerProvider.notifier).updateFromSession(session);

      final state = container.read(presenceControllerProvider);
      expect(notifyCount, 1);
      expect(state.yourActivity, 'Reading together');
      expect(state.isPartnerOnline, false);
      expect(state.partnerActivity, isNull);

      // A second call with unchanged fields must not notify again.
      container.read(presenceControllerProvider.notifier).updateFromSession(session);
      expect(notifyCount, 1);
    });
  });

  group('PresenceController write method delegates to CoupleSession', () {
    test('updateCurrentActivity writes through to the live CoupleSession instance', () async {
      final session = CoupleSession();
      await Future.delayed(Duration.zero);
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      await container.read(presenceControllerProvider.notifier).updateCurrentActivity('Making dinner');

      expect(session.yourActivity, 'Making dinner');
    });
  });
}

// Tests for SessionController (Item 3 gap-fix, Phase 3 -- front 4 of the
// architecture migration's `provider`-removal item, unit 5, the last of the
// five hub controllers). Since this unit, the controller mirrors
// CoupleSession's identity/session-lifecycle fields directly and delegates
// its lifecycle methods to the live CoupleSession instance -- see
// session_controller.dart's doc comment for why delegation, not
// reimplementation. Delegation methods that touch real Supabase RPCs
// (joinWithCode's success path, createRelationshipWorkspace, etc.) are
// already covered directly against CoupleSession in couple_session_test.dart
// and pairing_flow_test.dart; this file only needs to confirm each delegate
// forwards to the live instance, not re-prove CoupleSession's own behavior.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/relationship/session_controller.dart';
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

  group('SessionController.updateFromSession mirroring', () {
    test('build() starts as an empty SessionState with defaults', () {
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
      );
      addTearDown(container.dispose);

      final state = container.read(sessionControllerProvider);
      expect(state.isInitialized, false);
      expect(state.userId, isNull);
      expect(state.coupleId, isNull);
      expect(state.partnerId, isNull);
      expect(state.isPaired, false);
      expect(state.isCreator, false);
      expect(state.onboardingCompleted, false);
      expect(state.showPartnerDeletedNotice, false);
      expect(state.isOnboardingComplete, false);
    });

    test('a call with unchanged fields does not notify again', () async {
      final session = CoupleSession();
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      container.read(sessionControllerProvider.notifier).updateFromSession(session);

      var notifyCount = 0;
      container.listen(sessionControllerProvider, (prev, next) => notifyCount++);
      container.read(sessionControllerProvider.notifier).updateFromSession(session);

      expect(notifyCount, 0);
    });

    test('mirrors identity/lifecycle fields and notifies exactly once when they change', () async {
      SharedPreferences.setMockInitialValues({
        'couple_id': 'couple-123',
        'is_paired': true,
        'is_creator': true,
        'onboarding_completed': true,
      });

      final session = CoupleSession();
      await Future.delayed(Duration.zero);
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);
      var notifyCount = 0;
      container.listen(sessionControllerProvider, (prev, next) => notifyCount++);

      container.read(sessionControllerProvider.notifier).updateFromSession(session);

      final state = container.read(sessionControllerProvider);
      expect(notifyCount, 1);
      expect(state.isInitialized, true);
      expect(state.coupleId, 'couple-123');
      expect(state.isPaired, true);
      expect(state.isCreator, true);
      expect(state.onboardingCompleted, true);
      expect(state.isOnboardingComplete, true);

      // A second call with unchanged fields must not notify again.
      container.read(sessionControllerProvider.notifier).updateFromSession(session);
      expect(notifyCount, 1);
    });
  });

  group('SessionController write methods delegate to CoupleSession', () {
    test('forceInitialized writes through to the live CoupleSession instance', () async {
      final session = CoupleSession();
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      container.read(sessionControllerProvider.notifier).forceInitialized();

      expect(session.isInitialized, true);
    });

    test('clearPartnerDeletedNotice writes through to the live CoupleSession instance', () async {
      final session = CoupleSession();
      await Future.delayed(Duration.zero);
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      container.read(sessionControllerProvider.notifier).clearPartnerDeletedNotice();

      expect(session.showPartnerDeletedNotice, false);
    });

    test('unlinkPartner writes through to the live CoupleSession instance', () async {
      final session = CoupleSession();
      await Future.delayed(Duration.zero);
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.notifier).unlinkPartner();

      expect(session.isPaired, false);
    });
  });
}

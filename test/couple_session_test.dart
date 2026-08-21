import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  group('computeSessionStage', () {
    test('not initialized -> loading, regardless of other fields', () {
      final stage = computeSessionStage(
        isInitialized: false,
        userId: 'u1',
        coupleId: 'c1',
        isCreator: true,
        isPaired: true,
        onboardingCompleted: true,
        startDate: DateTime(2024, 1, 1),
      );
      expect(stage, SessionStage.loading);
    });

    test('initialized but signed out -> unauthenticated', () {
      final stage = computeSessionStage(
        isInitialized: true,
        userId: null,
        coupleId: null,
        isCreator: false,
        isPaired: false,
        onboardingCompleted: false,
        startDate: null,
      );
      expect(stage, SessionStage.unauthenticated);
    });

    test('onboarding complete with a couple -> ready', () {
      final stage = computeSessionStage(
        isInitialized: true,
        userId: 'u1',
        coupleId: 'c1',
        isCreator: false,
        isPaired: true,
        onboardingCompleted: true,
        startDate: DateTime(2024, 1, 1),
      );
      expect(stage, SessionStage.ready);
    });

    test('onboardingCompleted true but coupleId null does not count as ready', () {
      final stage = computeSessionStage(
        isInitialized: true,
        userId: 'u1',
        coupleId: null,
        isCreator: false,
        isPaired: false,
        onboardingCompleted: true,
        startDate: null,
      );
      expect(stage, SessionStage.needsCouple);
    });

    test('signed in, no workspace yet -> needsCouple', () {
      final stage = computeSessionStage(
        isInitialized: true,
        userId: 'u1',
        coupleId: null,
        isCreator: false,
        isPaired: false,
        onboardingCompleted: false,
        startDate: null,
      );
      expect(stage, SessionStage.needsCouple);
    });

    test('creator, unpaired, no start date -> needsWorkspace', () {
      final stage = computeSessionStage(
        isInitialized: true,
        userId: 'u1',
        coupleId: 'c1',
        isCreator: true,
        isPaired: false,
        onboardingCompleted: false,
        startDate: null,
      );
      expect(stage, SessionStage.needsWorkspace);
    });

    test('creator, paired, no start date -> needsGenesis', () {
      final stage = computeSessionStage(
        isInitialized: true,
        userId: 'u1',
        coupleId: 'c1',
        isCreator: true,
        isPaired: true,
        onboardingCompleted: false,
        startDate: null,
      );
      expect(stage, SessionStage.needsGenesis);
    });

    test('creator, paired, start date set, onboarding not complete -> needsAvatar', () {
      final stage = computeSessionStage(
        isInitialized: true,
        userId: 'u1',
        coupleId: 'c1',
        isCreator: true,
        isPaired: true,
        onboardingCompleted: false,
        startDate: DateTime(2024, 1, 1),
      );
      expect(stage, SessionStage.needsAvatar);
    });

    test('joiner (not creator) with a workspace -> needsAvatar', () {
      final stage = computeSessionStage(
        isInitialized: true,
        userId: 'u1',
        coupleId: 'c1',
        isCreator: false,
        isPaired: true,
        onboardingCompleted: false,
        startDate: null,
      );
      expect(stage, SessionStage.needsAvatar);
    });
  });

  group('CoupleSession.updateFromRelationship mirroring', () {
    // userId/partnerId/isSupabaseAvailable are only ever populated via the
    // Supabase auth listener (see relationship_provider.dart:388,532), which
    // never runs offline in a unit test (isSupabaseAvailable is false without
    // Supabase.initialize()). These tests exercise the prefs-derived fields
    // instead -- coupleId/isPaired/isCreator/onboardingCompleted -- which is
    // sufficient to prove the notify-only-on-change contract.
    test('a second call with unchanged fields does not notify again', () async {
      final session = CoupleSession();
      final rp = RelationshipProvider();
      await Future.delayed(Duration.zero);

      // First call always notifies at least once: RelationshipProvider's
      // offline early-init path (relationship_provider.dart:305-307) sets
      // isInitialized true once _loadLocalData resolves, which never
      // matches CoupleSession's own false default.
      session.updateFromRelationship(rp);

      var notifyCount = 0;
      session.addListener(() => notifyCount++);
      session.updateFromRelationship(rp);

      expect(notifyCount, 0);
      expect(session.coupleId, isNull);
      expect(session.isPaired, false);
    });

    test('notifies listeners exactly once when identity fields change', () async {
      SharedPreferences.setMockInitialValues({
        'couple_id': 'c1',
        'is_paired': true,
        'is_creator': true,
        'onboarding_completed': true,
      });

      final session = CoupleSession();
      var notifyCount = 0;
      session.addListener(() => notifyCount++);

      final rp = RelationshipProvider();
      await Future.delayed(Duration.zero);
      session.updateFromRelationship(rp);

      expect(notifyCount, 1);
      expect(session.coupleId, 'c1');
      expect(session.isPaired, true);
      expect(session.isCreator, true);
      expect(session.onboardingCompleted, true);

      // A second call with unchanged fields must not notify again.
      session.updateFromRelationship(rp);
      expect(notifyCount, 1);
    });
  });
}

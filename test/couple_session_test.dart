import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Since Phase 6b-1 of the architecture migration ("make CoupleSession
  // real"), CoupleSession owns the engine directly (auth listener,
  // users/couples streams, and every identity/pairing write method). The old
  // RelationshipProvider facade that used to mirror it was deleted once its
  // last direct readers converted to CoupleSession (Definition-of-Done sweep
  // item 4). These tests exercise CoupleSession's own hydration and write
  // paths directly, at the source.
  group('CoupleSession hydration and identity state', () {
    test('hydrates identity fields from SharedPreferences on construction', () async {
      SharedPreferences.setMockInitialValues({
        'couple_id': 'c1',
        'is_paired': true,
        'is_creator': true,
        'onboarding_completed': true,
      });

      final session = CoupleSession();
      await Future.delayed(Duration.zero);

      expect(session.coupleId, 'c1');
      expect(session.isPaired, true);
      expect(session.isCreator, true);
      expect(session.onboardingCompleted, true);
    });

    test('isInitialized becomes true once local hydration resolves offline', () async {
      final session = CoupleSession();
      // Synchronously false: _loadLocalData is still an in-flight Future.
      expect(session.isInitialized, false);

      await Future.delayed(Duration.zero);

      // Offline (no Supabase.initialize() in a unit test), so the
      // "!isSupabaseAvailable" branch marks hydration complete immediately
      // rather than waiting on an auth listener that will never fire.
      expect(session.isInitialized, true);
    });

    test('completeOnboarding sets the flag and persists it', () async {
      final session = CoupleSession();
      await Future.delayed(Duration.zero);

      expect(session.onboardingCompleted, false);

      await session.completeOnboarding();

      expect(session.onboardingCompleted, true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), true);
    });

    test('forceInitialized notifies listeners exactly once when it flips the flag', () {
      final session = CoupleSession();
      var notifyCount = 0;
      session.addListener(() => notifyCount++);

      session.forceInitialized();
      expect(session.isInitialized, true);
      expect(notifyCount, 1);

      // Calling it again with the flag already true must be a no-op.
      session.forceInitialized();
      expect(notifyCount, 1);
    });
  });

  group('license_details schema drift guard', () {
    test('Codebase contains no reference to nonexistent license_details.creator_id', () {
      // Ported from the now-deleted relationship_provider_test.dart when
      // RelationshipProvider was removed (Definition-of-Done sweep item 4)
      // -- that file's own deletion must not silently drop this regression
      // guard, referenced by license_repository.dart's doc comment as the
      // reason `creator_id` is deliberately left unmodeled: no Dart call
      // site reads it, and it must stay that way (server-only column).
      final content = File('lib/providers/couple_session.dart').readAsStringSync();
      expect(content.contains("['creator_id']"), false);
      expect(content.contains("'creator_id'"), false);
      expect(content.contains('"creator_id"'), false);
    });
  });
}

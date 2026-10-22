import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptography/cryptography.dart';
import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/core/security/key_management_service.dart';

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

    test(
      'onboardingCompleted true but coupleId null does not count as ready',
      () {
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
      },
    );

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

    test(
      'creator, paired, start date set, onboarding not complete -> needsAvatar',
      () {
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
      },
    );

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
  group('shouldResubscribePartner', () {
    test('a new partner appearing resubscribes', () {
      expect(
        shouldResubscribePartner(
          oldPartnerId: null,
          newPartnerId: 'p1',
          hasLiveSubscription: false,
        ),
        isTrue,
      );
    });

    test('a partner going away resubscribes, to tear the old one down', () {
      expect(
        shouldResubscribePartner(
          oldPartnerId: 'p1',
          newPartnerId: null,
          hasLiveSubscription: true,
        ),
        isTrue,
      );
    });

    test('a different partner resubscribes', () {
      expect(
        shouldResubscribePartner(
          oldPartnerId: 'p1',
          newPartnerId: 'p2',
          hasLiveSubscription: true,
        ),
        isTrue,
      );
    });

    test('an unchanged partner with no live subscription resubscribes', () {
      // The warm-start regression. _loadLocalData restores partnerId from
      // prefs before any stream resolves (the E2EE key exchange needs it),
      // so the id matches and a bare identity check said "nothing to do" --
      // leaving the partner's users subscription permanently unopened.
      expect(
        shouldResubscribePartner(
          oldPartnerId: 'p1',
          newPartnerId: 'p1',
          hasLiveSubscription: false,
        ),
        isTrue,
        reason: 'a warm start has the id cached but no subscription yet',
      );
    });

    test('an unchanged partner with a live subscription does nothing', () {
      expect(
        shouldResubscribePartner(
          oldPartnerId: 'p1',
          newPartnerId: 'p1',
          hasLiveSubscription: true,
        ),
        isFalse,
        reason: 'every later couple-row update must not churn the stream',
      );
    });

    test('an unpaired session stays quiet', () {
      expect(
        shouldResubscribePartner(
          oldPartnerId: null,
          newPartnerId: null,
          hasLiveSubscription: false,
        ),
        isFalse,
        reason:
            'with no partner there is nothing to subscribe to, so repeated '
            'couple-row updates must not re-run the teardown',
      );
    });
  });

  group('CoupleSession hydration and identity state', () {
    test(
      'hydrates identity fields from SharedPreferences on construction',
      () async {
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
      },
    );

    test('hydrates userId, so identity is known before auth resolves', () async {
      // userId used to be set only by the async Supabase auth listener, while
      // coupleId and partnerId were both mirrored to prefs. That left a window
      // on every cold start where the session was initialized but userId was
      // still null -- computeSessionStage reads that as `unauthenticated`,
      // which could bounce a returning user to the welcome screen until auth
      // caught up, and left anything keyed on the user id with nothing to key
      // on.
      SharedPreferences.setMockInitialValues({
        'user_id': 'u1',
        'couple_id': 'c1',
        'is_paired': true,
        'onboarding_completed': true,
      });

      final session = CoupleSession();
      await Future.delayed(Duration.zero);

      expect(session.userId, 'u1');
      expect(
        computeSessionStage(
          isInitialized: session.isInitialized,
          userId: session.userId,
          coupleId: session.coupleId,
          isCreator: session.isCreator,
          isPaired: session.isPaired,
          onboardingCompleted: session.onboardingCompleted,
          startDate: session.startDate,
        ),
        isNot(SessionStage.unauthenticated),
        reason:
            'a hydrated, onboarded session must not look signed out while '
            'the auth listener is still in flight',
      );
    });

    test('a session with no persisted userId still reports none', () async {
      SharedPreferences.setMockInitialValues({'couple_id': 'c1'});

      final session = CoupleSession();
      await Future.delayed(Duration.zero);

      expect(
        session.userId,
        isNull,
        reason: 'hydration must not invent an identity that was never stored',
      );
    });

    test(
      'isInitialized becomes true once local hydration resolves offline',
      () async {
        final session = CoupleSession();
        // Synchronously false: _loadLocalData is still an in-flight Future.
        expect(session.isInitialized, false);

        await Future.delayed(Duration.zero);

        // Offline (no Supabase.initialize() in a unit test), so the
        // "!isSupabaseAvailable" branch marks hydration complete immediately
        // rather than waiting on an auth listener that will never fire.
        expect(session.isInitialized, true);
      },
    );

    test('completeOnboarding sets the flag and persists it', () async {
      final session = CoupleSession();
      await Future.delayed(Duration.zero);

      expect(session.onboardingCompleted, false);

      await session.completeOnboarding();

      expect(session.onboardingCompleted, true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), true);
    });

    test(
      'forceInitialized notifies listeners exactly once when it flips the flag',
      () {
        final session = CoupleSession();
        var notifyCount = 0;
        session.addListener(() => notifyCount++);

        session.forceInitialized();
        expect(session.isInitialized, true);
        expect(notifyCount, 1);

        // Calling it again with the flag already true must be a no-op.
        session.forceInitialized();
        expect(notifyCount, 1);
      },
    );
  });

  group('license_details schema drift guard', () {
    test(
      'Codebase contains no reference to nonexistent license_details.creator_id',
      () {
        // Ported from the now-deleted relationship_provider_test.dart when
        // RelationshipProvider was removed (Definition-of-Done sweep item 4)
        // -- that file's own deletion must not silently drop this regression
        // guard, referenced by license_repository.dart's doc comment as the
        // reason `creator_id` is deliberately left unmodeled: no Dart call
        // site reads it, and it must stay that way (server-only column).
        final content = File(
          'lib/core/session/couple_session.dart',
        ).readAsStringSync();
        expect(content.contains("['creator_id']"), false);
        expect(content.contains("'creator_id'"), false);
        expect(content.contains('"creator_id"'), false);
      },
    );
  });

  test('offline account deletion preserves the only local photo key', () async {
    SharedPreferences.setMockInitialValues({'user_id': 'user-1'});
    final keys = KeyManagementService.withKeyPair(await X25519().newKeyPair());
    final originalKey = await keys.generateCoupleKey();
    await keys.storeCoupleKey('user-1', originalKey, coupleId: 'couple-1');
    final session = CoupleSession(keyManagementService: keys);
    await Future.delayed(Duration.zero);

    await expectLater(session.deleteAccount(), throwsStateError);
    expect(await keys.loadCoupleKey('user-1'), originalKey);
    expect(session.userId, 'user-1');
  });
}

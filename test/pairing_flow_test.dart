// Item 23 of the Definition-of-Done sweep: pairing/create-workspace flow
// coverage, made possible by injecting a FakeCoupleService into
// CoupleSession (ADR-010's stated exception -- see couple_session.dart's
// constructor doc comment).
//
// Scope note: joinWithCode's actual call to CoupleService.joinWithCode() is
// gated behind `isSupabaseAvailable && _userId != null` -- and `_userId` is
// a private field only ever set from the real Supabase auth-state listener,
// with no test seam to set it directly. That gate can't be satisfied from a
// unit test without either calling the real Supabase.initialize() (which
// this whole suite deliberately avoids -- see e.g. license_controller_test
// .dart's "no network" note) or adding a new auth-state test hook, neither
// of which was part of the approved item-23 scope. So the "successful
// join"/"rejected join via the service" scenarios described in the original
// plan are NOT reachable and are not tested here; what IS reachable and
// covered below is the malformed-code short-circuit (never reaches the
// service at all) and the re-entrancy guard. createRelationshipWorkspace has
// no such gate -- it calls the service unconditionally -- so its success and
// re-entrancy paths are both fully covered.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptography/cryptography.dart';
import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/core/security/key_management_service.dart';

import 'fake_couple_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // createRelationshipWorkspace/joinWithCode/recoverRelationship all touch
  // KeyManagementService for E2EE photo encryption's key exchange (posting a
  // public key, and -- for create -- minting/storing the couple photo key).
  // KeyManagementService.withKeyPair bypasses FlutterSecureStorage entirely
  // (no platform channel in a plain unit test).
  late KeyManagementService fakeKeyManagementService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => '.',
        );
    fakeKeyManagementService = KeyManagementService.withKeyPair(
      await X25519().newKeyPair(),
    );
  });

  group('CoupleSession.createRelationshipWorkspace', () {
    test(
      'a successful call sets coupleId/coupleCode/recoveryCode/isCreator and moves the stage forward',
      () async {
        final fake = FakeCoupleService();
        fake.createWorkspaceResponse = {
          'couple_id': 'couple-123',
          'pairing_code': 'ABC123',
          'recovery_code': 'REC-XYZ',
        };
        final session = CoupleSession(
          coupleService: fake,
          keyManagementService: fakeKeyManagementService,
        );
        await Future.delayed(Duration.zero);

        final stageBefore = computeSessionStage(
          isInitialized: true,
          userId: 'user-1',
          coupleId: session.coupleId,
          isCreator: session.isCreator,
          isPaired: session.isPaired,
          onboardingCompleted: session.onboardingCompleted,
          startDate: session.startDate,
        );
        expect(stageBefore, SessionStage.needsCouple);

        await session.createRelationshipWorkspace();

        expect(session.coupleId, 'couple-123');
        expect(session.coupleCode, 'ABC123');
        expect(session.recoveryCode, 'REC-XYZ');
        expect(session.isCreator, true);
        expect(session.isPaired, false);
        expect(session.onboardingCompleted, false);
        expect(session.status, RelationshipStatus.waiting);
        expect(fake.createWorkspaceCallCount, 1);

        final stageAfter = computeSessionStage(
          isInitialized: true,
          userId: 'user-1',
          coupleId: session.coupleId,
          isCreator: session.isCreator,
          isPaired: session.isPaired,
          onboardingCompleted: session.onboardingCompleted,
          startDate: session.startDate,
        );
        expect(stageAfter, SessionStage.needsWorkspace);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('couple_id'), 'couple-123');
        expect(prefs.getString('couple_code'), 'ABC123');
        expect(prefs.getBool('is_creator'), true);
      },
    );

    test(
      'a failure rethrows and leaves _isGeneratingCode reset for the next attempt',
      () async {
        final fake = FakeCoupleService();
        fake.createWorkspaceError = Exception('rpc unreachable');
        final session = CoupleSession(
          coupleService: fake,
          keyManagementService: fakeKeyManagementService,
        );
        await Future.delayed(Duration.zero);

        await expectLater(
          session.createRelationshipWorkspace(),
          throwsA(isA<Exception>()),
        );
        expect(session.coupleId, isNull);

        // The finally block must have cleared the in-flight guard, so a
        // second attempt is not silently swallowed as a no-op.
        fake.createWorkspaceError = null;
        fake.createWorkspaceResponse = {
          'couple_id': 'couple-456',
          'pairing_code': 'DEF456',
          'recovery_code': 'REC-2',
        };
        await session.createRelationshipWorkspace();
        expect(session.coupleId, 'couple-456');
        expect(fake.createWorkspaceCallCount, 2);
      },
    );

    test(
      're-entrant calls while a request is already in flight are no-ops',
      () async {
        final fake = FakeCoupleService();
        fake.createWorkspaceResponse = {
          'couple_id': 'couple-789',
          'pairing_code': 'GHI789',
          'recovery_code': 'REC-3',
        };
        final session = CoupleSession(
          coupleService: fake,
          keyManagementService: fakeKeyManagementService,
        );
        await Future.delayed(Duration.zero);

        // CoupleSession.createRelationshipWorkspace sets its in-flight guard
        // synchronously before its first await, so calling it twice back to
        // back without awaiting the first exercises the re-entrancy guard.
        final first = session.createRelationshipWorkspace();
        final second = session.createRelationshipWorkspace();
        await Future.wait([first, second]);

        expect(fake.createWorkspaceCallCount, 1);
        expect(session.coupleId, 'couple-789');
      },
    );
  });

  group('CoupleSession.joinWithCode', () {
    test(
      'rejects a malformed code without calling the service at all',
      () async {
        final fake = FakeCoupleService();
        final session = CoupleSession(
          coupleService: fake,
          keyManagementService: fakeKeyManagementService,
        );
        await Future.delayed(Duration.zero);

        final result = await session.joinWithCode('TOOSHORT-NOT-6-CHARS');

        expect(result, false);
        expect(fake.joinWithCodeCallCount, 0);
        expect(session.coupleId, isNull);
        expect(session.isPaired, false);
      },
    );

    test('an empty code is rejected the same way', () async {
      final fake = FakeCoupleService();
      final session = CoupleSession(
        coupleService: fake,
        keyManagementService: fakeKeyManagementService,
      );
      await Future.delayed(Duration.zero);

      final result = await session.joinWithCode('');

      expect(result, false);
      expect(fake.joinWithCodeCallCount, 0);
    });

    test(
      're-entrant calls while a join is already in flight are no-ops',
      () async {
        final fake = FakeCoupleService();
        final session = CoupleSession(
          coupleService: fake,
          keyManagementService: fakeKeyManagementService,
        );
        await Future.delayed(Duration.zero);

        // Offline (no Supabase), both calls return false regardless of
        // re-entrancy, so that return value alone can't prove the guard
        // fired. Using two *different* valid-length codes makes the guard
        // observable instead: CoupleSession.joinWithCode sets _isJoining
        // synchronously before its first await, so the second call below
        // (issued before the first has a chance to resume) must see the
        // guard already tripped and return before ever touching
        // _coupleCode -- if it didn't, session.coupleCode would end up as
        // the second call's code instead of the first's.
        final first = session.joinWithCode('ABCDEF');
        final second = session.joinWithCode('ZYXWVU');
        await Future.wait([first, second]);

        expect(session.coupleCode, 'ABCDEF');
        expect(fake.joinWithCodeCallCount, 0);
      },
    );
  });

  group('8-character pairing codes (20261003000200_harden_pairing)', () {
    test('isPlausiblePairingCode accepts 8 (and transitional 6) chars', () {
      expect(isPlausiblePairingCode('AB12CD34'), isTrue);
      expect(isPlausiblePairingCode('ABC123'), isTrue);
      expect(isPlausiblePairingCode('ABC12'), isFalse);
      expect(isPlausiblePairingCode('ABCD12345'), isFalse);
      expect(isPlausiblePairingCode('AB12-D34'), isFalse);
      expect(isPlausiblePairingCode(''), isFalse);
    });

    test(
      'joinWithCode lets an 8-character code through the client gate',
      () async {
        final session = CoupleSession(
          coupleService: FakeCoupleService(),
          keyManagementService: fakeKeyManagementService,
        );
        await Future.delayed(Duration.zero);

        // coupleCode is recorded only after the format gate passes, so it is
        // the observable proof the code was accepted (the RPC itself is
        // unreachable offline -- see this file's scope note).
        await session.joinWithCode(' ab12cd34 ');
        expect(session.coupleCode, 'AB12CD34');
      },
    );

    test('a too-short code still never reaches the session', () async {
      final session = CoupleSession(
        coupleService: FakeCoupleService(),
        keyManagementService: fakeKeyManagementService,
      );
      await Future.delayed(Duration.zero);

      expect(await session.joinWithCode('AB12C'), false);
      expect(session.coupleCode, isNull);
    });
  });

  group('pairingFailureMessage maps the RPC error_code', () {
    test('every stable code gets its own user-facing message', () {
      final messages = {
        for (final code in [
          'INVALID_CODE',
          'CODE_EXPIRED',
          'ALREADY_PAIRED',
          'INVALID_SESSION',
          'RATE_LIMITED',
        ])
          code: pairingFailureMessage({'success': false, 'error_code': code}),
      };
      expect(messages.values.toSet(), hasLength(5));
      expect(messages['INVALID_CODE'], contains('couldn\'t find'));
      expect(messages['CODE_EXPIRED'], contains('expired'));
      expect(messages['ALREADY_PAIRED'], contains('already connected'));
      expect(messages['INVALID_SESSION'], contains('sign in again'));
    });

    test('RATE_LIMITED reports the remaining lockout in minutes', () {
      final now = DateTime.utc(2026, 10, 3, 12);
      final message = pairingFailureMessage({
        'success': false,
        'error_code': 'RATE_LIMITED',
        'retry_after': now
            .add(const Duration(minutes: 4, seconds: 10))
            .toIso8601String(),
      }, now: now);
      expect(message, 'Too many attempts. Please try again in 5 minutes.');
    });

    test(
      'ignores the server\'s free-text "error" field (no raw DB text in the UI)',
      () {
        final message = pairingFailureMessage({
          'success': false,
          'error_code': 'SOMETHING_NEW',
          'error': 'P0001: internal detail',
        });
        expect(message, 'Pairing failed. Please try again.');
      },
    );
  });

  group('CoupleSession.recoverRelationship', () {
    test('keeps invalid codes as a normal failed result', () async {
      final fake = FakeCoupleService()
        ..recoverWithCodeResponse = {
          'success': false,
          'error_code': 'INVALID_CODE',
        };
      final session = CoupleSession(
        coupleService: fake,
        keyManagementService: fakeKeyManagementService,
      );
      await Future.delayed(Duration.zero);

      expect(await session.recoverRelationship('WRONG-CODE'), false);
      expect(session.coupleId, isNull);
    });

    test(
      'reports a persisted lockout without claiming the code is invalid',
      () async {
        final fake = FakeCoupleService()
          ..recoverWithCodeResponse = {
            'success': false,
            'error_code': 'USER_LOCKED',
            'retry_after': DateTime.now()
                .add(const Duration(minutes: 5))
                .toUtc()
                .toIso8601String(),
          };
        final session = CoupleSession(
          coupleService: fake,
          keyManagementService: fakeKeyManagementService,
        );
        await Future.delayed(Duration.zero);

        await expectLater(
          session.recoverRelationship('WRONG-CODE'),
          throwsA(
            predicate(
              (error) =>
                  error.toString().contains('Too many recovery attempts'),
            ),
          ),
        );
        expect(session.coupleId, isNull);
      },
    );
  });
}

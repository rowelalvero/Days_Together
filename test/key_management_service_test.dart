import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/services/key_management_service.dart';

/// Covers the ECDH+HKDF+AES-GCM key-wrapping logic via
/// [KeyManagementService.withKeyPair], which pre-seeds the keypair cache and
/// so never touches FlutterSecureStorage -- there's no platform channel in a
/// plain unit test (see vault_controller_test.dart for the same constraint).
///
/// The per-user storage/cache scoping group below is the regression test for
/// a real bug found during the mandatory two-device manual test: testing two
/// accounts back-to-back on one device, with storage keyed by a fixed name
/// instead of the signed-in user's id, silently handed the second account
/// the first account's keypair -- both posted the identical public key, and
/// every wrap/unwrap after that used a degenerate self-ECDH. That group
/// mocks the FlutterSecureStorage platform channel (an in-memory backing
/// map) specifically to exercise `KeyManagementService.instance`'s real
/// storage path, not the `withKeyPair` bypass used everywhere else in this
/// file.
void main() {
  Future<SimpleKeyPair> newKeyPair() => X25519().newKeyPair();

  group('getOrCreatePublicKeyBase64', () {
    test('returns a stable 32-byte X25519 public key for a seeded keypair', () async {
      final keyPair = await newKeyPair();
      final service = KeyManagementService.withKeyPair(keyPair);

      final first = await service.getOrCreatePublicKeyBase64('user');
      final second = await service.getOrCreatePublicKeyBase64('user');

      expect(first, second);
      expect(base64Decode(first).length, 32);
    });

    test('two independently generated keypairs have different public keys', () async {
      final serviceA = KeyManagementService.withKeyPair(await newKeyPair());
      final serviceB = KeyManagementService.withKeyPair(await newKeyPair());

      expect(
        await serviceA.getOrCreatePublicKeyBase64('user'),
        isNot(await serviceB.getOrCreatePublicKeyBase64('user')),
      );
    });
  });

  group('wrapKeyForPartner / unwrapKeyFromPartner', () {
    test('ECDH round trip: partner unwraps exactly what was wrapped for them', () async {
      final alice = KeyManagementService.withKeyPair(await newKeyPair());
      final bob = KeyManagementService.withKeyPair(await newKeyPair());

      final alicePublicKey = await alice.getOrCreatePublicKeyBase64('user');
      final bobPublicKey = await bob.getOrCreatePublicKeyBase64('user');

      final coupleKey = Uint8List.fromList(List.generate(32, (i) => i));

      // Alice wraps the couple key for Bob using Bob's public key.
      final wrapped = await alice.wrapKeyForPartner(
        userId: 'alice',
        coupleKeyBytes: coupleKey,
        partnerPublicKeyBase64: bobPublicKey,
      );

      // Bob unwraps it using Alice's public key -- ECDH guarantees both sides
      // land on the same shared secret regardless of which side computes it.
      final unwrapped = await bob.unwrapKeyFromPartner(
        userId: 'bob',
        wrappedKeyBase64: wrapped,
        partnerPublicKeyBase64: alicePublicKey,
      );

      expect(unwrapped, coupleKey);
    });

    test('a third party cannot unwrap a key not wrapped for them', () async {
      final alice = KeyManagementService.withKeyPair(await newKeyPair());
      final bob = KeyManagementService.withKeyPair(await newKeyPair());
      final mallory = KeyManagementService.withKeyPair(await newKeyPair());

      final bobPublicKey = await bob.getOrCreatePublicKeyBase64('user');
      final malloryPublicKey = await mallory.getOrCreatePublicKeyBase64('user');

      final wrapped = await alice.wrapKeyForPartner(
        userId: 'alice',
        coupleKeyBytes: Uint8List.fromList(List.filled(32, 7)),
        partnerPublicKeyBase64: bobPublicKey,
      );

      // Mallory tries to unwrap using her own public key in place of Bob's --
      // she derives a different shared secret/KEK, so the AES-GCM tag check
      // must fail rather than silently returning garbage plaintext.
      expect(
        () => mallory.unwrapKeyFromPartner(
          userId: 'mallory',
          wrappedKeyBase64: wrapped,
          partnerPublicKeyBase64: malloryPublicKey,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });

  group('generateCoupleKey', () {
    test('returns a random 32-byte key, different every call', () async {
      final service = KeyManagementService.withKeyPair(await newKeyPair());

      final keyA = await service.generateCoupleKey();
      final keyB = await service.generateCoupleKey();

      expect(keyA.length, 32);
      expect(keyB.length, 32);
      expect(keyA, isNot(keyB));
    });
  });

  group('KeyManagementService.instance -- per-user storage scoping', () {
    final backing = <String, String>{};

    Future<dynamic> fakeSecureStorageHandler(MethodCall call) async {
      final args = call.arguments as Map<Object?, Object?>;
      switch (call.method) {
        case 'read':
          return backing[args['key'] as String];
        case 'write':
          backing[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          backing.remove(args['key'] as String);
          return null;
        default:
          return null;
      }
    }

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      backing.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        fakeSecureStorageHandler,
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      );
    });

    test('two different signed-in users on the same device get independent keypairs', () async {
      final service = KeyManagementService.instance;

      final aliceKey = await service.getOrCreatePublicKeyBase64('user-alice');
      final bobKey = await service.getOrCreatePublicKeyBase64('user-bob');

      // This is the exact bug found on-device: without per-user scoping (in
      // both the in-memory cache and the secure-storage key name), the
      // second call would silently return the first user's already-cached
      // keypair instead of generating/loading a distinct one.
      expect(aliceKey, isNot(bobKey));

      // Calling again for the same user returns the same key (persisted and
      // cached, not regenerated every time).
      expect(await service.getOrCreatePublicKeyBase64('user-alice'), aliceKey);
      expect(await service.getOrCreatePublicKeyBase64('user-bob'), bobKey);
    });

    test('couple key storage is also isolated per user', () async {
      final service = KeyManagementService.instance;
      final keyForAlice = Uint8List.fromList(List.filled(32, 1));
      final keyForBob = Uint8List.fromList(List.filled(32, 2));

      await service.storeCoupleKey('user-alice', keyForAlice);
      await service.storeCoupleKey('user-bob', keyForBob);

      expect(await service.loadCoupleKey('user-alice'), keyForAlice);
      expect(await service.loadCoupleKey('user-bob'), keyForBob);
    });
  });
}

// Partner public-key pinning and the safety number (re-audit R-03 / audit
// F-14).
//
// The couple photo key used to be wrapped for whatever public key the server
// returned for the partner -- so anyone able to rewrite users.public_key
// (including the project's service_role, the adversary E2EE exists to
// exclude) could substitute their own key and receive the couple key. These
// tests use REAL X25519 keypairs and the real wrap/unwrap code; only the two
// Supabase touchpoints (reading the partner's public key, storing a wrapped
// key) are faked.

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:days_together/core/security/key_management_service.dart';
import 'package:days_together/core/session/couple_key_exchange.dart';

const _me = 'user-me';
const _partner = 'user-partner';
const _couple = 'couple-1';

Future<String> _publicKeyOf(SimpleKeyPair pair) async =>
    base64Encode((await pair.extractPublicKey()).bytes);

/// One device's side of the exchange, wired to a fake "server": the
/// partner's current public key, and the wrapped keys stored for them.
class _Device {
  _Device(this.keys, {required this.serverPartnerKey});

  final KeyManagementService keys;
  String? serverPartnerKey;
  final List<String> storedWraps = [];
  final List<String> keyChangeEvents = [];

  late final CoupleKeyExchange exchange = newExchange();

  /// A fresh exchange over the SAME key storage -- i.e. an app restart.
  CoupleKeyExchange newExchange() => CoupleKeyExchange(
    identity: () => (userId: _me, partnerId: _partner, coupleId: _couple),
    keyManagementService: keys,
    loadPartnerPublicKey: (_) async => serverPartnerKey,
    storeWrappedKey: (_, wrapped) async => storedWraps.add(wrapped),
    onPartnerKeyChanged: keyChangeEvents.add,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SimpleKeyPair myPair;
  late SimpleKeyPair partnerPair;
  late SimpleKeyPair attackerPair;
  late String partnerPub;
  late String attackerPub;
  late Uint8List coupleKey;

  setUp(() async {
    myPair = await X25519().newKeyPair();
    partnerPair = await X25519().newKeyPair();
    attackerPair = await X25519().newKeyPair();
    partnerPub = await _publicKeyOf(partnerPair);
    attackerPub = await _publicKeyOf(attackerPair);
    coupleKey = await KeyManagementService.withKeyPair(
      myPair,
    ).generateCoupleKey();
  });

  group('sending side: wrapForPartnerIfHeld', () {
    test('first use pins the partner key and wraps for it', () async {
      final keys = KeyManagementService.withKeyPair(myPair);
      await keys.storeCoupleKey(_me, coupleKey, coupleId: _couple);
      final device = _Device(keys, serverPartnerKey: partnerPub);

      await device.exchange.wrapForPartnerIfHeld(_partner);

      expect(device.storedWraps, hasLength(1));
      expect(
        await keys.pinnedPartnerKey(
          userId: _me,
          coupleId: _couple,
          partnerId: _partner,
        ),
        partnerPub,
      );
      // The genuine partner can unwrap it.
      final unwrapped = await KeyManagementService.withKeyPair(partnerPair)
          .unwrapKeyFromPartner(
            userId: _partner,
            wrappedKeyBase64: device.storedWraps.single,
            partnerPublicKeyBase64: await _publicKeyOf(myPair),
          );
      expect(unwrapped, coupleKey);
    });

    test(
      'a substituted key is refused: nothing is wrapped, the user is told',
      () async {
        final keys = KeyManagementService.withKeyPair(myPair);
        await keys.storeCoupleKey(_me, coupleKey, coupleId: _couple);
        final device = _Device(keys, serverPartnerKey: partnerPub);
        await device.exchange.wrapForPartnerIfHeld(_partner);

        // The server now presents a different key for the same partner; the
        // app restarts and re-observes the partner.
        device.serverPartnerKey = attackerPub;
        final restarted = device.newExchange();
        await restarted.wrapForPartnerIfHeld(_partner);

        expect(
          device.storedWraps,
          hasLength(1),
          reason: 'no wrap for attacker',
        );
        expect(device.keyChangeEvents, [_partner]);
        expect(restarted.partnerKeyChangedFor, _partner);
        expect(
          await keys.pinnedPartnerKey(
            userId: _me,
            coupleId: _couple,
            partnerId: _partner,
          ),
          partnerPub,
          reason: 'the pin is not silently replaced',
        );
      },
    );

    test('accepting the change re-pins and resumes wrapping', () async {
      final keys = KeyManagementService.withKeyPair(myPair);
      await keys.storeCoupleKey(_me, coupleKey, coupleId: _couple);
      final device = _Device(keys, serverPartnerKey: partnerPub);
      await device.exchange.wrapForPartnerIfHeld(_partner);

      // A legitimate change: the partner's new phone.
      final newPhone = await X25519().newKeyPair();
      device.serverPartnerKey = await _publicKeyOf(newPhone);
      final restarted = device.newExchange();
      await restarted.wrapForPartnerIfHeld(_partner);
      expect(device.storedWraps, hasLength(1));

      await restarted.acceptPartnerKey(_partner);

      expect(restarted.partnerKeyChangedFor, isNull);
      expect(device.storedWraps, hasLength(2));
      final unwrapped = await KeyManagementService.withKeyPair(newPhone)
          .unwrapKeyFromPartner(
            userId: _partner,
            wrappedKeyBase64: device.storedWraps.last,
            partnerPublicKeyBase64: await _publicKeyOf(myPair),
          );
      expect(unwrapped, coupleKey);
    });
  });

  group('receiving side: applying a wrapped key', () {
    Future<String> wrappedBy(SimpleKeyPair sender) async =>
        KeyManagementService.withKeyPair(sender).wrapKeyForPartner(
          userId: 'sender',
          coupleKeyBytes: coupleKey,
          partnerPublicKeyBase64: await _publicKeyOf(myPair),
        );

    test('a key wrapped by the pinned partner is applied', () async {
      final keys = KeyManagementService.withKeyPair(myPair);
      final device = _Device(keys, serverPartnerKey: partnerPub);

      await device.exchange.handleRowsForTest(_me, [
        {'couple_id': _couple, 'wrapped_key': await wrappedBy(partnerPair)},
      ]);

      expect(await keys.loadCoupleKey(_me), coupleKey);
    });

    test(
      'after a key substitution, a key wrapped by the impostor is NOT applied',
      () async {
        final keys = KeyManagementService.withKeyPair(myPair);
        // Pin the genuine partner first (an earlier, legitimate exchange).
        await keys.checkPartnerKey(
          userId: _me,
          coupleId: _couple,
          partnerId: _partner,
          publicKeyBase64: partnerPub,
        );
        final device = _Device(keys, serverPartnerKey: attackerPub);

        await device.exchange.handleRowsForTest(_me, [
          {'couple_id': _couple, 'wrapped_key': await wrappedBy(attackerPair)},
        ]);

        expect(await keys.loadCoupleKey(_me), isNull);
        expect(device.keyChangeEvents, [_partner]);
      },
    );
  });

  group('safety number', () {
    test('is symmetric, so both phones show the same number', () async {
      final mine = await _publicKeyOf(myPair);
      expect(
        await KeyManagementService.safetyNumber(mine, partnerPub),
        await KeyManagementService.safetyNumber(partnerPub, mine),
      );
    });

    test('is six groups of five digits', () async {
      final number = await KeyManagementService.safetyNumber(
        await _publicKeyOf(myPair),
        partnerPub,
      );
      expect(number, matches(RegExp(r'^\d{5}( \d{5}){5}$')));
    });

    test('changes when either key is substituted', () async {
      final mine = await _publicKeyOf(myPair);
      final genuine = await KeyManagementService.safetyNumber(mine, partnerPub);
      final swapped = await KeyManagementService.safetyNumber(
        mine,
        attackerPub,
      );
      expect(swapped, isNot(genuine));
    });
  });

  group('pins in real secure storage', () {
    final backing = <String, String>{};
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );

    setUp(() {
      backing.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = call.arguments as Map<Object?, Object?>;
            final key = args['key'] as String?;
            switch (call.method) {
              case 'read':
                return backing[key];
              case 'write':
                backing[key!] = args['value'] as String;
                return null;
              case 'delete':
                backing.remove(key);
                return null;
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('pin, match, detect change, accept -- and per-user scoping', () async {
      final keys = KeyManagementService.instance;
      Future<PartnerKeyTrust> check(String user, String key) =>
          keys.checkPartnerKey(
            userId: user,
            coupleId: _couple,
            partnerId: _partner,
            publicKeyBase64: key,
          );

      expect(await check(_me, partnerPub), PartnerKeyTrust.pinnedNow);
      expect(await check(_me, partnerPub), PartnerKeyTrust.matchesPin);
      expect(await check(_me, attackerPub), PartnerKeyTrust.changed);
      // Another account on the same device has its own pins.
      expect(
        await check('someone-else', attackerPub),
        PartnerKeyTrust.pinnedNow,
      );

      await keys.acceptPartnerKey(
        userId: _me,
        coupleId: _couple,
        partnerId: _partner,
        publicKeyBase64: attackerPub,
      );
      expect(await check(_me, attackerPub), PartnerKeyTrust.matchesPin);

      await keys.clearAllKeysForUser(_me);
      expect(await check(_me, partnerPub), PartnerKeyTrust.pinnedNow);
    });
  });
}

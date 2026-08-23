import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Generates, stores, and uses this device's X25519 keypair to share the
/// couple's AES photo-encryption key with a partner device via ECDH + HKDF +
/// AES-GCM key wrapping -- so the wrapped key stored on the server is only
/// ever usable by the one device whose public key it was wrapped for.
///
/// The private key and the couple's photo key both live only in
/// [FlutterSecureStorage], deliberately with no fallback to SharedPreferences
/// (unlike `VaultController`'s PIN storage): a plaintext-readable fallback
/// would defeat the entire point of end-to-end photo encryption.
///
/// Every method takes the currently signed-in user's id explicitly and scopes
/// both the persistent storage key *and* the in-memory keypair cache by it.
/// This class deliberately stays Supabase-free (see the class-level design
/// note in the photo-encryption plan), so it cannot read "who is signed in"
/// itself -- callers (`CoupleSession`, or a direct `auth.currentUser?.id`
/// read in `EncryptedStorageService`/`storage_image.dart`) already know this.
/// Without per-user scoping, testing two accounts back-to-back on the same
/// device/app-process would silently hand the second account the first
/// account's keypair (same in-memory cache, same storage key) -- which is
/// exactly the bug this scoping fixes: two accounts ended up posting the
/// identical public key, and every wrap/unwrap after that used a degenerate
/// self-ECDH instead of a genuine two-party one.
class KeyManagementService {
  KeyManagementService._() : _bypassSecureStorage = false;

  static final KeyManagementService instance = KeyManagementService._();

  /// Test-only seam: bypasses [FlutterSecureStorage] entirely -- both for the
  /// keypair (pre-seeded) and for [storeCoupleKey]/[loadCoupleKey] (kept in
  /// memory instead), and ignores the `userId` scoping entirely -- so the
  /// ECDH+HKDF+AES-GCM wrap/unwrap logic, and anything built on top of it
  /// (e.g. `CoupleSession`'s pairing flow), can be unit-tested without a
  /// platform channel (a plain `flutter test` has none -- see
  /// `vault_controller_test.dart` for the same constraint).
  @visibleForTesting
  KeyManagementService.withKeyPair(SimpleKeyPair keyPair)
    : _cachedKeyPair = keyPair,
      _bypassSecureStorage = true;

  static const _secureStorage = FlutterSecureStorage();

  static String _privateKeyStorageKeyFor(String userId) => 'e2ee_x25519_private_key_$userId';
  static String _coupleKeyStorageKeyFor(String userId) => 'e2ee_couple_photo_key_$userId';

  static final X25519 _keyExchangeAlgorithm = X25519();
  static final AesGcm _aesGcm = AesGcm.with256bits();

  // Domain separation for the HKDF-derived key-encryption-key -- see RFC
  // 5869's "info" parameter. Bumping this value invalidates all previously
  // wrapped keys, so it must never change once shipped.
  static final List<int> _wrapInfo = utf8.encode(
    'days_together.couple_photo_key.v1',
  );

  final bool _bypassSecureStorage;
  SimpleKeyPair? _cachedKeyPair;
  String? _cachedKeyPairUserId;
  Uint8List? _testCoupleKey;

  Future<SimpleKeyPair> _loadOrCreateKeyPair(String userId) async {
    if (_bypassSecureStorage) return _cachedKeyPair!;

    if (_cachedKeyPair != null && _cachedKeyPairUserId == userId) {
      return _cachedKeyPair!;
    }

    final storageKey = _privateKeyStorageKeyFor(userId);
    final storedBase64 = await _secureStorage.read(key: storageKey);
    if (storedBase64 != null) {
      final seed = base64Decode(storedBase64);
      final keyPair = await _keyExchangeAlgorithm.newKeyPairFromSeed(seed);
      _cachedKeyPair = keyPair;
      _cachedKeyPairUserId = userId;
      return keyPair;
    }

    final keyPair = await _keyExchangeAlgorithm.newKeyPair();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    await _secureStorage.write(
      key: storageKey,
      value: base64Encode(privateKeyBytes),
    );
    _cachedKeyPair = keyPair;
    _cachedKeyPairUserId = userId;
    return keyPair;
  }

  /// Returns [userId]'s X25519 public key (base64), generating a keypair on
  /// first call if one doesn't exist yet. Safe to post to `users.public_key`
  /// -- it is not secret.
  Future<String> getOrCreatePublicKeyBase64(String userId) async {
    final keyPair = await _loadOrCreateKeyPair(userId);
    final publicKey = await keyPair.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  Future<SecretKey> _deriveKek(String userId, String remotePublicKeyBase64) async {
    final keyPair = await _loadOrCreateKeyPair(userId);
    final remotePublicKey = SimplePublicKey(
      base64Decode(remotePublicKeyBase64),
      type: KeyPairType.x25519,
    );
    // ECDH: both sides compute this same shared secret independently, from
    // (their own private key + the other's public key) -- no need to
    // encrypt "for" a specific recipient the way RSA would.
    final sharedSecret = await _keyExchangeAlgorithm.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: remotePublicKey,
    );
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(secretKey: sharedSecret, info: _wrapInfo);
  }

  /// Wraps [coupleKeyBytes] -- using [userId]'s own keypair -- so only the
  /// holder of the private key matching [partnerPublicKeyBase64] can unwrap
  /// it.
  Future<String> wrapKeyForPartner({
    required String userId,
    required Uint8List coupleKeyBytes,
    required String partnerPublicKeyBase64,
  }) async {
    final kek = await _deriveKek(userId, partnerPublicKeyBase64);
    final secretBox = await _aesGcm.encrypt(coupleKeyBytes, secretKey: kek);
    return base64Encode(secretBox.concatenation());
  }

  /// Reverses [wrapKeyForPartner], using [userId]'s own keypair.
  /// [partnerPublicKeyBase64] is the *other* party's public key -- ECDH
  /// guarantees the derived KEK is identical regardless of which side
  /// computes it.
  Future<Uint8List> unwrapKeyFromPartner({
    required String userId,
    required String wrappedKeyBase64,
    required String partnerPublicKeyBase64,
  }) async {
    final kek = await _deriveKek(userId, partnerPublicKeyBase64);
    final secretBox = SecretBox.fromConcatenation(
      base64Decode(wrappedKeyBase64),
      nonceLength: AesGcm.defaultNonceLength,
      macLength: AesGcm.aesGcmMac.macLength,
    );
    final clearText = await _aesGcm.decrypt(secretBox, secretKey: kek);
    return Uint8List.fromList(clearText);
  }

  /// Generates a fresh random 256-bit AES key for encrypting the couple's
  /// photos. Call exactly once, on the workspace creator's device.
  Future<Uint8List> generateCoupleKey() async {
    final secretKey = await _aesGcm.newSecretKey();
    return Uint8List.fromList(await secretKey.extractBytes());
  }

  Future<void> storeCoupleKey(String userId, Uint8List coupleKeyBytes) {
    if (_bypassSecureStorage) {
      _testCoupleKey = coupleKeyBytes;
      return Future.value();
    }
    return _secureStorage.write(
      key: _coupleKeyStorageKeyFor(userId),
      value: base64Encode(coupleKeyBytes),
    );
  }

  Future<Uint8List?> loadCoupleKey(String userId) async {
    if (_bypassSecureStorage) return _testCoupleKey;
    final storedBase64 = await _secureStorage.read(key: _coupleKeyStorageKeyFor(userId));
    if (storedBase64 == null) return null;
    return base64Decode(storedBase64);
  }
}

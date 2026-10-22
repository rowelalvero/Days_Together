import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show compute;

/// Encrypts/decrypts photo bytes with AES-256-GCM using the couple's shared
/// photo-encryption key (see `KeyManagementService` for how that key itself
/// is generated and shared between partner devices).
///
/// Each photo gets a fresh random 12-byte nonce, prepended to the
/// ciphertext+tag via [SecretBox.concatenation] -- the couple key is reused
/// across every photo, but nonce reuse under a fixed key is what would break
/// AES-GCM's guarantees, and a fresh random nonce per encryption avoids that.
class PhotoEncryptionService {
  PhotoEncryptionService._();

  static final PhotoEncryptionService instance = PhotoEncryptionService._();

  /// Payloads at or above this size are encrypted/decrypted in a separate
  /// isolate (via [compute]) so a multi-hundred-KB photo doesn't block the
  /// UI thread; smaller payloads run inline to avoid isolate-spawn overhead.
  static const int _isolateThresholdBytes = 32 * 1024;

  Future<Uint8List> encryptBytes(
    Uint8List plaintext,
    Uint8List coupleKeyBytes,
  ) {
    final args = [plaintext, coupleKeyBytes];
    if (plaintext.length >= _isolateThresholdBytes) {
      return compute(_encryptPayload, args);
    }
    return _encryptPayload(args);
  }

  /// Decrypts [ciphertext] with [coupleKeyBytes]. Throws if [ciphertext]
  /// isn't a valid AES-GCM box for this key (wrong key, corrupted data, or --
  /// notably -- a legacy pre-encryption plaintext photo). Callers that need
  /// to render legacy plaintext photos should use [tryDecryptBytes] instead.
  Future<Uint8List> decryptBytes(
    Uint8List ciphertext,
    Uint8List coupleKeyBytes,
  ) {
    final args = [ciphertext, coupleKeyBytes];
    if (ciphertext.length >= _isolateThresholdBytes) {
      return compute(_decryptPayload, args);
    }
    return _decryptPayload(args);
  }

  /// Like [decryptBytes], but falls back to returning [ciphertext] unchanged
  /// if decryption fails -- the display path's way of supporting photos that
  /// were uploaded before this feature existed and were never encrypted.
  Future<Uint8List> tryDecryptBytes(
    Uint8List ciphertext,
    Uint8List coupleKeyBytes,
  ) async {
    try {
      return await decryptBytes(ciphertext, coupleKeyBytes);
    } catch (_) {
      return ciphertext;
    }
  }
}

// Top-level so `compute()` can run these in a separate isolate. Args are
// `[dataBytes, coupleKeyBytes]`, both `Uint8List` -- kept as a plain list
// rather than a custom class so isolate message-passing is unambiguous.

Future<Uint8List> _encryptPayload(List<Uint8List> args) async {
  final aesGcm = AesGcm.with256bits();
  final secretBox = await aesGcm.encrypt(
    args[0],
    secretKey: SecretKey(args[1]),
  );
  return secretBox.concatenation();
}

Future<Uint8List> _decryptPayload(List<Uint8List> args) async {
  final aesGcm = AesGcm.with256bits();
  final secretBox = SecretBox.fromConcatenation(
    args[0],
    nonceLength: AesGcm.defaultNonceLength,
    macLength: AesGcm.aesGcmMac.macLength,
  );
  final clearText = await aesGcm.decrypt(
    secretBox,
    secretKey: SecretKey(args[1]),
  );
  return Uint8List.fromList(clearText);
}

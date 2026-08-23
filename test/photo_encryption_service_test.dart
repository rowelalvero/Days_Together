import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/services/photo_encryption_service.dart';

void main() {
  final service = PhotoEncryptionService.instance;

  Uint8List keyOf(int seed) => Uint8List.fromList(List.filled(32, seed));

  group('encryptBytes / decryptBytes', () {
    test('round trip returns the original plaintext', () async {
      final plaintext = Uint8List.fromList(
        List.generate(500, (i) => i % 256),
      );
      final key = keyOf(1);

      final ciphertext = await service.encryptBytes(plaintext, key);
      final decrypted = await service.decryptBytes(ciphertext, key);

      expect(decrypted, plaintext);
      // Ciphertext must not equal plaintext, and must carry the 12-byte
      // nonce + 16-byte GCM tag overhead on top of the payload length.
      expect(ciphertext, isNot(plaintext));
      expect(ciphertext.length, plaintext.length + 12 + 16);
    });

    test('two encryptions of the same bytes use different nonces', () async {
      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);
      final key = keyOf(2);

      final first = await service.encryptBytes(plaintext, key);
      final second = await service.encryptBytes(plaintext, key);

      expect(first, isNot(second));
    });

    test('decrypting with the wrong key throws', () async {
      final plaintext = Uint8List.fromList([9, 9, 9]);
      final ciphertext = await service.encryptBytes(plaintext, keyOf(3));

      expect(
        () => service.decryptBytes(ciphertext, keyOf(4)),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('large payloads (routed through compute/isolate) round-trip too', () async {
      final plaintext = Uint8List.fromList(
        List.generate(64 * 1024, (i) => i % 256),
      );
      final key = keyOf(5);

      final ciphertext = await service.encryptBytes(plaintext, key);
      final decrypted = await service.decryptBytes(ciphertext, key);

      expect(decrypted, plaintext);
    });
  });

  group('tryDecryptBytes', () {
    test('falls back to the original bytes for legacy plaintext photos', () async {
      // A photo uploaded before this feature existed: raw bytes, never
      // encrypted, too short/malformed to parse as a SecretBox concatenation
      // in general -- but the important guarantee is that whatever garbage
      // results, tryDecryptBytes never throws and never fabricates data.
      final legacyPlaintext = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2]);

      final result = await service.tryDecryptBytes(legacyPlaintext, keyOf(6));

      expect(result, legacyPlaintext);
    });

    test('still decrypts genuinely encrypted bytes normally', () async {
      final plaintext = Uint8List.fromList([1, 2, 3]);
      final key = keyOf(7);
      final ciphertext = await service.encryptBytes(plaintext, key);

      final result = await service.tryDecryptBytes(ciphertext, key);

      expect(result, plaintext);
    });
  });
}
